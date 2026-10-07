-- ============================================================================
-- OutputReport.sql
-- Extracted from OutputReport.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: OutputReport_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
--   CostDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: OutputReport_TTX
-- Original data source: OutputReport
-- ----------------------------------------------------------------------------
-- INFERRED: "output" is what was shipped - shipment (SHP) and customer
-- return (RMA) transactions. SOCost is the unit sales price recorded on the
-- transaction; LineAmount is quantity times that price.
SELECT
    td.transactiongroup AS "TransactionGroup",
    th.transactiontype AS "TransactionType",
    th.transactiondate AS "TransactionDate",
    th.reference AS "Reference",
    td.partnumber AS "PartNumber",
    td.linenumber AS "LineNumber",
    td.quantity AS "Quantity",
    td.socost AS "SOCost",
    (td.quantity * td.socost) AS "LineAmount",
    pm.stockuom AS "StockUOM"
FROM transactiondetail td
JOIN transactionheader th ON th.transactiongroup = td.transactiongroup
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(td.partnumber)
WHERE th.transactiontype IN ('SHP', 'RMA')
ORDER BY th.transactiondate, td.transactiongroup, td.transactionid;
