// ============================================================================
// CrystalReportWrapper - Program.cs
//
// PURPOSE
//   Crystal Reports only ships a .NET/COM SDK, so it cannot be called
//   directly from Python. This console app is a thin "worker" process:
//   it does the actual Crystal Reports SDK work (open report, set
//   parameters/data source, export), and talks to the outside world
//   using plain command-line args + JSON on stdout. A Python process
//   can then launch this exe as a subprocess and treat it like any
//   other CLI tool - no .NET runtime knowledge required on the Python side.
//
// EXECUTION FLOW
//   1. Parse CLI arguments (report path, output path, export format,
//      optional path to a JSON file containing report parameters).
//   2. Load the .rpt file into a Crystal Reports ReportDocument.
//   3. Apply parameter values (e.g. {"CustomerID": 42}) to the report.
//   4. Export the report to the requested format (PDF, Excel, CSV...).
//   5. Print a single JSON line to stdout describing success/failure.
//      Python reads and parses this line to know what happened.
//
// WHY JSON-ON-STDOUT
//   Using one JSON object as the only "contract" on stdout keeps the
//   interface stable even if we change internal C# logic later -
//   Python never needs to know about .NET types, only about the
//   {"status": ..., "output_path": ..., "error": ...} shape.
// ============================================================================

using System;
using System.Data;
using System.IO;
using System.Runtime.ExceptionServices;
using System.Text.Json;
using CrystalDecisions.CrystalReports.Engine;
using CrystalDecisions.Shared;
using Npgsql;
// Diagnostics on the C# Program, Loading, and DLL's
/*ReportDocument report = new ReportDocument();
report.Load(@".\RegionCodes.rpt");
// Quick Diagnostics on the RPT File

Console.WriteLine($"Database Table Count: {report.Database.Tables.Count}");
Console.WriteLine($"Formulas: {report.DataDefinition.FormulaFields.Count}");
foreach (CrystalDecisions.CrystalReports.Engine.Table table in report.Database.Tables){
    Console.WriteLine($"Table: {table.Name}");
    Console.WriteLine($"Location: {table.Location}");
   
    Console.WriteLine("---------------------------------------");
}*/
namespace CrystalReportWrapper
{
    /// <summary>
    /// Represents the outcome of a report export, serialized to stdout as
    /// JSON so the calling Python process can parse it without needing to
    /// understand any Crystal Reports-specific exception types.
    /// </summary>
    internal class ExportResult
    {
        public bool Success { get; set; }
        public string? OutputPath { get; set; }
        public string? Error { get; set; }
    }

    // ------------------------------------------------------------------
    // --inspect mode result types. These describe what a .rpt actually
    // expects from its data source (table names, field names/types,
    // formula text, parameters) so mismatches like column-name casing
    // or missing UFL functions can be diagnosed by reading a JSON
    // manifest instead of trial-and-error against export errors.
    // ------------------------------------------------------------------
    internal class FieldInfo
    {
        public string Name { get; set; } = string.Empty;
        public string ValueType { get; set; } = string.Empty;
    }

    internal class TableInfo
    {
        public string Name { get; set; } = string.Empty;
        public string Location { get; set; } = string.Empty;
        public System.Collections.Generic.List<FieldInfo> Fields { get; set; } = new();

        // Location is just a display label (e.g. "RegionCodes") - it does
        // NOT tell you which server/DSN/driver the table actually logs
        // into. That lives on Table.LogOnInfo.ConnectionInfo. We surface
        // it as a flat string dictionary (rather than modeling every
        // possible ConnectionInfo/Attributes shape) because the set of
        // keys differs by connection type (ODBC vs OLE DB vs ADO.NET) -
        // dumping whatever is actually present is more useful here than a
        // rigid schema.
        public System.Collections.Generic.Dictionary<string, string> Connection { get; set; } = new();
    }

