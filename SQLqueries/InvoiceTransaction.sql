-- ============================================================================
-- InvoiceTransaction.sql
-- Written for InvoiceTransaction.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; aliases must match the
-- report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: InvoiceTransaction_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CompanyName (StringParameter)
--   VATRegNumber (StringParameter)
--   VATBranchID (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: InvoiceTransaction_TTX
-- Original data source: InvoiceTransaction
-- ----------------------------------------------------------------------------
-- Shipment (SHP) transactions priced from their sales order line.
-- INFERRED: the customer address is the sales order's bill-to address; tax
-- rates are the current rates of the order line's tax codes.
SELECT
    td.transactiongroup AS "TransactionGroup",
    td.partnumber AS "PartNumber",
    th.reference AS "Reference",
    td.linenumber AS "LineNumber",
    (CASE WHEN sd.sonumber IS NOT NULL THEN th.reference END) AS "SONumber",
    (CASE WHEN sd.sonumber IS NOT NULL THEN td.linenumber END) AS "SOLine",
    sh.jobnumber AS "JobNumber",
    sh.customerid AS "CustomerID",
    td.quantity AS "Quantity",
    th.transactiondate AS "TransactionDate",
    c.customername AS "CustomerName",
    sh.customerpo AS "CustomerPO",
    sh.currencycode AS "CurrencyCode",
    sh.currencyrate AS "CurrencyRate",
    pm.desctext AS "PartMaster_DescText",
    pm.stockuom AS "StockUOM",
    sd.customerprice AS "CustomerPrice",
    sd.salesuom AS "SalesUOM",
    sd.taxcode AS "TaxCode",
    sd.taxcode2 AS "TaxCode2",
    sd.taxcode3 AS "TaxCode3",
    coalesce(sd.taxableflag, false) AS "TaxableFlag",
    coalesce(sd.taxflag2, false) AS "TaxFlag2",
    coalesce(sd.taxflag3, false) AS "TaxFlag3",
    tx1.taxrate AS "BaseTaxRate",
    tx2.taxrate AS "TaxRate2",
    tx3.taxrate AS "TaxRate3",
    svc.desctext AS "ShipViaCodes_DescText",
    tc.desctext AS "TermsCodes_DescText",
    fc.desctext AS "FOBCodes_DescText",
    cur.currencysymbol AS "CurrencySymbol",
    cua.addressline1 AS "Customer_AddressLine1",
    coalesce(cua.addressline2, '') AS "Customer_AddressLine2",
    coalesce(cua.addressline3, '') AS "Customer_AddressLine3",
    coalesce(cua.addressline4, '') AS "Customer_AddressLine4",
    cua.city AS "Customer_City",
    cua.state AS "Customer_State",
    cua.zipcode AS "Customer_ZIPCode",
    cua.country AS "Customer_Country",
    cua.postal AS "Customer_Postal",
    (coalesce(td.quantity, 0) * coalesce(sd.customerprice, 0)) AS "ExtendedAmount",
    (CASE WHEN coalesce(sd.taxableflag, false) THEN (coalesce(td.quantity, 0) * coalesce(sd.customerprice, 0)) * coalesce(tx1.taxrate, 0) / 100 ELSE 0 END) AS "BaseTaxAmount",
    (CASE WHEN coalesce(sd.taxflag2, false) THEN ((coalesce(td.quantity, 0) * coalesce(sd.customerprice, 0)) + (CASE WHEN coalesce(sd.taxableflag, false) THEN (coalesce(td.quantity, 0) * coalesce(sd.customerprice, 0)) * coalesce(tx1.taxrate, 0) / 100 ELSE 0 END)) * coalesce(tx2.taxrate, 0) / 100 ELSE 0 END) AS "Tax2Amount",
    (CASE WHEN coalesce(sd.taxflag3, false) THEN ((coalesce(td.quantity, 0) * coalesce(sd.customerprice, 0)) + (CASE WHEN coalesce(sd.taxableflag, false) THEN (coalesce(td.quantity, 0) * coalesce(sd.customerprice, 0)) * coalesce(tx1.taxrate, 0) / 100 ELSE 0 END)) * coalesce(tx3.taxrate, 0) / 100 ELSE 0 END) AS "Tax3Amount",
    coa.addressline1 AS "Company_AddressLine1",
    coalesce(coa.addressline2, '') AS "Company_AddressLine2",
    coalesce(coa.addressline3, '') AS "Company_AddressLine3",
    coalesce(coa.addressline4, '') AS "Company_AddressLine4",
    coa.city AS "Company_City",
    coa.state AS "Company_State",
    coa.zipcode AS "Company_ZipCode",
    coa.country AS "Company_Country",
    coa.postal AS "Company_Postal"
FROM transactiondetail td
JOIN transactionheader th ON th.transactiongroup = td.transactiongroup
LEFT JOIN soheader sh ON upper(sh.sonumber) = upper(th.reference)
LEFT JOIN sodetail sd ON upper(sd.sonumber) = upper(th.reference) AND sd.soline = td.linenumber
LEFT JOIN customers c ON upper(c.customerid) = upper(sh.customerid)
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(td.partnumber)
LEFT JOIN taxcodes tx1 ON upper(tx1.taxcode) = upper(sd.taxcode)
LEFT JOIN taxcodes tx2 ON upper(tx2.taxcode) = upper(sd.taxcode2)
LEFT JOIN taxcodes tx3 ON upper(tx3.taxcode) = upper(sd.taxcode3)
LEFT JOIN currencycodes cur ON upper(cur.currencycode) = upper(sh.currencycode)
LEFT JOIN customeraddress cua ON upper(cua.customerid) = upper(sh.customerid) AND upper(cua.addressid) = upper(sh.billtoaddress)
LEFT JOIN shipviacodes svc ON upper(svc.shipviacode) = upper(sh.shipviacode)
LEFT JOIN termscodes tc ON upper(tc.termscode) = upper(sh.termscode)
LEFT JOIN fobcodes fc ON upper(fc.fobcode) = upper(sh.fobcode)
LEFT JOIN LATERAL (
    SELECT ca.*
    FROM companyaddress ca
    ORDER BY (upper(ca.addressid) = upper((SELECT p.invoiceremittoaddress FROM preferences p LIMIT 1))) DESC NULLS LAST,
             ca.billtoflag DESC, ca.addressid
    LIMIT 1
) coa ON true
WHERE th.transactiontype = 'SHP'
ORDER BY td.transactiongroup, td.linenumber, td.transactionid;
