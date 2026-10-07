-- ============================================================================
-- StandardCostBOM.sql
-- Extracted from StandardCostBOM.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: StandardCostBOM_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
--   CompanyName (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: StandardCostBOM_TTX
-- Original data source: StandardCostBOM
-- ----------------------------------------------------------------------------
SELECT
    b.assembly AS "Assembly",
    b.component AS "Component",
    b.itemsequence AS "ItemSequence",
    b.quantityper AS "QuantityPer",
    b.bomuomcode AS "BOMUOMCode",
    b.effectivedate AS "EffectiveDate",
    b.obsoletedate AS "ObsoleteDate",
    am.revision AS "Assembly_Revision",
    am.desctext AS "Assembly_DescText",
    am.stockuom AS "Assembly_StockUOM",
    am.stdmaterialcost AS "Assembly_STDMaterialCost",
    am.stdburdencost AS "Assembly_STDBurdenCost",
    am.stdlaborcost AS "Assembly_STDLaborCost",
    am.stdsetupcost AS "Assembly_STDSetUpCost",
    am.stdsubcontcost AS "Assembly_STDSubContCost",
    (coalesce(am.stdmaterialcost, 0) + coalesce(am.stdlaborcost, 0) + coalesce(am.stdburdencost, 0)
        + coalesce(am.stdsetupcost, 0) + coalesce(am.stdsubcontcost, 0)) AS "Assembly_Cost", -- INFERRED: sum of the standard cost elements
    am.isc AS "Assembly_ISC",
    cm.revision AS "Component_Revision",
    cm.desctext AS "Component_DescText",
    cm.stockuom AS "Component_StockUOM",
    cm.stdmaterialcost AS "Component_STDMaterialCost",
    cm.stdburdencost AS "Component_STDBurdenCost",
    cm.stdlaborcost AS "Component_STDLaborCost",
    cm.stdsetupcost AS "Component_STDSetUpCost",
    cm.stdsubcontcost AS "Component_STDSubContCost",
    (coalesce(cm.stdmaterialcost, 0) + coalesce(cm.stdlaborcost, 0) + coalesce(cm.stdburdencost, 0)
        + coalesce(cm.stdsetupcost, 0) + coalesce(cm.stdsubcontcost, 0)) AS "Component_Cost", -- INFERRED: sum of the standard cost elements
    cm.isc AS "Component_ISC",
    cm.densitycode AS "DensityCode",
    am.orderquantity AS "OrderQuantity", -- INFERRED: the assembly's order quantity
    -- INFERRED: factor that converts the BOM quantity (BOM UOM) to the
    -- component's stock UOM; 1 when the two UOMs are of different types.
    (CASE WHEN bu.uomtype = su.uomtype AND su.conversionfactor <> 0
          THEN bu.conversionfactor / su.conversionfactor ELSE 1 END) AS "TestConversion",
    -- INFERRED: quantity per, in stock UOM, times the component's standard cost.
    (b.quantityper * (CASE WHEN bu.uomtype = su.uomtype AND su.conversionfactor <> 0
          THEN bu.conversionfactor / su.conversionfactor ELSE 1 END)
        * (coalesce(cm.stdmaterialcost, 0) + coalesce(cm.stdlaborcost, 0) + coalesce(cm.stdburdencost, 0)
           + coalesce(cm.stdsetupcost, 0) + coalesce(cm.stdsubcontcost, 0))) AS "Component_TotalCost"
FROM bom b
LEFT JOIN partmaster am ON upper(am.partnumber) = upper(b.assembly)
LEFT JOIN partmaster cm ON upper(cm.partnumber) = upper(b.component)
LEFT JOIN uomcodes bu ON upper(bu.uomcode) = upper(b.bomuomcode)
LEFT JOIN uomcodes su ON upper(su.uomcode) = upper(cm.stockuom)
ORDER BY b.assembly, b.itemsequence, b.component;
