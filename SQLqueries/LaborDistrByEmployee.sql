-- ============================================================================
-- LaborDistrByEmployee.sql
-- Extracted from LaborDistrByEmployee.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: LaborDistrByEmployee_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: LaborDistrByEmployee_TTX
-- Original data source: LaborDistrByEmployee
-- ----------------------------------------------------------------------------
SELECT
    ld.wonumber AS "WONumber",
    ld.employeeid AS "EmployeeID",
    ld.sequenceid AS "SequenceID",
    ld.startdate AS "StartDate",
    ld.stopdate AS "StopDate",
    ld.quantitycompleted AS "QuantityCompleted",
    ld.accountnumber AS "LaborDistribution_AccountNumber",
    ld.wagerate AS "WageRate",
    e.departmentcode AS "DepartmentCode",
    e.lastname AS "LastName",
    e.firstname AS "FirstName",
    e.middleinitial AS "MiddleInitial",
    e.suffix AS "Suffix",
    dc.accountnumber AS "DepartmentCodes_AccountNumber",
    dc.desctext AS "DescText", -- INFERRED: the employee's department description
    (extract(epoch FROM (ld.stopdate - ld.startdate)) / 3600.0)::float8 AS "ActualTime" -- INFERRED: hours between start and stop
FROM labordistribution ld
LEFT JOIN employees e ON upper(e.employeeid) = upper(ld.employeeid)
LEFT JOIN departmentcodes dc ON upper(dc.departmentcode) = upper(e.departmentcode)
ORDER BY ld.employeeid, ld.startdate;
