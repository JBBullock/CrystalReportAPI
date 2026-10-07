-- ============================================================================
-- PartCountList.sql
-- Extracted from PartCountList.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: PartCountList_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: PartCountList_TTX
-- Original data source: PartCountList
-- ----------------------------------------------------------------------------
SELECT
    it.tagnumber AS "TagNumber",
    it.partnumber AS "PartNumber",
    it.departmentcode AS "DepartmentCode",
    it.locationcode AS "LocationCode",
    it.snlotnumber AS "SNLotNumber",
    it.inventoryquantity AS "InventoryQuantity",
    it.countquantity AS "CountQuantity",
    it.closedflag AS "ClosedFlag",
    pm.desctext AS "PartMaster_DescText",
    pm.stockuom AS "StockUOM",
    dc.desctext AS "DepartmentCodes_DescText",
    dc.accountnumber AS "AccountNumber",
    coalesce(dc.nettableflag, false) AS "NettableFlag"
FROM inventorytags it
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(it.partnumber)
LEFT JOIN departmentcodes dc ON upper(dc.departmentcode) = upper(it.departmentcode)
ORDER BY it.departmentcode, it.locationcode, it.partnumber, it.tagnumber;
