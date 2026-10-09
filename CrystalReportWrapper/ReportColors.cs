// ============================================================================
// CrystalReportWrapper - ReportColors.cs
//
// Removes the reports' last dependency on the legacy Crystal add-on: the
// alternate-row shading rule.
//
// Twelve of the original reports (Labor Router, Stock Status, Transaction
// Report, ...) shade every other detail row. In the original program that
// rule lives in the section's Color condition (Section Expert -> Color ->
// Background Color formula, "Section_Back_Color") and asks the legacy
// add-on (CRUFLMFGFunctions.dll) for the user's alternate-row colour
// preference. Where the add-on isn't installed - the Docker image - Crystal
// cannot compile that condition and the whole render fails, exactly like
// the label formulas ReportFormulas.cs already rewrites.
//
// ReportFormulas.cs works through the Engine API, which only exposes
// formula FIELDS. Section condition formulas are only reachable through the
// Report Application Server (RAS) object model behind
// ReportDocument.ReportClientDocument. To avoid adding five more RAS
// assembly references (and the build rounds that come with guessing their
// exact member names), the RAS part below is late-bound: it reaches the RAS
// objects with reflection + `dynamic`. The RAS assemblies are part of every
// Crystal runtime install (GAC), so they are there at run time wherever the
// worker runs; nothing new is needed at build time except Microsoft.CSharp
// (the `dynamic` binder, part of .NET Framework).
//
// What it does, right after the report is loaded (nothing is saved back to
// the .rpt):
//   1. Formula FIELDS that still call MFGFunctions after ReportFormulas.cs
//      and look like the colour rule (name has Color/Colour/Back) become
//          If RecordNumber Mod 2 = 0 Then Color (R, G, B) Else crNoColor
//      and ones named like "...Alternate..." become RecordNumber Mod 2 = 0.
//   2. Every SECTION condition formula (main report and subreports) that
//      calls MFGFunctions: a colour condition (BackgroundColor) gets the
//      same alternate-row expression, any other condition is cleared (the
//      section's fixed setting then applies) - both reported on stderr.
//
// The colour is the request's AlternateRowColor_R / _G / _B parameters
// (jsonInspections/global_report_parameters.json - the same preference
// names the legacy program uses), default 238, 238, 238.
//
// If the RAS step itself fails (an older runtime, a member name that
// differs), the render still goes on and the reason is written to stderr -
// the report then fails exactly as it did before, no worse. Run
//     CrystalReportWrapper.exe --report <file.rpt> --section-rules
// to list every section condition formula a report has, for diagnosis.
// ============================================================================

using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text.Json;
using CrystalDecisions.CrystalReports.Engine;

namespace CrystalReportWrapper
{
    internal static class ReportColors
    {
        private const string LibraryPrefix = "MFGFunctions";
        private const string RasVersion = ", Version=13.0.4000.0, Culture=neutral, PublicKeyToken=692fbea5521e1304";
        private const string DefModelAssembly = "CrystalDecisions.ReportAppServer.ReportDefModel" + RasVersion;
        private const string ControllersAssembly = "CrystalDecisions.ReportAppServer.Controllers" + RasVersion;

        // RAS ReportDefinition members that hold an Area (or a collection of
        // them, for the group areas). Tried one by one; a name the runtime
        // doesn't have is skipped.
        private static readonly string[] AreaMembers =
        {
            "ReportHeaderArea", "PageHeaderArea", "GroupHeaderAreas", "GroupHeaderArea",
            "DetailArea", "GroupFooterAreas", "GroupFooterArea", "PageFooterArea", "ReportFooterArea",
        };

        /// <summary>One section condition formula, for --section-rules.</summary>
        internal sealed class SectionRule
        {
            public string Subreport { get; set; } = string.Empty;
            public string Section { get; set; } = string.Empty;
            public string Condition { get; set; } = string.Empty;
            public string Text { get; set; } = string.Empty;
        }

        // ====================================================================
        // Entry point (Program.Render, right after ReportFormulas)
        // ====================================================================

