-- ============================================================================
-- InventoryVariance.sql
-- Written for InventoryVariance.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; aliases must match the
-- report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: InventoryVarianceReport_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: InventoryVarianceReport_TTX
-- Original data source: InventoryVariance
-- ----------------------------------------------------------------------------
SELECT
    it.tagnumber AS "TagNumber",
    it.partnumber AS "PartNumber",
    it.departmentcode AS "DepartmentCode",
    it.snlotnumber AS "SNLotNumber",
    it.jobnumber AS "JobNumber",
    it.locationcode AS "LocationCode",
    it.employeeid AS "EmployeeID",
    it.inventoryquantity AS "InventoryQuantity",
    it.countquantity AS "CountQuantity",
    pm.desctext AS "DescText",
    pm.cost AS "Cost",
    it.closedflag AS "ClosedFlag",
    (coalesce(it.countquantity, 0) - coalesce(it.inventoryquantity, 0)) AS "QuantityVariance", -- INFERRED: counted minus on record
    ((coalesce(it.countquantity, 0) - coalesce(it.inventoryquantity, 0)) * coalesce(pm.cost, 0)) AS "CostVariance"
FROM inventorytags it
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(it.partnumber)
ORDER BY it.departmentcode, it.locationcode, it.partnumber, it.tagnumber;
