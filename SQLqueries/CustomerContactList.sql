-- ============================================================================
-- CustomerContactList.sql
-- Extracted from CustomerContactList.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: CustomerContactList_TTX
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: CustomerContactList_TTX
-- Original data source: CustomerContactList
-- ----------------------------------------------------------------------------
-- INFERRED: one row per customer address, with that address's contacts
-- (customers with no address or no contact still appear).
SELECT
    c.customerid AS "CustomerID",
    ca.addressid AS "AddressID",
    c.customername AS "CustomerName",
    c.shipholdflag AS "ShipHoldFlag",
    c.activeflag AS "ActiveFlag",
    c.regioncode AS "RegionCode",
    c.pricedisctype AS "PriceDiscType",
    ca.city AS "City",
    ca.state AS "State",
    cc.contactid AS "ContactID",
    cc.name AS "Name",
    cc.phone AS "Phone",
    cc.fax AS "FAX",
    cc.phonefmt AS "PhoneFMT",
    cc.faxfmt AS "FAXFMT",
    cc.email AS "Email",
    pdc.discountpercentage AS "DiscountPercentage",
    pdc.desctext AS "PriceDiscountCodes_DescText",
    cdl.desctext AS "CustomerDiscLevel_DescText"
FROM customers c
LEFT JOIN customeraddress ca ON upper(ca.customerid) = upper(c.customerid)
LEFT JOIN customercontacts cc ON upper(cc.customerid) = upper(ca.customerid) AND upper(cc.addressid) = upper(ca.addressid)
LEFT JOIN pricediscountcodes pdc ON upper(pdc.pricecode) = upper(c.pricecode)
LEFT JOIN customerdisclevel cdl ON upper(cdl.customerdisclevel) = upper(c.customerdisclevel)
ORDER BY c.customerid, ca.addressid, cc.contactid;
