-- ============================================================================
-- CreditMemoTransaction.sql
-- Written for CreditMemoTransaction.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; aliases must match the
-- report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: CreditMemoTransaction_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CompanyName (StringParameter)
--   VATRegNumber (StringParameter)
--   VATBranchID (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: CreditMemoTransaction_TTX
-- Original data source: CreditMemoTransaction
-- ----------------------------------------------------------------------------
-- Customer return (RMA) transactions with their sales order line.
-- INFERRED: Cost is the unit sales price recorded on the transaction (its
-- inventory cost is 0 throughout); the address is the sales order's bill-to
-- address; tax rates are the current rates of the order line's tax codes.
SELECT
    td.transactiongroup AS "TransactionGroup",
    th.reference AS "Reference",
    th.transactiondate AS "TransactionDate",
    td.transactionid AS "TransactionID",
    td.partnumber AS "PartNumber",
    td.linenumber AS "LineNumber",
    td.quantity AS "Quantity",
    td.socost AS "Cost",
    td.uomconversion AS "UOMConversion",
    coalesce(td.snlotnumber, '') AS "SNLotNumber",
    (CASE WHEN sd.sonumber IS NOT NULL THEN th.reference END) AS "SONumber",
    (CASE WHEN sd.sonumber IS NOT NULL THEN td.linenumber END) AS "SOLine",
    coalesce(sd.taxableflag, false) AS "TaxableFlag",
    coalesce(sd.taxflag2, false) AS "TaxFlag2",
    coalesce(sd.taxflag3, false) AS "TaxFlag3",
    sd.taxcode AS "TaxCode",
    sd.taxcode2 AS "TaxCode2",
    sd.taxcode3 AS "TaxCode3",
    sh.currencycode AS "CurrencyCode",
    sh.currencyrate AS "CurrencyRate",
    sh.orderdate AS "OrderDate",
    c.customername AS "CustomerName",
    tx1.taxrate AS "BaseTaxRate",
    tx2.taxrate AS "TaxRate2",
    tx3.taxrate AS "TaxRate3",
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
    (coalesce(td.quantity, 0) * coalesce(td.socost, 0)) AS "ExtendedAmount",
    (CASE WHEN coalesce(sd.taxableflag, false) THEN (coalesce(td.quantity, 0) * coalesce(td.socost, 0)) * coalesce(tx1.taxrate, 0) / 100 ELSE 0 END) AS "BaseTaxAmount",
    (CASE WHEN coalesce(sd.taxflag2, false) THEN ((coalesce(td.quantity, 0) * coalesce(td.socost, 0)) + (CASE WHEN coalesce(sd.taxableflag, false) THEN (coalesce(td.quantity, 0) * coalesce(td.socost, 0)) * coalesce(tx1.taxrate, 0) / 100 ELSE 0 END)) * coalesce(tx2.taxrate, 0) / 100 ELSE 0 END) AS "Tax2Amount",
    (CASE WHEN coalesce(sd.taxflag3, false) THEN ((coalesce(td.quantity, 0) * coalesce(td.socost, 0)) + (CASE WHEN coalesce(sd.taxableflag, false) THEN (coalesce(td.quantity, 0) * coalesce(td.socost, 0)) * coalesce(tx1.taxrate, 0) / 100 ELSE 0 END)) * coalesce(tx3.taxrate, 0) / 100 ELSE 0 END) AS "Tax3Amount"
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
WHERE th.transactiontype = 'RMA'
ORDER BY td.transactiongroup, td.linenumber, td.transactionid;
