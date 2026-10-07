-- ============================================================================
-- WOPickList.sql
-- Extracted from WOPickList.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: WO Pick List_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: WO Pick List_TTX
-- Original data source: WOPickList
-- ----------------------------------------------------------------------------
-- Open work orders with the bill of materials of the part being built:
-- the components to pick.
SELECT
    wh.wonumber AS "WONumber",
    wh.partnumber AS "PartNumber",
    wh.workorderuom AS "WorkOrderUOM",
    wh.requireddate AS "RequiredDate",
    wh.startdate AS "StartDate",
    wh.releaseddate AS "ReleasedDate",
    wh.quantitytostart AS "QuantityToStart",
    wh.quantityreleased AS "QuantityReleased",
    am.stockroomcode AS "AssemblyStockroomCode",
    am.desctext AS "AssemblyDescText",
    am.revision AS "AssemblyRevision",
    am.stockuom AS "AssemblyStockUOM",
    am.departmentcode AS "AssemblyDepartmentCode",
    am.densitycode AS "AssemblyDensityCode",
    b.assembly AS "Assembly",
    b.component AS "Component",
    b.quantityper AS "QuantityPer",
    b.bomuomcode AS "BOMUOMCode",
    b.itemsequence AS "ItemSequence",
    b.obsoletedate AS "ObsoleteDate",
    b.effectivedate AS "EffectiveDate",
    cm.isc AS "ComponentISC",
    cm.stockroomcode AS "ComponentStockroomCode",
    cm.locationcode AS "ComponentLocationCode",
    cm.desctext AS "ComponentDescText",
    cm.revision AS "ComponentRevision",
    cm.stockuom AS "ComponentStockUOM",
    cm.densitycode AS "ComponentDensityCode",
    -- INFERRED: quantity to pick = quantity per x what is still to release.
    (b.quantityper * (coalesce(wh.quantitytostart, 0) - coalesce(wh.quantityreleased, 0))) AS "Quantity"
FROM woheader wh
JOIN bom b ON upper(b.assembly) = upper(wh.partnumber)
LEFT JOIN partmaster am ON upper(am.partnumber) = upper(wh.partnumber)
LEFT JOIN partmaster cm ON upper(cm.partnumber) = upper(b.component)
WHERE NOT wh.closedflag -- INFERRED: open work orders only
ORDER BY wh.wonumber, b.itemsequence, b.component;
