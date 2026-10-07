-- ============================================================================
-- StockStatus.sql
-- Extracted from StockStatus.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: StockStatus_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: StockStatus_TTX
-- Original data source: StockStatus
-- ----------------------------------------------------------------------------
SELECT
    pm.partnumber AS "PartNumber",
    pm.stockuom AS "StockUOM",
    pm.isc AS "ISC",
    pm.omc AS "OMC",
    pm.abccode AS "ABCCode",
    pm.departmentcode AS "DepartmentCode",
    pm.stockroomcode AS "StockroomCode",
    pm.leadtime AS "LeadTime",
    pm.suocode AS "SUOCode",
    pm.commoditycode AS "CommodityCode",
    pm.safetystock AS "SafetyStock",
    pm.orderquantity AS "OrderQuantity",
    pm.ordermultiple AS "OrderMultiple",
    pm.yieldfactor AS "YieldFactor",
    pm.listprice AS "ListPrice",
    coalesce(oh.quantity, 0) AS "QuantityOnHand", -- total of the part's inventory lots, all locations
    pm.ytdusage AS "YTDUsage",
    pm.lastxactiondate AS "LastXactionDate",
    pm.dateadded AS "DateAdded",
    pm.cost AS "Cost"
FROM partmaster pm
LEFT JOIN (
    SELECT upper(partnumber) AS partnumber, sum(quantity) AS quantity
    FROM inventorylots
    GROUP BY upper(partnumber)
) oh ON oh.partnumber = upper(pm.partnumber)
ORDER BY pm.partnumber;