    internal class FormulaInfo
    {
        public string Name { get; set; } = string.Empty;
        // Raw Crystal formula syntax text. Grep this for custom/UFL
        // function calls (e.g. "MFGFunctionsTranslationTranslate") that
        // won't exist on every machine the worker runs on.
        public string Text { get; set; } = string.Empty;
    }

    internal class ParameterInfo
    {
        public string Name { get; set; } = string.Empty;
        public string ValueKind { get; set; } = string.Empty;
    }

    internal class SubreportInfo
    {
        public string Name { get; set; } = string.Empty;
        public System.Collections.Generic.List<TableInfo> Tables { get; set; } = new();
        public System.Collections.Generic.List<FormulaInfo> Formulas { get; set; } = new();
        public System.Collections.Generic.List<ParameterInfo> Parameters { get; set; } = new();
    }

    internal class InspectResult
    {
        public bool Success { get; set; }
        public string ReportPath { get; set; } = string.Empty;
        public System.Collections.Generic.List<TableInfo> Tables { get; set; } = new();
        public System.Collections.Generic.List<FormulaInfo> Formulas { get; set; } = new();
        public System.Collections.Generic.List<ParameterInfo> Parameters { get; set; } = new();
        public System.Collections.Generic.List<SubreportInfo> Subreports { get; set; } = new();
        public string? Error { get; set; }
    }

    internal class Program
    {
        // ====================================================================
        // >>> DATABASE CONFIGURATION - EDIT THESE VALUES FOR YOUR POSTGRES <<<
        // ====================================================================
        // These are used to connect to Postgres directly from C# (via the
        // Npgsql driver), fetch the report's data as a DataTable, and hand
        // that table to Crystal Reports with SetDataSource(). Crystal never
        // talks to the database itself this way - no ODBC driver required,
        // which sidesteps the 32-bit/64-bit ODBC registration problems.
        //
        // Fill in your real values below:
        private const string PgHost = "127.0.0.1";        // <-- Postgres server hostname or IP
        private const string PgPort = "5234";              // <-- Postgres port (5432 is the default)
        private const string PgDatabase = "postgres"; // <-- database name
        private const string PgUser = "postgres";     // <-- database username
        private const string PgPassword = "engineer123"; // <-- database password

        // The SQL query that produces the rows the report should display.
        // Column names in this query's result set must match the field
        // names the report expects from its data source (set up in the
        // Crystal Designer under Database Expert -> ADO.NET (XML)).
        // Column aliases must match the report's field names exactly
        // (case-sensitive) - confirmed via --inspect: the report expects
        // "RegionCode" and "DescText", not "RegionName".
        private const string ReportQuery = @"SELECT regioncode AS ""RegionCode"", desctext AS ""DescText""  FROM regioncodes;"; // <-- your query here

        // Matches the table's Location ("RegionCodes") from --inspect.
        // Used as the DataTable's TableName below so Crystal's DataSet
        // binding matches it to the right report table by name rather
        // than relying on there only ever being one table.
        private const string ReportTableName = "RegionCodes";
        // ====================================================================

        /// <summary>
        /// Entry point. Expected usage:
        ///   CrystalReportWrapper.exe --report "C:\reports\sales.rpt"
        ///                             --output "C:\out\sales.pdf"
        ///                             --format PDF
        ///                             [--params "C:\out\params.json"]
        ///
        ///   CrystalReportWrapper.exe --report "C:\reports\sales.rpt" --inspect
        ///     (dumps the report's expected tables/fields/formulas/parameters
        ///      as JSON instead of exporting - no --output/--format needed)
        ///
        /// Exit code 0 = success, 1 = failure (mirrors the JSON "Success" flag
        /// so Python can also branch on subprocess return code alone).
        /// </summary>
        private static int Main(string[] args)
        {
            Console.WriteLine("Report Loaded Successfully");
            Console.WriteLine("====Main=====");
            Console.WriteLine($"Argument Count: {args.Length}");

            CliOptions options;
            try
            {
                options = ParseArgs(args);
            }
            catch (Exception ex)
            {
                EmitExportError(ex);
                return 1;
            }

            return options.Inspect ? RunInspect(options) : RunExportPipeline(options);
        }

