-- ============================================================================
-- TaxCodes.sql
-- Written for TaxCodes.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: TaxCodes_TTX
-- Source tables: taxcodes
-- Report parameters:
--   TaxCode (StringParameter)
--   LiabilityAccount (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: TaxCodes_TTX
-- Original data source: TaxCodes
-- ----------------------------------------------------------------------------
SELECT
    taxcode AS "TaxCode",
    taxrate::float8 AS "TaxRate",
    desctext AS "DescText",
    liabilityaccount::text AS "LiabilityAccount"
FROM taxcodes
ORDER BY taxcode;
