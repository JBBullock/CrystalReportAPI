-- ============================================================================
-- ShipViaCodes.sql
-- Written for ShipViaCodes.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: ShipViaCodes_TTX
-- Source tables: shipviacodes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: ShipViaCodes_TTX
-- Original data source: ShipViaCodes
-- ----------------------------------------------------------------------------
SELECT
    shipviacode AS "ShipViaCode",
    desctext AS "DescText"
FROM shipviacodes
ORDER BY shipviacode;