        /// <summary>
        /// Original export flow: load report, fetch Postgres data, bind it,
        /// apply parameters, export to disk. Unchanged in behavior from
        /// before --inspect was added - just pulled out of Main so Main can
        /// dispatch between this and RunInspect.
        /// </summary>
        private static int RunExportPipeline(CliOptions options)
        {
            var result = new ExportResult();

            try
            {
                // --- 1. Load the report -----------------------------------
                if (!File.Exists(options.ReportPath))
                {
                    throw new FileNotFoundException($"Report file not found: {options.ReportPath}");
                }

                using var report = new ReportDocument();
                Console.WriteLine($"Report Path of Crystal Report RPT: {options.ReportPath}");
                report.Load(options.ReportPath);

                // --- 1b. Fetch data from Postgres and push it into the report ---
                // This replaces Crystal's own database connection entirely -
                // we run the query ourselves with Npgsql (a pure managed
                // .NET driver, no ODBC/COM dependency) and hand Crystal a
                // finished DataTable. The report's .rpt file must be
                // designed against an ADO.NET (XML) data source with a
                // matching schema for this to line up correctly.
                DataTable reportData = FetchReportData();
                reportData.TableName = ReportTableName;

                // Passing the bare DataTable to SetDataSource (even at
                // the ReportDocument level) doesn't fully take this table
                // off the .ttx codepath - Crystal can still fall back to
                // the table's original field-definition driver
                // (crdb_fielddef.dll) during export/render, and that
                // driver has no 64-bit build, which is what "Failed to
                // load database information" actually means here even
                // though SetDataSource itself doesn't throw. Wrapping the
                // DataTable in a DataSet routes Crystal through its
                // ADO.NET provider (crdb_adoplus.dll) end-to-end instead,
                // which is 64-bit and never touches the dead .ttx path.
                var reportDataSet = new DataSet();
                reportDataSet.Tables.Add(reportData);
                report.SetDataSource(reportDataSet);
                Console.WriteLine($"Table Count: {report.Database.Tables.Count}");
                foreach (CrystalDecisions.CrystalReports.Engine.Table t in report.Database.Tables)
                {
                    Console.WriteLine($"Table: {t.Name}");
                    foreach (var col in reportData.Columns)
                        Console.WriteLine($"  expects binding to: {t.Name}");
                }
                //Console.WriteLine($"Database Source: {report.Database.Tables}");

                // If the report has subreports that ALSO need data (as
                // opposed to just parameters), apply the same table - or a
                // different query's result, if each subreport needs its own
                // data - to each one here. Uncomment and adjust as needed:
                //
                // foreach (ReportDocument subreport in report.Subreports)
                // {
                //     subreport.SetDataSource(reportData);
                // }

                // --- 2. Apply parameters (if any were supplied) -----------
                if (!string.IsNullOrEmpty(options.ParamsJsonPath))
                {
                    ApplyParameters(report, options.ParamsJsonPath);
                }

                // --- 3. Export to the requested format ---------------------
                // Ensure the destination folder exists; ExportToDisk throws
                // DirectoryNotFoundException otherwise, which is an easy
                // thing to hit on first run before any output folder exists.
                string? outputDir = Path.GetDirectoryName(options.OutputPath);
                if (!string.IsNullOrEmpty(outputDir))
                {
                    Directory.CreateDirectory(outputDir);
                }

                ExportReport(report, options.OutputPath, options.Format);

                // --- 4. Report success back to Python ----------------------
                result.Success = true;
                result.OutputPath = options.OutputPath;
            }
            catch (Exception ex)
            {
                // Any failure (bad path, missing parameter, license issue,
                // etc.) is captured here so the process still exits cleanly
                // with a JSON error payload instead of an unhandled crash
                // dump that Python would have to scrape from stderr.
                result.Success = false;
                // TEMPORARY: walk the full InnerException chain instead of
                // just the outer message. ex.Message alone is too vague for
                // exceptions like TypeInitializationException, where the
                // real cause (missing COM registration, missing dependent
                // DLL, licensing, etc.) is buried in an inner exception.
                // Revert to `ex.Message` once the pipeline is working.
                result.Error = FlattenExceptionChain(ex);
            }

            // Always emit exactly one JSON line on stdout - this is the
            // single point of contact between C# and Python. camelCase
            // property naming matches typical JSON/Python conventions
            // (Success -> "success", OutputPath -> "outputPath").
            WriteJsonLine(result);

            return result.Success ? 0 : 1;
        }

