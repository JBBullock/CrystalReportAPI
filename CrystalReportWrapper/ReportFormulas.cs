// ============================================================================
// CrystalReportWrapper - ReportFormulas.cs
//
// Removes the reports' dependency on the legacy program's Crystal add-on.
//
// The original Alliance/MFG reports get their column headings and captions
// from formulas like
//
//     LANG_Part_Number:   MFGFunctionsTranslationTranslate (26)
//
// MFGFunctionsTranslationTranslate lives in CRUFLMFGFunctions.dll, a VB6
// library that ships with the legacy program and looks label 26 up through
// that program's own login and database link (AMSInterfaces.dll,
// AMSGeneralCY.ocx, ...). On a machine without the legacy program installed -
// the Docker image, above all - Crystal cannot parse the formula and the
// render fails with "The remaining text does not appear to be part of the
// formula."
//
// So, right after a report is loaded, every call to that function is replaced
// with the label as plain text. The label is taken from the formula's own
// name: LANG_Part_Number -> "Part Number".
//
// Any OTHER function from that library (MFGFunctionsPreferences...,
// MFGFunctionsUOMConversions..., MFGFunctionsCompanyInfo...) is left alone
// and reported on stderr by formula name, so the next failure says exactly
// which formula needs a replacement written here.
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

        // A formula that is that one call and nothing else.
        private static readonly Regex OnlyATranslateCall = new Regex(
            @"^\s*MFGFunctionsTranslationTranslate\s*\(\s*(\d+)\s*\)\s*;?\s*$",
            RegexOptions.IgnoreCase);

        /// <summary>
        /// Rewrites, in the loaded report and its subreports, every formula
        /// that calls the legacy translation function. Nothing is saved back
        /// to the .rpt file.
        /// </summary>
        internal static void ReplaceLegacyFunctions(ReportDocument report)
        {
            var formulas = new List<FormulaFieldDefinition>();
            foreach (FormulaFieldDefinition formula in report.DataDefinition.FormulaFields)
            {
                formulas.Add(formula);
            }
            foreach (ReportDocument subreport in report.Subreports)
            {
                foreach (FormulaFieldDefinition formula in subreport.DataDefinition.FormulaFields)
                {
                    formulas.Add(formula);
                }
            }

            // Label number -> text, learned from the formulas that are nothing
            // but one call: LANG_Part_Number = Translate (26) says 26 is
            // "Part Number". Used for calls buried inside longer formulas.
            var labels = new Dictionary<string, string>();
            var labelFormulas = new List<FormulaFieldDefinition>();
            var otherFormulas = new List<FormulaFieldDefinition>();
            foreach (FormulaFieldDefinition formula in formulas)
            {
                string text = formula.Text ?? string.Empty;
                if (text.IndexOf(LibraryPrefix, StringComparison.OrdinalIgnoreCase) < 0)
                {
                    continue;
                }
                Match only = OnlyATranslateCall.Match(text);
                if (only.Success && IsLabelFormula(formula.Name))
                {
                    labels[only.Groups[1].Value] = LabelFromName(formula.Name);
                    labelFormulas.Add(formula);
                }
                else
                {
                    otherFormulas.Add(formula);
                }
            }

            // The plain labels first: longer formulas may refer to them, and
            // Crystal checks a formula when its text is set.
            foreach (FormulaFieldDefinition formula in labelFormulas)
            {
                Rewrite(formula, labels);
            }
            foreach (FormulaFieldDefinition formula in otherFormulas)
            {
                Rewrite(formula, labels);
            }
        }

        private static void Rewrite(FormulaFieldDefinition formula, Dictionary<string, string> labels)
        {
            string text = formula.Text ?? string.Empty;
            string ownLabel = IsLabelFormula(formula.Name) ? LabelFromName(formula.Name) : null;

            string rewritten = TranslateCall.Replace(text, call =>
            {
                string label;
                if (!labels.TryGetValue(call.Groups[1].Value, out label))
                {
                    label = ownLabel;
                }
                return label == null ? call.Value : Quote(label);
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

        private static bool IsLabelFormula(string name)
        {
            return name != null && name.StartsWith(LabelFormulaPrefix, StringComparison.OrdinalIgnoreCase);
        }

        /// <summary>LANG_Part_Number -> Part Number</summary>
        private static string LabelFromName(string name)
        {
            return name.Substring(LabelFormulaPrefix.Length).Replace('_', ' ').Trim();
        }

        /// <summary>A Crystal string literal; a quote inside it is doubled.</summary>
        private static string Quote(string text)
        {
            return "\"" + text.Replace("\"", "\"\"") + "\"";
        }
    }
}
