-- ============================================================================
-- EngineeringChangeNotice.sql
-- Extracted from EngineeringChangeNotice.rpt by CrystalReportWrapper --extract-sql.
-- Source of truth: TableQueryCatalog in CrystalReportWrapper\Program.cs -
-- edit the query there, then re-run --extract-sql to refresh this file.
-- Tables: EngineeringChangeNotice_TTX
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: EngineeringChangeNotice_TTX
-- Original data source: EngineeringChangeNotice
-- ----------------------------------------------------------------------------
SELECT
    eh.ecnnumber AS "ECNNumber",
    eh.ecnclasscode AS "ECNClassCode",
    eh.ecndate::timestamp AS "ECNDate",
    ep.partnumber AS "PartNumber",
    ep.desctext AS "ECNParts_DescText",
    pm.desctext AS "PartMaster_DescText",
    ecc.desctext AS "ECNClassCodes_DescText",
    eh.notes AS "Notes",
    (CASE WHEN eh.notes IS NULL THEN 1 ELSE 0 END) AS "Isnull_Notes"
FROM ecnheader eh
JOIN ecnparts ep ON ep.ecnnumber = eh.ecnnumber
LEFT JOIN partmaster pm ON pm.partnumber = ep.partnumber
LEFT JOIN ecnclasscodes ecc ON ecc.ecnclasscode = eh.ecnclasscode;
