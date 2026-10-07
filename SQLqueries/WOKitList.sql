-- ============================================================================
-- WOKitList.sql
-- Extracted from WOKitList.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: WOKitList_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: WOKitList_TTX
-- Original data source: WOKitList
-- ----------------------------------------------------------------------------
-- Kit issues (KIT transactions) to work orders.
SELECT
    td.transactiongroup AS "TransactionGroup",
    td.partnumber AS "TransactionDetail_PartNumber",
    td.fromdepartment AS "FromDepartment",
    td.fromlocation AS "FromLocation",
    td.snlotnumber AS "SNLotNumber",
    td.quantity AS "Quantity",
    th.auditdate AS "AuditDate",
    wh.wonumber AS "WONumber",
    wh.partnumber AS "WOHeader_PartNumber",
    coalesce(wh.jobnumber, '') AS "JobNumber",
    wh.wopriority AS "WOPriority",
    wh.startdate AS "StartDate",
    wh.requireddate AS "RequiredDate",
    wh.quantityrequired AS "QuantityRequired",
    wh.quantitytostart AS "QuantityToStart",
    wh.quantityreleased AS "QuantityReleased",
    hm.desctext AS "PartMasterH_DescText",
    dm.stockuom AS "StockUOM",
    dm.desctext AS "PartMasterD_DescText"
FROM transactiondetail td
JOIN transactionheader th ON th.transactiongroup = td.transactiongroup
JOIN woheader wh ON upper(wh.wonumber) = upper(th.reference)
LEFT JOIN partmaster hm ON upper(hm.partnumber) = upper(wh.partnumber)
LEFT JOIN partmaster dm ON upper(dm.partnumber) = upper(td.partnumber)
WHERE th.transactiontype = 'KIT'
ORDER BY wh.wonumber, td.partnumber, td.transactionid;
