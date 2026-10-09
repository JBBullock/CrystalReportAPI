// ============================================================================
// CrystalReportWrapper - Program.cs
//
// Renders one Crystal Report to PDF. Stateless: one request in on stdin, one
// PDF out on stdout, nothing written to disk and nothing kept between runs.
//
// CONTRACT (the only caller is pythonScripts/report_service.py)
//   stdin   one JSON object:
//             {
//               "reportPath": "C:\\app\\reports\\SalesOrder.rpt",
//               "sqlPath":    "C:\\app\\SQLqueries\\SalesOrder.sql",
//               "port":       5430,
//               "filter":     {"sonumber": 1234, "orderdate": {">=": "2026-01-01"}},
//               "parameters": {"CompanyName": "...", "QuantityDecimals": 2}
//             }
//   stdout  exit code 0: the PDF bytes, and nothing else.
//           exit code 1 or 2: one JSON object, {"error": "..."}.
//   stderr  diagnostics only. Never parsed by the caller.
//   exit    0 = rendered, 1 = failed, 2 = the request itself was wrong
//           (a malformed filter, or a filter column that no table in the
//           report has).
//
// The filter's forms - equals, wildcards, operators, dates - are described
// in ReportFilter.cs.
//
// Postgres host, database, user and password come from this process's
// environment (PG_HOST, PG_DATABASE, PG_USER, PG_PASSWORD). The port is the
// only connection value taken from the request.
//
// FLOW (see Render)
//   1. Load the .rpt.
//      Replace calls to the legacy program's label function with plain
//      text (see ReportFormulas.cs), and its alternate-row colour rule with
//      a plain one (see ReportColors.cs).
//   2. Read the report's .sql file: one query per Crystal table.
//   3. Run each query against Postgres, narrowed by the filter.
//   4. Hand the rows to Crystal.
//   5. Set the report's parameters.
//   6. Export to PDF in memory.
//
// Running the exe WITH arguments is a developer tool, not part of the
// service: see DevTools.cs (--inspect, --extract-sql).
// ============================================================================

using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.IO;
using System.Text.Json;
using CrystalDecisions.CrystalReports.Engine;
using CrystalDecisions.Shared;
using Npgsql;
using CrystalTable = CrystalDecisions.CrystalReports.Engine.Table;

namespace CrystalReportWrapper
{
    /// <summary>One render request, exactly as read from stdin.</summary>
    internal sealed class RenderRequest
    {
        public string ReportPath;
        public string SqlPath;
        public int Port;
        // Empty means "the whole report". See ReportFilter.cs.
        public List<FilterCondition> Filter = new List<FilterCondition>();
        // Parameter name -> value, matched to the report's own parameters by name.
        public Dictionary<string, JsonElement> Parameters =
            new Dictionary<string, JsonElement>(StringComparer.OrdinalIgnoreCase);
    }

    /// <summary>The caller asked for something this report cannot do (exit code 2).</summary>
    internal sealed class BadRequestException : Exception
    {
        public BadRequestException(string message) : base(message) { }
    }

    internal static class Program
    {
        private const int ExitRendered = 0;
        private const int ExitFailed = 1;
        private const int ExitBadRequest = 2;

        private static int Main(string[] args)
        {
            if (args.Length > 0)
            {
                return DevTools.Run(args);
            }

            // stdout carries the PDF, so nothing else may write to it: take the
            // raw stream first, then point every Console.Write at stderr.
            Stream stdout = Console.OpenStandardOutput();
            Console.SetOut(Console.Error);

            try
            {
                RenderRequest request = ReadRequest(Console.OpenStandardInput());
                byte[] pdf = Render(request);
                stdout.Write(pdf, 0, pdf.Length);
                stdout.Flush();
                return ExitRendered;
            }
            catch (BadRequestException ex)
            {
                WriteError(stdout, ex.Message);
                return ExitBadRequest;
            }
            catch (Exception ex)
            {
                WriteError(stdout, FlattenExceptionChain(ex));
                return ExitFailed;
            }
        }

