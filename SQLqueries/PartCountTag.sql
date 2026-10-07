-- ============================================================================
-- PartCountTag.sql
-- Extracted from PartCountTag.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: PartCountTag_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: PartCountTag_TTX
-- Original data source: PartCountTag
-- ----------------------------------------------------------------------------
SELECT
    it.tagnumber AS "TagNumber",
    it.partnumber AS "PartNumber",
    it.departmentcode AS "DepartmentCode",
    it.locationcode AS "LocationCode",
    it.snlotnumber AS "SNLotNumber",
    it.inventoryquantity AS "InventoryQuantity",
    it.jobnumber AS "JobNumber",
    pm.revision AS "Revision",
    pm.desctext AS "DescText",
    pm.stockuom AS "StockUOM"
FROM inventorytags it
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(it.partnumber)
ORDER BY it.tagnumber;
