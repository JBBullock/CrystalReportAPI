-- ============================================================================
-- InventoryPartCost.sql
-- Extracted from InventoryPartCost.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: InventoryPartCost_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: InventoryPartCost_TTX
-- Original data source: InventoryPartCost
-- ----------------------------------------------------------------------------
SELECT
    pm.partnumber AS "PartNumber",
    pm.desctext AS "DescText",
    pm.materialcost AS "MaterialCost",
    pm.laborcost AS "LaborCost",
    pm.burdencost AS "BurdenCost",
    pm.setupcost AS "SetUpCost",
    pm.subcontcost AS "SubContCost",
    pm.stdmaterialcost AS "STDMaterialCost",
    pm.stdburdencost AS "STDBurdenCost",
    pm.stdlaborcost AS "STDLaborCost",
    pm.stdsetupcost AS "STDSetUpCost",
    pm.stdsubcontcost AS "STDSubContCost",
    pm.ytdusage AS "YTDUsage",
    pm.costrevisiondate AS "CostRevisionDate",
    pm.listprice AS "ListPrice",
    pm.defaultpocost AS "DefaultPOCost",
    pm.orderquantity AS "OrderQuantity",
    (coalesce(pm.materialcost, 0) + coalesce(pm.laborcost, 0) + coalesce(pm.burdencost, 0)
        + coalesce(pm.setupcost, 0) + coalesce(pm.subcontcost, 0)) AS "CurrentCostsTotal",
    (coalesce(pm.stdmaterialcost, 0) + coalesce(pm.stdlaborcost, 0) + coalesce(pm.stdburdencost, 0)
        + coalesce(pm.stdsetupcost, 0) + coalesce(pm.stdsubcontcost, 0)) AS "StandardCostsTotal",
    ((coalesce(pm.materialcost, 0) + coalesce(pm.laborcost, 0) + coalesce(pm.burdencost, 0)
        + coalesce(pm.setupcost, 0) + coalesce(pm.subcontcost, 0))
     - (coalesce(pm.stdmaterialcost, 0) + coalesce(pm.stdlaborcost, 0) + coalesce(pm.stdburdencost, 0)
        + coalesce(pm.stdsetupcost, 0) + coalesce(pm.stdsubcontcost, 0))) AS "CostVariance", -- INFERRED: current minus standard
    pm.dateadded AS "DateAdded"
FROM partmaster pm
ORDER BY pm.partnumber;
