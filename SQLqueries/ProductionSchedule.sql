-- ============================================================================
-- ProductionSchedule.sql
-- Extracted from ProductionSchedule.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: ProductionSchedule_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: ProductionSchedule_TTX
-- Original data source: ProductionSchedule
-- ----------------------------------------------------------------------------
-- INFERRED: open work orders only.
SELECT
    wh.wonumber AS "WONumber",
    wh.partnumber AS "PartNumber",
    wh.startdate AS "StartDate",
    wh.requireddate AS "RequiredDate",
    wh.wopriority AS "WOPriority",
    wh.quantityreleased AS "QuantityReleased",
    wh.quantityrequired AS "QuantityRequired",
    wh.quantitycompleted AS "QuantityCompleted",
    wh.quantitytostart AS "QuantityToStart",
    wh.closedflag AS "ClosedFlag",
    pm.departmentcode AS "PartMaster_DepartmentCode",
    pm.standardhours AS "StandardHours",
    dc.departmentcode AS "DepartmentCodes_DepartmentCode",
    dc.desctext AS "DescText" -- INFERRED: the department's description
FROM woheader wh
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(wh.partnumber)
LEFT JOIN departmentcodes dc ON upper(dc.departmentcode) = upper(pm.departmentcode)
WHERE NOT wh.closedflag
ORDER BY pm.departmentcode, wh.startdate, wh.wonumber;