        internal static void ReplaceLegacyColorRules(ReportDocument report, Dictionary<string, JsonElement> parameters)
        {
            string colorExpression = AlternateRowExpression(parameters);

            FixFormulaFields(report, colorExpression);
            foreach (ReportDocument subreport in report.Subreports)
            {
                FixFormulaFields(subreport, colorExpression);
            }

            try
            {
                WalkSectionConditions(report, colorExpression, null);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(
                    "warning: could not check the report's section colour rules (RAS): " +
                    Program.FlattenExceptionChain(ex));
            }
        }

        /// <summary>Every section condition formula, for DevTools --section-rules.</summary>
        internal static List<SectionRule> DescribeSectionConditions(ReportDocument report)
        {
            var found = new List<SectionRule>();
            WalkSectionConditions(report, null, found);
            return found;
        }

        // ====================================================================
        // 1. Formula fields (Engine API)
        // ====================================================================

        private static void FixFormulaFields(ReportDocument document, string colorExpression)
        {
            foreach (FormulaFieldDefinition formula in document.DataDefinition.FormulaFields)
            {
                string text = formula.Text ?? string.Empty;
                if (text.IndexOf(LibraryPrefix, StringComparison.OrdinalIgnoreCase) < 0)
                {
                    continue;
                }
                string name = formula.Name ?? string.Empty;
                string replacement = null;
                if (Has(name, "color") || Has(name, "colour") || Has(name, "back"))
                {
                    replacement = colorExpression;
                }
                else if (Has(name, "alternate"))
                {
                    replacement = "RecordNumber Mod 2 = 0";
                }
                if (replacement == null)
                {
                    continue;  // ReportFormulas.cs already warned about it
                }
                Console.Error.WriteLine(
                    "info: formula '" + name + "' used the legacy add-on (" + text.Trim() +
                    "); replaced with: " + replacement);
                formula.Text = replacement;
            }
        }

        // ====================================================================
        // 2. Section condition formulas (RAS, late-bound)
        // ====================================================================

        /// <summary>
        /// Walks every section of the report and its subreports. With
        /// <paramref name="found"/> set it only lists the condition formulas;
        /// otherwise it rewrites the ones that call the legacy add-on.
        /// NoInlining keeps any RAS load failure inside the caller's try.
        /// </summary>
        [MethodImpl(MethodImplOptions.NoInlining)]
        private static void WalkSectionConditions(ReportDocument report, string colorExpression, List<SectionRule> found)
        {
            // The two RAS enums are found by what they hold, not by an exact
            // type name: the first version of this asked for
            // "CrSectionAreaConditionFormulaTypeEnum", which this runtime does
            // not have, and so never got as far as looking at a section.
            Type conditionEnum = FindEnum(
                DefModelAssembly, "the section condition formula types",
                type => Has(type.Name, "SectionArea") && Has(type.Name, "ConditionFormula"));
            Type propertyEnum = FindEnum(
                ControllersAssembly, "the report section properties",
                type => Has(type.Name, "ReportSectionProperty"));
            object formatProperty = null;
            foreach (string name in Enum.GetNames(propertyEnum))
            {
                if (name.EndsWith("Format", StringComparison.OrdinalIgnoreCase))
                {
                    formatProperty = Enum.Parse(propertyEnum, name);
                    break;
                }
            }
            if (formatProperty == null)
            {
                throw new InvalidOperationException(
                    propertyEnum.FullName + " has no ...Format member (it has: " +
                    string.Join(", ", Enum.GetNames(propertyEnum)) + ")");
            }

            // ReportClientDocument's declared type lives in the RAS ClientDoc
            // assembly, which this project doesn't reference - hence reflection.
            PropertyInfo rcdProperty = typeof(ReportDocument).GetProperty("ReportClientDocument");
            dynamic rcd = rcdProperty.GetValue(report, null);

            WalkDocument(rcd.ReportDefController, string.Empty, conditionEnum, formatProperty, colorExpression, found);

            dynamic subreports = rcd.SubreportController;
            foreach (object nameObject in (IEnumerable)subreports.GetSubreportNames())
            {
                string name = Convert.ToString(nameObject, CultureInfo.InvariantCulture);
                dynamic sub = subreports.GetSubreport(name);
                WalkDocument(sub.ReportDefController, name, conditionEnum, formatProperty, colorExpression, found);
            }
        }

