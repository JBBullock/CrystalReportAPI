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
using System.Text.RegularExpressions;
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

    // ------------------------------------------------------------------
    // --extract-sql mode result type. One JSON line per run, same
    // contract as --inspect/export: Python reads the last stdout line.
    // ------------------------------------------------------------------
    internal class ExtractSqlResult
    {
        public bool Success { get; set; }
        public string ReportPath { get; set; } = string.Empty;
        public string? SqlPath { get; set; }
        // Every table the report (and its subreports) expects, in order.
        public System.Collections.Generic.List<string> Tables { get; set; } = new();
        // Tables that had a TableQueryCatalog entry - real SQL was written.
        public System.Collections.Generic.List<string> MatchedTables { get; set; } = new();
        // Tables with NO catalog entry - a commented-out skeleton was
        // written instead, listing the columns the report expects.
        public System.Collections.Generic.List<string> MissingTables { get; set; } = new();
        // True when the .sql file already existed with different content
        // and was copied to <name>.sql.bak before being overwritten.
        public bool BackedUp { get; set; }
        public string? Error { get; set; }
    }

    internal class Program
    {
        // ====================================================================
        // >>> DATABASE CONFIGURATION - set via environment variables <<<
        // ====================================================================
        // These connect to Postgres directly from C# (via the Npgsql
        // driver), fetch the report's data as a DataTable, and hand that
        // table to Crystal Reports with SetDataSource() - Crystal never
        // talks to the database itself this way, no ODBC driver required,
        // which sidesteps the 32-bit/64-bit ODBC registration problems.
        //
        // Previously five hardcoded `const string` literals here,
        // including a plaintext password compiled straight into the
        // .exe and committed to source control. Moved to environment
        // variables for two reasons: (1) "127.0.0.1" only means
        // anything on a bare-metal run - inside a container it's the
        // container's OWN loopback, not the Docker host's, so a
        // hardcoded value silently breaks the moment this runs
        // containerized (see docker-compose.yml's PG_HOST, which points
        // at host.docker.internal instead); (2) a password baked into a
        // compiled binary can't be rotated without a rebuild and can't
        // be kept out of git history. Host/Port/Database/User keep the
        // SAME values as before as their fallback default, so a
        // bare-metal run with no environment variables set behaves
        // exactly like it did before this change. PgPassword has NO
        // fallback - this fails fast at startup (same pattern as
        // report_api_server.py's RPTCONVERT_API_KEY check) instead of
        // silently connecting with an empty or wrong password.
        private static readonly string PgHost = Environment.GetEnvironmentVariable("PG_HOST") ?? "127.0.0.1";
        private static readonly string PgPort = Environment.GetEnvironmentVariable("PG_PORT") ?? "5430";
        private static readonly string PgDatabase = Environment.GetEnvironmentVariable("PG_DATABASE") ?? "postgres";
        private static readonly string PgUser = Environment.GetEnvironmentVariable("PG_USER") ?? "postgres";
        // A property (evaluated on first USE in BuildReportDataSet), not a
        // static readonly field: as a field initializer, the throw below
        // ran in Program's type initializer, so merely touching ANY static
        // (e.g. TableQueryCatalog from --extract-sql, which never connects
        // to Postgres) failed with a TypeInitializationException when
        // PG_PASSWORD was unset. Export still fails fast - just at the
        // point a connection string is actually built.
        private static string PgPassword => Environment.GetEnvironmentVariable("PG_PASSWORD")
            ?? throw new InvalidOperationException(
                "PG_PASSWORD environment variable is not set - CrystalReportWrapper.exe " +
                "refuses to start without it, since a Postgres password used to be " +
                "hardcoded directly in this file (and therefore in source control). Set " +
                "PG_PASSWORD before running this - see docker-compose.yml for the " +
                "containerized case, or set it as a user/system environment variable for " +
                "a bare-metal run.");

        // TABLE QUERY CATALOG  (FALLBACK ONLY)
        // ------------------------------------
        // A report's queries now come from SQLqueries\<ReportName>.sql (see
        // LoadReportSqlFile). This dictionary is used only for a table that
        // file has no query for - new queries belong in the .sql file, and
        // an entry here can be deleted once its reports have files.
        //
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
                    orderdate::timestamp AS ""OrderDate"",
                    customerid AS ""CustomerID"",
                    salesperson AS ""SalesPerson"",
                    termscode AS ""TermsCode"",
                    shipviacode AS ""ShipViaCode"",
                    fobcode AS ""FOBCode"",
                    requireddate::timestamp AS ""RequiredDate"",
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
                    actualshipdate::timestamp AS ""ActualShipDate"",
                    quantityshipped AS ""QuantityShipped"",
                    quantityreturned AS ""QuantityReturned"",
                    scheduledshipdate::timestamp AS ""ScheduledShipDate"",
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
                    dateadded::timestamp AS ""DateAdded"",
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
                    dateadded::timestamp AS ""DateAdded"",
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
                    lastxactiondate::timestamp AS ""LastXactionDate"",
                    ytdusage AS ""YTDUsage"",
                    abccode AS ""ABCCode"",
                    abcdollarusage AS ""ABCDollarUsage"",
                    abcpartpercent AS ""ABCPartPercent"",
                    abcdollarpercent AS ""ABCDollarPercent"",
                    lastcountdate::timestamp AS ""LastCountDate"",
                    generatetagflag AS ""GenerateTagFlag"",
                    stdmaterialcost AS ""STDMaterialCost"",
                    stdburdencost AS ""STDBurdenCost"",
                    stdlaborcost AS ""STDLaborCost"",
                    stdsetupcost AS ""STDSetUpCost"",
                    stdsubcontcost AS ""STDSubContCost"",
                    costrevisiondate::timestamp AS ""CostRevisionDate"",
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
                    startdate::timestamp AS ""StartDate"",
                    requireddate::timestamp AS ""RequiredDate"",
                    wopriority AS ""WOPriority"",
                    quantitycompleted AS ""QuantityCompleted"",
                    quantityreleased AS ""QuantityReleased"",
                    quantityrequired AS ""QuantityRequired"",
                    quantitytostart AS ""QuantityToStart"",
                    partnumber AS ""PartNumber"",
                    workorderuom AS ""WorkOrderUOM"",
                    closedflag AS ""ClosedFlag"",
                    enteredby AS ""EnteredBy"",
                    releaseddate::timestamp AS ""ReleasedDate"",
                    jobnumber AS ""JobNumber"",
                    notes AS ""Notes"",
                    userdefined AS ""UserDefined"",
                    woheader_pkey AS ""WOHeader_PKey""
                FROM woheader;",

            // Company - added 2026-08-27. salesorder.rpt's Database.Tables
            // includes a table literally named 'company' (confirmed a real
            // Postgres table via SQLFetches/schema_only.sql - NOT the same
            // as `preferences`, ZMRP's own File > Company Preferences
            // table, and NOT vestigial as first suspected before the user
            // pointed at schema_only.sql). Column list/types below are
            // confirmed against that schema dump. Aliases are NOT
            // confirmed against a real --inspect of the live
            // reports/SalesOrder.rpt (TemplateRPTs\SalesOrder.rpt, which
            // WAS inspected on 2026-08-25 as jsonInspections/inspect-
            // sales.json, has no 'company' table at all - that inspection
            // is either stale or of a different copy of the file than the
            // one actually deployed to reports/, so it can't be used as
            // ground truth here) - six of these columns share their exact
            // name with this report's own global parameters
            // (CompanyName/CompanyPhone/CompanyFAX/CompanyEmail/
            // VATRegNumber/VATBranchID, confirmed present in inspect-
            // sales.json's parameter list), which is a strong but NOT
            // certain signal for what the table-bound fields are named
            // too - followed the same direct-PascalCase-of-the-column
            // convention as every other single-table entry here
            // (Customers/PartMaster/etc.) rather than renaming to match
            // the parameters, since this file's own precedent (see
            // Customers.vatregnumber -> ""VATRegNumber"") is bare
            // PascalCasing, not prefixing/renaming. If Export() throws a
            // field-not-found error naming a specific alias, adjust that
            // one alias to match - a much narrower fix than today's total
            // block. phone1fmt/phone2fmt/faxfmt are guessed to be a
            // paired display-format mask for phone1/phone2/fax (common in
            // legacy Access-style contact tables) - unconfirmed, included
            // as-is either way since dropping a real field would just
            // trade this error for the same kind of error on a different
            // field name.
            ["Company"] = @"
                SELECT
                    company_pkey AS ""Company_PKey"",
                    companyname AS ""CompanyName"",
                    contact1 AS ""Contact1"",
                    contact2 AS ""Contact2"",
                    email AS ""Email"",
                    regioncode AS ""RegionCode"",
                    vatregnumber AS ""VATRegNumber"",
                    vatbranchid AS ""VATBranchID"",
                    phone1 AS ""Phone1"",
                    phone1fmt AS ""Phone1Fmt"",
                    phone2 AS ""Phone2"",
                    phone2fmt AS ""Phone2Fmt"",
                    fax AS ""Fax"",
                    faxfmt AS ""FaxFmt""
                FROM company;",

            // COLUMN_MAP has no "Customer Discount Levels" entry to confirm
            // this against - column names assumed from the same code/
            // desctext shape every other 2-field code table here uses.
            // Verify against the real customerdisclevel schema.
            ["CustomerDiscLevel_TTX"] = @"
                SELECT
                    customerdisclevel AS ""CustomerDiscLevel"",
                    desctext AS ""DescText""
                FROM customerdisclevel;",

            // stocklocations' own column names aren't independently
            // confirmed (no COLUMN_MAP entry maps to this table - TABLE_MAP's
            // ("Inventory", "Locations") actually points at departmentcodes
            // instead) - departmentcode/locationcode/desctext assumed from
            // the StockLocations_DescText join alias --inspect returned,
            // plus the shape every other code table here follows. Verify
            // before relying on this.
            ["StockroomLocations_TTX"] = @"
                SELECT
                    sl.departmentcode AS ""DepartmentCode"",
                    sl.locationcode AS ""LocationCode"",
                    sl.desctext AS ""StockLocations_DescText"",
                    dc.desctext AS ""DepartmentCodes_DescText"",
                    dc.accountnumber AS ""AccountNumber"",
                    dc.nettableflag AS ""NettableFlag"",
                    dc.inventoryflag AS ""InventoryFlag""
                FROM stocklocations sl
                LEFT JOIN departmentcodes dc ON dc.departmentcode = sl.departmentcode;",

            // SalesOrder_TTX - one row per SO line, denormalized by the
            // legacy Alliance reporting engine from ~11 real tables. Every
            // join below is confirmed against the real pg_dumpall schema
            // (zonu_pg_dumpall_08_03_2026.sql), not guessed:
            //   - soheader.shiptoaddress/billtoaddress are varchar(6)
            //     CODES, not address blobs - they're customeraddress.
            //     addressid, joined together with soheader.customerid
            //     (customeraddress is keyed on (customerid, addressid),
            //     confirmed from its CREATE TABLE).
            //   - soheader.salesperson is an employeeid FK -> employees,
            //     which is where Acknowledgement_TTX/SalesOrder_TTX's
            //     "LastName" field comes from (there is no lastname
            //     anywhere on soheader itself).
            //   - taxcodes is joined three times (aliased tx1/tx2/tx3) -
            //     sodetail carries three independent tax codes
            //     (taxcode/taxcode2/taxcode3), each needing its own rate.
            //
            // The following fields are NOT raw columns anywhere in the
            // schema and are marked INFERRED below rather than treated as
            // fact - they're a reconstruction of plausible order-line math
            // (qty * price, extended by currency rate, taxed by rate where
            // the matching Taxable*Flag is true), not confirmed against
            // the legacy system's actual output:
            //   ConvertListPrice, AfterExchangePrice, LineAmount,
            //   LineSubtotal, BaseTaxAmount, Tax2Amount, Tax3Amount,
            //   LineTotal, CustomerDiscount.
            // Before trusting a rendered SalesOrder PDF's totals, pick one
            // real, already-invoiced SONumber and diff this report's
            // output against whatever the legacy system produced for the
            // same order - these formulas are a starting point, not a
            // verified match.
            ["SalesOrder_TTX"] = @"
                SELECT
                    sd.sonumber AS ""SONumber"",
                    sd.soline AS ""SOLine"",
                    sh.requireddate::timestamp AS ""RequiredDate"",
                    sh.customerid AS ""CustomerID"",
                    sh.orderedby AS ""OrderedBy"",
                    emp.lastname AS ""LastName"",
                    sh.orderdate::timestamp AS ""OrderDate"",
                    sh.currencycode AS ""CurrencyCode"",
                    sh.currencyrate AS ""CurrencyRate"",
                    sh.customerpo AS ""CustomerPO"",
                    sd.customerline AS ""CustomerLine"",
                    sd.taxableflag AS ""TaxableFlag"",
                    sd.taxcode AS ""TaxCode"",
                    sd.taxflag2 AS ""TaxFlag2"",
                    sd.taxcode2 AS ""TaxCode2"",
                    sd.taxflag3 AS ""TaxFlag3"",
                    sd.taxcode3 AS ""TaxCode3"",
                    sd.scheduledshipdate::timestamp AS ""ScheduledShipDate"",
                    sd.quantityordered AS ""QuantityOrdered"",
                    sd.salesuom AS ""SalesUOM"",
                    sd.customerprice AS ""CustomerPrice"",
                    sd.partxreference AS ""PartXReference"",
                    sd.partnumber AS ""PartNumber"",
                    pm.revision AS ""Revision"",
                    pm.desctext AS ""PartMaster_DescText"",
                    pm.stockuom AS ""StockUOM"",
                    pm.listprice AS ""ListPrice"",
                    pm.densitycode AS ""DensityCode"",
                    tc.desctext AS ""TermsCodes_DescText"",
                    svc.desctext AS ""ShipViaCodes_DescText"",
                    fc.desctext AS ""FOBCodes_DescText"",
                    sh.pricecode AS ""PriceCode"",
                    c.customerdisclevel AS ""CustomerDiscLevel"",
                    c.customername AS ""CustomerName"",
                    c.pricedisctype AS ""PriceDiscType"",
                    tx1.taxrate AS ""BaseTaxRate"",
                    tx2.taxrate AS ""TaxRate2"",
                    tx3.taxrate AS ""TaxRate3"",
                    shipaddr.addressline1 AS ""ShipToAddress_AddressLine1"",
                    shipaddr.addressline2 AS ""ShipToAddress_AddressLine2"",
                    shipaddr.addressline3 AS ""ShipToAddress_AddressLine3"",
                    shipaddr.addressline4 AS ""ShipToAddress_AddressLine4"",
                    shipaddr.city AS ""ShipToAddress_City"",
                    shipaddr.state AS ""ShipToAddress_State"",
                    shipaddr.zipcode AS ""ShipToAddress_ZIPCode"",
                    shipaddr.country AS ""ShipToAddress_Country"",
                    shipaddr.postal AS ""ShipToAddress_Postal"",
                    billaddr.addressline1 AS ""BillToAddress_AddressLine1"",
                    billaddr.addressline2 AS ""BillToAddress_AddressLine2"",
                    billaddr.addressline3 AS ""BillToAddress_AddressLine3"",
                    billaddr.addressline4 AS ""BillToAddress_AddressLine4"",
                    billaddr.city AS ""BillToAddress_City"",
                    billaddr.state AS ""BillToAddress_State"",
                    billaddr.zipcode AS ""BillToAddress_ZIPCode"",
                    billaddr.country AS ""BillToAddress_Country"",
                    billaddr.postal AS ""BillToAddress_Postal"",
                    cc.currencysymbol AS ""CurrencySymbol"",
                    sd.notes AS ""SODetail_Notes"",
                    NULL AS ""CustomerDiscount"", -- INFERRED: no numeric discount column on customerdisclevel; may belong on pricediscountcodes via sh.pricecode instead - unconfirmed, not guessed
                    cdl.desctext AS ""CustomerDiscLevel_DescText"",
                    (CASE WHEN sd.taxableflag THEN 'Yes' ELSE 'No' END) AS ""Taxable"", -- INFERRED text rendering of TaxableFlag
                    (pm.listprice * COALESCE(sh.currencyrate, 1)) AS ""ConvertListPrice"", -- INFERRED
                    (sd.customerprice * COALESCE(sh.currencyrate, 1)) AS ""AfterExchangePrice"", -- INFERRED
                    (sd.quantityordered * sd.customerprice) AS ""LineAmount"", -- INFERRED
                    (CASE WHEN sd.taxableflag THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx1.taxrate, 0) ELSE 0 END) AS ""BaseTaxAmount"", -- INFERRED
                    (sd.quantityordered * sd.customerprice) AS ""LineSubtotal"", -- INFERRED: assumed equal to LineAmount, unconfirmed distinction
                    (CASE WHEN sd.taxflag2 THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx2.taxrate, 0) ELSE 0 END) AS ""Tax2Amount"", -- INFERRED
                    (CASE WHEN sd.taxflag3 THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx3.taxrate, 0) ELSE 0 END) AS ""Tax3Amount"", -- INFERRED
                    (
                        (sd.quantityordered * sd.customerprice)
                        + (CASE WHEN sd.taxableflag THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx1.taxrate, 0) ELSE 0 END)
                        + (CASE WHEN sd.taxflag2 THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx2.taxrate, 0) ELSE 0 END)
                        + (CASE WHEN sd.taxflag3 THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx3.taxrate, 0) ELSE 0 END)
                    ) AS ""LineTotal"", -- INFERRED: LineAmount + all three tax amounts
                    sh.notes AS ""SOHeader_Notes"",
                    (CASE WHEN sd.notes IS NULL THEN 1 ELSE 0 END) AS ""SODetail_IsnullNotes"",
                    (CASE WHEN sh.notes IS NULL THEN 1 ELSE 0 END) AS ""SOHeader_IsnullNotes""
                FROM sodetail sd
                JOIN soheader sh ON sh.sonumber = sd.sonumber
                LEFT JOIN customers c ON c.customerid = sh.customerid
                LEFT JOIN partmaster pm ON pm.partnumber = sd.partnumber
                LEFT JOIN termscodes tc ON tc.termscode = sh.termscode
                LEFT JOIN shipviacodes svc ON svc.shipviacode = sh.shipviacode
                LEFT JOIN fobcodes fc ON fc.fobcode = sh.fobcode
                LEFT JOIN customerdisclevel cdl ON cdl.customerdisclevel = c.customerdisclevel
                LEFT JOIN taxcodes tx1 ON tx1.taxcode = sd.taxcode
                LEFT JOIN taxcodes tx2 ON tx2.taxcode = sd.taxcode2
                LEFT JOIN taxcodes tx3 ON tx3.taxcode = sd.taxcode3
                LEFT JOIN currencycodes cc ON cc.currencycode = sh.currencycode
                LEFT JOIN employees emp ON emp.employeeid = sh.salesperson
                LEFT JOIN customeraddress shipaddr ON shipaddr.customerid = sh.customerid AND shipaddr.addressid = sh.shiptoaddress
                LEFT JOIN customeraddress billaddr ON billaddr.customerid = sh.customerid AND billaddr.addressid = sh.billtoaddress;",

            // PartList_TTX - all 10 fields (per report_registry.json's
            // "tables" entry for "partlist", which now embeds the same
            // field data generate_reports_manifest.py's --inspect pass
            // captures) map onto partmaster directly, confirmed against
            // the real pg_dumpall schema - no joins needed, single table.
            ["PartList_TTX"] = @"
                SELECT
                    partnumber AS ""PartNumber"",
                    revision AS ""Revision"",
                    desctext AS ""DescText"",
                    stockuom AS ""StockUOM"",
                    densitycode AS ""DensityCode"",
                    isc AS ""ISC"",
                    omc AS ""OMC"",
                    icncode AS ""ICNCode"",
                    departmentcode AS ""DepartmentCode"",
                    stockroomcode AS ""StockroomCode""
                FROM partmaster;",

            // Acknowledgement_TTX / Quotation_TTX - matched against
            // TemplateTTX/Acknowledgement.TTX and Quotation.TTX: both are
            // field-for-field identical to SalesOrder.TTX (same 72 fields,
            // same names/types) - Acknowledgement, Quotation, and
            // SalesOrder are the same underlying SO-line report shape
            // rendered at three different points in the order lifecycle.
            // Reusing SalesOrder_TTX's query verbatim rather than
            // duplicating it - same caveats apply (see the INFERRED note
            // above SalesOrder_TTX for the ~9 computed money fields).
            ["Acknowledgement_TTX"] = @"
                SELECT
                    sd.sonumber AS ""SONumber"",
                    sd.soline AS ""SOLine"",
                    sh.requireddate::timestamp AS ""RequiredDate"",
                    sh.customerid AS ""CustomerID"",
                    sh.orderedby AS ""OrderedBy"",
                    emp.lastname AS ""LastName"",
                    sh.orderdate::timestamp AS ""OrderDate"",
                    sh.currencycode AS ""CurrencyCode"",
                    sh.currencyrate AS ""CurrencyRate"",
                    sh.customerpo AS ""CustomerPO"",
                    sd.customerline AS ""CustomerLine"",
                    sd.taxableflag AS ""TaxableFlag"",
                    sd.taxcode AS ""TaxCode"",
                    sd.taxflag2 AS ""TaxFlag2"",
                    sd.taxcode2 AS ""TaxCode2"",
                    sd.taxflag3 AS ""TaxFlag3"",
                    sd.taxcode3 AS ""TaxCode3"",
                    sd.scheduledshipdate::timestamp AS ""ScheduledShipDate"",
                    sd.quantityordered AS ""QuantityOrdered"",
                    sd.salesuom AS ""SalesUOM"",
                    sd.customerprice AS ""CustomerPrice"",
                    sd.partxreference AS ""PartXReference"",
                    sd.partnumber AS ""PartNumber"",
                    pm.revision AS ""Revision"",
                    pm.desctext AS ""PartMaster_DescText"",
                    pm.stockuom AS ""StockUOM"",
                    pm.listprice AS ""ListPrice"",
                    pm.densitycode AS ""DensityCode"",
                    tc.desctext AS ""TermsCodes_DescText"",
                    svc.desctext AS ""ShipViaCodes_DescText"",
                    fc.desctext AS ""FOBCodes_DescText"",
                    sh.pricecode AS ""PriceCode"",
                    c.customerdisclevel AS ""CustomerDiscLevel"",
                    c.customername AS ""CustomerName"",
                    c.pricedisctype AS ""PriceDiscType"",
                    tx1.taxrate AS ""BaseTaxRate"",
                    tx2.taxrate AS ""TaxRate2"",
                    tx3.taxrate AS ""TaxRate3"",
                    shipaddr.addressline1 AS ""ShipToAddress_AddressLine1"",
                    shipaddr.addressline2 AS ""ShipToAddress_AddressLine2"",
                    shipaddr.addressline3 AS ""ShipToAddress_AddressLine3"",
                    shipaddr.addressline4 AS ""ShipToAddress_AddressLine4"",
                    shipaddr.city AS ""ShipToAddress_City"",
                    shipaddr.state AS ""ShipToAddress_State"",
                    shipaddr.zipcode AS ""ShipToAddress_ZIPCode"",
                    shipaddr.country AS ""ShipToAddress_Country"",
                    shipaddr.postal AS ""ShipToAddress_Postal"",
                    billaddr.addressline1 AS ""BillToAddress_AddressLine1"",
                    billaddr.addressline2 AS ""BillToAddress_AddressLine2"",
                    billaddr.addressline3 AS ""BillToAddress_AddressLine3"",
                    billaddr.addressline4 AS ""BillToAddress_AddressLine4"",
                    billaddr.city AS ""BillToAddress_City"",
                    billaddr.state AS ""BillToAddress_State"",
                    billaddr.zipcode AS ""BillToAddress_ZIPCode"",
                    billaddr.country AS ""BillToAddress_Country"",
                    billaddr.postal AS ""BillToAddress_Postal"",
                    cc.currencysymbol AS ""CurrencySymbol"",
                    sd.notes AS ""SODetail_Notes"",
                    NULL AS ""CustomerDiscount"", -- INFERRED: no numeric discount column on customerdisclevel; may belong on pricediscountcodes via sh.pricecode instead - unconfirmed, not guessed
                    cdl.desctext AS ""CustomerDiscLevel_DescText"",
                    (CASE WHEN sd.taxableflag THEN 'Yes' ELSE 'No' END) AS ""Taxable"", -- INFERRED text rendering of TaxableFlag
                    (pm.listprice * COALESCE(sh.currencyrate, 1)) AS ""ConvertListPrice"", -- INFERRED
                    (sd.customerprice * COALESCE(sh.currencyrate, 1)) AS ""AfterExchangePrice"", -- INFERRED
                    (sd.quantityordered * sd.customerprice) AS ""LineAmount"", -- INFERRED
                    (CASE WHEN sd.taxableflag THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx1.taxrate, 0) ELSE 0 END) AS ""BaseTaxAmount"", -- INFERRED
                    (sd.quantityordered * sd.customerprice) AS ""LineSubtotal"", -- INFERRED: assumed equal to LineAmount, unconfirmed distinction
                    (CASE WHEN sd.taxflag2 THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx2.taxrate, 0) ELSE 0 END) AS ""Tax2Amount"", -- INFERRED
                    (CASE WHEN sd.taxflag3 THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx3.taxrate, 0) ELSE 0 END) AS ""Tax3Amount"", -- INFERRED
                    (
                        (sd.quantityordered * sd.customerprice)
                        + (CASE WHEN sd.taxableflag THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx1.taxrate, 0) ELSE 0 END)
                        + (CASE WHEN sd.taxflag2 THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx2.taxrate, 0) ELSE 0 END)
                        + (CASE WHEN sd.taxflag3 THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx3.taxrate, 0) ELSE 0 END)
                    ) AS ""LineTotal"", -- INFERRED: LineAmount + all three tax amounts
                    sh.notes AS ""SOHeader_Notes"",
                    (CASE WHEN sd.notes IS NULL THEN 1 ELSE 0 END) AS ""SODetail_IsnullNotes"",
                    (CASE WHEN sh.notes IS NULL THEN 1 ELSE 0 END) AS ""SOHeader_IsnullNotes""
                FROM sodetail sd
                JOIN soheader sh ON sh.sonumber = sd.sonumber
                LEFT JOIN customers c ON c.customerid = sh.customerid
                LEFT JOIN partmaster pm ON pm.partnumber = sd.partnumber
                LEFT JOIN termscodes tc ON tc.termscode = sh.termscode
                LEFT JOIN shipviacodes svc ON svc.shipviacode = sh.shipviacode
                LEFT JOIN fobcodes fc ON fc.fobcode = sh.fobcode
                LEFT JOIN customerdisclevel cdl ON cdl.customerdisclevel = c.customerdisclevel
                LEFT JOIN taxcodes tx1 ON tx1.taxcode = sd.taxcode
                LEFT JOIN taxcodes tx2 ON tx2.taxcode = sd.taxcode2
                LEFT JOIN taxcodes tx3 ON tx3.taxcode = sd.taxcode3
                LEFT JOIN currencycodes cc ON cc.currencycode = sh.currencycode
                LEFT JOIN employees emp ON emp.employeeid = sh.salesperson
                LEFT JOIN customeraddress shipaddr ON shipaddr.customerid = sh.customerid AND shipaddr.addressid = sh.shiptoaddress
                LEFT JOIN customeraddress billaddr ON billaddr.customerid = sh.customerid AND billaddr.addressid = sh.billtoaddress;",

            ["Quotation_TTX"] = @"
                SELECT
                    sd.sonumber AS ""SONumber"",
                    sd.soline AS ""SOLine"",
                    sh.requireddate::timestamp AS ""RequiredDate"",
                    sh.customerid AS ""CustomerID"",
                    sh.orderedby AS ""OrderedBy"",
                    emp.lastname AS ""LastName"",
                    sh.orderdate::timestamp AS ""OrderDate"",
                    sh.currencycode AS ""CurrencyCode"",
                    sh.currencyrate AS ""CurrencyRate"",
                    sh.customerpo AS ""CustomerPO"",
                    sd.customerline AS ""CustomerLine"",
                    sd.taxableflag AS ""TaxableFlag"",
                    sd.taxcode AS ""TaxCode"",
                    sd.taxflag2 AS ""TaxFlag2"",
                    sd.taxcode2 AS ""TaxCode2"",
                    sd.taxflag3 AS ""TaxFlag3"",
                    sd.taxcode3 AS ""TaxCode3"",
                    sd.scheduledshipdate::timestamp AS ""ScheduledShipDate"",
                    sd.quantityordered AS ""QuantityOrdered"",
                    sd.salesuom AS ""SalesUOM"",
                    sd.customerprice AS ""CustomerPrice"",
                    sd.partxreference AS ""PartXReference"",
                    sd.partnumber AS ""PartNumber"",
                    pm.revision AS ""Revision"",
                    pm.desctext AS ""PartMaster_DescText"",
                    pm.stockuom AS ""StockUOM"",
                    pm.listprice AS ""ListPrice"",
                    pm.densitycode AS ""DensityCode"",
                    tc.desctext AS ""TermsCodes_DescText"",
                    svc.desctext AS ""ShipViaCodes_DescText"",
                    fc.desctext AS ""FOBCodes_DescText"",
                    sh.pricecode AS ""PriceCode"",
                    c.customerdisclevel AS ""CustomerDiscLevel"",
                    c.customername AS ""CustomerName"",
                    c.pricedisctype AS ""PriceDiscType"",
                    tx1.taxrate AS ""BaseTaxRate"",
                    tx2.taxrate AS ""TaxRate2"",
                    tx3.taxrate AS ""TaxRate3"",
                    shipaddr.addressline1 AS ""ShipToAddress_AddressLine1"",
                    shipaddr.addressline2 AS ""ShipToAddress_AddressLine2"",
                    shipaddr.addressline3 AS ""ShipToAddress_AddressLine3"",
                    shipaddr.addressline4 AS ""ShipToAddress_AddressLine4"",
                    shipaddr.city AS ""ShipToAddress_City"",
                    shipaddr.state AS ""ShipToAddress_State"",
                    shipaddr.zipcode AS ""ShipToAddress_ZIPCode"",
                    shipaddr.country AS ""ShipToAddress_Country"",
                    shipaddr.postal AS ""ShipToAddress_Postal"",
                    billaddr.addressline1 AS ""BillToAddress_AddressLine1"",
                    billaddr.addressline2 AS ""BillToAddress_AddressLine2"",
                    billaddr.addressline3 AS ""BillToAddress_AddressLine3"",
                    billaddr.addressline4 AS ""BillToAddress_AddressLine4"",
                    billaddr.city AS ""BillToAddress_City"",
                    billaddr.state AS ""BillToAddress_State"",
                    billaddr.zipcode AS ""BillToAddress_ZIPCode"",
                    billaddr.country AS ""BillToAddress_Country"",
                    billaddr.postal AS ""BillToAddress_Postal"",
                    cc.currencysymbol AS ""CurrencySymbol"",
                    sd.notes AS ""SODetail_Notes"",
                    NULL AS ""CustomerDiscount"", -- INFERRED: no numeric discount column on customerdisclevel; may belong on pricediscountcodes via sh.pricecode instead - unconfirmed, not guessed
                    cdl.desctext AS ""CustomerDiscLevel_DescText"",
                    (CASE WHEN sd.taxableflag THEN 'Yes' ELSE 'No' END) AS ""Taxable"", -- INFERRED text rendering of TaxableFlag
                    (pm.listprice * COALESCE(sh.currencyrate, 1)) AS ""ConvertListPrice"", -- INFERRED
                    (sd.customerprice * COALESCE(sh.currencyrate, 1)) AS ""AfterExchangePrice"", -- INFERRED
                    (sd.quantityordered * sd.customerprice) AS ""LineAmount"", -- INFERRED
                    (CASE WHEN sd.taxableflag THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx1.taxrate, 0) ELSE 0 END) AS ""BaseTaxAmount"", -- INFERRED
                    (sd.quantityordered * sd.customerprice) AS ""LineSubtotal"", -- INFERRED: assumed equal to LineAmount, unconfirmed distinction
                    (CASE WHEN sd.taxflag2 THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx2.taxrate, 0) ELSE 0 END) AS ""Tax2Amount"", -- INFERRED
                    (CASE WHEN sd.taxflag3 THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx3.taxrate, 0) ELSE 0 END) AS ""Tax3Amount"", -- INFERRED
                    (
                        (sd.quantityordered * sd.customerprice)
                        + (CASE WHEN sd.taxableflag THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx1.taxrate, 0) ELSE 0 END)
                        + (CASE WHEN sd.taxflag2 THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx2.taxrate, 0) ELSE 0 END)
                        + (CASE WHEN sd.taxflag3 THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx3.taxrate, 0) ELSE 0 END)
                    ) AS ""LineTotal"", -- INFERRED: LineAmount + all three tax amounts
                    sh.notes AS ""SOHeader_Notes"",
                    (CASE WHEN sd.notes IS NULL THEN 1 ELSE 0 END) AS ""SODetail_IsnullNotes"",
                    (CASE WHEN sh.notes IS NULL THEN 1 ELSE 0 END) AS ""SOHeader_IsnullNotes""
                FROM sodetail sd
                JOIN soheader sh ON sh.sonumber = sd.sonumber
                LEFT JOIN customers c ON c.customerid = sh.customerid
                LEFT JOIN partmaster pm ON pm.partnumber = sd.partnumber
                LEFT JOIN termscodes tc ON tc.termscode = sh.termscode
                LEFT JOIN shipviacodes svc ON svc.shipviacode = sh.shipviacode
                LEFT JOIN fobcodes fc ON fc.fobcode = sh.fobcode
                LEFT JOIN customerdisclevel cdl ON cdl.customerdisclevel = c.customerdisclevel
                LEFT JOIN taxcodes tx1 ON tx1.taxcode = sd.taxcode
                LEFT JOIN taxcodes tx2 ON tx2.taxcode = sd.taxcode2
                LEFT JOIN taxcodes tx3 ON tx3.taxcode = sd.taxcode3
                LEFT JOIN currencycodes cc ON cc.currencycode = sh.currencycode
                LEFT JOIN employees emp ON emp.employeeid = sh.salesperson
                LEFT JOIN customeraddress shipaddr ON shipaddr.customerid = sh.customerid AND shipaddr.addressid = sh.shiptoaddress
                LEFT JOIN customeraddress billaddr ON billaddr.customerid = sh.customerid AND billaddr.addressid = sh.billtoaddress;",

            // EngineeringPartMaster_TTX - all 7 fields are a direct subset
            // of partmaster, confirmed against the real pg_dumpall schema.
            ["EngineeringPartMaster_TTX"] = @"
                SELECT
                    partnumber AS ""PartNumber"",
                    desctext AS ""DescText"",
                    revision AS ""Revision"",
                    dimension AS ""Dimension"",
                    weight AS ""Weight"",
                    densitycode AS ""DensityCode"",
                    stockuom AS ""StockUOM""
                FROM partmaster;",

            // IntrastatRates_TTX - confirmed against pg_dumpall's
            // intrastatrates table (PK icncode+regioncode, per PK_MAP).
            ["IntrastatRates_TTX"] = @"
                SELECT
                    icncode AS ""ICNCode"",
                    regioncode AS ""RegionCode"",
                    taxcode AS ""TaxCode""
                FROM intrastatrates;",

            // EngineeringChangeNotice_TTX - confirmed against ecnheader/
            // ecnparts (real pg_dumpall schema). ecnclasscodes is joined
            // inline below for its DescText only - it's not its own
            // TableQueryCatalog entry (ECNClassCodes_TTX was removed
            // 2026-08-27 along with the other *Codes_TTX report entries;
            // this report doesn't need it as a standalone catalog key,
            // only as a lookup within this query).
            // NOTE: ECNSummary_TTX used to share this exact comment (near-
            // identical field set to this report) but was removed
            // 2026-08-27 at the user's request - if it's ever re-added,
            // its query should still match this shape.
            ["EngineeringChangeNotice_TTX"] = @"
                SELECT
                    eh.ecnnumber AS ""ECNNumber"",
                    eh.ecnclasscode AS ""ECNClassCode"",
                    eh.ecndate::timestamp AS ""ECNDate"",
                    ep.partnumber AS ""PartNumber"",
                    ep.desctext AS ""ECNParts_DescText"",
                    pm.desctext AS ""PartMaster_DescText"",
                    ecc.desctext AS ""ECNClassCodes_DescText"",
                    eh.notes AS ""Notes"",
                    (CASE WHEN eh.notes IS NULL THEN 1 ELSE 0 END) AS ""Isnull_Notes""
                FROM ecnheader eh
                JOIN ecnparts ep ON ep.ecnnumber = eh.ecnnumber
                LEFT JOIN partmaster pm ON pm.partnumber = ep.partnumber
                LEFT JOIN ecnclasscodes ecc ON ecc.ecnclasscode = eh.ecnclasscode;",

            // WorkOrderTraveler_TTX - confirmed against woheader (WO
            // header: dates/quantities) + routers (the part's standard
            // routing steps - one row per operation, keyed by PartNumber,
            // NOT WONumber; a router entry has no wonumber column at all,
            // it's the routing template for that part, not a per-WO
            // schedule) + partmaster/workcenters/operationcodes for the
            // three *_DescText/Name lookups. This matches the field list
            // exactly: WONumber/PartNumber/StartDate/etc. come from
            // woheader, while OperationCode/SequenceID/WorkCenterID/
            // IsAlternate/QueueTime/SetUpTime/RunTime come from routers.
            // "Notes"/"Isnull_Notes" assumed to be the WO header's own
            // notes field (routers has its own "notes" column too, but
            // WorkOrderTraveler_TTX only has ONE Notes field, and the
            // report's header box - Work Order #/Job Number/Part Number -
            // is where a single free-text Notes field would naturally
            // live) - verify against the actual printed report once real
            // data is flowing, and swap to r.notes if it looks wrong.
            // StartDate/RequiredDate use safe_to_timestamp() (defined once via
            // SQLFetches/setup_safe_to_timestamp.sql) instead of a bare
            // ::timestamp cast - startdate/requireddate are varchar-backed
            // like every other date column here, and a bare cast aborts
            // the whole query on the first blank/malformed value instead
            // of just nulling that field. Added 2026-08-28 as a hardening
            // measure alongside investigating why this report renders
            // empty - NOT confirmed as the root cause of the empty render
            // (that could also be a zero-row filter match or a Crystal-
            // side binding issue - see crystal_reports_pipeline project
            // memory). Re-test after this change and re-open if still empty.
            ["WorkOrderTraveler_TTX"] = @"
                SELECT
                    wo.wonumber AS ""WONumber"",
                    wo.partnumber AS ""PartNumber"",
                    r.operationcode AS ""OperationCode"",
                    r.sequenceid AS ""SequenceID"",
                    wo.jobnumber AS ""JobNumber"",
                    safe_to_timestamp(wo.startdate) AS ""StartDate"",
                    safe_to_timestamp(wo.requireddate) AS ""RequiredDate"",
                    wo.quantitytostart AS ""QuantityToStart"",
                    wo.quantityrequired AS ""QuantityRequired"",
                    wo.quantityreleased AS ""QuantityReleased"",
                    wo.workorderuom AS ""WorkOrderUOM"",
                    wo.quantitycompleted AS ""QuantityCompleted"",
                    r.workcenterid AS ""WorkCenterID"",
                    r.isalternate AS ""IsAlternate"",
                    r.queuetime AS ""QueueTime"",
                    r.setuptime AS ""SetUpTime"",
                    r.runtime AS ""RunTime"",
                    wo.notes AS ""Notes"",
                    (CASE WHEN wo.notes IS NULL THEN 1 ELSE 0 END) AS ""Isnull_Notes"",
                    pm.stockuom AS ""StockUOM"",
                    pm.densitycode AS ""DensityCode"",
                    pm.desctext AS ""PartMaster_DescText"",
                    wc.workcentername AS ""WorkCenterName"",
                    oc.desctext AS ""OperationCodes_DescText""
                FROM woheader wo
                LEFT JOIN routers r ON r.partnumber = wo.partnumber
                LEFT JOIN partmaster pm ON pm.partnumber = wo.partnumber
                LEFT JOIN workcenters wc ON wc.workcenterid = r.workcenterid
                LEFT JOIN operationcodes oc ON oc.operationcode = r.operationcode
                ORDER BY r.sequenceid;",
            
            // PurchaseOrder_TTX - poheader+podetail (one row per PO line),
            // joined out to partmaster, suppliers/supplieraddress (the
            // "SupplierAddress_*" fields), companyaddress (BillToAddress_*/
            // ShipToAddress_* - poheader.billtoaddress/shiptoaddress point
            // at the BUYER's own address book, not the supplier's - same
            // inversion of SOHeader's convention there, since here the
            // company IS the buyer), and the same tax/terms/currency code
            // tables used elsewhere. Address FK columns (poheader.
            // billtoaddress/shiptoaddress/supplieraddress) are integer;
            // addressid columns are character varying - cast the integer
            // side to text to join. Money fields (ExtendedAmount/
            // BaseTaxAmount/.../LineTotal) are INFERRED the same way
            // SalesOrder_TTX's were: computed here from quantity/price/
            // tax-rate, not stored columns - not guessed, but not
            // confirmed against a real printed PO either.
            ["PurchaseOrder_TTX"] = @"
                SELECT
                    pd.ponumber AS ""PONumber"",
                    po.requisitionnumber AS ""RequisitionNumber"",
                    svc.desctext AS ""ShipViaDescription"",
                    po.buyercode AS ""BuyerCode"",
                    po.departmentcode AS ""DepartmentCode"",
                    po.orderdate::timestamp AS ""OrderDate"",
                    po.currencycode AS ""CurrencyCode"",
                    po.exchangerate AS ""ExchangeRate"",
                    po.requireddate::timestamp AS ""POHeader_RequiredDate"",
                    fc.desctext AS ""FOBDescription"",
                    pd.poline AS ""POLine"",
                    pd.partnumber AS ""PartNumber"",
                    pd.pounitprice AS ""POUnitPrice"",
                    pd.quantityordered AS ""QuantityOrdered"",
                    pd.purchaseuom AS ""PurchaseUOM"",
                    pd.taxableflag AS ""TaxableFlag"",
                    pd.basetaxcode AS ""BaseTaxCode"",
                    pd.taxflag2 AS ""TaxFlag2"",
                    pd.taxcode2 AS ""TaxCode2"",
                    pd.taxflag3 AS ""TaxFlag3"",
                    pd.taxcode3 AS ""TaxCode3"",
                    pd.revision AS ""Revision"",
                    pd.kitpartflag AS ""KitPartFlag"",
                    pd.partxreference AS ""PartXReference"",
                    pd.requireddate::timestamp AS ""PODetail_RequiredDate"",
                    pm.desctext AS ""PartMaster_DescText"",
                    pm.stockuom AS ""StockUOM"",
                    tx1.taxrate AS ""BaseTaxRate"",
                    tx2.taxrate AS ""TaxRate2"",
                    tx3.taxrate AS ""TaxRate3"",
                    s.suppliername AS ""SupplierName"",
                    s.companyaccount AS ""CompanyAccount"",
                    supaddr.addressline1 AS ""SupplierAddress_AddressLine1"",
                    supaddr.addressline2 AS ""SupplierAddress_AddressLine2"",
                    supaddr.addressline3 AS ""SupplierAddress_AddressLine3"",
                    supaddr.addressline4 AS ""SupplierAddress_AddressLine4"",
                    supaddr.city AS ""SupplierAddress_City"",
                    supaddr.state AS ""SupplierAddress_State"",
                    supaddr.zipcode AS ""SupplierAddress_ZIPCode"",
                    supaddr.country AS ""SupplierAddress_Country"",
                    supaddr.postal AS ""SupplierAddress_Postal"",
                    tc.desctext AS ""TermsCodes_DescText"",
                    cc.currencysymbol AS ""CurrencySymbol"",
                    po.notes AS ""Notes"",
                    pd.linenotes AS ""LineNotes"",
                    (CASE WHEN po.notes IS NULL THEN 1 ELSE 0 END) AS ""POHeader_IsnullNotes"",
                    (CASE WHEN pd.linenotes IS NULL THEN 1 ELSE 0 END) AS ""PODetail_IsnullLineNotes"",
                    billaddr.addressline1 AS ""BillToAddress_AddressLine1"",
                    billaddr.addressline2 AS ""BillToAddress_AddressLine2"",
                    billaddr.addressline3 AS ""BillToAddress_AddressLine3"",
                    billaddr.addressline4 AS ""BillToAddress_AddressLine4"",
                    billaddr.city AS ""BillToAddress_City"",
                    billaddr.state AS ""BillToAddress_State"",
                    billaddr.zipcode AS ""BillToAddress_ZipCode"",
                    billaddr.country AS ""BillToAddress_Country"",
                    billaddr.postal AS ""BillToAddress_Postal"",
                    shipaddr.addressline1 AS ""ShipToAddress_AddressLine1"",
                    shipaddr.addressline2 AS ""ShipToAddress_AddressLine2"",
                    shipaddr.addressline3 AS ""ShipToAddress_AddressLine3"",
                    shipaddr.addressline4 AS ""ShipToAddress_AddressLine4"",
                    shipaddr.city AS ""ShipToAddress_City"",
                    shipaddr.state AS ""ShipToAddress_State"",
                    shipaddr.zipcode AS ""ShipToAddress_ZipCode"",
                    shipaddr.country AS ""ShipToAddress_Country"",
                    shipaddr.postal AS ""ShipToAddress_Postal"",
                    (pd.quantityordered * pd.pounitprice) AS ""ExtendedAmount"", -- INFERRED
                    (CASE WHEN pd.taxableflag THEN (pd.quantityordered * pd.pounitprice) * COALESCE(tx1.taxrate, 0) ELSE 0 END) AS ""BaseTaxAmount"", -- INFERRED
                    (pd.quantityordered * pd.pounitprice) AS ""LineSubtotal"", -- INFERRED: assumed equal to ExtendedAmount
                    (CASE WHEN pd.taxflag2 THEN (pd.quantityordered * pd.pounitprice) * COALESCE(tx2.taxrate, 0) ELSE 0 END) AS ""Tax2Amount"", -- INFERRED
                    (CASE WHEN pd.taxflag3 THEN (pd.quantityordered * pd.pounitprice) * COALESCE(tx3.taxrate, 0) ELSE 0 END) AS ""Tax3Amount"", -- INFERRED
                    (
                        (pd.quantityordered * pd.pounitprice)
                        + (CASE WHEN pd.taxableflag THEN (pd.quantityordered * pd.pounitprice) * COALESCE(tx1.taxrate, 0) ELSE 0 END)
                        + (CASE WHEN pd.taxflag2 THEN (pd.quantityordered * pd.pounitprice) * COALESCE(tx2.taxrate, 0) ELSE 0 END)
                        + (CASE WHEN pd.taxflag3 THEN (pd.quantityordered * pd.pounitprice) * COALESCE(tx3.taxrate, 0) ELSE 0 END)
                    ) AS ""LineTotal"" -- INFERRED
                FROM podetail pd
                JOIN poheader po ON po.ponumber = pd.ponumber
                LEFT JOIN partmaster pm ON pm.partnumber = pd.partnumber
                LEFT JOIN suppliers s ON s.supplierid = po.supplierid
                LEFT JOIN supplieraddress supaddr ON supaddr.supplierid = po.supplierid AND supaddr.addressid = po.supplieraddress::text
                LEFT JOIN companyaddress billaddr ON billaddr.addressid = po.billtoaddress::text
                LEFT JOIN companyaddress shipaddr ON shipaddr.addressid = po.shiptoaddress::text
                LEFT JOIN termscodes tc ON tc.termscode = po.termscode
                LEFT JOIN shipviacodes svc ON svc.shipviacode = po.shipviacode
                LEFT JOIN fobcodes fc ON fc.fobcode = po.fobcode
                LEFT JOIN currencycodes cc ON cc.currencycode = po.currencycode
                LEFT JOIN taxcodes tx1 ON tx1.taxcode = pd.basetaxcode
                LEFT JOIN taxcodes tx2 ON tx2.taxcode = pd.taxcode2
                LEFT JOIN taxcodes tx3 ON tx3.taxcode = pd.taxcode3;",

            // PendingCostBOM_TTX - bom joined to partmaster TWICE (once as
            // the assembly/parent, once as the component/child) for the
            // Assembly_*/Component_* cost breakdown fields. Uses the
            // *current* cost columns (materialcost/laborcost/burdencost/
            // setupcost/subcontcost/cost), not the std* columns - matches
            // "Pending" in the report name (costs not yet rolled into
            // standard). Component_RowTotalCost/Assembly_TotalCost are
            // INFERRED: quantityper * the component's own rolled-up unit
            // cost (partmaster.cost, presumably materialcost+laborcost+
            // burdencost+setupcost+subcontcost already) - Assembly_TotalCost
            // here is just the assembly's own partmaster.cost, NOT a SUM of
            // every component row (a per-assembly rollup like that is a
            // Crystal group summary over this DataTable, not something one
            // flat SQL row can express) - if the report expects a true
            // rolled-up total instead, that needs its own summary formula
            // in the .rpt.
            ["PendingCostBOM_TTX"] = @"
                SELECT
                    b.assembly AS ""Assembly"",
                    b.component AS ""Component"",
                    b.itemsequence AS ""ItemSequence"",
                    b.quantityper AS ""QuantityPer"",
                    b.bomuomcode AS ""BOMUOMCode"",
                    b.obsoletedate::timestamp AS ""ObsoleteDate"",
                    b.effectivedate::timestamp AS ""EffectiveDate"",
                    am.desctext AS ""Assembly_DescText"",
                    am.revision AS ""Assembly_Revision"",
                    am.stockuom AS ""Assembly_StockUOM"",
                    am.materialcost AS ""Assembly_MaterialCost"",
                    am.laborcost AS ""Assembly_LaborCost"",
                    am.burdencost AS ""Assembly_BurdenCost"",
                    am.setupcost AS ""Assembly_SetUpCost"",
                    am.subcontcost AS ""Assembly_SubContCost"",
                    am.isc AS ""Assembly_ISC"",
                    am.orderquantity AS ""Assembly_OrderQuantity"",
                    cm.desctext AS ""Component_DescText"",
                    cm.revision AS ""Component_Revision"",
                    cm.stockuom AS ""Component_StockUOM"",
                    cm.isc AS ""Component_ISC"",
                    cm.materialcost AS ""Component_MaterialCost"",
                    cm.laborcost AS ""Component_LaborCost"",
                    cm.burdencost AS ""Component_BurdenCost"",
                    cm.setupcost AS ""Component_SetUpCost"",
                    cm.subcontcost AS ""Component_SubContCost"",
                    cm.orderquantity AS ""Component_OrderQuantity"",
                    (b.quantityper * cm.cost) AS ""Component_RowTotalCost"", -- INFERRED
                    am.cost AS ""Assembly_TotalCost"" -- INFERRED: assembly's own rolled-up cost, not a SUM of component rows
                FROM bom b
                LEFT JOIN partmaster am ON am.partnumber = b.assembly
                LEFT JOIN partmaster cm ON cm.partnumber = b.component;"
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
        ///                             [--sql-dir "C:\RPTConvert\SQLqueries"]
        ///                             [--sql-file "C:\RPTConvert\SQLqueries\sales.sql"]
        ///     (queries come from <sql-dir>\sales.sql - see LoadReportSqlFile)
        ///
        ///   CrystalReportWrapper.exe --report "C:\reports\sales.rpt" --inspect
        ///     (dumps the report's expected tables/fields/formulas/parameters
        ///      as JSON instead of exporting - no --output/--format needed)
        ///
        ///   CrystalReportWrapper.exe --report "C:\reports\sales.rpt" --extract-sql
        ///                             [--sql-out-dir "C:\RPTConvert\SQLqueries"]
        ///     (writes/refreshes <sql-out-dir>\sales.sql with a query, or a
        ///      column skeleton, for every table the report uses - see
        ///      RunExtractSql)
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

            if (options.ExtractSql)
            {
                return RunExtractSql(options);
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
                // during export/render, which is what "Failed to load
                // database information" actually means here even though
                // SetDataSource itself doesn't throw. Wrapping every
                // DataTable in one DataSet routes Crystal through its
                // ADO.NET provider (crdb_adoplus.dll) end-to-end instead,
                // which never touches the dead .ttx path.
                //
                // CORRECTION: this comment used to explain the fallback as
                // a 64-bit/32-bit bitness gap ("crdb_fielddef.dll has no
                // 64-bit build"). That was leftover text from when this
                // project's PlatformTarget was briefly x64 (see the
                // CrystalReportWrapper.csproj PlatformTarget comment for
                // that history) and was never corrected after it moved
                // back to x86 - misleading, since bitness can't be the
                // mechanism in an x86-only process that only ever loads
                // x86 builds of both DLLs. The actual reason DataSet/
                // SetDataSource routing is still needed here is unrelated
                // to bitness: a bare DataTable can leave Crystal still
                // referencing the report's originally-recorded .ttx
                // connection at export time instead of fully rebinding to
                // the supplied data; wrapping every table in one
                // same-named DataSet forces the ADO.NET (XML) provider
                // path end-to-end regardless of process bitness. This
                // whole worker builds and runs as x86 only - see
                // CrystalReportWrapper.csproj's PlatformTarget.
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

                // Optional: filter one or more tables down to a single
                // record (e.g. SOHeader/SODetail both WHERE SONumber =
                // '12345') instead of fetching the whole table. Absent
                // unless the caller passed --record-filter - every
                // existing report keeps its current "fetch everything"
                // behavior by default. See LoadRecordFilters/BuildReportDataSet.
                Dictionary<string, RecordFilter>? recordFilters = null;
                if (!string.IsNullOrEmpty(options.RecordFilterJsonPath))
                {
                    recordFilters = LoadRecordFilters(options.RecordFilterJsonPath);
                }

                // Queries come from SQLqueries\<ReportName>.sql when that
                // file exists; any table it doesn't cover falls back to the
                // embedded TableQueryCatalog. See LoadReportSqlFile.
                string sqlDir = ResolveSqlDir(options);
                Dictionary<string, string> fileQueries = LoadReportSqlFile(
                    options.ReportPath, sqlDir, requiredTables, out string sqlFilePath, options.SqlFile);
                Console.WriteLine(
                    $"SQL file: {sqlFilePath} ({(File.Exists(sqlFilePath) ? fileQueries.Count + " query/queries loaded" : "not found - using embedded catalog")})");

                DataSet reportDataSet = BuildReportDataSet(requiredTables, recordFilters, fileQueries, sqlFilePath);
                report.SetDataSource(reportDataSet);

                // report.SetDataSource(reportDataSet) above only reliably
                // clears a table's original data-provider binding (Access/
                // DAO, ODBC, or - the case that matters for the legacy
                // Alliance reports - a Field-Definitions-Only/TTX table
                // pointed at a path like C:\Alliance32\Reports\*.TTX that
                // hasn't existed since ~2002) when the table was originally
                // authored against an ADO.NET/XML-schema connection in the
                // Designer. For every other table type, Crystal can still
                // consider the table "not logged on" and try to actually
                // open its original provider during Export() - which is
                // what throws LogOnException here, unrelated to Postgres
                // entirely (Postgres already answered the query above; this
                // is Crystal separately trying to satisfy the table's own
                // baked-in connection). Calling the per-TABLE SetDataSource
                // overload (not the whole-DataSet one) is the documented
                // way to force that swap regardless of the table's original
                // driver, so do that explicitly for every table the report
                // expects that we actually have data for.
                foreach (CrystalDecisions.CrystalReports.Engine.Table pushTable in report.Database.Tables)
                {
                    if (reportDataSet.Tables.Contains(pushTable.Name))
                    {
                        pushTable.SetDataSource(reportDataSet.Tables[pushTable.Name]);
                    }
                }

                // Diagnostic only (no longer used to drive any fix) -
                // shows what each table's ORIGINAL design-time connection
                // info still says post-SetDataSource, so a future logon-
                // shaped failure is visible in console output immediately
                // instead of requiring another blind round-trip.
                foreach (CrystalDecisions.CrystalReports.Engine.Table diagTable in report.Database.Tables)
                {
                    ConnectionInfo ci = diagTable.LogOnInfo.ConnectionInfo;
                    Console.WriteLine(
                        $"Table '{diagTable.Name}' original connection - Server: '{ci.ServerName}', " +
                        $"Database: '{ci.DatabaseName}', UserID: '{ci.UserID}'");
                }

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
        /// --extract-sql mode: loads the report (never touches Postgres or
        /// exports), collects every table it expects - main report first,
        /// then subreports, de-duplicated - and writes the TableQueryCatalog
        /// query for each one into ONE file named after the report:
        /// reports\WorkOrderTraveler.rpt -> SQLqueries\WorkOrderTraveler.sql.
        ///
        /// Why the SQL comes from TableQueryCatalog and not the .rpt: these
        /// legacy reports are "Field Definitions Only" (TTX) reports, so the
        /// .rpt/.ttx only describe the columns the report expects - there is
        /// no SQL stored in either file. The real query is the hand-written
        /// catalog entry this worker already runs at export time, so that's
        /// the one written out here (exactly what export executes - the C#
        /// "" escaping is already resolved at runtime).
        ///
        /// A table with no catalog entry doesn't fail the run: it gets a
        /// commented-out SELECT skeleton listing every column the report
        /// expects (exact alias spelling + Crystal type), and is reported in
        /// MissingTables so a batch run can list what still needs writing.
        ///
        /// If the target .sql already exists with DIFFERENT content, it is
        /// copied to .sql.bak first, so a hand edit is never silently lost.
        /// </summary>
        private static int RunExtractSql(CliOptions options)
        {
            var result = new ExtractSqlResult { ReportPath = options.ReportPath };

            try
            {
                if (!File.Exists(options.ReportPath))
                {
                    throw new FileNotFoundException($"Report file not found: {options.ReportPath}");
                }

                using var report = new ReportDocument();
                report.Load(options.ReportPath);

                // Collect tables (main report, then each subreport), keeping
                // first-seen order and dropping repeats - one query per table
                // is all the export path ever runs.
                var tables = new List<CrystalDecisions.CrystalReports.Engine.Table>();
                var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach (CrystalDecisions.CrystalReports.Engine.Table t in report.Database.Tables)
                {
                    if (seen.Add(t.Name)) tables.Add(t);
                }
                foreach (ReportDocument subreport in report.Subreports)
                {
                    foreach (CrystalDecisions.CrystalReports.Engine.Table t in subreport.Database.Tables)
                    {
                        if (seen.Add(t.Name)) tables.Add(t);
                    }
                }

                // A report with no data tables (e.g. "template blank
                // portrait.rpt") needs no query - succeed without writing a file.
                if (tables.Count == 0)
                {
                    result.Success = true;
                    WriteJsonLine(result);
                    return 0;
                }

                string reportName = Path.GetFileNameWithoutExtension(options.ReportPath);
                string nl = "\r\n";

                // Queries already in this report's .sql file are kept as-is
                // (the file is the source of truth); the embedded catalog
                // only fills in tables the file has no query for.
                string outDir = ResolveSqlOutDir(options);
                Dictionary<string, string> fileQueries = LoadReportSqlFile(
                    options.ReportPath, outDir, tables.ConvertAll(t => t.Name), out _);
                var sb = new System.Text.StringBuilder();

                // ---- File header --------------------------------------------
                // No timestamp on purpose: re-running on an unchanged report
                // must produce an identical file (so it isn't backed up and
                // doesn't show as a git change every time).
                sb.Append("-- ============================================================================").Append(nl);
                sb.Append($"-- {reportName}.sql").Append(nl);
                sb.Append($"-- Extracted from {Path.GetFileName(options.ReportPath)} by CrystalReportWrapper --extract-sql.").Append(nl);
                sb.Append("-- CrystalReportWrapper runs the queries in this file at render time - edit").Append(nl);
                sb.Append("-- them here. One query per '-- Table: <name>' line; aliases must match the").Append(nl);
                sb.Append("-- report's field names exactly (case-sensitive).").Append(nl);
                sb.Append($"-- Tables: {string.Join(", ", tables.ConvertAll(t => t.Name))}").Append(nl);

                // Parameters + record selection formula: not part of the
                // catalog SQL (export filters via --record-filter /
                // parameters instead), but they're what a WHERE clause would
                // be derived from, so surface them as comments.
                var parameters = InspectParameters(EnumerateParameterFields(report.DataDefinition.ParameterFields));
                if (parameters.Count > 0)
                {
                    sb.Append("-- Report parameters:").Append(nl);
                    foreach (var p in parameters)
                    {
                        sb.Append($"--   {p.Name} ({p.ValueKind})").Append(nl);
                    }
                }

                string selectionFormula = string.Empty;
                try { selectionFormula = report.RecordSelectionFormula ?? string.Empty; }
                catch { /* some legacy reports throw here - just omit it */ }
                if (!string.IsNullOrWhiteSpace(selectionFormula))
                {
                    sb.Append("-- Crystal record selection formula (NOT applied by the SQL below):").Append(nl);
                    foreach (string line in SplitLines(selectionFormula))
                    {
                        sb.Append($"--   {line}").Append(nl);
                    }
                }
                sb.Append("-- ============================================================================").Append(nl);

                // ---- One section per table -----------------------------------
                foreach (var table in tables)
                {
                    result.Tables.Add(table.Name);
                    sb.Append(nl);
                    sb.Append("-- ----------------------------------------------------------------------------").Append(nl);
                    sb.Append($"-- Table: {table.Name}").Append(nl);
                    if (!string.IsNullOrEmpty(table.Location) &&
                        !string.Equals(table.Location, table.Name, StringComparison.OrdinalIgnoreCase))
                    {
                        sb.Append($"-- Original data source: {table.Location}").Append(nl);
                    }

                    string? query;
                    bool fromFile = fileQueries.TryGetValue(table.Name, out query);
                    if (fromFile || (TableQueryCatalog.TryGetValue(table.Name, out query) && !string.IsNullOrWhiteSpace(query)))
                    {
                        result.MatchedTables.Add(table.Name);
                        sb.Append("-- ----------------------------------------------------------------------------").Append(nl);
                        string sql = StripTrailingSemicolon(fromFile ? query! : Dedent(query!)) + ";";
                        sb.Append(sql.Replace("\r\n", "\n").Replace("\n", nl)).Append(nl);
                    }
                    else
                    {
                        result.MissingTables.Add(table.Name);
                        sb.Append("-- NO QUERY YET - TODO: replace the commented-out skeleton below with the").Append(nl);
                        sb.Append("-- real query (remove the /* and */ lines).").Append(nl);
                        sb.Append("-- Skeleton below lists every column the report expects; aliases must").Append(nl);
                        sb.Append("-- match exactly (case-sensitive) for Crystal to bind them.").Append(nl);
                        sb.Append("-- ----------------------------------------------------------------------------").Append(nl);
                        sb.Append("/*").Append(nl);
                        sb.Append("SELECT").Append(nl);
                        var fields = new List<CrystalDecisions.CrystalReports.Engine.FieldDefinition>();
                        foreach (CrystalDecisions.CrystalReports.Engine.FieldDefinition field in table.Fields)
                        {
                            fields.Add(field);
                        }
                        for (int i = 0; i < fields.Count; i++)
                        {
                            string fieldType = fields[i].ValueType.ToString();
                            string comma = i < fields.Count - 1 ? "," : "";
                            sb.Append($"    NULL AS \"{fields[i].Name}\"{comma} -- {fieldType} -> {SuggestPgType(fieldType)}").Append(nl);
                        }
                        sb.Append("FROM ???;").Append(nl);
                        sb.Append("*/").Append(nl);
                    }
                }

                // ---- Write (backing up a differing existing file) ------------
                Directory.CreateDirectory(outDir);
                string sqlPath = Path.Combine(outDir, reportName + ".sql");
                string content = sb.ToString();

                if (File.Exists(sqlPath))
                {
                    string existing = File.ReadAllText(sqlPath);
                    if (existing.Trim().Length > 0 && !string.Equals(existing, content, StringComparison.Ordinal))
                    {
                        File.Copy(sqlPath, sqlPath + ".bak", overwrite: true);
                        result.BackedUp = true;
                    }
                }

                File.WriteAllText(sqlPath, content, new System.Text.UTF8Encoding(false));
                result.SqlPath = sqlPath;
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

        // ====================================================================
        // REPORT SQL FILES  (SQLqueries\<ReportName>.sql)
        // ====================================================================
        // Each report's queries live in a .sql file named after its .rpt:
        // reports\Acknowledgement.rpt -> SQLqueries\Acknowledgement.sql.
        // Adding or fixing a report's SQL is a file edit - no rebuild.
        //
        // File format:
        //   * One-table report (nearly all the legacy _TTX reports): the
        //     file can be just the query.
        //   * Multi-table report: one query per table, each under a marker
        //     line naming the Crystal table it fills:
        //         -- Table: SOHeader
        //         SELECT ... ;
        //         -- Table: SODetail
        //         SELECT ... ;
        //     (--extract-sql writes this layout, markers included, for
        //     every report - both layouts load the same way.)
        //   * A section with no SQL in it (blank, or only comments, e.g. the
        //     /* ... */ skeleton --extract-sql writes for a table that has
        //     no query yet) counts as "no query" and falls back to the
        //     embedded TableQueryCatalog.
        //
        // Column aliases must still match the report's field names exactly
        // (AS "SONumber") - plain SQL quoting here, NOT the doubled ""
        // quotes the C# verbatim strings in TableQueryCatalog need.
        private static readonly Regex TableMarkerPattern =
            new(@"^\s*--\s*Table:\s*(\S+)\s*$", RegexOptions.IgnoreCase | RegexOptions.Compiled);
        private static readonly Regex BlockCommentPattern =
            new(@"/\*.*?\*/", RegexOptions.Singleline | RegexOptions.Compiled);
        private static readonly Regex LineCommentPattern =
            new(@"--[^\n]*", RegexOptions.Compiled);
        private static readonly Regex TrailingSemicolonPattern =
            new(@";\s*(--[^\n]*)?\s*\z", RegexOptions.Compiled);

        /// <summary>
        /// Where report .sql files are read from: --sql-dir if given, else
        /// the RPTCONVERT_SQL_DIR environment variable, else a SQLqueries
        /// folder next to the report's own folder
        /// (RPTConvert\reports\X.rpt -> RPTConvert\SQLqueries).
        /// </summary>
        private static string ResolveSqlDir(CliOptions options)
        {
            if (!string.IsNullOrWhiteSpace(options.SqlDir))
            {
                return Path.GetFullPath(options.SqlDir);
            }
            string? fromEnv = Environment.GetEnvironmentVariable("RPTCONVERT_SQL_DIR");
            if (!string.IsNullOrWhiteSpace(fromEnv))
            {
                return Path.GetFullPath(fromEnv);
            }
            string reportDir = Path.GetDirectoryName(Path.GetFullPath(options.ReportPath)) ?? ".";
            string parent = Path.GetDirectoryName(reportDir) ?? reportDir;
            return Path.Combine(parent, "SQLqueries");
        }

        /// <summary>
        /// --extract-sql's output folder: --sql-out-dir if given, otherwise
        /// the same folder the export path reads from (ResolveSqlDir), so
        /// an extracted file is picked up by the next render.
        /// </summary>
        private static string ResolveSqlOutDir(CliOptions options)
        {
            if (!string.IsNullOrWhiteSpace(options.SqlOutDir))
            {
                return Path.GetFullPath(options.SqlOutDir);
            }
            return ResolveSqlDir(options);
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
            var lines = new List<string>(text.Replace("\r\n", "\n").Split('\n'));
            bool Skippable(string line)
            {
                string t = line.Trim();
                return t.Length == 0 || t.StartsWith("--");
            }
            while (lines.Count > 0 && Skippable(lines[0])) lines.RemoveAt(0);
            while (lines.Count > 0 && Skippable(lines[lines.Count - 1])) lines.RemoveAt(lines.Count - 1);
            return string.Join("\n", lines);
        }

        /// <summary>
        /// Removes a final ';' (and a "-- comment" after it). Queries are
        /// run one at a time and may be wrapped as a subquery
        /// (BuildReportDataSet), where a trailing ';' is a syntax error.
        /// </summary>
        private static string StripTrailingSemicolon(string query)
        {
            return TrailingSemicolonPattern.Replace(query.TrimEnd(), string.Empty).TrimEnd();
        }

        /// <summary>
        /// Loads SQLqueries\&lt;ReportName&gt;.sql for reportPath and returns
        /// its queries keyed by Crystal table name (case-insensitive). A
        /// missing file returns an empty dictionary - every table then
        /// falls back to TableQueryCatalog. See the format notes above.
        ///
        /// reportTableNames is the report's own table list
        /// (report.Database.Tables): it names the table for a marker-less
        /// file, and flags markers that match no table in the report.
        /// </summary>
        private static Dictionary<string, string> LoadReportSqlFile(
            string reportPath,
            string sqlDir,
            IEnumerable<string> reportTableNames,
            out string sqlPath,
            string explicitSqlFile = null)
        {
            var queries = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            if (!string.IsNullOrWhiteSpace(explicitSqlFile))
            {
                // --sql-file: the caller named this report's file (Python's
                // reports_map.REPORT_SQL), so a missing file is an error
                // rather than a quiet fall back to the embedded catalog.
                sqlPath = Path.GetFullPath(explicitSqlFile);
                if (!File.Exists(sqlPath))
                {
                    throw new FileNotFoundException(
                        $"SQL file not found: {sqlPath} (named by --sql-file - check " +
                        $"REPORT_SQL in reports_map.py).");
                }
            }
            else
            {
                sqlPath = Path.Combine(sqlDir, Path.GetFileNameWithoutExtension(reportPath) + ".sql");
                if (!File.Exists(sqlPath))
                {
                    return queries;
                }
            }

            var expected = new List<string>();
            var expectedSet = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (string name in reportTableNames)
            {
                if (expectedSet.Add(name)) expected.Add(name);
            }

            // Split into sections at each "-- Table: X" line. The first
            // section (Key == null) is whatever precedes the first marker:
            // the whole file when there are no markers, else just a header.
            var sections = new List<KeyValuePair<string, string>>();
            string currentTable = null;
            var buffer = new System.Text.StringBuilder();
            foreach (string line in File.ReadAllText(sqlPath).Replace("\r\n", "\n").Split('\n'))
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
                            $"{sqlPath}: SQL found before the first '-- Table: <name>' line. " +
                            $"Put every query under a marker line.");
                    }
                    if (expected.Count != 1)
                    {
                        throw new InvalidOperationException(
                            $"{sqlPath} has no '-- Table: <name>' lines, but the report uses " +
                            $"{expected.Count} tables ({string.Join(", ", expected)}). Add a " +
                            $"marker line before each table's query.");
                    }
                    table = expected[0];
                }

                if (queries.ContainsKey(table))
                {
                    throw new InvalidOperationException(
                        $"{sqlPath}: more than one query for table '{table}'.");
                }
                if (!expectedSet.Contains(table))
                {
                    Console.WriteLine(
                        $"Warning: {sqlPath} has a query for '{table}', which is not a table " +
                        $"in this report ({string.Join(", ", expected)}) - check the marker's spelling.");
                }

                queries[table] = StripTrailingSemicolon(TrimCommentLines(section.Value));
            }

            return queries;
        }

        private static List<string> SplitLines(string text)
        {
            var lines = new List<string>();
            foreach (string raw in text.Replace("\r\n", "\n").Replace('\r', '\n').Split('\n'))
            {
                lines.Add(raw.TrimEnd());
            }
            return lines;
        }

        /// <summary>
        /// Catalog entries are C# verbatim strings indented to match the
        /// source file. Strip leading/trailing blank lines and the common
        /// leading indentation so the .sql reads like normal SQL. Returns
        /// LF-joined text.
        /// </summary>
        private static string Dedent(string text)
        {
            var lines = SplitLines(text);
            while (lines.Count > 0 && lines[0].Trim().Length == 0) lines.RemoveAt(0);
            while (lines.Count > 0 && lines[lines.Count - 1].Trim().Length == 0) lines.RemoveAt(lines.Count - 1);

            int indent = int.MaxValue;
            foreach (string line in lines)
            {
                if (line.Trim().Length == 0) continue;
                int n = 0;
                while (n < line.Length && (line[n] == ' ' || line[n] == '\t')) n++;
                indent = Math.Min(indent, n);
            }
            if (indent == int.MaxValue) indent = 0;

            for (int i = 0; i < lines.Count; i++)
            {
                lines[i] = lines[i].Length >= indent ? lines[i].Substring(indent) : lines[i].TrimStart();
            }
            return string.Join("\n", lines);
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
                    case "--record-filter":
                        options.RecordFilterJsonPath = args[++i];
                        break;
                    case "--inspect":
                        // Flag, not a key/value pair - takes no argument.
                        options.Inspect = true;
                        break;
                    case "--extract-sql":
                        // Flag - see RunExtractSql.
                        options.ExtractSql = true;
                        break;
                    case "--sql-out-dir":
                        options.SqlOutDir = args[++i];
                        break;
                    case "--sql-dir":
                        options.SqlDir = args[++i];
                        break;
                    case "--sql-file":
                        options.SqlFile = args[++i];
                        break;
                }
            }

            if (string.IsNullOrEmpty(options.ReportPath))
            {
                throw new ArgumentException("--report is a required argument.");
            }

            if (!options.Inspect && !options.ExtractSql && string.IsNullOrEmpty(options.OutputPath))
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
        // ("column", "value") to apply as a WHERE filter to one TableQueryCatalog
        // table. Value is already coerced to a CLR type (string/double/bool)
        // by CoerceFilterValue - see LoadRecordFilters.
        private readonly struct RecordFilter
        {
            public RecordFilter(string column, object value)
            {
                Column = column;
                Value = value;
            }
            public string Column { get; }
            public object Value { get; }
        }

        /// <summary>
        /// Parses a JSON file shaped like:
        ///   {"SOHeader": {"column": "SONumber", "value": "12345"},
        ///    "SODetail": {"column": "SONumber", "value": "12345"}}
        /// into a per-table RecordFilter dictionary. Table names are matched
        /// case-insensitively against TableQueryCatalog/requiredTableNames,
        /// same convention as TableQueryCatalog itself.
        ///
        /// This file is built on the Python/ZMRP side (report_service.py's
        /// render_report_for_record), which is where the report's db_tables
        /// list and the actual PK column name (via ZMRP's own PK_MAP) get
        /// resolved - Program.cs never needs to know what a "primary key"
        /// is, it just mechanically applies whatever column/value pairs
        /// it's handed.
        /// </summary>
        private static Dictionary<string, RecordFilter> LoadRecordFilters(string recordFilterJsonPath)
        {
            if (!File.Exists(recordFilterJsonPath))
            {
                throw new FileNotFoundException($"Record filter file not found: {recordFilterJsonPath}");
            }

            string json = File.ReadAllText(recordFilterJsonPath);
            using var doc = JsonDocument.Parse(json);

            var filters = new Dictionary<string, RecordFilter>(StringComparer.OrdinalIgnoreCase);
            foreach (JsonProperty prop in doc.RootElement.EnumerateObject())
            {
                JsonElement entry = prop.Value;
                if (!entry.TryGetProperty("column", out JsonElement columnEl) ||
                    !entry.TryGetProperty("value", out JsonElement valueEl))
                {
                    throw new ArgumentException(
                        $"Record filter entry for table '{prop.Name}' must have both " +
                        $"'column' and 'value' - got: {entry}");
                }

                filters[prop.Name] = new RecordFilter(
                    columnEl.GetString() ?? string.Empty,
                    CoerceFilterValue(valueEl));
            }
            return filters;
        }

        /// <summary>
        /// Lighter-weight cousin of CoerceToParameterType - a record filter
        /// value isn't tied to a Crystal ParameterFieldDefinition (there is
        /// no ParameterValueKind to consult), so this just maps JSON's own
        /// value kind onto a reasonable Npgsql-friendly CLR type.
        /// </summary>
        private static object CoerceFilterValue(JsonElement element)
        {
            return element.ValueKind switch
            {
                JsonValueKind.Number => element.GetDouble(),
                JsonValueKind.True => true,
                JsonValueKind.False => false,
                JsonValueKind.String => element.GetString()!,
                _ => element.ToString(),
            };
        }

        // Matches a TableQueryCatalog SELECT's own `... AS "SomeAlias"` clauses.
        // Column names in the catalog are always simple identifiers (no spaces
        // or punctuation), so [A-Za-z0-9_]+ is deliberately narrow rather than
        // trying to handle arbitrary quoted-identifier contents.
        private static readonly Regex ColumnAliasPattern =
            new(@"AS\s+""([A-Za-z0-9_]+)""", RegexOptions.IgnoreCase | RegexOptions.Compiled);

        /// <summary>
        /// Resolves the real, as-cataloged casing of a column alias in a
        /// TableQueryCatalog base query, given a caller-supplied column name
        /// of unknown casing. PK_MAP on the ZMRP/Python side uses lowercase
        /// names like "sonumber" (matching Postgres's actual lowercase
        /// physical columns), while TableQueryCatalog aliases columns
        /// PascalCase for Crystal Reports, e.g. `sonumber AS "SONumber"`.
        /// Postgres double-quoted identifiers are case-sensitive, so
        /// quoting whatever casing the caller sent (WHERE "sonumber" = ...)
        /// fails against the actual "SONumber" column even though the
        /// column genuinely exists on that table.
        ///
        /// Scanning the query's own AS clauses case-insensitively and using
        /// the text actually captured there sidesteps that - the query is
        /// always the source of truth for its own alias casing.
        ///
        /// Returns null (not a throw) when no alias matches - e.g. a
        /// db_tables data-entry mistake that points a filter at a table
        /// which never carries that column at all (Customers/PartMaster
        /// have no SONumber). The caller treats null as "can't safely
        /// filter this table" and falls back to fetching it unfiltered
        /// instead of emitting a WHERE clause against a column that
        /// doesn't exist.
        /// </summary>
        private static string? ResolveActualColumnAlias(string baseQuery, string requestedColumn)
        {
            foreach (Match m in ColumnAliasPattern.Matches(baseQuery))
            {
                string aliasName = m.Groups[1].Value;
                if (string.Equals(aliasName, requestedColumn, StringComparison.OrdinalIgnoreCase))
                {
                    return aliasName;
                }
            }
            return null;
        }

        private static DataSet BuildReportDataSet(
            IEnumerable<string> requiredTableNames,
            Dictionary<string, RecordFilter>? recordFilters = null,
            Dictionary<string, string>? fileQueries = null,
            string? sqlFilePath = null)
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
                // The report's own SQL file (SQLqueries\<ReportName>.sql,
                // see LoadReportSqlFile) wins. The embedded
                // TableQueryCatalog is only a fallback for tables that
                // file doesn't cover.
                string? query = null;
                string querySource;
                if (fileQueries != null && fileQueries.TryGetValue(tableName, out query))
                {
                    querySource = "SQL file";
                }
                else if (TableQueryCatalog.TryGetValue(tableName, out query))
                {
                    querySource = "embedded TableQueryCatalog";
                }
                else
                {
                    // Fail loudly and specifically instead of silently
                    // exporting a report with a missing table (which would
                    // otherwise surface later as a vague Crystal binding
                    // error).
                    throw new InvalidOperationException(
                        $"Report requires table '{tableName}', which has no query. " +
                        $"Add one to {sqlFilePath ?? "the report's .sql file in SQLqueries"}" +
                        $" (under a '-- Table: {tableName}' line if the report uses more " +
                        $"than one table) - run --extract-sql to get a column skeleton.");
                }
                query = StripTrailingSemicolon(query);
                Console.WriteLine($"Query for '{tableName}' from {querySource}");

                // If the caller asked to filter this specific table down to
                // one record, wrap the catalog's base query as a subquery
                // and add a parameterized WHERE - parameterized (not string-
                // interpolated) so a PK value containing a quote can't break
                // out of the query. The subquery wrapper means the original
                // TableQueryCatalog text never has to be parsed or edited -
                // it stays exactly what --inspect/the designer already
                // verified, just narrowed down.
                // filter is pre-assigned `default` (not just `out RecordFilter
                // filter` inline) so it stays definitely-assigned no matter
                // what happens to isFiltered later in this block. isFiltered
                // gets reassigned to false below (see ResolveActualColumnAlias
                // fallback) - once a bool gating an out-parameter's use is
                // reassigned anywhere in the method, the compiler can no
                // longer prove the out-parameter is assigned at any check of
                // that bool (CS0165), even ones textually before the
                // reassignment. Pre-assigning sidesteps that limitation
                // instead of fighting it.
                RecordFilter filter = default;
                bool isFiltered = recordFilters != null && recordFilters.TryGetValue(tableName, out filter);

                // The caller's casing for filter.Column isn't trustworthy
                // (see ResolveActualColumnAlias) - resolve it against this
                // table's own query text before building any SQL from it.
                string? resolvedAlias = null;
                if (isFiltered)
                {
                    resolvedAlias = ResolveActualColumnAlias(query, filter.Column);
                    if (resolvedAlias == null)
                    {
                        // Requested column isn't one of this table's own
                        // aliases - fail safe by fetching unfiltered instead
                        // of emitting a WHERE clause against a column that
                        // doesn't exist on this table at all.
                        Console.WriteLine(
                            $"Warning: table '{tableName}' has no column matching " +
                            $"'{filter.Column}' - fetching it unfiltered instead of " +
                            $"filtering by record. Check this table's db_tables entry " +
                            $"in report_registry.json.");
                        isFiltered = false;
                    }
                }

                string effectiveQuery = query;
                if (isFiltered)
                {
                    // Base query on its own lines, so a trailing "-- comment"
                    // in it can't swallow the closing parenthesis.
                    effectiveQuery =
                        $"SELECT * FROM (\n{query}\n) AS _rptconvert_filtered " +
                        $"WHERE \"{resolvedAlias}\" = @filterValue";
                }

                using var command = new NpgsqlCommand(effectiveQuery, connection);
                if (isFiltered)
                {
                    command.Parameters.AddWithValue("@filterValue", filter.Value);
                }
                using var adapter = new NpgsqlDataAdapter(command);

                // TableName set here (not after Fill) - DataSet.Tables.Add
                // uses this to key the table by name, which is what
                // Crystal's ADO.NET binding matches against report.Database
                // .Tables[i].Name.
                var table = new DataTable(tableName);
                adapter.Fill(table);

                Console.WriteLine(
                    isFiltered
                        ? $"Rows for '{tableName}' (filtered {resolvedAlias} = {filter.Value}): {table.Rows.Count}"
                        : $"Rows for '{tableName}': {table.Rows.Count}");
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
            // Path to a JSON file shaped {"SOHeader": {"column": "SONumber",
            // "value": "12345"}, "SODetail": {...}, ...} - one entry per
            // TableQueryCatalog table that should be filtered to a single
            // record instead of fetched whole. See BuildReportDataSet.
            public string? RecordFilterJsonPath { get; set; }
            public bool Inspect { get; set; } = false;
            // --extract-sql: write the report's TableQueryCatalog SQL to
            // <SqlOutDir>\<report name>.sql instead of exporting.
            public bool ExtractSql { get; set; } = false;
            // Defaults (when null) to a SQLqueries folder that is a sibling
            // of the report's own folder - i.e. RPTConvert\reports\X.rpt ->
            // RPTConvert\SQLqueries\X.sql. See ResolveSqlOutDir.
            public string? SqlOutDir { get; set; }
            // Folder holding <ReportName>.sql files read at render time.
            // Defaults (when null) to RPTCONVERT_SQL_DIR, then to that same
            // sibling SQLqueries folder. See ResolveSqlDir.
            public string? SqlDir { get; set; }
            // Exact .sql file for this report, from Python's
            // reports_map.REPORT_SQL. When set it replaces the
            // <SqlDir>\<ReportName>.sql lookup. See LoadReportSqlFile.
            public string? SqlFile { get; set; }
        }
    }
}