// RptBatchConvert
//
// Batch-opens legacy Crystal Reports (.rpt) files with the Crystal Reports
// runtime/SDK installed alongside CR2025 (or CR2016, if you're keeping the
// two-hop process) and re-saves them in the current format.
//
// REQUIRES:
//   - "SAP Crystal Reports, developer version for Microsoft Visual Studio"
//     runtime installed (matching your CR2025 install), which registers the
//     CrystalDecisions.CrystalReports.Engine / .Shared assemblies used below.
//   - References (from the SDK install, typically under
//     C:\Program Files (x86)\SAP BusinessObjects\Crystal Reports for .NET Framework 4.0\Common\SAP BusinessObjects Enterprise XI 4.0\win32_x86\dotnet):
//       CrystalDecisions.CrystalReports.Engine.dll
//       CrystalDecisions.Shared.dll
//       CrystalDecisions.ReportSource.dll (if using RAS-based flow)
//
// WHAT THIS DOES PER FILE:
//   1. Loads the RPT.
//   2. Re-saves it (this is what upgrades the on-disk format, same as
//      File > Save in the Designer).
//   3. Attempts a lightweight verification: forces the report engine to
//      resolve the report structure (not full data refresh, since 500+
//      files hitting live DBs at once is its own problem) and checks for
//      broken subreport links / missing table references.
//   4. Logs success/failure per file to a CSV so you get one master list
//      of what needs manual review, instead of finding out at go-live.
//
// This does NOT validate that formulas produce correct *data* -- only that
// the report structure survives the resave. Plan a separate, smaller pass
// where you actually refresh a sample against real data per report category.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using CrystalDecisions.CrystalReports.Engine;
using CrystalDecisions.Shared;

namespace RptBatchConvert
{
    class Program
    {
        static void Main(string[] args)
        {
            if (args.Length < 2)
            {
                Console.WriteLine("Usage: RptBatchConvert <sourceFolder> <outputFolder> [--overwrite]");
                return;
            }

            string sourceFolder = args[0];
            string outputFolder = args[1];
            bool overwrite = args.Contains("--overwrite");

            Directory.CreateDirectory(outputFolder);

            var rptFiles = Directory.GetFiles(sourceFolder, "*.rpt", SearchOption.AllDirectories);
            Console.WriteLine($"Found {rptFiles.Length} RPT files.");

            var logPath = Path.Combine(outputFolder, $"conversion_log_{DateTime.Now:yyyyMMdd_HHmmss}.csv");
            using var log = new StreamWriter(logPath);
            log.WriteLine("SourcePath,Status,SubreportCount,Issues");

            int ok = 0, failed = 0;

            foreach (var srcPath in rptFiles)
            {
                string relative = Path.GetRelativePath(sourceFolder, srcPath);
                string destPath = Path.Combine(outputFolder, relative);
                Directory.CreateDirectory(Path.GetDirectoryName(destPath)!);

                if (File.Exists(destPath) && !overwrite)
                {
                    Console.WriteLine($"SKIP (exists): {relative}");
                    continue;
                }

                var issues = new List<string>();
                int subreportCount = 0;

                using var reportDoc = new ReportDocument();
                try
                {
                    reportDoc.Load(srcPath, OpenReportMethod.OpenReportByTempCopy);

                    // Structural check: walk subreports and confirm each one
                    // still resolves. A subreport that silently dropped its
                    // link during conversion is the classic "opens fine,
                    // renders blank" failure.
                    subreportCount = reportDoc.Subreports.Count;
                    foreach (ISCRReportDocument sub in reportDoc.Subreports)
                    {
                        try
                        {
                            var _ = sub.ReportDefinition.ReportObjects.Count;
                        }
                        catch (Exception subEx)
                        {
                            issues.Add($"Subreport '{sub.Name}': {subEx.Message}");
                        }
                    }

                    // Structural check: table / datasource references.
                    foreach (Table table in reportDoc.Database.Tables)
                    {
                        if (string.IsNullOrWhiteSpace(table.LogOnInfo.ConnectionInfo.ServerName)
                            && string.IsNullOrWhiteSpace(table.LogOnInfo.ConnectionInfo.DatabaseName))
                        {
                            issues.Add($"Table '{table.Name}' has no resolvable connection info.");
                        }
                    }

                    // The actual conversion: save in current-version format.
                    reportDoc.SaveAs(destPath);

                    reportDoc.Close();

                    string status = issues.Count == 0 ? "OK" : "OK_WITH_WARNINGS";
                    if (issues.Count == 0) ok++; else failed++; // treat warnings as needing review
                    log.WriteLine($"\"{relative}\",{status},{subreportCount},\"{string.Join(" | ", issues)}\"");
                    Console.WriteLine($"{status}: {relative}" + (issues.Count > 0 ? $" ({issues.Count} issue(s))" : ""));
                }
                catch (Exception ex)
                {
                    failed++;
                    log.WriteLine($"\"{relative}\",FAILED,{subreportCount},\"{ex.Message.Replace("\"", "'")}\"");
                    Console.WriteLine($"FAILED: {relative} -- {ex.Message}");
                }
            }

            Console.WriteLine();
            Console.WriteLine($"Done. OK/warned: {ok}  Failed: {failed}  Log: {logPath}");
        }
    }
}
