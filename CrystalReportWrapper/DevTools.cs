// ============================================================================
// DevTools.cs - developer tools. NOT part of the report service.
//
// The service runs the exe with no arguments (see Program.cs). Running it
// WITH arguments, by hand, reaches these two tools for setting up a report:
//
//   CrystalReportWrapper.exe --report "C:\reports\sales.rpt" --inspect
//       Prints the tables, fields, formulas and parameters the report
//       expects, as one JSON line. Touches neither Postgres nor disk.
//
//   CrystalReportWrapper.exe --report "C:\reports\sales.rpt" --extract-sql
//                            [--sql-out-dir "C:\RPTConvert\SQLqueries"]
//       Writes/refreshes <sql-out-dir>\sales.sql. Queries already in the
//       file are kept. A table with no query yet gets a commented-out
//       skeleton listing the columns the report expects. This is the one
//       place the exe writes a file. --sql-out-dir defaults to a SQLqueries
//       folder beside the report's own folder.
//
// Both print one JSON line on stdout and exit 0 (success) or 1 (failure).
// ============================================================================

using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.Json;
using CrystalDecisions.CrystalReports.Engine;
using CrystalDecisions.Shared;
using CrystalTable = CrystalDecisions.CrystalReports.Engine.Table;
using CrystalTables = CrystalDecisions.CrystalReports.Engine.Tables;
using CrystalField = CrystalDecisions.CrystalReports.Engine.FieldDefinition;

namespace CrystalReportWrapper
{
    internal class FieldInfo
    {
        public string Name { get; set; } = string.Empty;
        public string ValueType { get; set; } = string.Empty;
    }

    internal class TableInfo
    {
        public string Name { get; set; } = string.Empty;
        public string Location { get; set; } = string.Empty;
        public List<FieldInfo> Fields { get; set; } = new List<FieldInfo>();
        // The table's original design-time connection (server, driver, ...).
        public Dictionary<string, string> Connection { get; set; } = new Dictionary<string, string>();
    }

    internal class FormulaInfo
    {
        public string Name { get; set; } = string.Empty;
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
        public List<TableInfo> Tables { get; set; } = new List<TableInfo>();
        public List<FormulaInfo> Formulas { get; set; } = new List<FormulaInfo>();
        public List<ParameterInfo> Parameters { get; set; } = new List<ParameterInfo>();
    }

    internal class InspectResult
    {
        public bool Success { get; set; }
        public string ReportPath { get; set; } = string.Empty;
        public List<TableInfo> Tables { get; set; } = new List<TableInfo>();
        public List<FormulaInfo> Formulas { get; set; } = new List<FormulaInfo>();
        public List<ParameterInfo> Parameters { get; set; } = new List<ParameterInfo>();
        public List<SubreportInfo> Subreports { get; set; } = new List<SubreportInfo>();
        public string Error { get; set; }
    }

    internal class ExtractSqlResult
    {
        public bool Success { get; set; }
        public string ReportPath { get; set; } = string.Empty;
        public string SqlPath { get; set; }
        // Every table the report (and its subreports) expects, in order.
        public List<string> Tables { get; set; } = new List<string>();
        // Tables the .sql file already had a query for.
        public List<string> MatchedTables { get; set; } = new List<string>();
        // Tables with no query yet - a commented-out skeleton was written.
        public List<string> MissingTables { get; set; } = new List<string>();
        // True when the .sql file existed with different content and was
        // copied to <name>.sql.bak before being overwritten.
        public bool BackedUp { get; set; }
        public string Error { get; set; }
    }

    internal static class DevTools
    {
        internal static int Run(string[] args)
        {
            string reportPath = null;
            string sqlOutDir = null;
            bool inspect = false;
            bool extractSql = false;

            for (int i = 0; i < args.Length; i++)
            {
                switch (args[i])
                {
                    case "--report": reportPath = i + 1 < args.Length ? args[++i] : null; break;
                    case "--sql-out-dir": sqlOutDir = i + 1 < args.Length ? args[++i] : null; break;
                    case "--inspect": inspect = true; break;
                    case "--extract-sql": extractSql = true; break;
                }
            }

            if (string.IsNullOrEmpty(reportPath) || inspect == extractSql)
            {
                Console.Error.WriteLine(
                    "Usage: CrystalReportWrapper.exe --report <file.rpt> --inspect\n" +
                    "       CrystalReportWrapper.exe --report <file.rpt> --extract-sql [--sql-out-dir <folder>]\n" +
                    "With no arguments the exe is the report service worker: it reads one JSON\n" +
                    "request on stdin and writes the PDF to stdout (see Program.cs).");
                return 1;
            }

            return inspect ? RunInspect(reportPath) : RunExtractSql(reportPath, sqlOutDir);
        }

