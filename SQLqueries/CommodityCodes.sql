-- ============================================================================
-- CommodityCodes.sql
-- Written for CommodityCodes.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: CommodityCodes_TTX
-- Source tables: commoditycodes, employees, departmentcodes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: CommodityCodes_TTX
-- Original data source: CommodityCodes
-- ----------------------------------------------------------------------------
-- One row per commodity code, with its buyer (employee) and that buyer's department.
SELECT
    cc.commoditycode AS "CommodityCode",
    cc.employeeid AS "EmployeeID",
    cc.desctext AS "CommodityCodes_DescText",
    e.departmentcode AS "DepartmentCode",
    e.lastname AS "LastName",
    e.firstname AS "FirstName",
    e.middleinitial AS "MiddleInitial",
    dc.desctext AS "DepartmentCodes_DescText"
FROM commoditycodes cc
LEFT JOIN employees e ON upper(e.employeeid) = upper(cc.employeeid)
LEFT JOIN departmentcodes dc ON upper(dc.departmentcode) = upper(e.departmentcode)
ORDER BY cc.commoditycode;
