-- ============================================================================
-- POCommitmentGraph.sql
-- Extracted from POCommitmentGraph.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: POCommitmentGraph_TTX
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: POCommitmentGraph_TTX
-- Original data source: POCommitmentGraph
-- ----------------------------------------------------------------------------
-- INFERRED: per required date, the value still to be received on open PO
-- lines (ExistingCost) and the value of MRP's planned purchases at the
-- part's current cost (PlannedCost).
SELECT
    d.commit_date AS "Date",
    sum(d.existing_cost) AS "ExistingCost",
    sum(d.planned_cost) AS "PlannedCost"
FROM (
    SELECT
        date_trunc('day', pd.requireddate) AS commit_date,
        (coalesce(pd.quantityordered, 0) - coalesce(pd.quantityreceived, 0) + coalesce(pd.quantityrtv, 0)) * coalesce(pd.pounitprice, 0) AS existing_cost,
        0::float8 AS planned_cost
    FROM podetail pd
    JOIN poheader ph ON upper(ph.ponumber) = upper(pd.ponumber)
    WHERE NOT pd.closedflag AND NOT ph.closedflag AND pd.requireddate IS NOT NULL
    UNION ALL
    SELECT
        date_trunc('day', mp.requireddate),
        0::float8,
        coalesce(mp.requiredquantity, 0) * coalesce(pm.cost, 0)
    FROM mrpplanning mp
    LEFT JOIN partmaster pm ON upper(pm.partnumber) = upper(mp.partnumber)
    WHERE mp.posttype = 8 AND mp.requireddate IS NOT NULL
) d
GROUP BY d.commit_date
ORDER BY d.commit_date;
