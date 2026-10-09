-- ============================================================================
-- SystemUsedOnCodes.sql
-- Written for SystemUsedOnCodes.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: SystemUsedOnCodes_TTX
-- Source tables: suocodes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: SystemUsedOnCodes_TTX
-- Original data source: SystemUsedOnCodes
-- ----------------------------------------------------------------------------
SELECT
    suocode AS "SUOCode",
    desctext AS "DescText"
FROM suocodes
ORDER BY suocode;
