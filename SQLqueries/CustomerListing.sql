-- ============================================================================
-- CustomerListing.sql
-- Extracted from CustomerListing.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: CustomerListing_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: CustomerListing_TTX
-- Original data source: CustomerListing
-- ----------------------------------------------------------------------------
-- INFERRED: one row per customer address, with that address's contacts.
SELECT
    c.customerid AS "CustomerID",
    ca.addressid AS "AddressID",
    cc.contactid AS "ContactID",
    c.customername AS "CustomerName",
    c.regioncode AS "RegionCode",
    c.activeflag AS "ActiveFlag",
    c.vatregnumber AS "VATRegNumber",
    c.vatbranchid AS "VATBranchID",
    c.shipviacode AS "ShipViaCode",
    c.dateadded AS "DateAdded",
    c.creditlimit AS "CreditLimit",
    c.currencycode AS "CurrencyCode",
    c.termscode AS "TermsCode",
    c.pricedisctype AS "PriceDiscType",
    cur.exchangerate AS "ExchangeRate",
    ca.addressline1 AS "AddressLine1",
    ca.addressline2 AS "AddressLine2",
    ca.addressline3 AS "AddressLine3",
    ca.addressline4 AS "AddressLine4",
    ca.city AS "City",
    ca.state AS "State",
    ca.zipcode AS "ZIPCode",
    ca.postal AS "Postal",
    ca.country AS "Country",
    coalesce(ca.shiptoflag, false) AS "ShipToFlag",
    coalesce(ca.billtoflag, false) AS "BillToFlag",
    pdc.discountpercentage AS "DiscountPercentage",
    pdc.desctext AS "PriceDiscountCodes_DescText",
    cdl.desctext AS "CustomerDiscLevel_DescText",
    cc.name AS "Name",
    cc.email AS "Email",
    cc.phone AS "Phone",
    cc.phonefmt AS "PhoneFMT",
    cc.fax AS "FAX",
    cc.faxfmt AS "FAXFMT"
FROM customers c
LEFT JOIN customeraddress ca ON upper(ca.customerid) = upper(c.customerid)
LEFT JOIN customercontacts cc ON upper(cc.customerid) = upper(ca.customerid) AND upper(cc.addressid) = upper(ca.addressid)
LEFT JOIN currencycodes cur ON upper(cur.currencycode) = upper(c.currencycode)
LEFT JOIN pricediscountcodes pdc ON upper(pdc.pricecode) = upper(c.pricecode)
LEFT JOIN customerdisclevel cdl ON upper(cdl.customerdisclevel) = upper(c.customerdisclevel)
ORDER BY c.customerid, ca.addressid, cc.contactid;
