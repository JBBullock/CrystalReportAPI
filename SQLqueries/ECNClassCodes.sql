-- ============================================================================
-- ECNClassCodes.sql
-- Written for ECNClassCodes.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: ECNClassCodes_TTX
-- Source tables: ecnclasscodes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: ECNClassCodes_TTX
-- Original data source: ECNClassCodes
-- ----------------------------------------------------------------------------
SELECT
    ecnclasscode AS "ECNClassCode",
    desctext AS "DescText"
FROM ecnclasscodes
ORDER BY ecnclasscode;
