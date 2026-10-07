-- ============================================================================
-- POReceipt.sql
-- Extracted from POReceipt.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: POReceipt_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: POReceipt_TTX
-- Original data source: POReceipt
-- ----------------------------------------------------------------------------
SELECT
    td.transactiongroup AS "TransactionGroup",
    td.transactionid AS "TransactionID",
    td.partnumber AS "PartNumber",
    th.transactiondate AS "TransactionDate",
    th.reference AS "Reference",
    td.linenumber AS "LineNumber",
    td.snlotnumber AS "SNLotNumber",
    td.pocost AS "POCost",
    td.cost AS "Cost",
    td.uomconversion AS "UOMConversion",
    td.quantity AS "Quantity",
    ph.requestedby AS "RequestedBy",
    ph.regioncode AS "RegionCode",
    pm.desctext AS "PartMaster_DescText",
    e.firstname AS "FirstName",
    e.lastname AS "LastName",
    s.suppliername AS "SupplierName",
    tc.desctext AS "TermsCodes_DescText",
    svc.desctext AS "ShipViaCodes_DescText",
    pd.quantityreceived AS "PO_QuantityReceived"
FROM transactiondetail td
JOIN transactionheader th ON th.transactiongroup = td.transactiongroup
LEFT JOIN poheader ph ON upper(ph.ponumber) = upper(th.reference)
LEFT JOIN podetail pd ON upper(pd.ponumber) = upper(th.reference) AND pd.poline = td.linenumber
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(td.partnumber)
LEFT JOIN employees e ON upper(e.employeeid) = upper(ph.requestedby)
LEFT JOIN suppliers s ON upper(s.supplierid) = upper(ph.supplierid)
LEFT JOIN termscodes tc ON upper(tc.termscode) = upper(ph.termscode)
LEFT JOIN shipviacodes svc ON upper(svc.shipviacode) = upper(ph.shipviacode)
WHERE th.transactiontype = 'POR'
ORDER BY th.reference, td.linenumber, th.transactiondate, td.transactionid;
