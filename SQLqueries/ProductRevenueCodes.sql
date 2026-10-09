-- ============================================================================
-- ProductRevenueCodes.sql
-- Written for ProductRevenueCodes.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: ProductRevenueCodes_TTX
-- Source tables: productclasscodes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: ProductRevenueCodes_TTX
-- Original data source: ProductRevenueCodes
-- ----------------------------------------------------------------------------
-- The legacy "product revenue codes" are the product class codes.
SELECT
    productclass AS "ProductClass",
    revenueaccount::text AS "RevenueAccount",
    expenseaccount::text AS "ExpenseAccount",
    desctext AS "DescText"
FROM productclasscodes
ORDER BY productclass;
