-- ============================================================================
-- OpenPOLineItems.sql
-- Extracted from OpenPOLineItems.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: OpenPOLineItems_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: OpenPOLineItems_TTX
-- Original data source: OpenPOLineItems
-- ----------------------------------------------------------------------------
-- INFERRED: open = neither the PO nor the line is closed.
SELECT
    pd.ponumber AS "PONumber",
    pd.poline AS "POLine",
    pd.partnumber AS "PartNumber",
    pd.purchaseuom AS "PurchaseUOM",
    pd.quantityordered AS "QuantityOrdered",
    pd.quantityreceived AS "QuantityReceived",
    pd.quantityrtv AS "QuantityRTV",
    pd.requireddate AS "RequiredDate",
    pd.revision AS "PODetail_Revision",
    s.suppliername AS "SupplierName",
    pm.densitycode AS "DensityCode",
    pm.desctext AS "DescText",
    pm.revision AS "PartMaster_Revision",
    pm.stockuom AS "StockUOM",
    (coalesce(pd.quantityordered, 0) - coalesce(pd.quantityreceived, 0) + coalesce(pd.quantityrtv, 0)) AS "PONetQty", -- INFERRED: ordered - received + returned
    ((coalesce(pd.quantityordered, 0) - coalesce(pd.quantityreceived, 0) + coalesce(pd.quantityrtv, 0)) * (CASE WHEN pu.uomtype = su.uomtype AND su.conversionfactor <> 0
          THEN pu.conversionfactor / su.conversionfactor ELSE 1 END)) AS "StockQty", -- INFERRED: PONetQty in stock UOM
    pd.closedflag AS "ClosedFlag"
FROM podetail pd
JOIN poheader ph ON upper(ph.ponumber) = upper(pd.ponumber)
LEFT JOIN suppliers s ON upper(s.supplierid) = upper(ph.supplierid)
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(pd.partnumber)
LEFT JOIN uomcodes pu ON upper(pu.uomcode) = upper(pd.purchaseuom)
LEFT JOIN uomcodes su ON upper(su.uomcode) = upper(pm.stockuom)
WHERE NOT pd.closedflag AND NOT ph.closedflag
ORDER BY pd.partnumber, pd.requireddate, pd.ponumber, pd.poline;
