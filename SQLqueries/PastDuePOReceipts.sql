-- ============================================================================
-- PastDuePOReceipts.sql
-- Extracted from PastDuePOReceipts.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: PastDuePOReceipts_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: PastDuePOReceipts_TTX
-- Original data source: PastDuePOReceipts
-- ----------------------------------------------------------------------------
-- Open PO lines whose required date has passed. (The report itself also
-- hides lines that are not yet due.)
SELECT
    pd.ponumber AS "PONumber",
    pd.poline AS "POLine",
    pd.partnumber AS "PartNumber",
    pd.requireddate AS "RequiredDate",
    pd.quantityordered AS "QuantityOrdered",
    pd.quantityrtv AS "QuantityRTV",
    pd.quantityreceived AS "QuantityReceived",
    pd.lastreceiptdate AS "LastReceiptDate",
    ph.supplierid AS "SupplierID",
    s.suppliername AS "SupplierName",
    ph.orderdate AS "OrderDate",
    coalesce(ph.poplacedwith, '') AS "POPlacedWith",
    sc.name AS "Name",
    coalesce(sc.fax, '') AS "FAX",
    coalesce(sc.faxfmt, '') AS "FAXFMT",
    coalesce(sc.phone, '') AS "Phone",
    coalesce(sc.phonefmt, '') AS "PhoneFMT",
    sc.email AS "Email",
    (coalesce(pd.quantityordered, 0) - coalesce(pd.quantityreceived, 0) + coalesce(pd.quantityrtv, 0)) AS "QuantityOpen",
    (CURRENT_DATE - pd.requireddate::date)::float8 AS "DaysLate"
FROM podetail pd
JOIN poheader ph ON upper(ph.ponumber) = upper(pd.ponumber)
LEFT JOIN suppliers s ON upper(s.supplierid) = upper(ph.supplierid)
LEFT JOIN suppliercontacts sc ON upper(sc.supplierid) = upper(ph.supplierid)
    AND upper(sc.addressid) = upper(ph.supplieraddress)
    AND upper(sc.contactid) = upper(ph.suppliercontact) -- INFERRED: the contact named on the PO
WHERE NOT pd.closedflag AND NOT ph.closedflag
  AND pd.requireddate < CURRENT_DATE
  AND (coalesce(pd.quantityordered, 0) - coalesce(pd.quantityreceived, 0) + coalesce(pd.quantityrtv, 0)) > 0
ORDER BY ph.supplierid, pd.requireddate, pd.ponumber, pd.poline;
