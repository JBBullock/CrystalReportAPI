-- ============================================================================
-- ManualPartsList.sql
-- Extracted from ManualPartsList.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: ManualPartsList_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: ManualPartsList_TTX
-- Original data source: ManualPartsList
-- ----------------------------------------------------------------------------
-- INFERRED: MRP lines for parts whose order method code (OMC) is 'M' (manual).
SELECT
    mp.partnumber AS "PartNumber",
    mp.jobnumber AS "JobNumber",
    mp.requireddate AS "RequiredDate",
    mp.requiredquantity AS "RequiredQuantity",
    mp.balance AS "Balance",
    mp.reference AS "Reference",
    mp.pegging AS "Pegging",
    mp.referenceline AS "ReferenceLine",
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
    pm.departmentcode AS "DepartmentCode",
    pm.stockroomcode AS "StockroomCode",
    mp.mrpjobid AS "MRPJobID",
    mp.priority AS "Priority",
    e.lastname AS "LastName" -- the part's MRP planner
FROM mrpplanning mp
LEFT JOIN mrpparts mpp ON mpp.mrpheaderid = mp.mrpheaderid
LEFT JOIN mrpjobs mj ON mj.mrpheaderid = mp.mrpheaderid AND mj.mrpjobid = mp.mrpjobid
LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(mp.partnumber)
LEFT JOIN employees e ON upper(e.employeeid) = upper(mpp.planner)
WHERE upper(mpp.omc) = 'M'
ORDER BY mp.partnumber, mp.mrpjobid, mp.balancesortorder;
