-- ============================================================================
-- PastDueShipmentsByPartNumber.sql
-- Extracted from PastDueShipmentsByPartNumber.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: BackOrderListing_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- Crystal record selection formula (NOT applied by the SQL below):
--   If ({BackOrderListing_TTX.ActualShipDate} < {BackOrderListing_TTX.ScheduledShipDate}) Then
--       {BackOrderListing_TTX.ScheduledShipDate} = AllDatesToYesterday
--   
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: BackOrderListing_TTX
-- Original data source: PastDueShipmentsByPartNumber
-- ----------------------------------------------------------------------------
-- Open sales order lines with a quantity still to ship. The report's own
-- record selection keeps the ones scheduled before today.
-- INFERRED: BackOrderQuantity = ordered - shipped + returned;
-- BackOrderCost = that quantity x the customer price.
SELECT
    sd.sonumber AS "SONumber",
    sd.soline AS "SOLine",
    sd.partnumber AS "PartNumber",
    sh.customerid AS "CustomerID",
    sd.scheduledshipdate AS "ScheduledShipDate",
    sd.quantityordered AS "QuantityOrdered",
    sd.quantityshipped AS "QuantityShipped",
    sd.quantityreturned AS "QuantityReturned",
    sd.customerprice AS "CustomerPrice",
    pm.desctext AS "DescText",
    sd.actualshipdate AS "ActualShipDate",
    (coalesce(sd.quantityordered, 0) - coalesce(sd.quantityshipped, 0) + coalesce(sd.quantityreturned, 0)) AS "BackOrderQuantity",
    ((coalesce(sd.quantityordered, 0) - coalesce(sd.quantityshipped, 0) + coalesce(sd.quantityreturned, 0)) * coalesce(sd.customerprice, 0)) AS "BackOrderCost"
FROM sodetail sd
JOIN soheader sh ON upper(sh.sonumber) = upper(sd.sonumber)
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(sd.partnumber)
WHERE NOT sd.closedflag AND NOT sh.closedflag
  AND (coalesce(sd.quantityordered, 0) - coalesce(sd.quantityshipped, 0) + coalesce(sd.quantityreturned, 0)) > 0
ORDER BY sd.partnumber, sd.scheduledshipdate, sd.sonumber, sd.soline;
