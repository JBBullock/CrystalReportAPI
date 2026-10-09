-- ============================================================================
-- POTotalsGraph.sql
-- Extracted from POTotalsGraph.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: POTotalsGraph_TTX
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: POTotalsGraph_TTX
-- Original data source: POTotalsGraph
-- ----------------------------------------------------------------------------
SELECT
    ph.supplierid AS "SupplierID",
    pd.quantityordered AS "QuantityOrdered",
    pd.pounitprice AS "POUnitPrice",
    -- Stored as text. Cast so the report gets a real date: its chart groups
    -- by date, and with text it drew one bar for every distinct value.
    pd.requireddate::timestamp AS "RequiredDate",
    pd.closedflag AS "ClosedFlag",
    (pd.quantityordered * pd.pounitprice) AS "LineTotalNoTax"
FROM podetail pd
JOIN poheader ph ON upper(ph.ponumber) = upper(pd.ponumber)
ORDER BY pd.requireddate::timestamp, ph.supplierid;
