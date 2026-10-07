-- ============================================================================
-- ShortageReport.sql
-- Extracted from ShortageReport.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: ShortageReport_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: ShortageReport_TTX
-- Original data source: ShortageReport
-- ----------------------------------------------------------------------------
-- Shortages recorded against purchase orders and against work orders.
SELECT
    x.powonumber AS "POWONumber",
    x.partnumber AS "PartNumber",
    x.linenumber AS "LineNumber",
    x.transactiondate AS "TransactionDate",
    x.quantity AS "Quantity",
    pm.desctext AS "PartMaster_DescText",
    pm.departmentcode AS "DepartmentCode",
    pm.stockroomcode AS "StockroomCode",
    pm.isc AS "ISC",
    pm.omc AS "OMC",
    dc.desctext AS "Stockroom_DescText", -- INFERRED: description of the part's stockroom department
    e.lastname AS "LastName" -- INFERRED: the employee who entered the part
FROM (
    SELECT ponumber AS powonumber, partnumber, linenumber, transactiondate, quantity FROM poshortages
    UNION ALL
    SELECT wonumber, partnumber, ''::varchar, transactiondate, quantity FROM woshortages
) x
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(x.partnumber)
LEFT JOIN departmentcodes dc ON upper(dc.departmentcode) = upper(pm.stockroomcode)
LEFT JOIN employees e ON upper(e.employeeid) = upper(pm.enteredby)
ORDER BY x.partnumber, x.transactiondate, x.powonumber;
