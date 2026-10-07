-- ============================================================================
-- PIPByPurchaseOrder.sql
-- Extracted from PIPByPurchaseOrder.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: PIPByPurchaseOrder_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: PIPByPurchaseOrder_TTX
-- Original data source: PIPByPurchaseOrder
-- ----------------------------------------------------------------------------
-- Purchases in process, by PO line. Same INFERRED rules as PIPByPartNumber.sql.
SELECT
    pi.ponumber AS "PONumber",
    pi.poline AS "POLine",
    pd.partnumber AS "PO_PartNumber",
    pd.startdate AS "StartDate",
    pd.requireddate AS "RequiredDate",
    pd.quantityordered AS "QuantityOrdered",
    pd.quantityrtv AS "QuantityRTV",
    pd.quantityreleased AS "PO_QuantityReleased",
    pd.quantityreceived AS "QuantityReceived",
    pd.closedflag AS "ClosedFlag",
    pi.partnumber AS "PIPIssues_PartNumber",
    pi.uomcode AS "UOMCode",
    pi.quantityreleased AS "PIPIssues_QuantityReleased",
    pom.desctext AS "PartMasterPO_DescText",
    dm.desctext AS "PartMasterD_DescText",
    dm.stockuom AS "StockUOM",
    dm.densitycode AS "DensityCode",
    dm.cost AS "Cost",
    coalesce(nullif(pi.materialcost, 0), dm.cost, 0) AS "UnitCost",
    (coalesce(pi.quantityreleased, 0) * coalesce(nullif(pi.materialcost, 0), dm.cost, 0)) AS "TotalPIPIssues",
    (CASE WHEN coalesce(pd.quantityordered, 0) > 0 THEN least(100, 100.0 * coalesce(pd.quantityreceived, 0) / pd.quantityordered) ELSE 0 END)::float8 AS "POPercentCompleted",
    ((coalesce(pi.quantityreleased, 0) * coalesce(nullif(pi.materialcost, 0), dm.cost, 0)) * (1 - (CASE WHEN coalesce(pd.quantityordered, 0) > 0 THEN least(100, 100.0 * coalesce(pd.quantityreceived, 0) / pd.quantityordered) ELSE 0 END) / 100.0))::float8 AS "PIPValue"
FROM pipissues pi
JOIN podetail pd ON upper(pd.ponumber) = upper(pi.ponumber) AND pd.poline = pi.poline
LEFT JOIN partmaster pom ON upper(pom.partnumber) = upper(pd.partnumber)
LEFT JOIN partmaster dm ON upper(dm.partnumber) = upper(pi.partnumber)
WHERE NOT pd.closedflag
ORDER BY pi.ponumber, pi.poline, pi.partnumber, pi.issueid;
