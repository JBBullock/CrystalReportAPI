-- ============================================================================
-- ProductDiscountCodes.sql
-- Written for ProductDiscountCodes.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: ProductDiscountCodes_TTX
-- Source tables: productdisccodes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: ProductDiscountCodes_TTX
-- Original data source: ProductDiscountCodes
-- ----------------------------------------------------------------------------
SELECT
    productpricecode AS "ProductPriceCode",
    desctext AS "DescText"
FROM productdisccodes
ORDER BY productpricecode;
