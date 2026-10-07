-- ============================================================================
-- SOListByCustomerID.sql
-- Extracted from SOListByCustomerID.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: SOListByCustomerID_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: SOListByCustomerID_TTX
-- Original data source: SOListByCustomerID
-- ----------------------------------------------------------------------------
SELECT
    sd.sonumber AS "SONumber",
    sd.soline AS "SOLine",
    sd.partnumber AS "PartNumber",
    sh.customerid AS "SOHeader_CustomerID",
    sh.orderdate AS "OrderDate",
    sh.requireddate AS "RequiredDate",
    c.customerid AS "Customers_CustomerID",
    sd.quantityordered AS "QuantityOrdered",
    sd.customerprice AS "CustomerPrice",
    sd.actualshipdate AS "ActualShipDate",
    sd.scheduledshipdate AS "ScheduledShipDate",
    sd.quantityshipped AS "QuantityShipped",
    c.customername AS "CustomerName",
    (sd.quantityordered * sd.customerprice) AS "LineAmount"
FROM sodetail sd
JOIN soheader sh ON upper(sh.sonumber) = upper(sd.sonumber)
LEFT JOIN customers c ON upper(c.customerid) = upper(sh.customerid)
ORDER BY sh.customerid, sd.sonumber, sd.soline;