        // ====================================================================
        // --inspect
        // ====================================================================

        private static int RunInspect(string reportPath)
        {
            var result = new InspectResult { ReportPath = reportPath };
            try
            {
                if (!File.Exists(reportPath))
                {
                    throw new FileNotFoundException("Report file not found: " + reportPath);
                }

                using (var report = new ReportDocument())
                {
                    report.Load(reportPath);

                    result.Tables = InspectTables(report.Database.Tables);
                    result.Formulas = InspectFormulas(report.DataDefinition.FormulaFields);
                    result.Parameters = InspectParameters(report.DataDefinition.ParameterFields);

                    foreach (ReportDocument subreport in report.Subreports)
                    {
                        result.Subreports.Add(new SubreportInfo
                        {
                            Name = subreport.Name,
                            Tables = InspectTables(subreport.Database.Tables),
                            Formulas = InspectFormulas(subreport.DataDefinition.FormulaFields),
                            Parameters = InspectParameters(subreport.DataDefinition.ParameterFields)
                        });
                    }
                }
                result.Success = true;
            }
            catch (Exception ex)
            {
                result.Success = false;
                result.Error = Program.FlattenExceptionChain(ex);
            }

            WriteJsonLine(result);
            return result.Success ? 0 : 1;
        }

        private static List<TableInfo> InspectTables(CrystalTables tables)
        {
            var list = new List<TableInfo>();
            foreach (CrystalTable table in tables)
            {
                var info = new TableInfo { Name = table.Name, Location = table.Location };

                foreach (CrystalField field in table.Fields)
                {
                    info.Fields.Add(new FieldInfo { Name = field.Name, ValueType = field.ValueType.ToString() });
                }

                ConnectionInfo connInfo = table.LogOnInfo.ConnectionInfo;
                info.Connection["ServerName"] = connInfo.ServerName ?? string.Empty;
                info.Connection["DatabaseName"] = connInfo.DatabaseName ?? string.Empty;
                info.Connection["UserID"] = connInfo.UserID ?? string.Empty;
                info.Connection["Type"] = connInfo.Type.ToString();
                info.Connection["IntegratedSecurity"] = connInfo.IntegratedSecurity.ToString();
                CollectConnectionAttributes(info.Connection, connInfo.Attributes, "Attr:");

                list.Add(info);
            }
            return list;
        }

        /// <summary>
        /// ConnectionInfo.Attributes is a wrapper; its entries live in
        /// .Collection, a NameValuePairs2 reached by Count + indexer (it has
        /// no enumerator). A pair's value can itself be a nested
        /// DbConnectionAttributes, flattened here as "prefix.innerName".
        /// </summary>
        private static void CollectConnectionAttributes(
            Dictionary<string, string> target,
            DbConnectionAttributes attributes,
            string prefix)
        {
            NameValuePairs2 pairs = attributes.Collection;
            for (int i = 0; i < pairs.Count; i++)
            {
                var pair = (NameValuePair2)pairs[i];
                if (pair.Value is DbConnectionAttributes nested)
                {
                    CollectConnectionAttributes(target, nested, prefix + pair.Name + ".");
                }
                else
                {
                    target[prefix + pair.Name] = pair.Value?.ToString() ?? string.Empty;
                }
            }
        }

        private static List<FormulaInfo> InspectFormulas(FormulaFieldDefinitions formulas)
        {
            var list = new List<FormulaInfo>();
            foreach (FormulaFieldDefinition f in formulas)
            {
                list.Add(new FormulaInfo { Name = f.Name, Text = f.Text });
            }
            return list;
        }

        private static List<ParameterInfo> InspectParameters(ParameterFieldDefinitions fields)
        {
            var list = new List<ParameterInfo>();
            foreach (ParameterFieldDefinition p in fields)
            {
                list.Add(new ParameterInfo { Name = p.Name, ValueKind = p.ParameterValueKind.ToString() });
            }
            return list;
        }

