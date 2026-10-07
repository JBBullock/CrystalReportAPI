-- ============================================================================
-- POPickList.sql
-- Extracted from POPickList.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: POPickList_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: POPickList_TTX
-- Original data source: POPickList
-- ----------------------------------------------------------------------------
-- Subcontract (kit) PO lines with the bill of materials of the part ordered:
-- the components to pick and send to the supplier.
SELECT
    pd.ponumber AS "PONumber",
    pd.poline AS "POLine",
    pd.partnumber AS "PartNumber",
    pd.purchaseuom AS "PurchaseUOM",
    pd.quantityordered AS "QuantityOrdered",
    pd.quantityreleased AS "QuantityReleased",
    pd.requireddate AS "RequiredDate",
    pd.releasedate AS "ReleaseDate",
    ph.requisitionnumber AS "RequisitionNumber",
    ph.supplierid AS "SupplierID",
    s.suppliername AS "SupplierName",
    am.desctext AS "AssemblyDescText",
    am.stockroomcode AS "AssemblyStockroomCode",
    am.departmentcode AS "AssemblyDepartmentCode",
    am.revision AS "AssemblyRevision",
    am.stockuom AS "AssemblyStockUOM",
    am.densitycode AS "AssemblyDensityCode",
    b.assembly AS "Assembly",
    b.component AS "Component",
    b.quantityper AS "QuantityPer",
    b.bomuomcode AS "BOMUOMCode",
    b.itemsequence AS "ItemSequence",
    b.obsoletedate AS "ObsoleteDate",
    b.effectivedate AS "EffectiveDate",
    cm.isc AS "ComponentISC",
    cm.locationcode AS "ComponentLocationCode",
    cm.desctext AS "ComponentDescText",
    cm.revision AS "ComponentRevision",
    cm.stockuom AS "ComponentStockUOM",
    cm.densitycode AS "ComponentDensityCode",
    -- INFERRED: quantity to pick = quantity per x what is still to release.
    (b.quantityper * (coalesce(pd.quantityordered, 0) - coalesce(pd.quantityreleased, 0))) AS "Quantity"
FROM podetail pd
JOIN poheader ph ON upper(ph.ponumber) = upper(pd.ponumber)
JOIN bom b ON upper(b.assembly) = upper(pd.partnumber)
LEFT JOIN suppliers s ON upper(s.supplierid) = upper(ph.supplierid)
LEFT JOIN partmaster am ON upper(am.partnumber) = upper(pd.partnumber)
LEFT JOIN partmaster cm ON upper(cm.partnumber) = upper(b.component)
WHERE pd.kitpartflag -- INFERRED: only lines flagged as kit (subcontract) parts
ORDER BY pd.ponumber, pd.poline, b.itemsequence, b.component;
