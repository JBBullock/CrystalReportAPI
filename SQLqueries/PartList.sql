-- ============================================================================
-- PartList.sql
-- Extracted from PartList.rpt by CrystalReportWrapper --extract-sql.
-- Source of truth: TableQueryCatalog in CrystalReportWrapper\Program.cs -
-- edit the query there, then re-run --extract-sql to refresh this file.
-- Tables: PartList_TTX
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: PartList_TTX
-- Original data source: PartList
-- ----------------------------------------------------------------------------
SELECT
    partnumber AS "PartNumber",
    revision AS "Revision",
    desctext AS "DescText",
    stockuom AS "StockUOM",
    densitycode AS "DensityCode",
    isc AS "ISC",
    omc AS "OMC",
    icncode AS "ICNCode",
    departmentcode AS "DepartmentCode",
    stockroomcode AS "StockroomCode"
FROM partmaster;
