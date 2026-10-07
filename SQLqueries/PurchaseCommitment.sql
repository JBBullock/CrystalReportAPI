-- ============================================================================
-- PurchaseCommitment.sql
-- Extracted from PurchaseCommitment.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: PurchaseCommitment_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
--   CompanyName (StringParameter)
--   CompanyPhone (StringParameter)
--   CompanyEmail (StringParameter)
--   CompanyFAX (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: PurchaseCommitment_TTX
-- Original data source: PurchaseCommitment
-- ----------------------------------------------------------------------------
-- INFERRED: open PO lines only; LineAmount is the value still to be received.
SELECT
    pd.ponumber AS "PONumber",
    pd.poline AS "POLine",
    pd.pounitprice AS "POUnitPrice",
    pd.requireddate AS "RequiredDate",
    ph.orderdate AS "OrderDate",
    s.suppliername AS "SupplierName",
    dc.accountnumber AS "AccountNumber", -- INFERRED: account of the PO line's department
    ((coalesce(pd.quantityordered, 0) - coalesce(pd.quantityreceived, 0) + coalesce(pd.quantityrtv, 0)) * coalesce(pd.pounitprice, 0)) AS "LineAmount",
    pd.closedflag AS "ClosedFlag",
    pd.quantityordered AS "QuantityOrdered",
    pd.quantityrtv AS "QuantityRTV",
    pd.quantityreceived AS "QuantityReceived"
FROM podetail pd
JOIN poheader ph ON upper(ph.ponumber) = upper(pd.ponumber)
LEFT JOIN suppliers s ON upper(s.supplierid) = upper(ph.supplierid)
LEFT JOIN departmentcodes dc ON upper(dc.departmentcode) = upper(coalesce(nullif(pd.departmentcode, ''), ph.departmentcode))
WHERE NOT pd.closedflag AND NOT ph.closedflag
ORDER BY pd.requireddate, pd.ponumber, pd.poline;