        // ====================================================================
        // The flow
        // ====================================================================

        private static byte[] Render(RenderRequest request)
        {
            if (!File.Exists(request.ReportPath))
            {
                throw new FileNotFoundException("Report file not found: " + request.ReportPath);
            }

            using (var report = new ReportDocument())
            {
                // 1. Load the .rpt. It names the tables it needs.
                report.Load(request.ReportPath);
                // The labels come from a legacy add-on this machine may not have.
                ReportFormulas.ReplaceLegacyFunctions(report);
                // ...and so does the alternate-row shading rule.
                ReportColors.ReplaceLegacyColorRules(report, request.Parameters);
                List<string> tableNames = TableNames(report);

                // 2. One query per table, from the report's .sql file.
                Dictionary<string, string> queries = ReportSql.Load(request.SqlPath, tableNames);

                // 3. Run them, narrowed by the filter.
                using (DataSet data = FetchData(request.Port, tableNames, queries, request.SqlPath, request.Filter))
                {
                    // 4. Hand the rows to Crystal.
                    BindData(report, data);

                    // 5. Set the report's parameters.
                    ApplyParameters(report, request.Parameters, request.Filter);

                    // 6. Export.
                    return ExportPdf(report);
                }
            }
        }

        // ====================================================================
        // Request in, error out
        // ====================================================================

        private static RenderRequest ReadRequest(Stream stdin)
        {
            using (JsonDocument doc = JsonDocument.Parse(stdin))
            {
                JsonElement root = doc.RootElement;
                var request = new RenderRequest
                {
                    ReportPath = RequiredString(root, "reportPath"),
                    SqlPath = RequiredString(root, "sqlPath"),
                };

                if (!root.TryGetProperty("port", out JsonElement port)
                    || port.ValueKind != JsonValueKind.Number
                    || !port.TryGetInt32(out int portNumber))
                {
                    throw new ArgumentException("Request needs an integer 'port'.");
                }
                request.Port = portNumber;

                if (root.TryGetProperty("filter", out JsonElement filter) && filter.ValueKind == JsonValueKind.Object)
                {
                    request.Filter = ReportFilter.Parse(filter);
                }
                // Clone(): the values must outlive this JsonDocument.
                if (root.TryGetProperty("parameters", out JsonElement parameters) && parameters.ValueKind == JsonValueKind.Object)
                {
                    foreach (JsonProperty p in parameters.EnumerateObject())
                    {
                        request.Parameters[p.Name] = p.Value.Clone();
                    }
                }
                return request;
            }
        }

        private static string RequiredString(JsonElement root, string name)
        {
            if (root.TryGetProperty(name, out JsonElement value) && value.ValueKind == JsonValueKind.String)
            {
                string text = value.GetString();
                if (!string.IsNullOrWhiteSpace(text))
                {
                    return text;
                }
            }
            throw new ArgumentException("Request needs a '" + name + "' string.");
        }

        private static void WriteError(Stream stdout, string message)
        {
            Console.Error.WriteLine("ERROR: " + message);
            byte[] json = JsonSerializer.SerializeToUtf8Bytes(new Dictionary<string, string> { { "error", message } });
            stdout.Write(json, 0, json.Length);
            stdout.Flush();
        }

        /// <summary>
        /// Joins every InnerException message into one line. The outer message
        /// alone is often useless with Crystal (TypeInitializationException,
        /// "Failed to load database information", ...).
        /// </summary>
        internal static string FlattenExceptionChain(Exception ex)
        {
            var messages = new List<string>();
            for (Exception current = ex; current != null; current = current.InnerException)
            {
                messages.Add(current.GetType().Name + ": " + current.Message);
            }
            return string.Join(" ---> ", messages);
        }

        // ====================================================================
        // Steps 1-2: what the report needs
        // ====================================================================

        private static List<string> TableNames(ReportDocument report)
        {
            var names = new List<string>();
            foreach (CrystalTable table in report.Database.Tables)
            {
                names.Add(table.Name);
            }
            return names;
        }

