-- ============================================================================
-- DepartmentCodes.sql
-- Written for DepartmentCodes.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: DepartmentCodes_TTX
-- Source tables: departmentcodes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: DepartmentCodes_TTX
-- Original data source: DepartmentCodes
-- ----------------------------------------------------------------------------
SELECT
    departmentcode AS "DepartmentCode",
    desctext AS "DescText",
    accountnumber::text AS "AccountNumber",
    coalesce(nettableflag, false) AS "NettableFlag",
    coalesce(inventoryflag, false) AS "InventoryFlag"
FROM departmentcodes
ORDER BY departmentcode;
