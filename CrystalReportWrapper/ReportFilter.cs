// ============================================================================
// ReportFilter.cs - turns the request's "filter" into SQL conditions.
//
// The filter is a JSON object, column name -> what to match:
//
//   {"sonumber": 1234}                       equals
//   {"partnumber": "CA03*"}                  wildcard: * = any characters,
//                                            ? = exactly one character
//   {"orderdate": {">=": "2026-01-01",       operators: =  !=  <  <=  >  >=
//                  "<=": "2026-01-31"}}      several on one column = AND
//   {"partnumber": {"!=": "CA03*"}}          wildcards work with = and !=
//   {"partnumber": "*"}                      "*" alone = all, no condition
//
// Different columns are combined with AND.
//
// How a value is compared depends on the column's type, which is asked of
// Postgres for the report query's OUTPUT column (so a text date the query
// casts to a timestamp is filtered as a date):
//
//   * wildcard        as text, ignoring upper/lower case.
//   * date/timestamp  as a date. Send YYYY-MM-DD (a time may follow). A value
//                     with no time means the WHOLE day: "<= 2026-01-31"
//                     includes everything on the 31st, "= 2026-01-31" matches
//                     any time that day.
//   * number          as a number, so 1234 matches 1234.00.
//   * anything else   as text, exact match.
//
// Values only ever reach Postgres as query parameters, never as SQL text.
// ============================================================================

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Text.Json;
using Npgsql;
using NpgsqlTypes;

namespace CrystalReportWrapper
{
    /// <summary>One comparison: column, operator, value.</summary>
    internal sealed class FilterCondition
    {
        public string Column;
        public string Operator;     // one of ReportFilter.Operators
        public JsonElement Value;   // text, number or true/false
    }

    internal static class ReportFilter
    {
        private static readonly string[] Operators = { "=", "!=", "<", "<=", ">", ">=" };

        /// <summary>
        /// Reads the request's filter object into a flat list of conditions.
        /// Anything malformed is a BadRequestException.
        /// </summary>
        internal static List<FilterCondition> Parse(JsonElement filter)
        {
            var conditions = new List<FilterCondition>();
            foreach (JsonProperty column in filter.EnumerateObject())
            {
                if (column.Value.ValueKind == JsonValueKind.Object)
                {
                    int count = 0;
                    foreach (JsonProperty comparison in column.Value.EnumerateObject())
                    {
                        if (Array.IndexOf(Operators, comparison.Name) < 0)
                        {
                            throw new BadRequestException(
                                "Filter on '" + column.Name + "' uses unknown operator '" + comparison.Name +
                                "'. Use one of: " + string.Join("  ", Operators));
                        }
                        Add(conditions, column.Name, comparison.Name, comparison.Value);
                        count++;
                    }
                    if (count == 0)
                    {
                        throw new BadRequestException("Filter on '" + column.Name + "' is empty.");
                    }
                }
                else
                {
                    Add(conditions, column.Name, "=", column.Value);
                }
            }
            return conditions;
        }

        private static void Add(List<FilterCondition> conditions, string column, string op, JsonElement value)
        {
            switch (value.ValueKind)
            {
                case JsonValueKind.String:
                case JsonValueKind.Number:
                case JsonValueKind.True:
                case JsonValueKind.False:
                    break;
                default:
                    throw new BadRequestException(
                        "Filter value for '" + column + "' must be text, a number or true/false.");
            }

            // "*" alone means "all": no condition on this column.
            if (op == "=" && value.ValueKind == JsonValueKind.String && IsAllStars(value.GetString()))
            {
                return;
            }

            // Clone(): the value must outlive the request's JsonDocument.
            conditions.Add(new FilterCondition { Column = column, Operator = op, Value = value.Clone() });
        }

