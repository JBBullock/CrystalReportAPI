-- ============================================================================
-- HolidayList.sql
-- Written for HolidayList.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: Holiday List_TTX
-- Source tables: calendar
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: Holiday List_TTX
-- Original data source: HolidayList
-- ----------------------------------------------------------------------------
-- INFERRED: the holiday list is the calendar table (description + date range).
SELECT
    desctext AS "DescText",
    (CASE WHEN trim(startdate::text) = '' THEN NULL ELSE startdate::text::timestamp END) AS "StartDate",
    (CASE WHEN trim(enddate::text) = '' THEN NULL ELSE enddate::text::timestamp END) AS "EndDate"
FROM calendar
ORDER BY 2, 1;
