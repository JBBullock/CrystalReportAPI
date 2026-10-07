-- ============================================================================
-- PIPByPartNumber.sql
-- Extracted from PIPByPartNumber.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: PIPByPartNumber_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: PIPByPartNumber_TTX
-- Original data source: PIPByPartNumber
-- ----------------------------------------------------------------------------
-- Purchases in process: material issued to open (subcontract) PO lines.
-- INFERRED: open lines only; TotalPIPIssues = quantity issued x its unit
-- cost (the part's current cost when the issue carries none); POPercentCompleted = received / ordered, as 0-100; the value still
-- in process = TotalPIPIssues x the share not yet received.
SELECT
    pi.ponumber AS "PONumber",
    pi.poline AS "POLine",
    pi.partnumber AS "PartNumber",
    pi.quantityreleased AS "PIPIssues_QuantityReleased",
    pi.uomcode AS "UOMCode",
    pi.snlotnumber AS "SNLOTNumber",
    pd.quantityreleased AS "PO_QuantityReleased",
    pd.quantityreceived AS "QuantityReceived",
    pd.closedflag AS "ClosedFlag",
    pm.desctext AS "DescText",
    pm.stockuom AS "StockUOM",
    pm.cost AS "Cost",
    pm.densitycode AS "DensityCode",
    coalesce(nullif(pi.materialcost, 0), pm.cost, 0) AS "InventoryCost",
    (coalesce(pi.quantityreleased, 0) * coalesce(nullif(pi.materialcost, 0), pm.cost, 0)) AS "TotalPIPIssues",
    (CASE WHEN coalesce(pd.quantityordered, 0) > 0 THEN least(100, 100.0 * coalesce(pd.quantityreceived, 0) / pd.quantityordered) ELSE 0 END)::float8 AS "POPercentCompleted",
    ((coalesce(pi.quantityreleased, 0) * coalesce(nullif(pi.materialcost, 0), pm.cost, 0)) * (1 - (CASE WHEN coalesce(pd.quantityordered, 0) > 0 THEN least(100, 100.0 * coalesce(pd.quantityreceived, 0) / pd.quantityordered) ELSE 0 END) / 100.0))::float8 AS "CalculatePIPValue"
FROM pipissues pi
JOIN podetail pd ON upper(pd.ponumber) = upper(pi.ponumber) AND pd.poline = pi.poline
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(pi.partnumber)
WHERE NOT pd.closedflag
ORDER BY pi.partnumber, pi.ponumber, pi.poline, pi.issueid;