        /// <summary>
        /// --inspect mode: loads the report but never touches Postgres or
        /// exports anything. Walks report.Database.Tables (and every
        /// subreport's tables), DataDefinition.FormulaFields, and
        /// DataDefinition.ParameterFields, and prints the whole thing as one
        /// JSON line - the same "one JSON line on stdout" contract as the
        /// export path, just a different payload shape.
        ///
        /// Point of this: instead of discovering a report's expected schema
        /// by iterating on export errors (wrong column name/case, wrong
        /// table count, formula calling a missing UFL, etc.), run this once
        /// per .rpt and get the actual contract the report was designed
        /// against, so mock/replacement tables can be built to match it.
        /// </summary>
        private static int RunInspect(CliOptions options)
        {
            var result = new InspectResult { ReportPath = options.ReportPath };

            try
            {
                if (!File.Exists(options.ReportPath))
                {
                    throw new FileNotFoundException($"Report file not found: {options.ReportPath}");
                }

                using var report = new ReportDocument();
                report.Load(options.ReportPath);

                result.Tables = InspectTables(report.Database.Tables);
                result.Formulas = InspectFormulas(report.DataDefinition.FormulaFields);
                result.Parameters = InspectParameters(
                    EnumerateParameterFields(report.DataDefinition.ParameterFields));

                foreach (ReportDocument subreport in report.Subreports)
                {
                    result.Subreports.Add(new SubreportInfo
                    {
                        Name = subreport.Name,
                        Tables = InspectTables(subreport.Database.Tables),
                        Formulas = InspectFormulas(subreport.DataDefinition.FormulaFields),
                        Parameters = InspectParameters(
                            EnumerateParameterFields(subreport.DataDefinition.ParameterFields))
                    });
                }

                result.Success = true;
            }
            catch (Exception ex)
            {
                result.Success = false;
                result.Error = FlattenExceptionChain(ex);
            }

            WriteJsonLine(result);
            return result.Success ? 0 : 1;
        }

