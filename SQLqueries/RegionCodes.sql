-- ============================================================================
-- RegionCodes.sql
-- Written for RegionCodes.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: RegionCodes_TTX
-- Source tables: regioncodes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: RegionCodes_TTX
-- Original data source: RegionCodes
-- ----------------------------------------------------------------------------
SELECT
    regioncode AS "RegionCode",
    desctext AS "DescText"
FROM regioncodes
ORDER BY regioncode;
