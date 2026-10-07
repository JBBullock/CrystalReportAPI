-- ============================================================================
-- SupplierListing.sql
-- Extracted from SupplierListing.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: SupplierListing_TTX
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: SupplierListing_TTX
-- Original data source: SupplierListing
-- ----------------------------------------------------------------------------
-- INFERRED: one row per supplier address, with that address's contacts.
SELECT
    s.supplierid AS "SupplierID",
    s.suppliername AS "SupplierName",
    sa.addressid AS "AddressID",
    s.activeflag AS "ActiveFlag",
    s.regioncode AS "RegionCode",
    s.dateadded AS "DateAdded",
    s.apholdflag AS "APHoldFlag",
    s.currencycode AS "CurrencyCode",
    s.vatregnumber AS "VATRegNumber",
    s.vatbranchid AS "VATBranchID",
    sa.taxcode AS "TaxCode",
    sc.name AS "Name",
    sc.email AS "Email",
    coalesce(sc.phone, '') AS "Phone",
    coalesce(sc.phonefmt, '') AS "PhoneFMT",
    coalesce(sc.fax, '') AS "FAX",
    coalesce(sc.faxfmt, '') AS "FAXFMT",
    sa.addressline1 AS "AddressLine1",
    sa.addressline2 AS "AddressLine2",
    sa.addressline3 AS "AddressLine3",
    sa.addressline4 AS "AddressLine4",
    sa.city AS "City",
    sa.state AS "State",
    sa.zipcode AS "ZIPCode",
    sa.country AS "Country",
    sa.postal AS "Postal"
FROM suppliers s
LEFT JOIN supplieraddress sa ON upper(sa.supplierid) = upper(s.supplierid)
LEFT JOIN suppliercontacts sc ON upper(sc.supplierid) = upper(sa.supplierid) AND upper(sc.addressid) = upper(sa.addressid)
ORDER BY s.supplierid, sa.addressid, sc.contactid;