        // ====================================================================
        // --extract-sql
        // ====================================================================

        /// <summary>
        /// The legacy reports are "Field Definitions Only" (TTX) reports:
        /// the .rpt describes the columns it expects and stores no SQL. So
        /// this cannot extract a query - it writes the file layout the
        /// service reads, keeps every query already in the file, and adds a
        /// column skeleton for each table that has none yet.
        /// </summary>
        private static int RunExtractSql(string reportPath, string sqlOutDir)
        {
            var result = new ExtractSqlResult { ReportPath = reportPath };
            try
            {
                if (!File.Exists(reportPath))
                {
                    throw new FileNotFoundException("Report file not found: " + reportPath);
                }

                using (var report = new ReportDocument())
                {
                    report.Load(reportPath);

                    // Main report's tables, then each subreport's; first-seen
                    // order, repeats dropped.
                    var tables = new List<CrystalTable>();
                    var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                    foreach (CrystalTable t in report.Database.Tables)
                    {
                        if (seen.Add(t.Name)) tables.Add(t);
                    }
                    foreach (ReportDocument subreport in report.Subreports)
                    {
                        foreach (CrystalTable t in subreport.Database.Tables)
                        {
                            if (seen.Add(t.Name)) tables.Add(t);
                        }
                    }

                    // A report with no data tables needs no file.
                    if (tables.Count == 0)
                    {
                        result.Success = true;
                        WriteJsonLine(result);
                        return 0;
                    }

                    string reportName = Path.GetFileNameWithoutExtension(reportPath);
                    string outDir = ResolveSqlOutDir(reportPath, sqlOutDir);
                    string sqlPath = Path.Combine(outDir, reportName + ".sql");
                    List<string> tableNames = tables.ConvertAll(t => t.Name);

                    Dictionary<string, string> existingQueries = File.Exists(sqlPath)
                        ? ReportSql.Load(sqlPath, tableNames)
                        : new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

                    const string nl = "\r\n";
                    const string rule = "-- ----------------------------------------------------------------------------";
                    var sb = new StringBuilder();

                    // ---- File header ------------------------------------------
                    // No timestamp: re-running on an unchanged report must
                    // produce an identical file.
                    sb.Append("-- ============================================================================").Append(nl);
                    sb.Append("-- " + reportName + ".sql").Append(nl);
                    sb.Append("-- Written for " + Path.GetFileName(reportPath) + " by CrystalReportWrapper --extract-sql.").Append(nl);
                    sb.Append("-- CrystalReportWrapper runs the queries in this file at render time - edit").Append(nl);
                    sb.Append("-- them here. One query per '-- Table: <name>' line; aliases must match the").Append(nl);
                    sb.Append("-- report's field names exactly (case-sensitive).").Append(nl);
                    sb.Append("-- Tables: " + string.Join(", ", tableNames)).Append(nl);

                    List<ParameterInfo> parameters = InspectParameters(report.DataDefinition.ParameterFields);
                    if (parameters.Count > 0)
                    {
                        sb.Append("-- Report parameters:").Append(nl);
                        foreach (ParameterInfo p in parameters)
                        {
                            sb.Append("--   " + p.Name + " (" + p.ValueKind + ")").Append(nl);
                        }
                    }

                    string selectionFormula = string.Empty;
                    try { selectionFormula = report.RecordSelectionFormula ?? string.Empty; }
                    catch { /* some legacy reports throw here - just omit it */ }
                    if (!string.IsNullOrWhiteSpace(selectionFormula))
                    {
                        sb.Append("-- Crystal record selection formula (NOT applied by the SQL below):").Append(nl);
                        foreach (string line in ReportSql.SplitLines(selectionFormula))
                        {
                            sb.Append("--   " + line).Append(nl);
                        }
                    }
                    sb.Append("-- ============================================================================").Append(nl);

                    // ---- One section per table ---------------------------------
                    foreach (CrystalTable table in tables)
                    {
                        result.Tables.Add(table.Name);
                        sb.Append(nl);
                        sb.Append(rule).Append(nl);
                        sb.Append("-- Table: " + table.Name).Append(nl);
                        if (!string.IsNullOrEmpty(table.Location) &&
                            !string.Equals(table.Location, table.Name, StringComparison.OrdinalIgnoreCase))
                        {
                            sb.Append("-- Original data source: " + table.Location).Append(nl);
                        }

                        if (existingQueries.TryGetValue(table.Name, out string query))
                        {
                            result.MatchedTables.Add(table.Name);
                            sb.Append(rule).Append(nl);
                            string sql = ReportSql.StripTrailingSemicolon(query) + ";";
                            sb.Append(sql.Replace("\r\n", "\n").Replace("\n", nl)).Append(nl);
                        }
                        else
                        {
                            result.MissingTables.Add(table.Name);
                            sb.Append("-- NO QUERY YET - TODO: replace the commented-out skeleton below with the").Append(nl);
                            sb.Append("-- real query (remove the /* and */ lines).").Append(nl);
                            sb.Append("-- Skeleton below lists every column the report expects; aliases must").Append(nl);
                            sb.Append("-- match exactly (case-sensitive) for Crystal to bind them.").Append(nl);
                            sb.Append(rule).Append(nl);
                            sb.Append("/*").Append(nl);
                            sb.Append("SELECT").Append(nl);
                            var fields = new List<CrystalField>();
                            foreach (CrystalField field in table.Fields)
                            {
                                fields.Add(field);
                            }
                            for (int i = 0; i < fields.Count; i++)
                            {
                                string fieldType = fields[i].ValueType.ToString();
                                string comma = i < fields.Count - 1 ? "," : "";
                                sb.Append("    NULL AS \"" + fields[i].Name + "\"" + comma + " -- " + fieldType + " -> " + SuggestPgType(fieldType)).Append(nl);
                            }
                            sb.Append("FROM ???;").Append(nl);
                            sb.Append("*/").Append(nl);
                        }
                    }

                    // ---- Write (backing up a differing existing file) ----------
                    Directory.CreateDirectory(outDir);
                    string content = sb.ToString();
                    if (File.Exists(sqlPath))
                    {
                        string existing = File.ReadAllText(sqlPath);
                        if (existing.Trim().Length > 0 && !string.Equals(existing, content, StringComparison.Ordinal))
                        {
                            File.Copy(sqlPath, sqlPath + ".bak", true);
                            result.BackedUp = true;
                        }
                    }
                    File.WriteAllText(sqlPath, content, new UTF8Encoding(false));
                    result.SqlPath = sqlPath;
                }
                result.Success = true;
            }
            catch (Exception ex)
            {
                result.Success = false;
                result.Error = Program.FlattenExceptionChain(ex);
            }

            WriteJsonLine(result);
            return result.Success ? 0 : 1;
        }