        // ====================================================================
        // Step 3: Postgres
        // ====================================================================

        /// <summary>One table's query, ready to run.</summary>
        private sealed class TableFetch
        {
            public string TableName;
            public string Sql;
            public List<NpgsqlParameter> SqlParameters = new List<NpgsqlParameter>();
            public List<string> FilteredOn = new List<string>();
        }

        /// <summary>
        /// Connects once, then for every table the report needs: asks
        /// Postgres which columns the table's query returns, applies the
        /// filter conditions that table has a column for, and fetches the rows.
        ///
        /// A condition applies to every table whose query returns a column
        /// of that name (compared without regard to case - callers send the
        /// database's lowercase name, the queries alias columns in the
        /// report's mixed case). Tables without the column are fetched whole.
        /// A column that NO table has is an error: returning an unfiltered
        /// report for a filtered request would be a wrong answer.
        /// </summary>
        private static DataSet FetchData(
            int port,
            List<string> tableNames,
            Dictionary<string, string> queries,
            string sqlPath,
            List<FilterCondition> filter)
        {
            var connectionString = new NpgsqlConnectionStringBuilder
            {
                Host = RequiredEnvironment("PG_HOST"),
                Port = port,
                Database = RequiredEnvironment("PG_DATABASE"),
                Username = RequiredEnvironment("PG_USER"),
                Password = RequiredEnvironment("PG_PASSWORD"),
            }.ConnectionString;

            using (var connection = new NpgsqlConnection(connectionString))
            {
                connection.Open();

                // Plan every table before fetching any, so a bad filter is
                // reported without first pulling whole tables.
                var fetches = new List<TableFetch>();
                var unmatched = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach (FilterCondition condition in filter)
                {
                    unmatched.Add(condition.Column);
                }
                foreach (string tableName in tableNames)
                {
                    if (!queries.TryGetValue(tableName, out string query))
                    {
                        throw new InvalidOperationException(
                            "Report requires table '" + tableName + "', which has no query in " + sqlPath +
                            ". Add one under a '-- Table: " + tableName + "' line.");
                    }

                    TableFetch fetch = PlanFetch(connection, tableName, query, filter);
                    unmatched.ExceptWith(fetch.FilteredOn);
                    fetches.Add(fetch);
                }

                if (unmatched.Count > 0)
                {
                    throw new BadRequestException(
                        "Filter column(s) not found in any table of this report: " +
                        string.Join(", ", unmatched) + ".");
                }

                var data = new DataSet();
                foreach (TableFetch fetch in fetches)
                {
                    using (var command = new NpgsqlCommand(fetch.Sql, connection))
                    {
                        command.Parameters.AddRange(fetch.SqlParameters.ToArray());
                        using (var adapter = new NpgsqlDataAdapter(command))
                        {
                            // Crystal matches a DataTable to a report table by name.
                            var table = new DataTable(fetch.TableName);
                            adapter.Fill(table);
                            data.Tables.Add(table);
                            Console.WriteLine(
                                "Table '" + fetch.TableName + "': " + table.Rows.Count + " row(s)" +
                                (fetch.FilteredOn.Count > 0 ? ", filtered on " + string.Join(", ", fetch.FilteredOn) : ""));
                        }
                    }
                }
                return data;
            }
        }

        private static string RequiredEnvironment(string name)
        {
            string value = Environment.GetEnvironmentVariable(name);
            if (string.IsNullOrEmpty(value))
            {
                throw new InvalidOperationException("Environment variable " + name + " is not set.");
            }
            return value;
        }

