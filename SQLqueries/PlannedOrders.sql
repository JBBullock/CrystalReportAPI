-- ============================================================================
-- PlannedOrders.sql
-- Extracted from PlannedOrders.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: PlannedOrders_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: PlannedOrders_TTX
-- Original data source: PlannedOrders
-- ----------------------------------------------------------------------------
-- INFERRED: planned orders are the MRP lines MRP itself created
-- (posttype 8 = planned purchase, 9 = planned work order).
SELECT
    mp.mrpheaderid AS "MRPHeaderID",
    mp.mrpjobid AS "MRPJobID",
    mp.partnumber AS "PartNumber",
    mp.jobnumber AS "JobNumber",
    mp.priority AS "Priority",
    mpp.isc AS "ISC",
    mpp.omc AS "OMC",
    mpp.leadtime AS "LeadTime",
    mpp.safetystock AS "SafetyStock",
    mpp.orderquantity AS "OrderQuantity",
    mpp.ordermultiple AS "OrderMultiple",
    mpp.yieldfactor AS "YieldFactor",
    pm.revision AS "Revision",
    pm.desctext AS "DescText",
    pm.stockuom AS "StockUOM",
    e.lastname AS "LastName", -- the part's MRP planner
    mp.startdate AS "StartDate",
    mp.startquantity AS "StartQuantity",
    mp.requireddate AS "RequiredDate",
    mp.requiredquantity AS "RequiredQuantity",
    mp.balance AS "Balance",
    mp.reference AS "Reference",
    mp.pegging AS "Pegging",
    mp.movedate AS "MoveDate",
    mp.referenceline AS "ReferenceLine",
    mp.action AS "MRP_Action",
    pm.departmentcode AS "DepartmentCode",
    pm.stockroomcode AS "StockroomCode",
    mj.onhand AS "OnHand",
    mp.balancesortorder AS "BalanceSortOrder"
FROM mrpplanning mp
LEFT JOIN mrpparts mpp ON mpp.mrpheaderid = mp.mrpheaderid
LEFT JOIN mrpjobs mj ON mj.mrpheaderid = mp.mrpheaderid AND mj.mrpjobid = mp.mrpjobid
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(mp.partnumber)
LEFT JOIN employees e ON upper(e.employeeid) = upper(mpp.planner)
WHERE mp.posttype IN (8, 9)
ORDER BY mp.partnumber, mp.mrpjobid, mp.balancesortorder;
