-- ============================================================================
-- CurrencyCodes.sql
-- Written for CurrencyCodes.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: CurrencyCodes_TTX
-- Source tables: currencycodes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: CurrencyCodes_TTX
-- Original data source: CurrencyCodes
-- ----------------------------------------------------------------------------
SELECT
    currencycode AS "CurrencyCode",
    exchangerate::float8 AS "ExchangeRate",
    desctext AS "DescText",
    eurorate::float8 AS "EURORate",
    coalesce(emumember, false) AS "EMUMember",
    currencysymbol AS "CurrencySymbol"
FROM currencycodes
ORDER BY currencycode;