        /// <summary>
        /// --sql-out-dir if given, else a SQLqueries folder beside the
        /// report's own folder (RPTConvert\reports\X.rpt -> RPTConvert\SQLqueries).
        /// </summary>
        private static string ResolveSqlOutDir(string reportPath, string sqlOutDir)
        {
            if (!string.IsNullOrWhiteSpace(sqlOutDir))
            {
                return Path.GetFullPath(sqlOutDir);
            }
            string reportDir = Path.GetDirectoryName(Path.GetFullPath(reportPath)) ?? ".";
            string parent = Path.GetDirectoryName(reportDir) ?? reportDir;
            return Path.Combine(parent, "SQLqueries");
        }

        /// <summary>Rough Crystal FieldValueType -> Postgres type hint for skeletons.</summary>
        private static string SuggestPgType(string crystalType)
        {
            switch (crystalType)
            {
                case "StringField": return "text";
                case "BooleanField": return "boolean";
                case "DateField": return "date";
                case "DateTimeField": return "timestamp";
                case "TimeField": return "time";
                case "CurrencyField":
                case "NumberField": return "numeric";
                case "Int8sField":
                case "Int8uField":
                case "Int16sField":
                case "Int16uField":
                case "Int32sField": return "integer";
                case "Int32uField": return "bigint";
                default: return "?";
            }
        }

        private static void WriteJsonLine<T>(T payload)
        {
            var jsonOptions = new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };
            Console.WriteLine(JsonSerializer.Serialize(payload, jsonOptions));
        }
    }
}
