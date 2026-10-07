-- ============================================================================
-- PartCrossReference.sql
-- Extracted from PartCrossReference.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: PartCrossReference_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: PartCrossReference_TTX
-- Original data source: PartCrossReference
-- ----------------------------------------------------------------------------
SELECT
    px.partnumber AS "PartNumber",
    px.partxreference AS "PartXReference",
    px.supplierid AS "SupplierID",
    px.xrefdesctext AS "XRefDescText",
    px.supplierrating AS "SupplierRating",
    px.supplierleadtime AS "SupplierLeadtime",
    px.approvedsource AS "ApprovedSource",
    px.supplierprice AS "SupplierPrice",
    pm.desctext AS "DescText",
    pm.revision AS "Revision",
    pm.stockuom AS "StockUOM",
    pm.defaultpocost AS "DefaultPOCost",
    s.suppliername AS "SupplierName"
FROM partxreference px
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(px.partnumber)
LEFT JOIN suppliers s ON upper(s.supplierid) = upper(px.supplierid)
ORDER BY px.partnumber, px.partxreference, px.supplierid;
