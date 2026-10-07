-- ============================================================================
-- ReturnToVendorList.sql
-- Extracted from ReturnToVendorList.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: ReturnToVendorList_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: ReturnToVendorList_TTX
-- Original data source: ReturnToVendorList
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
    ph.regioncode AS "RegionCode",
    s.suppliername AS "SupplierName",
    pm.desctext AS "PartMaster.DescText",
    svc.desctext AS "ShipViaCodes.DescText"
FROM transactiondetail td
JOIN transactionheader th ON th.transactiongroup = td.transactiongroup
LEFT JOIN poheader ph ON upper(ph.ponumber) = upper(th.reference)
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(td.partnumber)
LEFT JOIN suppliers s ON upper(s.supplierid) = upper(ph.supplierid)
LEFT JOIN shipviacodes svc ON upper(svc.shipviacode) = upper(ph.shipviacode)
WHERE th.transactiontype = 'RTV'
ORDER BY th.reference, td.linenumber, th.transactiondate, td.transactionid;
