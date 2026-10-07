-- ============================================================================
-- LaborUtilization.sql
-- Written for LaborUtilization.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; aliases must match the
-- report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: LaborUtilization_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: LaborUtilization_TTX
-- Original data source: LaborUtilization
-- ----------------------------------------------------------------------------
-- INFERRED: ActualTime = hours between start and stop. StandardTime = the
-- router operation's setup time plus its run time x the quantity completed.
-- UtilizationPercent = standard / actual x 100 (the report's own totals use
-- the same ratio).
SELECT
    ld.wonumber AS "WONumber",
    ld.sequenceid AS "SequenceID",
    ld.employeeid AS "EmployeeID",
    ld.accountnumber AS "LaborDistribution_AccountNumber",
    ld.quantitycompleted AS "QuantityCompleted",
    ld.startdate AS "StartDate",
    ld.stopdate AS "StopDate",
    r.setuptime AS "SetUpTime",
    r.runtime AS "RunTime",
    e.departmentcode AS "DepartmentCode",
    coalesce(e.firstname, '') AS "FirstName",
    coalesce(e.lastname, '') AS "LastName",
    coalesce(e.middleinitial, '') AS "MiddleInitial",
    coalesce(e.suffix, '') AS "Suffix",
    ld.wagerate AS "WageRate",
    dc.accountnumber AS "DepartmentCodes_AccountNumber",
    dc.desctext AS "DescText", -- INFERRED: the employee's department description
    t.actual_hours AS "ActualTime",
    t.standard_hours AS "StandardTime",
    (CASE WHEN t.actual_hours > 0 THEN t.standard_hours / t.actual_hours * 100 ELSE 0 END)::float8 AS "UtilizationPercent"
FROM labordistribution ld
LEFT JOIN routers r ON upper(r.partnumber) = upper(ld.partnumber) AND r.sequenceid = ld.sequenceid
LEFT JOIN employees e ON upper(e.employeeid) = upper(ld.employeeid)
LEFT JOIN departmentcodes dc ON upper(dc.departmentcode) = upper(e.departmentcode)
CROSS JOIN LATERAL (
    SELECT
        coalesce(extract(epoch FROM (ld.stopdate - ld.startdate)) / 3600.0, 0)::float8 AS actual_hours,
        (coalesce(r.setuptime, 0) + coalesce(r.runtime, 0) * coalesce(ld.quantitycompleted, 0))::float8 AS standard_hours
) t
ORDER BY e.departmentcode, ld.employeeid, ld.startdate;
