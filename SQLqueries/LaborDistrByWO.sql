-- ============================================================================
-- LaborDistrByWO.sql
-- Extracted from LaborDistrByWO.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: LaborDistrByWO_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: LaborDistrByWO_TTX
-- Original data source: LaborDistrByWO
-- ----------------------------------------------------------------------------
SELECT
    ld.wonumber AS "LaborDistribution_WONumber",
    wh.wonumber AS "WOHeader_WONumber",
    wh.partnumber AS "PartNumber",
    ld.employeeid AS "EmployeeID",
    ld.startdate AS "LaborDistribution_StartDate",
    ld.stopdate AS "LaborDistribution_StopDate",
    ld.quantitycompleted AS "LaborDistribution_QuantityCompleted",
    ld.accountnumber AS "LaborDistribution_AccountNumber",
    ld.wagerate AS "WageRate",
    ld.sequenceid AS "SequenceID",
    wh.startdate AS "WOHeader_StartDate",
    wh.requireddate AS "WOHeader_RequiredDate",
    wh.quantitytostart AS "QuantityToStart",
    wh.quantityreleased AS "QuantityReleased",
    wh.quantityrequired AS "QuantityRequired",
    wh.quantitycompleted AS "WOHeader_QuantityCompleted",
    pm.desctext AS "DescText", -- the work order part's description
    dc.accountnumber AS "DepartmentCodes_AccountNumber",
    (extract(epoch FROM (ld.stopdate - ld.startdate)) / 3600.0)::float8 AS "ActualTime" -- INFERRED: hours between start and stop
FROM labordistribution ld
LEFT JOIN woheader wh ON upper(wh.wonumber) = upper(ld.wonumber)
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(wh.partnumber)
LEFT JOIN employees e ON upper(e.employeeid) = upper(ld.employeeid)
LEFT JOIN departmentcodes dc ON upper(dc.departmentcode) = upper(e.departmentcode)
ORDER BY ld.wonumber, ld.sequenceid, ld.startdate;
