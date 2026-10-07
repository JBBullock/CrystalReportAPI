-- ============================================================================
-- Invoice.sql
-- Written for Invoice.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; aliases must match the
-- report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: InvoiceReport_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CompanyName (StringParameter)
--   VATBranchID (StringParameter)
--   VATRegNumber (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: InvoiceReport_TTX
-- Original data source: Invoice
-- ----------------------------------------------------------------------------
-- INFERRED: the customer address is the sales order's bill-to address, and
-- the line notes are the sales order line's notes (invoice lines have none).
SELECT
    ih.invoicenumber AS "InvoiceNumber",
    ih.trackingnumber AS "TrackingNumber",
    ih.carrier AS "Carrier",
    ih.freightamount AS "FreightAmount",
    ih.shipmentdate AS "ShipmentDate",
    idt.invoiceline AS "InvoiceLine",
    idt.partnumber AS "PartNumber",
    idt.soline AS "SOLine",
    idt.quantity AS "Quantity",
    idt.price AS "Price",
    idt.salesuom AS "SalesUOM",
    idt.taxableflag AS "TaxableFlag",
    idt.basetaxcode AS "BaseTaxCode",
    idt.basetaxrate AS "BaseTaxRate",
    idt.taxflag2 AS "TaxFlag2",
    idt.taxcode2 AS "TaxCode2",
    idt.taxrate2 AS "TaxRate2",
    idt.taxflag3 AS "TaxFlag3",
    idt.taxcode3 AS "TaxCode3",
    idt.taxrate3 AS "TaxRate3",
    (coalesce(idt.quantity, 0) * coalesce(idt.price, 0)) AS "ExtendedAmount",
    (CASE WHEN idt.taxableflag THEN (coalesce(idt.quantity, 0) * coalesce(idt.price, 0)) * coalesce(idt.basetaxrate, 0) / 100 ELSE 0 END) AS "BaseTaxAmount",
    (CASE WHEN idt.taxflag2 THEN ((coalesce(idt.quantity, 0) * coalesce(idt.price, 0)) + (CASE WHEN idt.taxableflag THEN (coalesce(idt.quantity, 0) * coalesce(idt.price, 0)) * coalesce(idt.basetaxrate, 0) / 100 ELSE 0 END)) * coalesce(idt.taxrate2, 0) / 100 ELSE 0 END) AS "Tax2Amount",
    (CASE WHEN idt.taxflag3 THEN ((coalesce(idt.quantity, 0) * coalesce(idt.price, 0)) + (CASE WHEN idt.taxableflag THEN (coalesce(idt.quantity, 0) * coalesce(idt.price, 0)) * coalesce(idt.basetaxrate, 0) / 100 ELSE 0 END)) * coalesce(idt.taxrate3, 0) / 100 ELSE 0 END) AS "Tax3Amount",
    ((coalesce(idt.quantity, 0) * coalesce(idt.price, 0)) + (CASE WHEN idt.taxableflag THEN (coalesce(idt.quantity, 0) * coalesce(idt.price, 0)) * coalesce(idt.basetaxrate, 0) / 100 ELSE 0 END)) AS "LineSubtotal",
    (((coalesce(idt.quantity, 0) * coalesce(idt.price, 0)) + (CASE WHEN idt.taxableflag THEN (coalesce(idt.quantity, 0) * coalesce(idt.price, 0)) * coalesce(idt.basetaxrate, 0) / 100 ELSE 0 END)) + (CASE WHEN idt.taxflag2 THEN ((coalesce(idt.quantity, 0) * coalesce(idt.price, 0)) + (CASE WHEN idt.taxableflag THEN (coalesce(idt.quantity, 0) * coalesce(idt.price, 0)) * coalesce(idt.basetaxrate, 0) / 100 ELSE 0 END)) * coalesce(idt.taxrate2, 0) / 100 ELSE 0 END) + (CASE WHEN idt.taxflag3 THEN ((coalesce(idt.quantity, 0) * coalesce(idt.price, 0)) + (CASE WHEN idt.taxableflag THEN (coalesce(idt.quantity, 0) * coalesce(idt.price, 0)) * coalesce(idt.basetaxrate, 0) / 100 ELSE 0 END)) * coalesce(idt.taxrate3, 0) / 100 ELSE 0 END)) AS "LineTotal",
    ih.sonumber AS "SONumber",
    sh.jobnumber AS "JobNumber",
    sh.customerpo AS "CustomerPO",
    sh.currencycode AS "CurrencyCode",
    sh.currencyrate AS "CurrencyRate",
    sd.partxreference AS "PartXReference",
    cua.addressline1 AS "Customer_AddressLine1",
    coalesce(cua.addressline2, '') AS "Customer_AddressLine2",
    coalesce(cua.addressline3, '') AS "Customer_AddressLine3",
    coalesce(cua.addressline4, '') AS "Customer_AddressLine4",
    cua.city AS "Customer_City",
    cua.state AS "Customer_State",
    cua.zipcode AS "Customer_ZIPCode",
    cua.country AS "Customer_Country",
    cua.postal AS "Customer_Postal",
    coa.addressline1 AS "Company_AddressLine1",
    coalesce(coa.addressline2, '') AS "Company_AddressLine2",
    coalesce(coa.addressline3, '') AS "Company_AddressLine3",
    coalesce(coa.addressline4, '') AS "Company_AddressLine4",
    coa.city AS "Company_City",
    coa.state AS "Company_State",
    coa.zipcode AS "Company_ZipCode",
    coa.country AS "Company_Country",
    coa.postal AS "Company_Postal",
    ih.customerid AS "CustomerID",
    c.customername AS "CustomerName",
    pm.desctext AS "PartMaster_DescText",
    pm.stockuom AS "StockUOM",
    cur.currencysymbol AS "CurrencySymbol",
    fc.desctext AS "FOBCodes_DescText",
    tc.desctext AS "TermsCodes_DescText",
    ih.notes AS "InvoiceHeader_Notes",
    sd.notes AS "InvoiceDetail_Notes",
    ih.billoflading AS "BillOfLading",
    (CASE WHEN ih.notes IS NULL OR ih.notes = '' THEN -1 ELSE 0 END) AS "IsNull_InvoiceHeaderNotes",
    (CASE WHEN sd.notes IS NULL OR sd.notes = '' THEN -1 ELSE 0 END) AS "IsNull_InvoiceDetailNotes"
FROM invoiceheader ih
JOIN invoicedetail idt ON upper(idt.invoicenumber) = upper(ih.invoicenumber)
LEFT JOIN soheader sh ON upper(sh.sonumber) = upper(ih.sonumber)
LEFT JOIN sodetail sd ON upper(sd.sonumber) = upper(idt.sonumber) AND sd.soline = idt.soline
LEFT JOIN customers c ON upper(c.customerid) = upper(ih.customerid)
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(idt.partnumber)
LEFT JOIN currencycodes cur ON upper(cur.currencycode) = upper(sh.currencycode)
LEFT JOIN fobcodes fc ON upper(fc.fobcode) = upper(sh.fobcode)
LEFT JOIN termscodes tc ON upper(tc.termscode) = upper(sh.termscode)
LEFT JOIN customeraddress cua ON upper(cua.customerid) = upper(ih.customerid) AND upper(cua.addressid) = upper(sh.billtoaddress)
LEFT JOIN LATERAL (
    SELECT ca.*
    FROM companyaddress ca
    ORDER BY (upper(ca.addressid) = upper((SELECT p.invoiceremittoaddress FROM preferences p LIMIT 1))) DESC NULLS LAST,
             ca.billtoflag DESC, ca.addressid
    LIMIT 1
) coa ON true
ORDER BY ih.invoicenumber, idt.invoiceline;
