// ============================================================================
// ReportSql.cs - reads a report's .sql file.
//
// Each report has ONE .sql file (reports_map.py's REPORT_SQL says which). It
// holds one query per Crystal table the report uses.
//
// File format:
//   * One-table report: the file can be just the query.
//   * Multi-table report: each query sits under a marker line naming the
//     Crystal table it fills:
//         -- Table: SOHeader
//         SELECT ... ;
//         -- Table: SODetail
//         SELECT ... ;
//   * A section with no SQL in it (blank, or only comments - e.g. the
//     /* ... */ skeleton --extract-sql writes) counts as "no query".
//
// Column aliases must match the report's field names exactly, including
// case: SELECT sonumber AS "SONumber".
// ============================================================================

using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace CrystalReportWrapper
{
    internal static class ReportSql
    {
        // (.+?) not (\S+): Crystal table names can contain spaces
        // ("WO Pick List_TTX").
        private static readonly Regex TableMarkerPattern =
            new Regex(@"^\s*--\s*Table:\s*(.+?)\s*$", RegexOptions.IgnoreCase | RegexOptions.Compiled);
        private static readonly Regex BlockCommentPattern =
            new Regex(@"/\*.*?\*/", RegexOptions.Singleline | RegexOptions.Compiled);
        private static readonly Regex LineCommentPattern =
            new Regex(@"--[^\n]*", RegexOptions.Compiled);
        private static readonly Regex TrailingSemicolonPattern =
            new Regex(@";\s*(--[^\n]*)?\s*\z", RegexOptions.Compiled);

        /// <summary>
        /// The queries in sqlPath, keyed by Crystal table name (compared
        /// without regard to case). A table the file has no query for is
        /// simply absent from the result - the caller decides whether that
        /// is an error.
        ///
        /// reportTableNames is the report's own table list: it names the
        /// table for a marker-less file.
        /// </summary>
        internal static Dictionary<string, string> Load(string sqlPath, List<string> reportTableNames)
        {
            if (!File.Exists(sqlPath))
            {
                throw new FileNotFoundException("SQL file not found: " + sqlPath);
            }

            // Split into sections at each "-- Table: X" line. The first
            // section (Key == null) is whatever precedes the first marker:
            // the whole file when there are no markers, else just a header.
            var sections = new List<KeyValuePair<string, string>>();
            string currentTable = null;
            var buffer = new StringBuilder();
            foreach (string line in SplitLines(File.ReadAllText(sqlPath)))
            {
                Match marker = TableMarkerPattern.Match(line);
                if (marker.Success)
                {
                    sections.Add(new KeyValuePair<string, string>(currentTable, buffer.ToString()));
                    buffer.Clear();
                    currentTable = marker.Groups[1].Value;
                    continue;
                }
                buffer.Append(line).Append('\n');
            }
            sections.Add(new KeyValuePair<string, string>(currentTable, buffer.ToString()));
            bool hasMarkers = sections.Count > 1;

            var queries = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (KeyValuePair<string, string> section in sections)
            {
                if (!ContainsSql(section.Value))
                {
                    continue;
                }

                string table = section.Key;
                if (table == null)
                {
                    if (hasMarkers)
                    {
                        throw new InvalidOperationException(
                            sqlPath + ": SQL found before the first '-- Table: <name>' line. " +
                            "Put every query under a marker line.");
                    }
                    if (reportTableNames.Count != 1)
                    {
                        throw new InvalidOperationException(
                            sqlPath + " has no '-- Table: <name>' lines, but the report uses " +
                            reportTableNames.Count + " tables (" + string.Join(", ", reportTableNames) +
                            "). Add a marker line before each table's query.");
                    }
                    table = reportTableNames[0];
                }

                if (queries.ContainsKey(table))
                {
                    throw new InvalidOperationException(sqlPath + ": more than one query for table '" + table + "'.");
                }
                queries[table] = StripTrailingSemicolon(TrimCommentLines(section.Value));
            }
            return queries;
        }

        /// <summary>
        /// Removes a final ';' (and a "-- comment" after it). A query may be
        /// wrapped as a subquery, where a trailing ';' is a syntax error.
        /// </summary>
        internal static string StripTrailingSemicolon(string query)
        {
            return TrailingSemicolonPattern.Replace(query.TrimEnd(), string.Empty).TrimEnd();
        }

        internal static List<string> SplitLines(string text)
        {
            var lines = new List<string>();
            foreach (string raw in text.Replace("\r\n", "\n").Replace('\r', '\n').Split('\n'))
            {
                lines.Add(raw.TrimEnd());
            }
            return lines;
        }

        /// <summary>True if text has anything left once comments are removed.</summary>
        private static bool ContainsSql(string text)
        {
            string stripped = BlockCommentPattern.Replace(text, " ");
            stripped = LineCommentPattern.Replace(stripped, " ");
            return stripped.Trim().Trim(';').Trim().Length > 0;
        }

        /// <summary>Drops blank and comment-only lines from both ends.</summary>
        private static string TrimCommentLines(string text)
        {
            List<string> lines = SplitLines(text);
            while (lines.Count > 0 && IsSkippable(lines[0])) lines.RemoveAt(0);
            while (lines.Count > 0 && IsSkippable(lines[lines.Count - 1])) lines.RemoveAt(lines.Count - 1);
            return string.Join("\n", lines);
        }

        private static bool IsSkippable(string line)
        {
            string trimmed = line.Trim();
            return trimmed.Length == 0 || trimmed.StartsWith("--");
        }
    }
}
