-- ============================================================================
-- StockroomLocations.sql
-- Extracted from StockroomLocations.rpt by CrystalReportWrapper --extract-sql.
-- Source of truth: TableQueryCatalog in CrystalReportWrapper\Program.cs -
-- edit the query there, then re-run --extract-sql to refresh this file.
-- Tables: StockroomLocations_TTX
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: StockroomLocations_TTX
-- Original data source: StockroomLocations
-- ----------------------------------------------------------------------------
SELECT
    sl.departmentcode AS "DepartmentCode",
    sl.locationcode AS "LocationCode",
    sl.desctext AS "StockLocations_DescText",
    dc.desctext AS "DepartmentCodes_DescText",
    dc.accountnumber AS "AccountNumber",
    dc.nettableflag AS "NettableFlag",
    dc.inventoryflag AS "InventoryFlag"
FROM stocklocations sl
LEFT JOIN departmentcodes dc ON dc.departmentcode = sl.departmentcode;
