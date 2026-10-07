-- ============================================================================
-- SOBookings.sql
-- Extracted from SOBookings.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: SOBookings_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: SOBookings_TTX
-- Original data source: SOBookings
-- ----------------------------------------------------------------------------
SELECT
    sd.sonumber AS "SONumber",
    sd.soline AS "SOLine",
    sd.partnumber AS "PartNumber",
    sh.customerid AS "CustomerID",
    sh.orderdate AS "OrderDate",
    sh.salesperson AS "SalesPerson",
    sh.requireddate AS "RequiredDate",
    sd.quantityordered AS "QuantityOrdered",
    sd.customerprice AS "CustomerPrice",
    c.customername AS "CustomerName",
    sh.regioncode AS "RegionCode",
    pm.desctext AS "DescText",
    (sd.quantityordered * sd.customerprice) AS "LineAmount",
    sd.closedflag AS "ClosedFlag"
FROM sodetail sd
JOIN soheader sh ON upper(sh.sonumber) = upper(sd.sonumber)
LEFT JOIN customers c ON upper(c.customerid) = upper(sh.customerid)
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(sd.partnumber)
ORDER BY sh.orderdate, sd.sonumber, sd.soline;
