-- ============================================================================
-- Exception.sql
-- Extracted from Exception.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: ExceptionReport_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: ExceptionReport_TTX
-- Original data source: Exception
-- ----------------------------------------------------------------------------
-- INFERRED: the exception report lists the MRP lines that carry an action
-- message (mrpplanning.action is set).
SELECT
    mp.mrpjobid AS "MRPJobID",
    mp.partnumber AS "PartNumber",
    mp.jobnumber AS "JobNumber",
    mp.priority AS "Priority",
    pm.revision AS "Revision",
    pm.desctext AS "DescText",
    pm.stockuom AS "StockUOM",
    e.lastname AS "LastName", -- the part's MRP planner
    pm.departmentcode AS "DepartmentCode",
    pm.stockroomcode AS "StockroomCode",
    mpp.isc AS "ISC",
    mpp.omc AS "OMC",
    mpp.safetystock AS "SafetyStock",
    mpp.leadtime AS "LeadTime",
    mpp.orderquantity AS "OrderQuantity",
    mpp.ordermultiple AS "OrderMultiple",
    mpp.yieldfactor AS "YieldFactor",
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
    mj.onhand AS "OnHand",
    mp.balancesortorder AS "BalanceSortOrder"
FROM mrpplanning mp
LEFT JOIN mrpparts mpp ON mpp.mrpheaderid = mp.mrpheaderid
LEFT JOIN mrpjobs mj ON mj.mrpheaderid = mp.mrpheaderid AND mj.mrpjobid = mp.mrpjobid
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(mp.partnumber)
LEFT JOIN employees e ON upper(e.employeeid) = upper(mpp.planner)
WHERE mp.action IS NOT NULL
ORDER BY mp.partnumber, mp.mrpjobid, mp.balancesortorder;
