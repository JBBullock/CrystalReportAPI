-- ============================================================================
-- MiscUnplannedIssues.sql
-- Extracted from MiscUnplannedIssues.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: MiscUnplannedIssues_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: MiscUnplannedIssues_TTX
-- Original data source: MiscUnplannedIssues
-- ----------------------------------------------------------------------------
SELECT
    td.transactiongroup AS "TransactionGroup",
    td.transactionid AS "TransactionID",
    td.partnumber AS "PartNumber",
    td.fromdepartment AS "FromDepartment",
    td.todepartment AS "ToDepartment",
    td.snlotnumber AS "SNLotNumber",
    td.cost AS "Cost",
    td.quantity AS "Quantity",
    td.linenumber AS "LineNumber",
    td.fromlocation AS "FromLocation",
    th.transactiondate AS "TransactionDate",
    th.reference AS "Reference",
    th.enteredby AS "EnteredBy",
    pm.desctext AS "DescText"
FROM transactiondetail td
JOIN transactionheader th ON th.transactiongroup = td.transactiongroup
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(td.partnumber)
WHERE th.transactiontype = 'UPL'
ORDER BY td.partnumber, th.transactiondate, td.transactionid;
