-- ============================================================================
-- SOPickList.sql
-- Extracted from SOPickList.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: SOPickList_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: SOPickList_TTX
-- Original data source: SOPickList
-- ----------------------------------------------------------------------------
-- INFERRED: open sales order lines with a quantity still to ship;
-- RequiredQuantity = ordered - shipped + returned.
SELECT
    sd.sonumber AS "SONumber",
    sd.soline AS "SOLine",
    sh.customerid AS "CustomerID",
    sd.partnumber AS "PartNumber",
    sh.requireddate AS "RequiredDate",
    sd.quantityordered AS "QuantityOrdered",
    sd.quantityshipped AS "QuantityShipped",
    sd.quantityreturned AS "QuantityReturned",
    sd.scheduledshipdate AS "ScheduledShipDate",
    sd.closedflag AS "ClosedFlag",
    c.customername AS "CustomerName",
    pm.revision AS "Revision",
    pm.desctext AS "DescText",
    pm.stockuom AS "StockUOM",
    pm.locationcode AS "LocationCode",
    pm.stockroomcode AS "StockroomCode",
    (coalesce(sd.quantityordered, 0) - coalesce(sd.quantityshipped, 0) + coalesce(sd.quantityreturned, 0)) AS "RequiredQuantity"
FROM sodetail sd
JOIN soheader sh ON upper(sh.sonumber) = upper(sd.sonumber)
LEFT JOIN customers c ON upper(c.customerid) = upper(sh.customerid)
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(sd.partnumber)
WHERE NOT sd.closedflag AND NOT sh.closedflag
  AND (coalesce(sd.quantityordered, 0) - coalesce(sd.quantityshipped, 0) + coalesce(sd.quantityreturned, 0)) > 0
ORDER BY sd.sonumber, sd.soline;
