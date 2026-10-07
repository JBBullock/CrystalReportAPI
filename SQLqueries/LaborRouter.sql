-- ============================================================================
-- LaborRouter.sql
-- Extracted from LaborRouter.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: LaborRouter_TTX
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: LaborRouter_TTX
-- Original data source: LaborRouter
-- ----------------------------------------------------------------------------
SELECT
    r.partnumber AS "PartNumber",
    r.operationcode AS "OperationCode",
    r.workcenterid AS "WorkCenterID",
    r.queuetime AS "QueueTime",
    r.setuptime AS "SetUpTime",
    r.runtime AS "RunTime",
    r.isalternate AS "IsAlternate",
    pm.revision AS "Revision",
    pm.desctext AS "PartMaster_DescText",
    pm.stockuom AS "StockUOM",
    oc.desctext AS "OperationCodes_DescText",
    wc.workcentername AS "WorkCenterName",
    r.sequenceid AS "SequenceID"
FROM routers r
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(r.partnumber)
LEFT JOIN operationcodes oc ON upper(oc.operationcode) = upper(r.operationcode)
LEFT JOIN workcenters wc ON upper(wc.workcenterid) = upper(r.workcenterid)
ORDER BY r.partnumber, r.sequenceid;
