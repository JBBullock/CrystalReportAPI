-- ============================================================================
-- OperationCodes.sql
-- Written for OperationCodes.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: OperationCodes_TTX
-- Source tables: operationcodes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: OperationCodes_TTX
-- Original data source: OperationCodes
-- ----------------------------------------------------------------------------
SELECT
    operationcode AS "OperationCode",
    desctext AS "DescText"
FROM operationcodes
ORDER BY operationcode;
