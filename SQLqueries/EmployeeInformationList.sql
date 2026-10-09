-- ============================================================================
-- EmployeeInformationList.sql
-- Written for EmployeeInformationList.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: EmployeeInformationList_TTX
-- Source tables: employees
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: EmployeeInformationList_TTX
-- Original data source: EmployeeInformationList
-- ----------------------------------------------------------------------------
SELECT
    employeeid AS "EmployeeID",
    departmentcode AS "DepartmentCode",
    ssn::text AS "SSN",
    firstname AS "FirstName",
    middleinitial AS "MiddleInitial",
    lastname AS "LastName",
    addressline1 AS "AddressLine1",
    addressline2 AS "AddressLine2",
    NULL::text AS "AddressLine3", -- INFERRED: employees has only two address lines
    NULL::text AS "AddressLine4", -- INFERRED: employees has only two address lines
    city AS "City",
    state AS "State",
    zip::text AS "ZIP",
    postal AS "Postal",
    country AS "Country",
    email AS "Email",
    wagerate::float8 AS "WageRate",
    commissionrate::float8 AS "CommissionRate",
    coalesce(active, false) AS "Active",
    phone AS "Phone",
    fax AS "FAX"
FROM employees
ORDER BY employeeid;
