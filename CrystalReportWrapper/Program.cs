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
using System.Collections.Generic;
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

        // TABLE QUERY CATALOG
        // -------------------
        // This is NOT "the tables for the current report" - it's every
        // table this worker knows how to fetch, across ALL reports you'll
        // ever run through it. A given .rpt only pulls the subset it
        // actually references (see RunExportPipeline, which reads
        // report.Database.Tables and looks up just those names here) - so
        // adding support for a new report is usually a zero-code-change
        // operation as long as it only touches tables already cataloged.
        // Only a genuinely new table needs a new entry, and that entry is
        // then reused by every future report that also touches it. This is
        // what avoids needing a separate .cs file (or even a recompile)
        // per report.
        //
        // Case-insensitive lookup (OrdinalIgnoreCase) - Table.Name from a
        // loaded .rpt should match Location exactly, but this avoids a
        // silent "no matching table" over a stray casing difference.
        //
        // Confirmed via --inspect against Backlog_RFoF_WO.rpt: that report
        // expects SODetail, SOHeader, PartMaster, and Customers - NOT
        // WOHeader, despite "WO" in the filename. WOHeader belongs to a
        // different .rpt (WorkOrderTraveler.rpt is the likely candidate) -
        // once you --inspect that one, add a WOHeader entry here (once)
        // and both reports work off the same catalog.
        //
        // Column aliases below match --inspect's field list per table
        // exactly (case-sensitive on the DataTable/Crystal side, even
        // though the dictionary key lookup itself is case-insensitive),
        // same rule as RegionCode/DescText. Postgres table/column names are
        // assumed lowercase-of-the-Access-name (confirmed pattern from
        // RegionCodes: "RegionCodes" -> regioncodes, "RegionCode" ->
        // regioncode) - verify against your actual Postgres schema and
        // adjust the left-hand side (before AS) if your migration used
        // different casing/naming.
        private static readonly Dictionary<string, string> TableQueryCatalog = new(StringComparer.OrdinalIgnoreCase)
        {
            ["SOHeader"] = @"
                SELECT
                    sonumber AS ""SONumber"",
                    orderdate AS ""OrderDate"",
                    customerid AS ""CustomerID"",
                    salesperson AS ""SalesPerson"",
                    termscode AS ""TermsCode"",
                    shipviacode AS ""ShipViaCode"",
                    fobcode AS ""FOBCode"",
                    requireddate AS ""RequiredDate"",
                    enteredby AS ""EnteredBy"",
                    notes AS ""Notes"",
                    billtoaddress AS ""BillToAddress"",
                    shiptoaddress AS ""ShipToAddress"",
                    orderedby AS ""OrderedBy"",
                    customerpo AS ""CustomerPO"",
                    pricecode AS ""PriceCode"",
                    shipholdflag AS ""ShipHoldFlag"",
                    closedflag AS ""ClosedFlag"",
                    departmentcode AS ""DepartmentCode"",
                    currencycode AS ""CurrencyCode"",
                    currencyrate AS ""CurrencyRate"",
                    jobnumber AS ""JobNumber"",
                    regioncode AS ""RegionCode"",
                    attention AS ""Attention"",
                    quotenumber AS ""QuoteNumber"",
                    ordertype AS ""OrderType"",
                    userdefined AS ""UserDefined"",
                    soheader_pkey AS ""SOHeader_PKey"",
                    billtocontact AS ""BillToContact"",
                    shiptocontact AS ""ShipToContact""
                FROM soheader;",

            ["SODetail"] = @"
                SELECT
                    sonumber AS ""SONumber"",
                    soline AS ""SOLine"",
                    customerline AS ""CustomerLine"",
                    taxableflag AS ""TaxableFlag"",
                    partnumber AS ""PartNumber"",
                    partxreference AS ""PartXReference"",
                    quantityordered AS ""QuantityOrdered"",
                    actualshipdate AS ""ActualShipDate"",
                    quantityshipped AS ""QuantityShipped"",
                    quantityreturned AS ""QuantityReturned"",
                    scheduledshipdate AS ""ScheduledShipDate"",
                    customerprice AS ""CustomerPrice"",
                    salesuom AS ""SalesUOM"",
                    notes AS ""Notes"",
                    taxcode AS ""TaxCode"",
                    taxflag2 AS ""TaxFlag2"",
                    taxflag3 AS ""TaxFlag3"",
                    taxcode2 AS ""TaxCode2"",
                    taxcode3 AS ""TaxCode3"",
                    closedflag AS ""ClosedFlag"",
                    productclass AS ""ProductClass"",
                    userdefined1 AS ""UserDefined1"",
                    userdefined AS ""UserDefined"",
                    sodetail_pkey AS ""SODetail_PKey""
                FROM sodetail;",

            ["Customers"] = @"
                SELECT
                    customerid AS ""CustomerID"",
                    customername AS ""CustomerName"",
                    pricecode AS ""PriceCode"",
                    regioncode AS ""RegionCode"",
                    shipholdflag AS ""ShipHoldFlag"",
                    termscode AS ""TermsCode"",
                    shipviacode AS ""ShipViaCode"",
                    fobcode AS ""FOBCode"",
                    currencycode AS ""CurrencyCode"",
                    vatregnumber AS ""VATRegNumber"",
                    vatbranchid AS ""VATBranchID"",
                    dateadded AS ""DateAdded"",
                    notes AS ""Notes"",
                    activeflag AS ""ActiveFlag"",
                    creditlimit AS ""CreditLimit"",
                    pricedisctype AS ""PriceDiscType"",
                    customerdisclevel AS ""CustomerDiscLevel"",
                    userdefined1 AS ""UserDefined1"",
                    salespersonid AS ""SalespersonID"",
                    customers_pkey AS ""Customers_PKey""
                FROM customers;",

            ["PartMaster"] = @"
                SELECT
                    partnumber AS ""PartNumber"",
                    revision AS ""Revision"",
                    desctext AS ""DescText"",
                    stockuom AS ""StockUOM"",
                    densitycode AS ""DensityCode"",
                    bomlevel AS ""BOMLevel"",
                    graphicpath AS ""GraphicPath"",
                    dimension AS ""Dimension"",
                    weight AS ""Weight"",
                    userdefined1 AS ""UserDefined1"",
                    enteredby AS ""EnteredBy"",
                    dateadded AS ""DateAdded"",
                    engnotes AS ""EngNotes"",
                    isc AS ""ISC"",
                    omc AS ""OMC"",
                    departmentcode AS ""DepartmentCode"",
                    stockroomcode AS ""StockroomCode"",
                    locationcode AS ""LocationCode"",
                    uompurchase AS ""UOMPurchase"",
                    leadtime AS ""LeadTime"",
                    ordermultiple AS ""OrderMultiple"",
                    yieldfactor AS ""YieldFactor"",
                    safetystock AS ""SafetyStock"",
                    orderquantity AS ""OrderQuantity"",
                    defaultpocost AS ""DefaultPOCost"",
                    listprice AS ""ListPrice"",
                    suocode AS ""SUOCode"",
                    commoditycode AS ""CommodityCode"",
                    icncode AS ""ICNCode"",
                    productclass AS ""ProductClass"",
                    productpricecode AS ""ProductPriceCode"",
                    specialstorage AS ""SpecialStorage"",
                    shelflife AS ""ShelfLife"",
                    standardhours AS ""StandardHours"",
                    partcommflag AS ""PartCommFlag"",
                    partcommrate AS ""PartCommRate"",
                    taxableflag AS ""TaxableFlag"",
                    taxcode AS ""TaxCode"",
                    userdefined2 AS ""UserDefined2"",
                    lastxactiondate AS ""LastXactionDate"",
                    ytdusage AS ""YTDUsage"",
                    abccode AS ""ABCCode"",
                    abcdollarusage AS ""ABCDollarUsage"",
                    abcpartpercent AS ""ABCPartPercent"",
                    abcdollarpercent AS ""ABCDollarPercent"",
                    lastcountdate AS ""LastCountDate"",
                    generatetagflag AS ""GenerateTagFlag"",
                    stdmaterialcost AS ""STDMaterialCost"",
                    stdburdencost AS ""STDBurdenCost"",
                    stdlaborcost AS ""STDLaborCost"",
                    stdsetupcost AS ""STDSetUpCost"",
                    stdsubcontcost AS ""STDSubContCost"",
                    costrevisiondate AS ""CostRevisionDate"",
                    materialcost AS ""MaterialCost"",
                    laborcost AS ""LaborCost"",
                    burdencost AS ""BurdenCost"",
                    setupcost AS ""SetUpCost"",
                    subcontcost AS ""SubContCost"",
                    cost AS ""Cost"",
                    partmaster_pkey AS ""PartMaster_PKey""
                FROM partmaster;",

            // Confirmed via --inspect against WorkOrderTraveler.rpt. NOTE:
            // this table's original source is a DIFFERENT Access file
            // (Pen.mdb) than SOHeader/SODetail/Customers/PartMaster above
            // (which come from OpticalZonuMRP.mdb) - confirm your Postgres
            // migration actually includes this data under a "woheader"
            // table before relying on this query; it may not have been
            // migrated yet if the migration only covered OpticalZonuMRP.mdb.
            ["WOHeader"] = @"
                SELECT
                    wonumber AS ""WONumber"",
                    startdate AS ""StartDate"",
                    requireddate AS ""RequiredDate"",
                    wopriority AS ""WOPriority"",
                    quantitycompleted AS ""QuantityCompleted"",
                    quantityreleased AS ""QuantityReleased"",
                    quantityrequired AS ""QuantityRequired"",
                    quantitytostart AS ""QuantityToStart"",
                    partnumber AS ""PartNumber"",
                    workorderuom AS ""WorkOrderUOM"",
                    closedflag AS ""ClosedFlag"",
                    enteredby AS ""EnteredBy"",
                    releaseddate AS ""ReleasedDate"",
                    jobnumber AS ""JobNumber"",
                    notes AS ""Notes"",
                    userdefined AS ""UserDefined"",
                    woheader_pkey AS ""WOHeader_PKey""
                FROM woheader;",

            // WorkOrderTraveler_TTX is INTENTIONALLY NOT in this catalog
            // yet. Its --inspect connection info (Database DLL:
            // crdb_fielddef.dll, QE_DatabaseType: "Field Definitions Only")
            // means it isn't a plain table - Crystal only has a cached
            // snapshot of its column shapes, the live connection is gone.
            // Its fields (PartMaster_DescText, WorkCenterName,
            // OperationCodes_DescText, and a suspicious "Isnull_Notes"
            // column) strongly suggest it was originally a hand-written SQL
            // Command joining a WO routing/operations table with
            // PartMaster, WorkCenters, and OperationCodes - not something
            // safe to guess at. Check Database Expert in the Crystal
            // Designer for a Command object and its stored SQL text before
            // adding an entry here.
        };

        // RELATION CATALOG
        // ----------------
        // Same "write once, reuse across every report" idea as the table
        // catalog above, but for joins. A pair of tables either relates the
        // same way in every report that uses both of them, or it doesn't
        // relate at all - so these are keyed on the TABLE PAIR, not on any
        // particular report. BuildReportDataSet adds a relation only when
        // both of its tables are actually present for the current report,
        // so a report using just SOHeader+Customers gets that one relation
        // and skips the other two automatically - no per-report relation
        // list to maintain.
        //
        // First three confirmed against the actual Crystal-generated SQL
        // for a report using these tables (its "EXTERNAL JOIN" lines are
        // Crystal's own client-side correlation syntax for Access/DAO
        // reports that don't do real cross-table SQL joins - same thing
        // DataRelation does here). The fourth (WOHeader-SODetail) came from
        // that same query and was new information - in this database, work
        // orders link to sales-order lines by matching PartNumber, not by
        // any order number. Not yet confirmed for every report that uses
        // both tables, but table relationships are a property of the
        // database, not any one report, so it's cataloged here rather than
        // re-derived per report. Verify in the Crystal designer if a
        // report's linked/grouped sections render empty or duplicated.
        private static readonly List<(string ParentTable, string ParentColumn, string ChildTable, string ChildColumn)> RelationCatalog = new()
        {
            ("SOHeader", "SONumber", "SODetail", "SONumber"),
            ("Customers", "CustomerID", "SOHeader", "CustomerID"),
            ("PartMaster", "PartNumber", "SODetail", "PartNumber"),
            ("WOHeader", "PartNumber", "SODetail", "PartNumber"),
        };
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
                // finished DataTable (or, for multi-table reports, several
                // DataTables in one DataSet). The report's .rpt file must be
                // designed against an ADO.NET (XML) data source with a
                // matching schema for this to line up correctly.
                //
                // Passing a bare DataTable to SetDataSource (even at the
                // ReportDocument level) doesn't fully take it off the .ttx
                // codepath - Crystal can still fall back to the table's
                // original field-definition driver (crdb_fielddef.dll)
                // during export/render, and that driver has no 64-bit
                // build, which is what "Failed to load database
                // information" actually means here even though
                // SetDataSource itself doesn't throw. Wrapping every
                // DataTable in one DataSet routes Crystal through its
                // ADO.NET provider (crdb_adoplus.dll) end-to-end instead,
                // which is 64-bit and never touches the dead .ttx path.
                //
                // Which tables to fetch is NOT hardcoded per report - the
                // .rpt itself already says what it needs, right here in
                // report.Database.Tables, now that it's loaded. This is
                // what makes one exe/one Program.cs work across every
                // report: each report just asks for whatever subset of the
                // TableQueryCatalog it happens to use.
                var requiredTables = new List<string>();
                foreach (CrystalDecisions.CrystalReports.Engine.Table t in report.Database.Tables)
                {
                    requiredTables.Add(t.Name);
                }

                DataSet reportDataSet = BuildReportDataSet(requiredTables);
                report.SetDataSource(reportDataSet);

                Console.WriteLine($"Table Count (report expects): {report.Database.Tables.Count}");
                Console.WriteLine($"Table Count (data source provides): {reportDataSet.Tables.Count}");
                foreach (CrystalDecisions.CrystalReports.Engine.Table t in report.Database.Tables)
                {
                    // This is the multi-table version of the diagnostic
                    // that used to just print every column name against
                    // the single table - now it flags, per table the
                    // report actually expects, whether our DataSet
                    // supplied a same-named DataTable at all. A report
                    // expecting 5 tables but only getting 3 matches here
                    // is a much faster diagnosis than an opaque export
                    // failure later.
                    bool matched = reportDataSet.Tables.Contains(t.Name);
                    Console.WriteLine($"Table: {t.Name} - {(matched ? "matched in data source" : "NO MATCHING TABLE IN DATA SOURCE (check TableQueryCatalog key spelling/casing)")}");
                }

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
        /// Connects to Postgres once and runs the query for each table in
        /// requiredTableNames (looked up from TableQueryCatalog), returning
        /// all results as named DataTables inside a single DataSet ready to
        /// hand to Crystal via ReportDocument.SetDataSource. Then adds
        /// whichever RelationCatalog entries apply given the tables that
        /// actually ended up present.
        ///
        /// requiredTableNames is driven by the loaded report itself
        /// (report.Database.Tables), not hardcoded - this is what lets the
        /// same catalog + this one method serve every report, instead of
        /// needing per-report code.
        /// </summary>
        private static DataSet BuildReportDataSet(IEnumerable<string> requiredTableNames)
        {
            // Builds a connection string from the constants above. Npgsql's
            // connection string keys are: Host, Port, Database, Username,
            // Password - see https://www.npgsql.org/doc/connection-string-parameters.html
            // for additional options (SSL Mode, Timeout, etc.) if your setup
            // needs them.
            string connectionString =
                $"Host={PgHost};Port={PgPort};Database={PgDatabase};" +
                $"Username={PgUser};Password={PgPassword};";

            var dataSet = new DataSet();

            using var connection = new NpgsqlConnection(connectionString);
            connection.Open();

            foreach (string tableName in requiredTableNames)
            {
                if (!TableQueryCatalog.TryGetValue(tableName, out string? query))
                {
                    // Fail loudly and specifically instead of silently
                    // exporting a report with a missing table (which would
                    // otherwise surface later as a vague Crystal binding
                    // error). This is the "you need one new catalog entry"
                    // signal - not a "write a new Program.cs" signal.
                    throw new InvalidOperationException(
                        $"Report requires table '{tableName}', which has no entry in " +
                        $"TableQueryCatalog. Add a query for it there (once) - every " +
                        $"other report that also uses '{tableName}' will reuse the same entry.");
                }

                using var command = new NpgsqlCommand(query, connection);
                using var adapter = new NpgsqlDataAdapter(command);

                // TableName set here (not after Fill) - DataSet.Tables.Add
                // uses this to key the table by name, which is what
                // Crystal's ADO.NET binding matches against report.Database
                // .Tables[i].Name.
                var table = new DataTable(tableName);
                adapter.Fill(table);

                Console.WriteLine($"Rows for '{tableName}': {table.Rows.Count}");
                dataSet.Tables.Add(table);
            }

            // Report links: --inspect doesn't surface the Database Expert
            // Links tab directly, but the report's real (non-LANG) formulas
            // reference these table pairs together (e.g. "Sample" reads
            // both SOHeader.CustomerPO and SODetail.QuantityReturned;
            // "BoMvalidate" reads PartMaster.Cost/UserDefined1 against
            // SODetail rows), and the shared columns are all StringField on
            // both sides - so these are inferred, not confirmed from the
            // .rpt's actual Links tab. Verify in the Crystal designer if
            // sections render empty or duplicated.
            //
            // Only added when BOTH sides of a RelationCatalog entry are
            // present in THIS report's DataSet - a report that only uses
            // SOHeader+Customers skips the other two relations automatically.
            //
            // createConstraints: false - real MDB-sourced data is exactly
            // the kind of thing that violates strict FK/unique constraints
            // (blank PartNumbers, a SODetail line whose part got deleted
            // from PartMaster, etc.). true would throw a ConstraintException
            // on the first bad row instead of just leaving that row
            // unmatched, which is what Crystal will silently do anyway.
            foreach (var rel in RelationCatalog)
            {
                if (dataSet.Tables.Contains(rel.ParentTable) && dataSet.Tables.Contains(rel.ChildTable))
                {
                    dataSet.Relations.Add(
                        $"{rel.ParentTable}To{rel.ChildTable}",
                        dataSet.Tables[rel.ParentTable].Columns[rel.ParentColumn],
                        dataSet.Tables[rel.ChildTable].Columns[rel.ChildColumn],
                        false);
                }
            }

            return dataSet;
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