-- ============================================================================
-- EngineeringPartMaster.sql
-- Extracted from EngineeringPartMaster.rpt by CrystalReportWrapper --extract-sql.
-- Source of truth: TableQueryCatalog in CrystalReportWrapper\Program.cs -
-- edit the query there, then re-run --extract-sql to refresh this file.
-- Tables: EngineeringPartMaster_TTX
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: EngineeringPartMaster_TTX
-- Original data source: EngineeringPartMaster
-- ----------------------------------------------------------------------------
SELECT
    partnumber AS "PartNumber",
    desctext AS "DescText",
    revision AS "Revision",
    dimension AS "Dimension",
    weight AS "Weight",
    densitycode AS "DensityCode",
    stockuom AS "StockUOM"
FROM partmaster;
