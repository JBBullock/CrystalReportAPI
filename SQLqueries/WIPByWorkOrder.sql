-- ============================================================================
-- WIPByWorkOrder.sql
-- Extracted from WIPByWorkOrder.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: WIPByWorkOrder_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: WIPByWorkOrder_TTX
-- Original data source: WIPByWorkOrder
-- ----------------------------------------------------------------------------
-- Work in process, by work order. Same INFERRED rules as WIPByPartNumber.sql.
SELECT
    wi.wonumber AS "WONumber",
    wh.partnumber AS "WOHeader_PartNumber",
    wh.startdate AS "StartDate",
    wh.requireddate AS "RequiredDate",
    wh.quantitytostart AS "QuantityToStart",
    wh.quantityrequired AS "QuantityRequired",
    wh.quantityreleased AS "WOHeader_QuantityReleased",
    wh.quantitycompleted AS "QuantityCompleted",
    wh.closedflag AS "ClosedFlag",
    wi.partnumber AS "WIPIssues_PartNumber",
    wi.uomcode AS "UOMCode",
    wi.quantityreleased AS "WIPIssues_QuantityReleased",
    hm.desctext AS "PartMasterH_DescText",
    dm.desctext AS "PartMasterD_DescText",
    dm.stockuom AS "StockUOM",
    dm.densitycode AS "DensityCode",
    dm.cost AS "Cost",
    coalesce(nullif(wi.materialcost, 0), dm.cost, 0) AS "UnitCost",
    (coalesce(wi.quantityreleased, 0) * coalesce(nullif(wi.materialcost, 0), dm.cost, 0)) AS "TotalWIPIssues",
    (CASE WHEN coalesce(wh.quantityrequired, 0) > 0 THEN least(100, 100.0 * coalesce(wh.quantitycompleted, 0) / wh.quantityrequired) ELSE 0 END)::float8 AS "WOPercentCompleted",
    ((coalesce(wi.quantityreleased, 0) * coalesce(nullif(wi.materialcost, 0), dm.cost, 0)) * (1 - (CASE WHEN coalesce(wh.quantityrequired, 0) > 0 THEN least(100, 100.0 * coalesce(wh.quantitycompleted, 0) / wh.quantityrequired) ELSE 0 END) / 100.0))::float8 AS "WIPValue"
FROM wipissues wi
JOIN woheader wh ON upper(wh.wonumber) = upper(wi.wonumber)
LEFT JOIN partmaster hm ON upper(hm.partnumber) = upper(wh.partnumber)
LEFT JOIN partmaster dm ON upper(dm.partnumber) = upper(wi.partnumber)
WHERE NOT wh.closedflag
ORDER BY wi.wonumber, wi.partnumber, wi.issueid;
