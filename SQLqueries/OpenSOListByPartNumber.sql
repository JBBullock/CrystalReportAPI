-- ============================================================================
-- OpenSOListByPartNumber.sql
-- Extracted from OpenSOListByPartNumber.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: SOListByPartNumber_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: SOListByPartNumber_TTX
-- Original data source: OpenSOListByPartNumber
-- ----------------------------------------------------------------------------
-- INFERRED: open = neither the order nor the line is closed. Remaining =
-- ordered - shipped + returned, and LineAmount is the remaining value.
SELECT
    sd.sonumber AS "SONumber",
    sd.soline AS "SOLine",
    sd.partnumber AS "PartNumber",
    sd.quantityordered AS "QuantityOrdered",
    sd.quantityreturned AS "QuantityReturned",
    sd.quantityshipped AS "QuantityShipped",
    (coalesce(sd.quantityordered, 0) - coalesce(sd.quantityshipped, 0) + coalesce(sd.quantityreturned, 0)) AS "Remaining",
    sd.customerprice AS "CustomerPrice",
    sd.scheduledshipdate AS "ScheduledShipDate",
    ((coalesce(sd.quantityordered, 0) - coalesce(sd.quantityshipped, 0) + coalesce(sd.quantityreturned, 0)) * coalesce(sd.customerprice, 0)) AS "LineAmount",
    sd.closedflag AS "ClosedFlag",
    pm.desctext AS "DescText",
    sh.customerid AS "CustomerID"
FROM sodetail sd
JOIN soheader sh ON upper(sh.sonumber) = upper(sd.sonumber)
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(sd.partnumber)
WHERE NOT sd.closedflag AND NOT sh.closedflag
ORDER BY sd.partnumber, sd.scheduledshipdate, sd.sonumber, sd.soline;
