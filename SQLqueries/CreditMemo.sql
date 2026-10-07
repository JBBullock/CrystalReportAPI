-- ============================================================================
-- CreditMemo.sql
-- Written for CreditMemo.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; aliases must match the
-- report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: CreditMemo_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CompanyName (StringParameter)
--   VATRegNumber (StringParameter)
--   VATBranchID (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: CreditMemo_TTX
-- Original data source: CreditMemo
-- ----------------------------------------------------------------------------
-- INFERRED: the address is the sales order's bill-to address.
SELECT
    ch.creditmemonumber AS "CreditMemoNumber",
    ch.invoicenumber AS "InvoiceNumber",
    ch.sonumber AS "CreditMemoHeader_SONumber",
    ch.freightamount AS "FreightAmount",
    ch.returndate AS "ReturnDate",
    cd.creditmemoline AS "CreditMemoLine",
    cd.soline AS "SOLine",
    cd.partnumber AS "CreditMemoDetail_PartNumber",
    cd.price AS "Price",
    cd.quantity AS "Quantity",
    cd.salesuom AS "SalesUOM",
    cd.taxableflag AS "TaxableFlag",
    cd.basetaxrate AS "BaseTaxRate",
    cd.basetaxcode AS "BaseTaxCode",
    cd.taxflag2 AS "TaxFlag2",
    cd.taxrate2 AS "TaxRate2",
    cd.taxcode2 AS "TaxCode2",
    cd.taxflag3 AS "TaxFlag3",
    cd.taxrate3 AS "TaxRate3",
    cd.taxcode3 AS "TaxCode3",
    pm.partnumber AS "PartMaster_PartNumber",
    pm.stockuom AS "StockUOM",
    sh.sonumber AS "SOHeader_SONumber",
    sh.orderdate AS "OrderDate",
    sh.currencycode AS "CurrencyCode",
    sh.currencyrate AS "CurrencyRate",
    ch.customerid AS "CustomerID",
    c.customername AS "CustomerName",
    cur.currencysymbol AS "CurrencySymbol",
    cua.addressline1 AS "AddressLine1",
    coalesce(cua.addressline2, '') AS "AddressLine2",
    coalesce(cua.addressline3, '') AS "AddressLine3",
    coalesce(cua.addressline4, '') AS "AddressLine4",
    cua.city AS "City",
    cua.state AS "State",
    cua.zipcode AS "ZIPCode",
    cua.postal AS "Postal",
    cua.country AS "Country",
    (coalesce(cd.quantity, 0) * coalesce(cd.price, 0)) AS "ExtendedAmount",
    (CASE WHEN cd.taxableflag THEN (coalesce(cd.quantity, 0) * coalesce(cd.price, 0)) * coalesce(cd.basetaxrate, 0) / 100 ELSE 0 END) AS "BaseTaxAmount",
    (CASE WHEN cd.taxflag2 THEN ((coalesce(cd.quantity, 0) * coalesce(cd.price, 0)) + (CASE WHEN cd.taxableflag THEN (coalesce(cd.quantity, 0) * coalesce(cd.price, 0)) * coalesce(cd.basetaxrate, 0) / 100 ELSE 0 END)) * coalesce(cd.taxrate2, 0) / 100 ELSE 0 END) AS "Tax2Amount",
    (CASE WHEN cd.taxflag3 THEN ((coalesce(cd.quantity, 0) * coalesce(cd.price, 0)) + (CASE WHEN cd.taxableflag THEN (coalesce(cd.quantity, 0) * coalesce(cd.price, 0)) * coalesce(cd.basetaxrate, 0) / 100 ELSE 0 END)) * coalesce(cd.taxrate3, 0) / 100 ELSE 0 END) AS "Tax3Amount",
    ((coalesce(cd.quantity, 0) * coalesce(cd.price, 0)) + (CASE WHEN cd.taxableflag THEN (coalesce(cd.quantity, 0) * coalesce(cd.price, 0)) * coalesce(cd.basetaxrate, 0) / 100 ELSE 0 END)) AS "LineSubtotal",
    (((coalesce(cd.quantity, 0) * coalesce(cd.price, 0)) + (CASE WHEN cd.taxableflag THEN (coalesce(cd.quantity, 0) * coalesce(cd.price, 0)) * coalesce(cd.basetaxrate, 0) / 100 ELSE 0 END)) + (CASE WHEN cd.taxflag2 THEN ((coalesce(cd.quantity, 0) * coalesce(cd.price, 0)) + (CASE WHEN cd.taxableflag THEN (coalesce(cd.quantity, 0) * coalesce(cd.price, 0)) * coalesce(cd.basetaxrate, 0) / 100 ELSE 0 END)) * coalesce(cd.taxrate2, 0) / 100 ELSE 0 END) + (CASE WHEN cd.taxflag3 THEN ((coalesce(cd.quantity, 0) * coalesce(cd.price, 0)) + (CASE WHEN cd.taxableflag THEN (coalesce(cd.quantity, 0) * coalesce(cd.price, 0)) * coalesce(cd.basetaxrate, 0) / 100 ELSE 0 END)) * coalesce(cd.taxrate3, 0) / 100 ELSE 0 END)) AS "LineTotal"
FROM creditmemoheader ch
JOIN creditmemodetail cd ON upper(cd.creditmemonumber) = upper(ch.creditmemonumber)
LEFT JOIN soheader sh ON upper(sh.sonumber) = upper(ch.sonumber)
LEFT JOIN customers c ON upper(c.customerid) = upper(ch.customerid)
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(cd.partnumber)
LEFT JOIN currencycodes cur ON upper(cur.currencycode) = upper(sh.currencycode)
LEFT JOIN customeraddress cua ON upper(cua.customerid) = upper(ch.customerid) AND upper(cua.addressid) = upper(sh.billtoaddress)
ORDER BY ch.creditmemonumber, cd.creditmemoline;