        private static System.Collections.Generic.List<TableInfo> InspectTables(
            CrystalDecisions.CrystalReports.Engine.Tables tables)
        {
            var list = new System.Collections.Generic.List<TableInfo>();
            foreach (CrystalDecisions.CrystalReports.Engine.Table table in tables)
            {
                var info = new TableInfo
                {
                    Name = table.Name,
                    Location = table.Location
                };

                foreach (CrystalDecisions.CrystalReports.Engine.FieldDefinition field in table.Fields)
                {
                    info.Fields.Add(new FieldInfo
                    {
                        Name = field.Name,
                        ValueType = field.ValueType.ToString()
                    });
                }

                // ConnectionInfo is what actually decides which server/
                // database/driver Crystal tries to log into - this is
                // where "TTX" (or whatever the original data source is
                // called) shows up concretely, as opposed to Location
                // which is just the bare table name.
                ConnectionInfo connInfo = table.LogOnInfo.ConnectionInfo;
                info.Connection["ServerName"] = connInfo.ServerName ?? string.Empty;
                info.Connection["DatabaseName"] = connInfo.DatabaseName ?? string.Empty;
                info.Connection["UserID"] = connInfo.UserID ?? string.Empty;
                info.Connection["Type"] = connInfo.Type.ToString();
                info.Connection["IntegratedSecurity"] = connInfo.IntegratedSecurity.ToString();

                // Attributes is a free-form property bag; for ODBC/OLE DB
                // tables this is typically where the DSN name, provider,
                // and driver DLL actually live (e.g. "Data Source",
                // "Database DLL", "QE_ServerDescription"). Dump every
                // entry rather than guessing which keys exist.
                CollectConnectionAttributes(info.Connection, connInfo.Attributes, "Attr:");

                list.Add(info);
            }
            return list;
        }
        /// <summary>
        /// ConnectionInfo.Attributes is a DbConnectionAttributes - a thin
        /// wrapper, not itself a list. The actual entries live one level
        /// down, in DbConnectionAttributes.Collection, which is a
        /// NameValuePairs2 of NameValuePair2 (Name/Value) items accessed
        /// by Count + a 0-based indexer (not foreach - neither type
        /// exposes GetEnumerator, which is why a plain foreach over
        /// either one fails to compile). Some OLE DB connections nest a
        /// second DbConnectionAttributes inside a pair's Value for
        /// provider-specific settings, so this recurses into those and
        /// flattens them as "prefix.innerName" keys instead of printing
        /// an opaque object reference.
        /// </summary>
        private static void CollectConnectionAttributes(
            System.Collections.Generic.Dictionary<string, string> target,
            DbConnectionAttributes attributes,
            string prefix)
        {
            NameValuePairs2 pairs = attributes.Collection;
            for (int i = 0; i < pairs.Count; i++)
            {
                var pair = (NameValuePair2)pairs[i];
                if (pair.Value is DbConnectionAttributes nested)
                {
                    CollectConnectionAttributes(target, nested, $"{prefix}{pair.Name}.");
                }
                else
                {
                    target[$"{prefix}{pair.Name}"] = pair.Value?.ToString() ?? string.Empty;
                }
            }
        }

        private static System.Collections.Generic.List<FormulaInfo> InspectFormulas(
            FormulaFieldDefinitions formulas)
        {
            var list = new System.Collections.Generic.List<FormulaInfo>();
            foreach (FormulaFieldDefinition f in formulas)
            {
                list.Add(new FormulaInfo { Name = f.Name, Text = f.Text });
            }
            return list;
        }

        private static System.Collections.Generic.List<ParameterInfo> InspectParameters(
            System.Collections.Generic.IEnumerable<ParameterFieldDefinition> fields)
        {
            var list = new System.Collections.Generic.List<ParameterInfo>();
            foreach (ParameterFieldDefinition p in fields)
            {
                list.Add(new ParameterInfo { Name = p.Name, ValueKind = p.ParameterValueKind.ToString() });
            }
            return list;
        }

        /// <summary>
        /// Walks ex.InnerException down to the root cause and joins every
        /// level into one readable string, since the top-level message
        /// alone is often too vague (e.g. TypeInitializationException).
        /// </summary>
        private static string FlattenExceptionChain(Exception ex)
        {
            var messages = new System.Collections.Generic.List<string>();
            Exception? current = ex;
            while (current != null)
            {
                messages.Add($"{current.GetType().Name}: {current.Message}");
                current = current.InnerException;
            }
            return string.Join(" ---> ", messages);
        }

        private static void EmitExportError(Exception ex)
        {
            var result = new ExportResult { Success = false, Error = FlattenExceptionChain(ex) };
            WriteJsonLine(result);
        }

        private static void WriteJsonLine<T>(T payload)
        {
            var jsonOptions = new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            };
            Console.WriteLine(JsonSerializer.Serialize(payload, jsonOptions));
        }