        /// <summary>
        /// Builds the SQL for one table. With no applicable filter condition
        /// that is the query as written. Otherwise the query is wrapped as a
        /// subquery with a parameterized WHERE, so its own text is never
        /// edited and a filter value can never become part of the SQL.
        /// </summary>
        private static TableFetch PlanFetch(
            NpgsqlConnection connection,
            string tableName,
            string query,
            List<FilterCondition> filter)
        {
            var fetch = new TableFetch { TableName = tableName, Sql = query };
            if (filter.Count == 0)
            {
                return fetch;
            }

            List<KeyValuePair<string, Type>> columns = QueryColumns(connection, query);
            var conditions = new List<string>();
            foreach (FilterCondition condition in filter)
            {
                foreach (KeyValuePair<string, Type> column in columns)
                {
                    if (!string.Equals(column.Key, condition.Column, StringComparison.OrdinalIgnoreCase))
                    {
                        continue;
                    }
                    conditions.Add(ReportFilter.ToSql(condition, column.Key, column.Value, fetch.SqlParameters));
                    if (!fetch.FilteredOn.Contains(column.Key)) fetch.FilteredOn.Add(column.Key);
                    break;
                }
            }

            if (conditions.Count > 0)
            {
                // The query sits on its own lines so a trailing "-- comment"
                // in it cannot swallow the closing parenthesis.
                fetch.Sql = "SELECT * FROM (\n" + query + "\n) AS filtered WHERE " + string.Join(" AND ", conditions);
            }
            return fetch;
        }

        /// <summary>
        /// The columns a query returns - name as spelled, and CLR type - asked
        /// of Postgres itself (schema only: no rows are read).
        /// </summary>
        private static List<KeyValuePair<string, Type>> QueryColumns(NpgsqlConnection connection, string query)
        {
            var columns = new List<KeyValuePair<string, Type>>();
            using (var command = new NpgsqlCommand(query, connection))
            using (NpgsqlDataReader reader = command.ExecuteReader(CommandBehavior.SchemaOnly))
            {
                for (int i = 0; i < reader.FieldCount; i++)
                {
                    columns.Add(new KeyValuePair<string, Type>(reader.GetName(i), reader.GetFieldType(i)));
                }
            }
            return columns;
        }

        // ====================================================================
        // Step 4: bind
        // ====================================================================

        /// <summary>
        /// Replaces the report's own data connection with the fetched rows.
        /// Both calls are needed for the legacy reports: the whole-DataSet
        /// call routes Crystal through its ADO.NET provider, and the per-table
        /// call is what actually detaches a table from its original
        /// field-definition (.ttx) source, which no longer exists. Without the
        /// second, Export fails with a logon error.
        /// </summary>
        private static void BindData(ReportDocument report, DataSet data)
        {
            report.SetDataSource(data);
            foreach (CrystalTable table in report.Database.Tables)
            {
                table.SetDataSource(data.Tables[table.Name]);
            }
        }

        // ====================================================================
        // Step 5: parameters
        // ====================================================================

        /// <summary>
        /// Gives every parameter the report defines (main report and
        /// subreports) its value from the request, matched by name without
        /// regard to case. Values the report doesn't use are ignored. A
        /// parameter with no value fails here, by name, rather than as a
        /// vague "missing parameter values" from Crystal at export time.
        /// Subreport parameters linked to a main-report field are skipped -
        /// Crystal fills those itself.
        ///
        /// A parameter the request's parameters don't name is next looked up
        /// in the filter: a plain "equals" condition on a column of the same
        /// name (e.g. {"workcenterid": "WC01"} supplies ?WorkCenterID). If
        /// that finds nothing either, a parameter listed in
        /// BlankWhenAbsent gets an empty value instead of failing.
        /// </summary>
        private static void ApplyParameters(
            ReportDocument report, Dictionary<string, JsonElement> values, List<FilterCondition> filter)
        {
            var fields = new List<ParameterFieldDefinition>();
            foreach (ParameterFieldDefinition field in report.DataDefinition.ParameterFields)
            {
                fields.Add(field);
            }
            foreach (ReportDocument subreport in report.Subreports)
            {
                foreach (ParameterFieldDefinition field in subreport.DataDefinition.ParameterFields)
                {
                    fields.Add(field);
                }
            }

            var missing = new List<string>();
            foreach (ParameterFieldDefinition field in fields)
            {
                if (field.IsLinked())
                {
                    continue;
                }

                string name = field.Name.TrimStart('?');
                if (!values.TryGetValue(name, out JsonElement value)
                    && !TryValueFromFilter(filter, name, out value)
                    && !TryBlankValue(name, out value))
                {
                    if (!missing.Contains(name)) missing.Add(name);
                    continue;
                }

                // ApplyCurrentValues takes a collection even for one value.
                var current = new ParameterValues();
                current.Add(new ParameterDiscreteValue { Value = CoerceToParameterType(value, field) });
                field.ApplyCurrentValues(current);
            }

            if (missing.Count > 0)
            {
                throw new InvalidOperationException(
                    "Report needs parameter(s) the service has no value for: " + string.Join(", ", missing) +
                    ". Add them to global_report_parameters.json.");
            }
        }

