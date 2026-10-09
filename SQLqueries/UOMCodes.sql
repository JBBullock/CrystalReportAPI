-- ============================================================================
-- UOMCodes.sql
-- Written for UOMCodes.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: UOMCodes_TTX
-- Source tables: uomcodes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: UOMCodes_TTX
-- Original data source: UOMCodes
-- ----------------------------------------------------------------------------
SELECT
    uomcode AS "UOMCode",
    desctext AS "DescText",
    uomtype::float8 AS "UOMType",
    conversionfactor::float8 AS "ConversionFactor",
    (CASE WHEN conversionfactor = 1 THEN -1 ELSE 0 END)::int2 AS "IsBaseUOM" -- INFERRED: the base unit of its type is the one with factor 1 (-1 = true, as the legacy program wrote flags)
FROM uomcodes
ORDER BY uomtype, uomcode;
