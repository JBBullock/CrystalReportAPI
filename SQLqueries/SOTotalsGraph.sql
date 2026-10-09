-- ============================================================================
-- SOTotalsGraph.sql
-- Extracted from SOTotalsGraph.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: SOTotalsGraph_TTX
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: SOTotalsGraph_TTX
-- Original data source: SOTotalsGraph
-- ----------------------------------------------------------------------------
SELECT
    sh.customerid AS "CustomerID",
    sd.quantityordered AS "QuantityOrdered",
    sd.customerprice AS "CustomerPrice",
    -- Stored as text. Cast so the report gets a real date: its chart groups
    -- by date, and with text it drew one bar for every distinct value.
    sd.scheduledshipdate::timestamp AS "ScheduledShipDate",
    sd.closedflag AS "ClosedFlag",
    (sd.quantityordered * sd.customerprice) AS "LineTotalNoTax"
FROM sodetail sd
JOIN soheader sh ON upper(sh.sonumber) = upper(sd.sonumber)
ORDER BY sd.scheduledshipdate::timestamp, sh.customerid;