        /// <summary>
        /// The SQL for one condition against one column of a query's result,
        /// e.g. "OrderDate" &gt;= @f0. Its values are appended to parameters.
        /// columnName is the column's real spelling; columnType is its CLR type.
        /// </summary>
        internal static string ToSql(
            FilterCondition condition,
            string columnName,
            Type columnType,
            List<NpgsqlParameter> parameters)
        {
            string column = "\"" + columnName.Replace("\"", "\"\"") + "\"";
            string op = condition.Operator;
            string text = ValueText(condition.Value);

            // ---- Wildcard -------------------------------------------------
            if (condition.Value.ValueKind == JsonValueKind.String && HasWildcard(text))
            {
                if (op != "=" && op != "!=")
                {
                    throw new BadRequestException(
                        "Filter on '" + condition.Column + "': wildcards (* and ?) work with = and != only, not " + op + ".");
                }
                string pattern = AddParameter(parameters, NpgsqlDbType.Text, ToLikePattern(text));
                return "CAST(" + column + " AS text) " + (op == "=" ? "ILIKE " : "NOT ILIKE ") + pattern + " ESCAPE '\\'";
            }

            // ---- Date / timestamp -----------------------------------------
            if (columnType == typeof(DateTime) || columnType == typeof(DateTimeOffset))
            {
                if (!TryGetDate(text, out DateTime value, out bool wholeDay))
                {
                    throw new BadRequestException(
                        "Filter on '" + condition.Column + "' needs a date as YYYY-MM-DD, got '" + text + "'.");
                }
                if (!wholeDay)
                {
                    return column + " " + SqlOperator(op) + " " + AddParameter(parameters, NpgsqlDbType.Timestamp, value);
                }

                // No time given: the value stands for the whole day, which is
                // the range [day, next day).
                DateTime nextDay = value.AddDays(1);
                switch (op)
                {
                    case "=":
                        return "(" + column + " >= " + AddParameter(parameters, NpgsqlDbType.Timestamp, value) +
                               " AND " + column + " < " + AddParameter(parameters, NpgsqlDbType.Timestamp, nextDay) + ")";
                    case "!=":
                        return "(" + column + " < " + AddParameter(parameters, NpgsqlDbType.Timestamp, value) +
                               " OR " + column + " >= " + AddParameter(parameters, NpgsqlDbType.Timestamp, nextDay) + ")";
                    case "<":
                        return column + " < " + AddParameter(parameters, NpgsqlDbType.Timestamp, value);
                    case "<=":
                        return column + " < " + AddParameter(parameters, NpgsqlDbType.Timestamp, nextDay);
                    case ">":
                        return column + " >= " + AddParameter(parameters, NpgsqlDbType.Timestamp, nextDay);
                    default: // ">="
                        return column + " >= " + AddParameter(parameters, NpgsqlDbType.Timestamp, value);
                }
            }

            // ---- Number ---------------------------------------------------
            if (IsNumeric(columnType))
            {
                if (!decimal.TryParse(text, NumberStyles.Number, CultureInfo.InvariantCulture, out decimal number))
                {
                    throw new BadRequestException(
                        "Filter on '" + condition.Column + "' needs a number, got '" + text + "'.");
                }
                return column + " " + SqlOperator(op) + " " + AddParameter(parameters, NpgsqlDbType.Numeric, number);
            }

            // ---- Text (and anything else) ---------------------------------
            return "CAST(" + column + " AS text) " + SqlOperator(op) + " " + AddParameter(parameters, NpgsqlDbType.Text, text);
        }

        // ====================================================================
        // Helpers
        // ====================================================================

        /// <summary>Adds one query parameter and returns its "@name" placeholder.</summary>
        private static string AddParameter(List<NpgsqlParameter> parameters, NpgsqlDbType type, object value)
        {
            string name = "f" + parameters.Count;
            parameters.Add(new NpgsqlParameter(name, type) { Value = value });
            return "@" + name;
        }

        private static string SqlOperator(string op)
        {
            return op == "!=" ? "<>" : op;
        }

        private static string ValueText(JsonElement value)
        {
            switch (value.ValueKind)
            {
                case JsonValueKind.String: return value.GetString();
                case JsonValueKind.True: return "true";
                case JsonValueKind.False: return "false";
                default: return value.GetRawText();   // a number, as written
            }
        }

        private static bool HasWildcard(string text)
        {
            return text.IndexOf('*') >= 0 || text.IndexOf('?') >= 0;
        }

        private static bool IsAllStars(string text)
        {
            string trimmed = text.Trim();
            return trimmed.Length > 0 && trimmed.Trim('*').Length == 0;
        }

        /// <summary>
        /// "CA03*" -> "CA03%". * becomes %, ? becomes _, and any % _ or \
        /// already in the text is escaped so it matches itself.
        /// </summary>
        private static string ToLikePattern(string text)
        {
            var pattern = new StringBuilder();
            foreach (char c in text)
            {
                switch (c)
                {
                    case '*': pattern.Append('%'); break;
                    case '?': pattern.Append('_'); break;
                    case '%':
                    case '_':
                    case '\\': pattern.Append('\\').Append(c); break;
                    default: pattern.Append(c); break;
                }
            }
            return pattern.ToString();
        }

        /// <summary>
        /// wholeDay is true for a bare YYYY-MM-DD. A value with a time
        /// ("2026-01-31T14:30:00") is taken as that exact moment.
        /// </summary>
        private static bool TryGetDate(string text, out DateTime value, out bool wholeDay)
        {
            wholeDay = DateTime.TryParseExact(
                text.Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out value);
            if (wholeDay)
            {
                return true;
            }
            return DateTime.TryParse(text, CultureInfo.InvariantCulture, DateTimeStyles.None, out value);
        }

        private static bool IsNumeric(Type type)
        {
            return type == typeof(short) || type == typeof(int) || type == typeof(long)
                || type == typeof(decimal) || type == typeof(float) || type == typeof(double);
        }
    }
}
