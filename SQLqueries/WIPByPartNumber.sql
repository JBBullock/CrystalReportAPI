-- ============================================================================
-- WIPByPartNumber.sql
-- Extracted from WIPByPartNumber.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: WIPByPartNumber_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: WIPByPartNumber_TTX
-- Original data source: WIPByPartNumber
-- ----------------------------------------------------------------------------
-- Work in process: material issued to open work orders.
-- INFERRED: open work orders only; TotalWIPIssues = quantity issued x its
-- unit cost (the part's current cost when the issue carries none); WOPercentCompleted = completed / required, as 0-100; the value
-- still in process = TotalWIPIssues x the share not yet completed.
SELECT
    wi.wonumber AS "WONumber",
    wi.partnumber AS "PartNumber",
    wi.quantityreleased AS "WIPIssues_QuantityReleased",
    wi.uomcode AS "UOMCode",
    wi.snlotnumber AS "SNLOTNumber",
    wh.quantityreleased AS "WOHeader_QuantityReleased",
    wh.quantitycompleted AS "QuantityCompleted",
    wh.closedflag AS "ClosedFlag",
    pm.desctext AS "DescText",
    pm.stockuom AS "StockUOM",
    pm.cost AS "Cost",
    pm.densitycode AS "DensityCode",
    coalesce(nullif(wi.materialcost, 0), pm.cost, 0) AS "InventoryCost",
    (coalesce(wi.quantityreleased, 0) * coalesce(nullif(wi.materialcost, 0), pm.cost, 0)) AS "TotalWIPIssues",
    (CASE WHEN coalesce(wh.quantityrequired, 0) > 0 THEN least(100, 100.0 * coalesce(wh.quantitycompleted, 0) / wh.quantityrequired) ELSE 0 END)::float8 AS "WOPercentCompleted",
    ((coalesce(wi.quantityreleased, 0) * coalesce(nullif(wi.materialcost, 0), pm.cost, 0)) * (1 - (CASE WHEN coalesce(wh.quantityrequired, 0) > 0 THEN least(100, 100.0 * coalesce(wh.quantitycompleted, 0) / wh.quantityrequired) ELSE 0 END) / 100.0))::float8 AS "CalculateWIPValue"
FROM wipissues wi
JOIN woheader wh ON upper(wh.wonumber) = upper(wi.wonumber)
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(wi.partnumber)
WHERE NOT wh.closedflag
ORDER BY wi.partnumber, wi.wonumber, wi.issueid;
