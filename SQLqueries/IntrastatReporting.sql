-- ============================================================================
-- IntrastatReporting.sql
-- Extracted from IntrastatReporting.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: IntrastatReporting_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: IntrastatReporting_TTX
-- Original data source: IntrastatReporting
-- ----------------------------------------------------------------------------
SELECT
    ir.transactionid AS "TransactionID",
    ir.regioncode AS "RegionCode",
    ir.icncode AS "ICNCode",
    ir.sonumber AS "SONumber",
    ir.ponumber AS "PONumber",
    ir.linenumber AS "LineNumber",
    ir.cost AS "Cost",
    ir.taxrate AS "TaxRate",
    ir.transactiondate AS "TransactionDate",
    ir.vatregnumber AS "VATRegNumber",
    (ir.cost * ir.taxrate / 100) AS "Tax_Collected" -- INFERRED: tax rates are stored as percentages (e.g. 7.75)
FROM intrastatreport ir
ORDER BY ir.regioncode, ir.icncode, ir.transactiondate;
