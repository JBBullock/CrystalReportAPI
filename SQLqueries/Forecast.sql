-- ============================================================================
-- Forecast.sql
-- Extracted from Forecast.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: ForecastReport_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: ForecastReport_TTX
-- Original data source: Forecast
-- ----------------------------------------------------------------------------
SELECT
    fh.forecastid AS "ForecastID",
    fp.partnumber AS "PartNumber",
    fh.originationdate AS "OriginationDate",
    fh.mrpinputflag AS "MRPInputFlag",
    pm.revision AS "Revision",
    pm.desctext AS "DescText",
    pm.stockuom AS "StockUOM",
    e.lastname AS "LastName",
    fp.timefence AS "TimeFence",
    fq.forecaststartdate AS "ForecastStartDate",
    fq.forecastenddate AS "ForecastEndDate",
    fq.forecastquantity AS "ForecastQuantity",
    fh.notes AS "Notes",
    (CASE WHEN fh.notes IS NULL OR fh.notes = '' THEN -1 ELSE 0 END) AS "Isnull_Notes"
FROM forecastheader fh
JOIN forecastparts fp ON upper(fp.forecastid) = upper(fh.forecastid)
LEFT JOIN forecastquantities fq ON upper(fq.forecastid) = upper(fp.forecastid) AND upper(fq.partnumber) = upper(fp.partnumber)
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(fp.partnumber)
LEFT JOIN employees e ON upper(e.employeeid) = upper(fh.employeeid)
ORDER BY fh.forecastid, fp.partnumber, fq.quantityid;
