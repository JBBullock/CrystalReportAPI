-- ============================================================================
-- POBySupplier.sql
-- Extracted from POBySupplier.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: POBySupplier_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: POBySupplier_TTX
-- Original data source: POBySupplier
-- ----------------------------------------------------------------------------
SELECT
    ph.supplierid AS "SupplierID",
    pd.ponumber AS "PONumber",
    pd.poline AS "POLine",
    pd.partnumber AS "PartNumber",
    s.suppliername AS "SupplierName",
    s.companyaccount AS "CompanyAccount",
    pd.pounitprice AS "POUnitPrice",
    pd.quantityordered AS "QuantityOrdered",
    pd.requireddate AS "RequiredDate",
    (pd.quantityordered * pd.pounitprice) AS "LineAmount"
FROM podetail pd
JOIN poheader ph ON upper(ph.ponumber) = upper(pd.ponumber)
LEFT JOIN suppliers s ON upper(s.supplierid) = upper(ph.supplierid)
ORDER BY ph.supplierid, pd.ponumber, pd.poline;