        /// <summary>
        /// Minimal hand-rolled argument parser (kept dependency-free on
        /// purpose - this worker should build with nothing but the Crystal
        /// Reports SDK and the .NET base class library).
        /// </summary>
        private static CliOptions ParseArgs(string[] args)
        {
            var options = new CliOptions();

            for (int i = 0; i < args.Length; i++)
            {
                Console.WriteLine($"args[{i}] = {args[i]}");
                switch (args[i])
                {
                    case "--report":
                        options.ReportPath = args[++i];
                        break;
                    case "--output":
                        options.OutputPath = args[++i];
                        break;
                    case "--format":
                        options.Format = args[++i];
                        break;
                    case "--params":
                        options.ParamsJsonPath = args[++i];
                        break;
                    case "--inspect":
                        // Flag, not a key/value pair - takes no argument.
                        options.Inspect = true;
                        break;
                }
            }

            if (string.IsNullOrEmpty(options.ReportPath))
            {
                throw new ArgumentException("--report is a required argument.");
            }

            if (!options.Inspect && string.IsNullOrEmpty(options.OutputPath))
            {
                throw new ArgumentException("--report and --output are required arguments.");
            }

            return options;
        }

        /// <summary>
        /// Reads a flat JSON object (e.g. {"Region": "West", "Year": 2026})
        /// written by Python and pushes each value into the matching
        /// Crystal Reports parameter field. Crystal parameters are
        /// name-based, so the JSON keys must match the report's parameter
        /// names exactly (case-insensitive match is applied for convenience).
        /// </summary>
        private static void ApplyParameters(ReportDocument report, string paramsJsonPath)
        {
            if (!File.Exists(paramsJsonPath))
            {
                throw new FileNotFoundException($"Parameters file not found: {paramsJsonPath}");
            }

            string json = File.ReadAllText(paramsJsonPath);
            using var doc = JsonDocument.Parse(json);

            // ParameterFields on the top-level ReportDocument only covers
            // parameters defined on the MAIN report. Many .rpt files (this
            // one included) define their parameters on a subreport instead,
            // so a lookup that only checks report.DataDefinition.ParameterFields
            // finds nothing and every parameter appears "unknown" even
            // though the report does have them. Build one combined lookup
            // across the main report and every subreport.
            var allFields = new System.Collections.Generic.List<ParameterFieldDefinition>();
            allFields.AddRange(EnumerateParameterFields(report.DataDefinition.ParameterFields));
            foreach (ReportDocument subreport in report.Subreports)
            {
                allFields.AddRange(EnumerateParameterFields(subreport.DataDefinition.ParameterFields));
            }

            foreach (JsonProperty prop in doc.RootElement.EnumerateObject())
            {
                ParameterFieldDefinition? field = null;
                foreach (ParameterFieldDefinition candidate in allFields)
                {
                    if (string.Equals(candidate.Name.TrimStart('?'), prop.Name, StringComparison.OrdinalIgnoreCase))
                    {
                        field = candidate;
                        break;
                    }
                }

                if (field == null)
                {
                    string available = string.Join(", ", allFields.ConvertAll(f => f.Name));
                    throw new ArgumentException(
                        $"Report has no parameter named '{prop.Name}'. " +
                        $"Available parameters: {available}");
                }

                // ApplyCurrentValues expects a ParameterValues collection,
                // even for a single scalar value.
                var values = new ParameterValues();
                var discrete = new ParameterDiscreteValue
                {
                    Value = CoerceToParameterType(prop.Value, field)
                };
                values.Add(discrete);
                field.ApplyCurrentValues(values);
            }
        }

        private static System.Collections.Generic.IEnumerable<ParameterFieldDefinition> EnumerateParameterFields(
            ParameterFieldDefinitions definitions)
        {
            foreach (ParameterFieldDefinition d in definitions)
            {
                yield return d;
            }
        }

