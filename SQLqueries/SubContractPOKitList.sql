-- ============================================================================
-- SubContractPOKitList.sql
-- Extracted from SubContractPOKitList.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: SubContractPOKitList_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: SubContractPOKitList_TTX
-- Original data source: SubContractPOKitList
-- ----------------------------------------------------------------------------
-- Kit issues (KIT transactions) sent out against a subcontract PO line.
SELECT
    td.transactiongroup AS "TransactionGroup",
    td.transactionid AS "TransactionID",
    td.partnumber AS "TranD_PartNumber",
    pd.partnumber AS "POD_PartNumber",
    td.linenumber AS "LineNumber",
    th.reference AS "Reference",
    td.fromlocation AS "FromLocation",
    td.fromdepartment AS "FromDepartment",
    td.quantity AS "Quantity",
    th.auditdate AS "AuditDate",
    td.snlotnumber AS "SNLotNumber",
    -- The transaction's own spelling of the PO number and line: the report
    -- hides a row where these differ from Reference / LineNumber, and the
    -- database stores some PO numbers in mixed case.
    th.reference AS "PONumber",
    td.linenumber AS "POLine",
    coalesce(pd.jobnumber, '') AS "JobNumber",
    coalesce(pd.partxreference, '') AS "PartXReference",
    pd.requireddate AS "RequiredDate",
    pd.quantityordered AS "QuantityOrdered",
    pd.quantityreleased AS "QuantityReleased",
    b.assembly AS "Assembly",
    b.component AS "Component",
    b.bomuomcode AS "BOMUOMCode",
    pom.desctext AS "PartMaster_DescText",   -- the PO line's (assembly) part
    tm.desctext AS "PartMaster1_DescText",   -- the issued (component) part
    tm.stockuom AS "StockUOM",
    s.suppliername AS "SupplierName",
    sa.addressline1 AS "AddressLine1",
    sa.addressline2 AS "AddressLine2",
    sa.addressline3 AS "AddressLine3",
    sa.addressline4 AS "AddressLine4",
    sa.city AS "City",
    sa.state AS "State",
    sa.zipcode AS "ZIPCode",
    sa.country AS "Country",
    sa.postal AS "Postal"
FROM transactiondetail td
JOIN transactionheader th ON th.transactiongroup = td.transactiongroup
JOIN podetail pd ON upper(pd.ponumber) = upper(th.reference) AND pd.poline = td.linenumber
JOIN poheader ph ON upper(ph.ponumber) = upper(pd.ponumber)
LEFT JOIN bom b ON upper(b.assembly) = upper(pd.partnumber) AND upper(b.component) = upper(td.partnumber)
LEFT JOIN partmaster pom ON upper(pom.partnumber) = upper(pd.partnumber)
LEFT JOIN partmaster tm ON upper(tm.partnumber) = upper(td.partnumber)
LEFT JOIN suppliers s ON upper(s.supplierid) = upper(ph.supplierid)
LEFT JOIN supplieraddress sa ON upper(sa.supplierid) = upper(ph.supplierid) AND upper(sa.addressid) = upper(ph.supplieraddress)
WHERE th.transactiontype = 'KIT'
ORDER BY pd.ponumber, pd.poline, td.partnumber, td.transactionid;
