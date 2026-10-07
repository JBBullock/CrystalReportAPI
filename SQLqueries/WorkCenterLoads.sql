-- ============================================================================
-- WorkCenterLoads.sql
-- Extracted from WorkCenterLoads.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: WorkCenterLoads_TTX
-- Report parameters:
--   WorkCenterID (StringParameter)
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: WorkCenterLoads_TTX
-- Original data source: WorkCenterLoads
-- ----------------------------------------------------------------------------
SELECT
    cd.workcenterid AS "WorkCenterID",
    cd.wonumber AS "WONumber",
    cd.partnumber AS "PartNumber",
    cd.sequenceid AS "SequenceID",
    cd.startdatetime AS "StartDateTime",
    cd.stopdatetime AS "StopDateTime",
    cd.startquantity AS "StartQuantity",
    cd.minutesused AS "MinutesUsed",
    cd.summarydate AS "SummaryDate",
    cd.operationcode AS "OperationCode",
    coalesce(ch.overcapacity, false) AS "OverCapacity",
    wc.workcentername AS "WorkCenterName",
    cs.startdate AS "StartDate",
    cs.capacity AS "Capacity",
    cs.capusage AS "CapUsage"
FROM crpdetail cd
LEFT JOIN crpheader ch ON upper(ch.workcenterid) = upper(cd.workcenterid)
LEFT JOIN workcenters wc ON upper(wc.workcenterid) = upper(cd.workcenterid)
LEFT JOIN crpsummary cs ON upper(cs.workcenterid) = upper(cd.workcenterid) AND cs.startdate = cd.summarydate -- INFERRED link
ORDER BY cd.workcenterid, cd.startdatetime;
