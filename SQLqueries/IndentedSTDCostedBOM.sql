-- ============================================================================
-- IndentedSTDCostedBOM.sql
-- Extracted from IndentedSTDCostedBOM.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: IndentedStdCostBOM_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
--   CompanyName (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: IndentedStdCostBOM_TTX
-- Original data source: IndentedSTDCostedBOM
-- ----------------------------------------------------------------------------
-- Same explosion as IndentedBOM.sql, with STANDARD costs.
-- INFERRED: the *Cost columns are the part's standard costs, and AssCost /
-- CompCost are the sum of the five standard cost elements.
WITH RECURSIVE explosion AS (
    SELECT
        b.assembly AS top_assembly,
        b.component, b.itemsequence, b.quantityper, b.bomuomcode, b.obsoletedate, b.effectivedate,
        1 AS bom_level,
        ARRAY[upper(b.assembly), upper(b.component)] AS path,
        ARRAY[coalesce(b.itemsequence, '') || '|' || upper(b.component)] AS sort_path
    FROM bom b
    UNION ALL
    SELECT
        x.top_assembly,
        b.component, b.itemsequence, b.quantityper, b.bomuomcode, b.obsoletedate, b.effectivedate,
        x.bom_level + 1,
        x.path || upper(b.component),
        x.sort_path || (coalesce(b.itemsequence, '') || '|' || upper(b.component))
    FROM explosion x
    JOIN bom b ON upper(b.assembly) = upper(x.component)
    WHERE upper(b.component) <> ALL (x.path)   -- stops a circular BOM
      AND x.bom_level < 25
)
SELECT
    x.bom_level AS "ReportSection",
    x.top_assembly AS "Assembly",
    am.desctext AS "AssDescText",
    am.revision AS "AssRevision",
    am.stockuom AS "AssStockUOM",
    am.isc AS "AssISC",
    am.orderquantity AS "AssOrderQuantity",
    am.stdmaterialcost AS "AssMaterialCost",
    am.stdlaborcost AS "AssLaborCost",
    am.stdburdencost AS "AssBurdenCost",
    am.stdsetupcost AS "AssSetupCost",
    am.stdsubcontcost AS "AssSubContCost",
    (coalesce(am.stdmaterialcost, 0) + coalesce(am.stdlaborcost, 0) + coalesce(am.stdburdencost, 0)
        + coalesce(am.stdsetupcost, 0) + coalesce(am.stdsubcontcost, 0)) AS "AssCost",
    x.component AS "Component",
    x.itemsequence AS "ItemSequence",
    cm.desctext AS "CompDescText",
    cm.revision AS "CompRevision",
    x.quantityper AS "QuantityPer",
    x.bomuomcode AS "BOMUOMCode",
    cm.stockuom AS "CompStockUOM",
    x.obsoletedate AS "ObsoleteDate",
    x.effectivedate AS "EffectiveDate",
    cm.isc AS "CompISC",
    cm.orderquantity AS "CompOrderQuantity",
    cm.densitycode AS "DensityCode",
    cm.stdmaterialcost AS "CompMaterialCost",
    cm.stdlaborcost AS "CompLaborCost",
    cm.stdburdencost AS "CompBurdenCost",
    cm.stdsetupcost AS "CompSetupCost",
    cm.stdsubcontcost AS "CompSubContCost",
    (coalesce(cm.stdmaterialcost, 0) + coalesce(cm.stdlaborcost, 0) + coalesce(cm.stdburdencost, 0)
        + coalesce(cm.stdsetupcost, 0) + coalesce(cm.stdsubcontcost, 0)) AS "CompCost",
    -- INFERRED: factor that converts the BOM quantity (BOM UOM) to the
    -- component's stock UOM; 1 when the two UOMs are of different types.
    (CASE WHEN bu.uomtype = su.uomtype AND su.conversionfactor <> 0
          THEN bu.conversionfactor / su.conversionfactor ELSE 1 END) AS "TestConversion"
FROM explosion x
LEFT JOIN partmaster am ON upper(am.partnumber) = upper(x.top_assembly)
LEFT JOIN partmaster cm ON upper(cm.partnumber) = upper(x.component)
LEFT JOIN uomcodes bu ON upper(bu.uomcode) = upper(x.bomuomcode)
LEFT JOIN uomcodes su ON upper(su.uomcode) = upper(cm.stockuom)
ORDER BY x.top_assembly, x.sort_path;
