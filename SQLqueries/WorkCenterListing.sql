-- ============================================================================
-- WorkCenterListing.sql
-- Extracted from WorkCenterListing.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: WorkCenterListing_TTX
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: WorkCenterListing_TTX
-- Original data source: WorkCenterListing
-- ----------------------------------------------------------------------------
-- One row per work center shift (and per recorded downtime of that shift);
-- a work center with no shifts appears once with the shift columns empty.
SELECT
    wc.workcenterid AS "WorkCenterID",
    ws.shiftid AS "ShiftID",
    wc.workcentername AS "WorkCenterName",
    wc.defaultwagerate AS "DefaultWageRate",
    wc.wcaccountnumber AS "WCAccountNumber",
    wc.useshifts AS "UseShifts",
    ws.starttime AS "StartTime",
    ws.stoptime AS "StopTime",
    coalesce(ws.capacity, wc.capacity) AS "Capacity", -- INFERRED: the shift's capacity, else the work center's
    coalesce(ws.monday, false) AS "Monday",
    coalesce(ws.tuesday, false) AS "Tuesday",
    coalesce(ws.wednesday, false) AS "Wednesday",
    coalesce(ws.thursday, false) AS "Thursday",
    coalesce(ws.friday, false) AS "Friday",
    coalesce(ws.saturday, false) AS "Saturday",
    coalesce(ws.sunday, false) AS "Sunday",
    sd.startdate AS "StartDate",
    sd.reasondown AS "ReasonDown"
FROM workcenters wc
LEFT JOIN workcentershifts ws ON upper(ws.workcenterid) = upper(wc.workcenterid)
LEFT JOIN shiftdowntime sd ON upper(sd.workcenterid) = upper(ws.workcenterid) AND upper(sd.shiftid) = upper(ws.shiftid)
ORDER BY wc.workcenterid, ws.shiftid, sd.startdate;