        /// <summary>
        /// Converts a System.Text.Json element into the specific CLR type
        /// Crystal expects for this parameter's declared type. Crystal is
        /// strict here: e.g. a parameter declared as DateTime rejects a
        /// plain string, and a Number-typed parameter expects a numeric
        /// type, not always double. ParameterValueKind tells us which
        /// conversion to apply.
        /// </summary>
        private static object CoerceToParameterType(JsonElement element, ParameterFieldDefinition field)
        {
            switch (field.ParameterValueKind)
            {
                case ParameterValueKind.NumberParameter:
                    return element.ValueKind == JsonValueKind.Number
                        ? element.GetDouble()
                        : double.Parse(element.GetString() ?? "0");

                case ParameterValueKind.CurrencyParameter:
                    return element.ValueKind == JsonValueKind.Number
                        ? (decimal)element.GetDouble()
                        : decimal.Parse(element.GetString() ?? "0");

                case ParameterValueKind.BooleanParameter:
                    return element.ValueKind switch
                    {
                        JsonValueKind.True => true,
                        JsonValueKind.False => false,
                        JsonValueKind.String => bool.Parse(element.GetString()!),
                        _ => throw new ArgumentException(
                            $"Parameter '{field.Name}' expects a boolean value.")
                    };

                case ParameterValueKind.DateParameter:
                case ParameterValueKind.DateTimeParameter:
                    // Accept ISO-8601 strings from Python (e.g. "2026-01-15"
                    // or "2026-01-15T00:00:00"); Crystal wants an actual
                    // DateTime instance, not a string.
                    string dateText = element.ValueKind == JsonValueKind.String
                        ? element.GetString()!
                        : element.ToString();
                    return DateTime.Parse(dateText, System.Globalization.CultureInfo.InvariantCulture);

                case ParameterValueKind.StringParameter:
                default:
                    // Fall back to string for text parameters and any kind
                    // we haven't special-cased (e.g. TimeParameter is rare
                    // enough not to be worth guessing at here).
                    return element.ValueKind == JsonValueKind.String
                        ? element.GetString()!
                        : element.ToString();
            }
        }

        /// <summary>
        /// Exports the loaded report to disk. Crystal's export API is
        /// format-driven via ExportFormatType; we map a small set of
        /// human-friendly strings (as sent from Python) onto that enum.
        /// </summary>
        private static void ExportReport(ReportDocument report, string outputPath, string format)
        {
            ExportFormatType exportType = format.ToUpperInvariant() switch
            {
                "PDF" => ExportFormatType.PortableDocFormat,
                "EXCEL" or "XLSX" => ExportFormatType.ExcelWorkbook,
                "CSV" => ExportFormatType.CharacterSeparatedValues,
                "WORD" or "DOCX" => ExportFormatType.WordForWindows,
                _ => throw new NotSupportedException($"Unsupported export format: {format}")
            };

            report.ExportToDisk(exportType, outputPath);
        }

        /// <summary>
        /// Connects to Postgres using the configuration constants at the top
        /// of this file, runs ReportQuery, and returns the results as a
        /// DataTable ready to hand to Crystal via ReportDocument.SetDataSource.
        /// </summary>
        private static DataTable FetchReportData()
        {
            
            // Builds a connection string from the constants above. Npgsql's
            // connection string keys are: Host, Port, Database, Username,
            // Password - see https://www.npgsql.org/doc/connection-string-parameters.html
            // for additional options (SSL Mode, Timeout, etc.) if your setup
            // needs them.
            string connectionString =
                $"Host={PgHost};Port={PgPort};Database={PgDatabase};" +
                $"Username={PgUser};Password={PgPassword};";

            using var connection = new NpgsqlConnection(connectionString);
            connection.Open();

            using var command = new NpgsqlCommand(ReportQuery, connection);
            using var adapter = new NpgsqlDataAdapter(command);

            var table = new DataTable();
            adapter.Fill(table);
            
            Console.WriteLine($"Rows: {table.Rows.Count}");
            return table;
        }


        private class CliOptions
        {
            public string ReportPath { get; set; } = string.Empty;
            public string OutputPath { get; set; } = string.Empty;
            public string Format { get; set; } = "PDF";
            public string? ParamsJsonPath { get; set; }
            public bool Inspect { get; set; } = false;
        }
    }
}