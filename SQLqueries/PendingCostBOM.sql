-- ============================================================================
-- PendingCostBOM.sql
-- Extracted from PendingCostBOM.rpt by CrystalReportWrapper --extract-sql.
-- Source of truth: TableQueryCatalog in CrystalReportWrapper\Program.cs -
-- edit the query there, then re-run --extract-sql to refresh this file.
-- Tables: PendingCostBOM_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
--   CompanyName (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: PendingCostBOM_TTX
-- Original data source: PendingCostBOM
-- ----------------------------------------------------------------------------
SELECT
    b.assembly AS "Assembly",
    b.component AS "Component",
    b.itemsequence AS "ItemSequence",
    b.quantityper AS "QuantityPer",
    b.bomuomcode AS "BOMUOMCode",
    b.obsoletedate::timestamp AS "ObsoleteDate",
    b.effectivedate::timestamp AS "EffectiveDate",
    am.desctext AS "Assembly_DescText",
    am.revision AS "Assembly_Revision",
    am.stockuom AS "Assembly_StockUOM",
    am.materialcost AS "Assembly_MaterialCost",
    am.laborcost AS "Assembly_LaborCost",
    am.burdencost AS "Assembly_BurdenCost",
    am.setupcost AS "Assembly_SetUpCost",
    am.subcontcost AS "Assembly_SubContCost",
    am.isc AS "Assembly_ISC",
    am.orderquantity AS "Assembly_OrderQuantity",
    cm.desctext AS "Component_DescText",
    cm.revision AS "Component_Revision",
    cm.stockuom AS "Component_StockUOM",
    cm.isc AS "Component_ISC",
    cm.materialcost AS "Component_MaterialCost",
    cm.laborcost AS "Component_LaborCost",
    cm.burdencost AS "Component_BurdenCost",
    cm.setupcost AS "Component_SetUpCost",
    cm.subcontcost AS "Component_SubContCost",
    cm.orderquantity AS "Component_OrderQuantity",
    (b.quantityper * cm.cost) AS "Component_RowTotalCost", -- INFERRED
    am.cost AS "Assembly_TotalCost" -- INFERRED: assembly's own rolled-up cost, not a SUM of component rows
FROM bom b
LEFT JOIN partmaster am ON am.partnumber = b.assembly
LEFT JOIN partmaster cm ON cm.partnumber = b.component;
