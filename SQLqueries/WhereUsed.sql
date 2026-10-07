-- ============================================================================
-- WhereUsed.sql
-- Extracted from WhereUsed.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: WhereUsed_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: WhereUsed_TTX
-- Original data source: WhereUsed
-- ----------------------------------------------------------------------------
SELECT
    b.assembly AS "Assembly",
    b.component AS "Component",
    b.itemsequence AS "ItemSequence",
    b.quantityper AS "QuantityPer",
    b.obsoletedate AS "ObsoleteDate",
    b.effectivedate AS "EffectiveDate",
    b.bomuomcode AS "BOMUOMCode",
    am.desctext AS "Assembly_DescText",
    am.revision AS "Assembly_Revision",
    am.stockuom AS "Assembly_StockUOM",
    cm.desctext AS "Component_DescText",
    cm.revision AS "Component_Revision",
    cm.stockuom AS "Component_StockUOM"
FROM bom b
LEFT JOIN partmaster am ON upper(am.partnumber) = upper(b.assembly)
LEFT JOIN partmaster cm ON upper(cm.partnumber) = upper(b.component)
ORDER BY b.component, b.assembly;