        /// <summary>
        /// Report parameters only a person could choose, which the original
        /// program asked for in a prompt. When neither the request's
        /// parameters nor its filter supplies one, it is sent blank rather
        /// than failing the render. (Work Center Loads / Loads Graph:
        /// WorkCenterID - TODO.md item 2; Tax Codes: TaxCode and LiabilityAccount.)
        /// </summary>
        private static readonly HashSet<string> BlankWhenAbsent =
            new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "WorkCenterID",                 // Work Center Loads (+ Graph)
                "TaxCode", "LiabilityAccount",  // Tax Codes (Codes menu)
            };

        /// <summary>
        /// The value of a single "equals" filter condition on a column named
        /// like the parameter (case ignored). A wildcard or a range is not a
        /// single value, so it doesn't count.
        /// </summary>
        private static bool TryValueFromFilter(List<FilterCondition> filter, string name, out JsonElement value)
        {
            value = default(JsonElement);
            if (filter == null)
            {
                return false;
            }
            foreach (FilterCondition condition in filter)
            {
                if (condition.Operator != "="
                    || !string.Equals(condition.Column, name, StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }
                if (condition.Value.ValueKind == JsonValueKind.String)
                {
                    string text = condition.Value.GetString() ?? string.Empty;
                    if (text.IndexOf('*') >= 0 || text.IndexOf('?') >= 0)
                    {
                        continue;
                    }
                }
                value = condition.Value;
                return true;
            }
            return false;
        }

        private static bool TryBlankValue(string name, out JsonElement value)
        {
            value = default(JsonElement);
            if (!BlankWhenAbsent.Contains(name))
            {
                return false;
            }
            using (JsonDocument blank = JsonDocument.Parse("\"\""))
            {
                value = blank.RootElement.Clone();
            }
            return true;
        }

        /// <summary>
        /// Crystal is strict about parameter types: a Date parameter rejects a
        /// string, a Number parameter wants a double.
        /// </summary>
        private static object CoerceToParameterType(JsonElement element, ParameterFieldDefinition field)
        {
            string text = element.ValueKind == JsonValueKind.String ? element.GetString() : element.GetRawText();
            switch (field.ParameterValueKind)
            {
                case ParameterValueKind.NumberParameter:
                    return double.Parse(text, CultureInfo.InvariantCulture);

                case ParameterValueKind.CurrencyParameter:
                    return decimal.Parse(text, CultureInfo.InvariantCulture);

                case ParameterValueKind.BooleanParameter:
                    return bool.Parse(text);

                case ParameterValueKind.DateParameter:
                case ParameterValueKind.DateTimeParameter:
                    return DateTime.Parse(text, CultureInfo.InvariantCulture);

                default:
                    return text;
            }
        }

        // ====================================================================
        // Step 6: export
        // ====================================================================

        private static byte[] ExportPdf(ReportDocument report)
        {
            using (Stream exported = report.ExportToStream(ExportFormatType.PortableDocFormat))
            using (var buffer = new MemoryStream())
            {
                if (exported.CanSeek)
                {
                    exported.Seek(0, SeekOrigin.Begin);
                }
                exported.CopyTo(buffer);
                return buffer.ToArray();
            }
        }
    }
}