        private static void WalkDocument(
            dynamic defController, string subreportName, Type conditionEnum, object formatProperty,
            string colorExpression, List<SectionRule> found)
        {
            dynamic definition = defController.ReportDefinition;
            // Reading a condition can fail for a type that does not apply to
            // sections, which is fine - but if NOT ONE could be read, the way
            // this code reaches them is wrong and that must not pass silently.
            int conditionsRead = 0;
            string firstReadError = null;
            foreach (dynamic area in Areas(definition))
            {
                foreach (dynamic section in (IEnumerable)area.Sections)
                {
                    string sectionName = SafeName(section);
                    dynamic format = section.Format;
                    // Edits go on a copy, then the copy is applied through the
                    // controller - RAS ignores direct edits of a live object.
                    dynamic copy = found == null ? format.Clone(true) : format;
                    bool changed = false;

                    foreach (string typeName in Enum.GetNames(conditionEnum))
                    {
                        object type = Enum.Parse(conditionEnum, typeName);
                        dynamic condition;
                        string text;
                        try
                        {
                            condition = ConditionOf(copy, type);
                            conditionsRead++;
                            if (condition == null) continue;
                            text = Convert.ToString(condition.Text, CultureInfo.InvariantCulture) ?? string.Empty;
                        }
                        catch (Exception ex)
                        {
                            if (firstReadError == null)
                            {
                                firstReadError = typeName + ": " + Program.FlattenExceptionChain(ex);
                            }
                            continue;  // this condition type doesn't apply to sections
                        }
                        if (text.Trim().Length == 0)
                        {
                            continue;
                        }

                        if (found != null)
                        {
                            found.Add(new SectionRule
                            {
                                Subreport = subreportName,
                                Section = sectionName,
                                Condition = ShortConditionName(typeName),
                                Text = text,
                            });
                            continue;
                        }
                        if (text.IndexOf(LibraryPrefix, StringComparison.OrdinalIgnoreCase) < 0)
                        {
                            continue;
                        }

                        bool isColor = Has(typeName, "color") || Has(typeName, "colour");
                        string replacement = isColor ? colorExpression : string.Empty;
                        Console.Error.WriteLine(
                            "info: section '" + Where(subreportName, sectionName) + "' " +
                            ShortConditionName(typeName) + " condition used the legacy add-on (" + text.Trim() + "); " +
                            (isColor ? "replaced with: " + replacement : "cleared"));
                        condition.Text = replacement;
                        changed = true;
                    }

                    if (changed)
                    {
                        dynamic property = formatProperty;
                        defController.ReportSectionController.SetProperty(section, property, copy);
                    }
                }
            }
            if (conditionsRead == 0 && firstReadError != null)
            {
                throw new InvalidOperationException(
                    "could not read any section condition formula" +
                    (subreportName.Length > 0 ? " in subreport '" + subreportName + "'" : string.Empty) +
                    ". First failure - " + firstReadError);
            }
        }

        /// <summary>
        /// One condition formula of a section format. The key goes in as
        /// `dynamic` so the call is bound with its real (enum) type; the
        /// number is the fallback for a runtime that wants it that way.
        /// </summary>
        private static dynamic ConditionOf(dynamic format, object type)
        {
            dynamic formulas = format.ConditionFormulas;
            try
            {
                dynamic key = type;
                return formulas[key];
            }
            catch (Exception)
            {
                return formulas[Convert.ToInt32(type, CultureInfo.InvariantCulture)];
            }
        }

