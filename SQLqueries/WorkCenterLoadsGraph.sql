-- ============================================================================
-- WorkCenterLoadsGraph.sql
-- Extracted from WorkCenterLoadsGraph.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: WorkCenterLoadsGraph_TTX
-- Report parameters:
--   WorkCenterID (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: WorkCenterLoadsGraph_TTX
-- Original data source: WorkCenterLoadsGraph
-- ----------------------------------------------------------------------------
SELECT
    cs.workcenterid AS "WorkCenterID",
    cs.startdate AS "StartDate",
    cs.capusage AS "CapUsage"
FROM crpsummary cs
ORDER BY cs.workcenterid, cs.startdate;
