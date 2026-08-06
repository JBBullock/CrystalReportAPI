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
using System.IO;
using System.Text.Json;
using CrystalDecisions.CrystalReports.Engine;
using CrystalDecisions.Shared;

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

    internal class Program
    {
        /// <summary>
        /// Entry point. Expected usage:
        ///   CrystalReportWrapper.exe --report "C:\reports\sales.rpt"
        ///                             --output "C:\out\sales.pdf"
        ///                             --format PDF
        ///                             [--params "C:\out\params.json"]
        /// Exit code 0 = success, 1 = failure (mirrors the JSON "Success" flag
        /// so Python can also branch on subprocess return code alone).
        /// </summary>
        private static int Main(string[] args)
        {
            var result = new ExportResult();

            try
            {
                // --- 1. Parse arguments -----------------------------------
                var options = ParseArgs(args);

                // --- 2. Load the report -----------------------------------
                if (!File.Exists(options.ReportPath))
                {
                    throw new FileNotFoundException($"Report file not found: {options.ReportPath}");
                }

                using var report = new ReportDocument();
                report.Load(options.ReportPath);

                // --- 3. Apply parameters (if any were supplied) -----------
                if (!string.IsNullOrEmpty(options.ParamsJsonPath))
                {
                    ApplyParameters(report, options.ParamsJsonPath);
                }

                // --- 4. Export to the requested format ---------------------
                // Ensure the destination folder exists; ExportToDisk throws
                // DirectoryNotFoundException otherwise, which is an easy
                // thing to hit on first run before any output folder exists.
                string? outputDir = Path.GetDirectoryName(options.OutputPath);
                if (!string.IsNullOrEmpty(outputDir))
                {
                    Directory.CreateDirectory(outputDir);
                }

                ExportReport(report, options.OutputPath, options.Format);

                // --- 5. Report success back to Python ----------------------
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
                var messages = new System.Collections.Generic.List<string>();
                Exception current = ex;
                while (current != null)
                {
                    messages.Add($"{current.GetType().Name}: {current.Message}");
                    current = current.InnerException;
                }
                result.Error = string.Join(" ---> ", messages);
            }

            // Always emit exactly one JSON line on stdout - this is the
            // single point of contact between C# and Python. camelCase
            // property naming matches typical JSON/Python conventions
            // (Success -> "success", OutputPath -> "outputPath").
            var jsonOptions = new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            };
            Console.WriteLine(JsonSerializer.Serialize(result, jsonOptions));

            return result.Success ? 0 : 1;
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
                }
            }

            if (string.IsNullOrEmpty(options.ReportPath) || string.IsNullOrEmpty(options.OutputPath))
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

            // ParameterFields is Crystal's collection of report-defined
            // parameters (built at design time in the .rpt file). Build a
            // case-insensitive name lookup up front so callers don't have
            // to match the .rpt's exact parameter casing.
            ParameterFieldDefinitions definitions = report.DataDefinition.ParameterFields;

            foreach (JsonProperty prop in doc.RootElement.EnumerateObject())
            {
                ParameterFieldDefinition? field = null;
                foreach (ParameterFieldDefinition candidate in definitions)
                {
                    if (string.Equals(candidate.Name.TrimStart('?'), prop.Name, StringComparison.OrdinalIgnoreCase))
                    {
                        field = candidate;
                        break;
                    }
                }

                if (field == null)
                {
                    throw new ArgumentException(
                        $"Report has no parameter named '{prop.Name}'. " +
                        $"Available parameters: {string.Join(", ", GetParameterNames(definitions))}");
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

        private static System.Collections.Generic.IEnumerable<string> GetParameterNames(
            ParameterFieldDefinitions definitions)
        {
            foreach (ParameterFieldDefinition d in definitions)
            {
                yield return d.Name;
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

        /// <summary>Parsed CLI arguments container.</summary>
        private class CliOptions
        {
            public string ReportPath { get; set; } = string.Empty;
            public string OutputPath { get; set; } = string.Empty;
            public string Format { get; set; } = "PDF";
            public string? ParamsJsonPath { get; set; }
        }
    }
}