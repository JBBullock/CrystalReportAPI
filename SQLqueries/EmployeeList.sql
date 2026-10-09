-- ============================================================================
-- EmployeeList.sql
-- Written for EmployeeList.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: EmployeeListReport_TTX
-- Source tables: employees
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: EmployeeListReport_TTX
-- Original data source: EmployeeList
-- ----------------------------------------------------------------------------
SELECT
    employeeid AS "EmployeeID",
    departmentcode AS "DepartmentCode",
    firstname AS "FirstName",
    lastname AS "LastName",
    middleinitial AS "MiddleInitial",
    ssn::text AS "SSN",
    coalesce(active, false) AS "Active"
FROM employees
ORDER BY employeeid;
