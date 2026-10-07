-- ============================================================================
-- StockroomOnHand.sql
-- Extracted from StockroomOnHand.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: StockroomOnHand_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: StockroomOnHand_TTX
-- Original data source: StockroomOnHand
-- ----------------------------------------------------------------------------
SELECT
    il.partnumber AS "PartNumber",
    il.departmentcode AS "DepartmentCode",
    il.locationcode AS "LocationCode",
    il.snlotnumber AS "SNLotNumber",
    il.jobnumber AS "JobNumber",
    il.quantity AS "Quantity",
    il.datereceived AS "DateReceived",
    sn.expirationdate AS "ExpirationDate",
    pm.desctext AS "PartMaster_DescText",
    coalesce(nullif(il.materialcost, 0), pm.cost) AS "Cost", -- INFERRED: the lot's own unit cost, else the part's current cost
    dc.desctext AS "DepartmentCodes_DescText",
    dc.accountnumber AS "AccountNumber",
    coalesce(dc.nettableflag, false) AS "NettableFlag",
    (il.quantity * coalesce(nullif(il.materialcost, 0), pm.cost)) AS "ExtendedCost"
FROM inventorylots il
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(il.partnumber)
LEFT JOIN departmentcodes dc ON upper(dc.departmentcode) = upper(il.departmentcode)
LEFT JOIN seriallotnumbers sn ON upper(sn.partnumber) = upper(il.partnumber)
    AND upper(sn.snlotnumber) = upper(il.snlotnumber) AND il.snlotnumber <> ''
ORDER BY il.departmentcode, il.locationcode, il.partnumber, il.snlotnumber;
