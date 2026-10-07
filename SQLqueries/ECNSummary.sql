-- ============================================================================
-- ECNSummary.sql
-- Written for ECNSummary.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; aliases must match the
-- report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: ECNSummary_TTX
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: ECNSummary_TTX
-- Original data source: ECNSummary
-- ----------------------------------------------------------------------------
SELECT
    eh.ecnnumber AS "ECNNumber",
    eh.ecnclasscode AS "ECNClassCode",
    eh.ecndate AS "ECNDate",
    ep.partnumber AS "PartNumber",
    ep.desctext AS "ECNParts_DescText",
    pm.desctext AS "PartMaster_DescText",
    ecc.desctext AS "ECNClassCodes_DescText",
    eh.notes AS "Notes",
    (CASE WHEN eh.notes IS NULL OR eh.notes = '' THEN -1 ELSE 0 END) AS "Isnull_Notes"
FROM ecnheader eh
LEFT JOIN ecnparts ep ON upper(ep.ecnnumber) = upper(eh.ecnnumber)
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(ep.partnumber)
LEFT JOIN ecnclasscodes ecc ON upper(ecc.ecnclasscode) = upper(eh.ecnclasscode)
ORDER BY eh.ecnnumber, ep.partnumber;