        /// <summary>
        /// The enum in a RAS assembly that <paramref name="isWanted"/> picks.
        /// If there is none, the error lists the enums the assembly does have.
        /// </summary>
        private static Type FindEnum(string assemblyName, string what, Func<Type, bool> isWanted)
        {
            Assembly assembly = Assembly.Load(assemblyName);
            Type[] types;
            try
            {
                types = assembly.GetTypes();
            }
            catch (ReflectionTypeLoadException ex)
            {
                types = ex.Types;
            }
            var enums = new List<string>();
            foreach (Type type in types)
            {
                if (type == null || !type.IsEnum)
                {
                    continue;
                }
                if (isWanted(type))
                {
                    return type;
                }
                enums.Add(type.Name);
            }
            enums.Sort(StringComparer.Ordinal);
            throw new InvalidOperationException(
                "found no enum for " + what + " in " + assembly.GetName().Name +
                ". Its enums: " + string.Join(", ", enums));
        }

        /// <summary>Every Area of a RAS ReportDefinition, whatever members this runtime names them by.</summary>
        private static List<object> Areas(dynamic definition)
        {
            var areas = new List<object>();
            foreach (string member in AreaMembers)
            {
                object value;
                try
                {
                    value = definition.GetType().InvokeMember(
                        member, BindingFlags.GetProperty, null, definition, null);
                }
                catch (Exception)
                {
                    continue;
                }
                if (value == null)
                {
                    continue;
                }
                if (HasMember(value, "Sections"))
                {
                    if (!areas.Contains(value)) areas.Add(value);
                }
                else if (value is IEnumerable many)
                {
                    foreach (object area in many)
                    {
                        if (area != null && !areas.Contains(area)) areas.Add(area);
                    }
                }
            }
            if (areas.Count == 0)
            {
                throw new InvalidOperationException(
                    "found no areas on the RAS ReportDefinition (tried " + string.Join(", ", AreaMembers) + ")");
            }
            return areas;
        }

        // ====================================================================
        // Helpers
        // ====================================================================

        /// <summary>If RecordNumber Mod 2 = 0 Then Color (R, G, B) Else crNoColor</summary>
        private static string AlternateRowExpression(Dictionary<string, JsonElement> parameters)
        {
            int r = Channel(parameters, "AlternateRowColor_R");
            int g = Channel(parameters, "AlternateRowColor_G");
            int b = Channel(parameters, "AlternateRowColor_B");
            return string.Format(CultureInfo.InvariantCulture,
                "If RecordNumber Mod 2 = 0 Then Color ({0}, {1}, {2}) Else crNoColor", r, g, b);
        }

        private static int Channel(Dictionary<string, JsonElement> parameters, string name)
        {
            const int fallback = 238;
            if (parameters == null || !parameters.TryGetValue(name, out JsonElement value))
            {
                return fallback;
            }
            string text = value.ValueKind == JsonValueKind.String ? value.GetString() : value.GetRawText();
            return double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out double number)
                ? Math.Max(0, Math.Min(255, (int)Math.Round(number)))
                : fallback;
        }

        private static bool HasMember(object target, string member)
        {
            try
            {
                target.GetType().InvokeMember(member, BindingFlags.GetProperty, null, target, null);
                return true;
            }
            catch (Exception)
            {
                return false;
            }
        }

        private static string SafeName(dynamic section)
        {
            try { return Convert.ToString(section.Name, CultureInfo.InvariantCulture) ?? string.Empty; }
            catch (Exception) { return string.Empty; }
        }

        // crSectionAreaConditionFormulaTypeBackgroundColor -> BackgroundColor
        private static string ShortConditionName(string typeName)
        {
            const string prefix = "crSectionAreaConditionFormulaType";
            return typeName.StartsWith(prefix, StringComparison.Ordinal) ? typeName.Substring(prefix.Length) : typeName;
        }

        private static string Where(string subreport, string section)
        {
            return string.IsNullOrEmpty(subreport) ? section : subreport + "/" + section;
        }

        private static bool Has(string text, string part)
        {
            return text != null && text.IndexOf(part, StringComparison.OrdinalIgnoreCase) >= 0;
        }
    }
}
