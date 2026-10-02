-- ============================================================================
-- Quotation.sql
-- Extracted from Quotation.rpt by CrystalReportWrapper --extract-sql.
-- Source of truth: TableQueryCatalog in CrystalReportWrapper\Program.cs -
-- edit the query there, then re-run --extract-sql to refresh this file.
-- Tables: Acknowledgement_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
--   CostDecimals (NumberParameter)
--   CompanyName (StringParameter)
--   CompanyPhone (StringParameter)
--   CompanyFAX (StringParameter)
--   CompanyEmail (StringParameter)
--   VATRegNumber (StringParameter)
--   VATBranchID (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: Acknowledgement_TTX
-- Original data source: Quotation
-- ----------------------------------------------------------------------------
SELECT
    sd.sonumber AS "SONumber",
    sd.soline AS "SOLine",
    sh.requireddate::timestamp AS "RequiredDate",
    sh.customerid AS "CustomerID",
    sh.orderedby AS "OrderedBy",
    emp.lastname AS "LastName",
    sh.orderdate::timestamp AS "OrderDate",
    sh.currencycode AS "CurrencyCode",
    sh.currencyrate AS "CurrencyRate",
    sh.customerpo AS "CustomerPO",
    sd.customerline AS "CustomerLine",
    sd.taxableflag AS "TaxableFlag",
    sd.taxcode AS "TaxCode",
    sd.taxflag2 AS "TaxFlag2",
    sd.taxcode2 AS "TaxCode2",
    sd.taxflag3 AS "TaxFlag3",
    sd.taxcode3 AS "TaxCode3",
    sd.scheduledshipdate::timestamp AS "ScheduledShipDate",
    sd.quantityordered AS "QuantityOrdered",
    sd.salesuom AS "SalesUOM",
    sd.customerprice AS "CustomerPrice",
    sd.partxreference AS "PartXReference",
    sd.partnumber AS "PartNumber",
    pm.revision AS "Revision",
    pm.desctext AS "PartMaster_DescText",
    pm.stockuom AS "StockUOM",
    pm.listprice AS "ListPrice",
    pm.densitycode AS "DensityCode",
    tc.desctext AS "TermsCodes_DescText",
    svc.desctext AS "ShipViaCodes_DescText",
    fc.desctext AS "FOBCodes_DescText",
    sh.pricecode AS "PriceCode",
    c.customerdisclevel AS "CustomerDiscLevel",
    c.customername AS "CustomerName",
    c.pricedisctype AS "PriceDiscType",
    tx1.taxrate AS "BaseTaxRate",
    tx2.taxrate AS "TaxRate2",
    tx3.taxrate AS "TaxRate3",
    shipaddr.addressline1 AS "ShipToAddress_AddressLine1",
    shipaddr.addressline2 AS "ShipToAddress_AddressLine2",
    shipaddr.addressline3 AS "ShipToAddress_AddressLine3",
    shipaddr.addressline4 AS "ShipToAddress_AddressLine4",
    shipaddr.city AS "ShipToAddress_City",
    shipaddr.state AS "ShipToAddress_State",
    shipaddr.zipcode AS "ShipToAddress_ZIPCode",
    shipaddr.country AS "ShipToAddress_Country",
    shipaddr.postal AS "ShipToAddress_Postal",
    billaddr.addressline1 AS "BillToAddress_AddressLine1",
    billaddr.addressline2 AS "BillToAddress_AddressLine2",
    billaddr.addressline3 AS "BillToAddress_AddressLine3",
    billaddr.addressline4 AS "BillToAddress_AddressLine4",
    billaddr.city AS "BillToAddress_City",
    billaddr.state AS "BillToAddress_State",
    billaddr.zipcode AS "BillToAddress_ZIPCode",
    billaddr.country AS "BillToAddress_Country",
    billaddr.postal AS "BillToAddress_Postal",
    cc.currencysymbol AS "CurrencySymbol",
    sd.notes AS "SODetail_Notes",
    NULL AS "CustomerDiscount", -- INFERRED: no numeric discount column on customerdisclevel; may belong on pricediscountcodes via sh.pricecode instead - unconfirmed, not guessed
    cdl.desctext AS "CustomerDiscLevel_DescText",
    (CASE WHEN sd.taxableflag THEN 'Yes' ELSE 'No' END) AS "Taxable", -- INFERRED text rendering of TaxableFlag
    (pm.listprice * COALESCE(sh.currencyrate, 1)) AS "ConvertListPrice", -- INFERRED
    (sd.customerprice * COALESCE(sh.currencyrate, 1)) AS "AfterExchangePrice", -- INFERRED
    (sd.quantityordered * sd.customerprice) AS "LineAmount", -- INFERRED
    (CASE WHEN sd.taxableflag THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx1.taxrate, 0) ELSE 0 END) AS "BaseTaxAmount", -- INFERRED
    (sd.quantityordered * sd.customerprice) AS "LineSubtotal", -- INFERRED: assumed equal to LineAmount, unconfirmed distinction
    (CASE WHEN sd.taxflag2 THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx2.taxrate, 0) ELSE 0 END) AS "Tax2Amount", -- INFERRED
    (CASE WHEN sd.taxflag3 THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx3.taxrate, 0) ELSE 0 END) AS "Tax3Amount", -- INFERRED
    (
        (sd.quantityordered * sd.customerprice)
        + (CASE WHEN sd.taxableflag THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx1.taxrate, 0) ELSE 0 END)
        + (CASE WHEN sd.taxflag2 THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx2.taxrate, 0) ELSE 0 END)
        + (CASE WHEN sd.taxflag3 THEN (sd.quantityordered * sd.customerprice) * COALESCE(tx3.taxrate, 0) ELSE 0 END)
    ) AS "LineTotal", -- INFERRED: LineAmount + all three tax amounts
    sh.notes AS "SOHeader_Notes",
    (CASE WHEN sd.notes IS NULL THEN 1 ELSE 0 END) AS "SODetail_IsnullNotes",
    (CASE WHEN sh.notes IS NULL THEN 1 ELSE 0 END) AS "SOHeader_IsnullNotes"
FROM sodetail sd
JOIN soheader sh ON sh.sonumber = sd.sonumber
LEFT JOIN customers c ON c.customerid = sh.customerid
LEFT JOIN partmaster pm ON pm.partnumber = sd.partnumber
LEFT JOIN termscodes tc ON tc.termscode = sh.termscode
LEFT JOIN shipviacodes svc ON svc.shipviacode = sh.shipviacode
LEFT JOIN fobcodes fc ON fc.fobcode = sh.fobcode
LEFT JOIN customerdisclevel cdl ON cdl.customerdisclevel = c.customerdisclevel
LEFT JOIN taxcodes tx1 ON tx1.taxcode = sd.taxcode
LEFT JOIN taxcodes tx2 ON tx2.taxcode = sd.taxcode2
LEFT JOIN taxcodes tx3 ON tx3.taxcode = sd.taxcode3
LEFT JOIN currencycodes cc ON cc.currencycode = sh.currencycode
LEFT JOIN employees emp ON emp.employeeid = sh.salesperson
LEFT JOIN customeraddress shipaddr ON shipaddr.customerid = sh.customerid AND shipaddr.addressid = sh.shiptoaddress
LEFT JOIN customeraddress billaddr ON billaddr.customerid = sh.customerid AND billaddr.addressid = sh.billtoaddress;
