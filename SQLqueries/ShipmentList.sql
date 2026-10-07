-- ============================================================================
-- ShipmentList.sql
-- Extracted from ShipmentList.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: ShipmentListReport_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: ShipmentListReport_TTX
-- Original data source: ShipmentList
-- ----------------------------------------------------------------------------
SELECT
    td.transactiongroup AS "TransactionGroup",
    td.transactionid AS "TransactionID",
    td.partnumber AS "PartNumber",
    th.reference AS "Reference",
    td.linenumber AS "LineNumber",
    th.transactiondate AS "TransactionDate",
    td.snlotnumber AS "SNLotNumber",
    td.uomconversion AS "UOMConversion",
    td.quantity AS "Quantity",
    sh.jobnumber AS "JobNumber",
    sh.customerpo AS "CustomerPO",
    sh.attention AS "Attention",
    pm.desctext AS "PartMaster_DescText",
    pm.stockuom AS "StockUOM",
    sd.salesuom AS "SalesUOM",
    c.customername AS "CustomerName",
    svc.desctext AS "ShipViaCodes_DescText",
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
    coalesce(td.transactioninformation, '') AS "TransactionInformation"
FROM transactiondetail td
JOIN transactionheader th ON th.transactiongroup = td.transactiongroup
LEFT JOIN soheader sh ON upper(sh.sonumber) = upper(th.reference)
LEFT JOIN sodetail sd ON upper(sd.sonumber) = upper(th.reference) AND sd.soline = td.linenumber
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(td.partnumber)
LEFT JOIN customers c ON upper(c.customerid) = upper(sh.customerid)
LEFT JOIN shipviacodes svc ON upper(svc.shipviacode) = upper(sh.shipviacode)
LEFT JOIN customeraddress shipaddr ON upper(shipaddr.customerid) = upper(sh.customerid) AND upper(shipaddr.addressid) = upper(sh.shiptoaddress)
LEFT JOIN customeraddress billaddr ON upper(billaddr.customerid) = upper(sh.customerid) AND upper(billaddr.addressid) = upper(sh.billtoaddress)
WHERE th.transactiontype = 'SHP'
ORDER BY th.reference, td.linenumber, th.transactiondate, td.transactionid;
