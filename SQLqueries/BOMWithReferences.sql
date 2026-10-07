-- ============================================================================
-- BOMWithReferences.sql
-- Written for BOMWithReferences.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; aliases must match the
-- report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: BOMWithReferences_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: BOMWithReferences_TTX
-- Original data source: BOMWithReferences
-- ----------------------------------------------------------------------------
-- One row per BOM line and reference designator; a BOM line with no
-- designators appears once with the designator columns empty.
SELECT
    b.assembly AS "Assembly",
    b.component AS "Component",
    b.itemsequence AS "ItemSequence",
    b.quantityper AS "QuantityPer",
    b.bomuomcode AS "BOMUOMCode",
    b.obsoletedate AS "ObsoleteDate",
    b.effectivedate AS "EffectiveDate",
    coalesce(rd.refdesignator, '') AS "RefDesignator",
    coalesce(rd.desctext, '') AS "RefDesignators_DescText",
    am.revision AS "Assembly_Revision",
    am.desctext AS "Assembly_DescText",
    am.stockuom AS "Assembly_StockUOM",
    cm.revision AS "Component_Revision",
    cm.desctext AS "Component_DescText",
    cm.stockuom AS "Component_StockUOM",
    cm.isc AS "ISC", -- INFERRED: the component's source code (the line item), not the assembly's
    rd.notes AS "Notes", -- the reference designator's notes
    (CASE WHEN rd.notes IS NULL OR rd.notes = '' THEN -1 ELSE 0 END) AS "Isnull_RefDesNotes"
FROM bom b
LEFT JOIN refdesignators rd ON upper(rd.assembly) = upper(b.assembly) AND upper(rd.component) = upper(b.component)
LEFT JOIN partmaster am ON upper(am.partnumber) = upper(b.assembly)
LEFT JOIN partmaster cm ON upper(cm.partnumber) = upper(b.component)
ORDER BY b.assembly, b.itemsequence, b.component, rd.refdesignator;
