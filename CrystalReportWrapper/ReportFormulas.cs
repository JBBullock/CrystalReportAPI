// ============================================================================
// CrystalReportWrapper - ReportFormulas.cs
//
// Removes the reports' dependency on the legacy program's Crystal add-on.
//
// The original Alliance/MFG reports get their titles, column headings and
// captions from formulas like
//
//     LANG_PART_NUMBER:   MFGFunctionsTranslationTranslate (26)
//     LANG_SUBTOTAL_C:    MFGFunctionsTranslationTranslate (509) + ": "
//     TaxableString:      IF ({PurchaseOrder_TTX.TaxableFlag}) THEN
//                             MFGFunctionsTranslationTranslate (1888)
//                         ELSE MFGFunctionsTranslationTranslate (1889)
//
// MFGFunctionsTranslationTranslate lives in CRUFLMFGFunctions.dll, a VB6
// library that ships with the legacy program and looks label 26 up through
// that program's own login and database link (AMSInterfaces.dll,
// AMSGeneralCY.ocx, ...). On a machine without the legacy program installed -
// the Docker image, above all - Crystal cannot parse the formula and the
// render fails with "The remaining text does not appear to be part of the
// formula."
//
// So, right after a report is loaded, every call to that function - wherever
// it sits in a formula - is replaced with the label as a plain string. The
// wording comes from LegacyLabels.cs, which holds what the legacy add-on
// itself answers for each number. It is the only function of that library
// the reports use (checked across every .rpt by dump_formulas.py).
//
// A label number missing from LegacyLabels.cs (a report added later) falls
// back to the formula's own name, LANG_Part_Number -> "Part Number"; if the
// formula is not a LANG_ one the call is left alone and reported on stderr
// by formula name. Re-run dump_formulas.py to pick new numbers up.
// ============================================================================

using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using CrystalDecisions.CrystalReports.Engine;

namespace CrystalReportWrapper
{
    internal static class ReportFormulas
    {
        private const string LibraryPrefix = "MFGFunctions";
        private const string LabelFormulaPrefix = "LANG_";

        // MFGFunctionsTranslationTranslate (26)
        private static readonly Regex TranslateCall = new Regex(
            @"MFGFunctionsTranslationTranslate\s*\(\s*(\d+)\s*\)",
            RegexOptions.IgnoreCase);

        /// <summary>
        /// Rewrites, in the loaded report and its subreports, every formula
        /// that calls the legacy translation function. Nothing is saved back
        /// to the .rpt file.
        /// </summary>
        internal static void ReplaceLegacyFunctions(ReportDocument report)
        {
            // Formulas that stand alone go first: others may refer to them
            // ({@LANG_TITLE}), and Crystal checks a formula when its text is set.
            var standAlone = new List<FormulaFieldDefinition>();
            var referring = new List<FormulaFieldDefinition>();
            Collect(report, standAlone, referring);
            foreach (ReportDocument subreport in report.Subreports)
            {
                Collect(subreport, standAlone, referring);
            }

            foreach (FormulaFieldDefinition formula in standAlone)
            {
                Rewrite(formula);
            }
            foreach (FormulaFieldDefinition formula in referring)
            {
                Rewrite(formula);
            }
        }

        private static void Collect(
            ReportDocument document,
            List<FormulaFieldDefinition> standAlone,
            List<FormulaFieldDefinition> referring)
        {
            foreach (FormulaFieldDefinition formula in document.DataDefinition.FormulaFields)
            {
                string text = formula.Text ?? string.Empty;
                if (text.IndexOf(LibraryPrefix, StringComparison.OrdinalIgnoreCase) < 0)
                {
                    continue;
                }
                (text.Contains("{@") ? referring : standAlone).Add(formula);
            }
        }

        private static void Rewrite(FormulaFieldDefinition formula)
        {
            string text = formula.Text ?? string.Empty;

            string rewritten = TranslateCall.Replace(text, call =>
            {
                string label = LabelFor(call.Groups[1].Value, formula.Name);
                return label == null ? call.Value : Literal(label);
            });

            if (rewritten != text)
            {
                formula.Text = rewritten;
            }
            if (rewritten.IndexOf(LibraryPrefix, StringComparison.OrdinalIgnoreCase) >= 0)
            {
                Console.Error.WriteLine(
                    "warning: formula '" + formula.Name + "' still calls the legacy " +
                    "MFGFunctions library and will fail without it: " + rewritten.Trim());
            }
        }

        /// <summary>The text for one label number, or null if nothing is known.</summary>
        private static string LabelFor(string number, string formulaName)
        {
            int id;
            string label;
            if (int.TryParse(number, out id) && LegacyLabels.Text.TryGetValue(id, out label))
            {
                return label;
            }
            if (formulaName != null && formulaName.StartsWith(LabelFormulaPrefix, StringComparison.OrdinalIgnoreCase))
            {
                // LANG_Part_Number -> Part Number
                return formulaName.Substring(LabelFormulaPrefix.Length).Replace('_', ' ').Trim();
            }
            return null;
        }

        /// <summary>
        /// The label as a Crystal string expression. A two-line label
        /// ("Yield" / "Factor") becomes ("Yield" + Chr (13) + Chr (10) +
        /// "Factor"), in brackets so it stays one value inside a longer
        /// formula.
        /// </summary>
        private static string Literal(string label)
        {
            string[] lines = label.Replace("\r\n", "\n").Replace('\r', '\n').Split('\n');
            if (lines.Length == 1)
            {
                return Quote(lines[0]);
            }
            var quoted = new List<string>();
            foreach (string line in lines)
            {
                quoted.Add(Quote(line));
            }
            return "(" + string.Join(" + Chr (13) + Chr (10) + ", quoted) + ")";
        }

        /// <summary>A Crystal string literal; a quote inside it is doubled.</summary>
        private static string Quote(string text)
        {
            return "\"" + text.Replace("\"", "\"\"") + "\"";
        }
    }
}
