-- ============================================================================
-- POByPartNumber.sql
-- Extracted from POByPartNumber.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: POByPartNumber_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: POByPartNumber_TTX
-- Original data source: POByPartNumber
-- ----------------------------------------------------------------------------
SELECT
    pd.ponumber AS "PONumber",
    pd.poline AS "POLine",
    pd.partnumber AS "PartNumber",
    pd.requireddate AS "RequiredDate",
    pd.quantityordered AS "QuantityOrdered",
    pd.pounitprice AS "POUnitPrice",
    pm.desctext AS "DescText",
    (pd.quantityordered * pd.pounitprice) AS "LineAmount"
FROM podetail pd
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(pd.partnumber)
ORDER BY pd.partnumber, pd.ponumber, pd.poline;
