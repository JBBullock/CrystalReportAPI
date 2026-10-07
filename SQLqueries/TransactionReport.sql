-- ============================================================================
-- TransactionReport.sql
-- Extracted from TransactionReport.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: TransactionReport_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: TransactionReport_TTX
-- Original data source: TransactionReport
-- ----------------------------------------------------------------------------
SELECT
    td.transactiongroup AS "TransactionGroup",
    td.transactionid AS "TransactionID",
    td.partnumber AS "PartNumber",
    th.transactiontype AS "TransactionType",
    th.reference AS "Reference",
    th.transactiondate AS "TransactionDate",
    td.quantity AS "Quantity",
    td.cost AS "Cost",
    td.snlotnumber AS "SNLotNumber",
    td.linenumber AS "LineNumber",
    fd.accountnumber AS "FromDepartmentCodes_AccountNumber",
    tdc.accountnumber AS "ToDepartmentCodes_AccountNumber"
FROM transactiondetail td
JOIN transactionheader th ON th.transactiongroup = td.transactiongroup
LEFT JOIN departmentcodes fd ON upper(fd.departmentcode) = upper(td.fromdepartment)
LEFT JOIN departmentcodes tdc ON upper(tdc.departmentcode) = upper(td.todepartment)
ORDER BY th.transactiondate, td.transactiongroup, td.transactionid;
