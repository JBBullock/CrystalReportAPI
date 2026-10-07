-- ============================================================================
-- BillOfMaterials.sql
-- Extracted from BillOfMaterials.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: BillOfMaterials_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: BillOfMaterials_TTX
-- Original data source: BillOfMaterials
-- ----------------------------------------------------------------------------
SELECT
    b.assembly AS "Assembly",
    b.component AS "Component",
    b.itemsequence AS "ItemSequence",
    b.quantityper AS "QuantityPer",
    b.bomuomcode AS "BOMUOMCode",
    b.effectivedate AS "EffectiveDate",
    b.obsoletedate AS "ObsoleteDate",
    am.desctext AS "Assembly_DescText",
    am.revision AS "Assembly_Revision",
    am.stockuom AS "Assembly_StockUOM",
    cm.desctext AS "Component_DescText",
    cm.revision AS "Component_Revision",
    cm.stockuom AS "Component_StockUOM",
    cm.isc AS "ISC", -- INFERRED: the component's source code (the line item), not the assembly's
    am.orderquantity AS "OrderQuantity", -- INFERRED: the assembly's order quantity (header value)
    b.notes AS "Notes",
    am.engnotes AS "Assembly_EngNotes",
    cm.engnotes AS "Component_EngNotes",
    (CASE WHEN b.notes IS NULL OR b.notes = '' THEN -1 ELSE 0 END) AS "Isnull_BOMNotes",
    (CASE WHEN am.engnotes IS NULL OR am.engnotes = '' THEN -1 ELSE 0 END) AS "Isnull_AssemblyNotes",
    (CASE WHEN cm.engnotes IS NULL OR cm.engnotes = '' THEN -1 ELSE 0 END) AS "Isnull_ComponentNotes"
FROM bom b
LEFT JOIN partmaster am ON upper(am.partnumber) = upper(b.assembly)
LEFT JOIN partmaster cm ON upper(cm.partnumber) = upper(b.component)
ORDER BY b.assembly, b.itemsequence, b.component;
