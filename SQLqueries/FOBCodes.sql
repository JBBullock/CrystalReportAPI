-- ============================================================================
-- FOBCodes.sql
-- Written for FOBCodes.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: FOBCodes_TTX
-- Source tables: fobcodes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: FOBCodes_TTX
-- Original data source: FOBCodes
-- ----------------------------------------------------------------------------
SELECT
    fobcode AS "FOBCode",
    desctext AS "DescText"
FROM fobcodes
ORDER BY fobcode;
