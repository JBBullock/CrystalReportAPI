-- ============================================================================
-- TermsCodes.sql
-- Written for TermsCodes.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: TermsCodes_TTX
-- Source tables: termscodes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: TermsCodes_TTX
-- Original data source: TermsCodes
-- ----------------------------------------------------------------------------
SELECT
    termscode AS "TermsCode",
    desctext AS "DescText"
FROM termscodes
ORDER BY termscode;
