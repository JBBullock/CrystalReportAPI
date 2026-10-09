-- ============================================================================
-- PriceDiscountCodes.sql
-- Written for PriceDiscountCodes.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: PriceDiscountCodes_TTX
-- Source tables: pricediscountcodes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: PriceDiscountCodes_TTX
-- Original data source: PriceDiscountCodes
-- ----------------------------------------------------------------------------
SELECT
    pricecode AS "PriceCode",
    discountpercentage::float8 AS "DiscountPercentage",
    desctext AS "DescText"
FROM pricediscountcodes
ORDER BY pricecode;
