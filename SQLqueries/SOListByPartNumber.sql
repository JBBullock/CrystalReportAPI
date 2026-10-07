-- ============================================================================
-- SOListByPartNumber.sql
-- Extracted from SOListByPartNumber.rpt by CrystalReportWrapper --extract-sql.
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
-- Original data source: SOListByPartNumber
-- ----------------------------------------------------------------------------
SELECT
    sd.sonumber AS "SONumber",
    sd.soline AS "SOLine",
    sd.partnumber AS "PartNumber",
    sd.quantityordered AS "QuantityOrdered",
    sd.customerprice AS "CustomerPrice",
    sd.scheduledshipdate AS "ScheduledShipDate",
    pm.desctext AS "DescText",
    (sd.quantityordered * sd.customerprice) AS "LineAmount"
FROM sodetail sd
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(sd.partnumber)
ORDER BY sd.partnumber, sd.sonumber, sd.soline;
