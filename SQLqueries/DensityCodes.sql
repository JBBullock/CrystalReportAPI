-- ============================================================================
-- DensityCodes.sql
-- Written for DensityCodes.rpt (Codes menu). Checked against the schema dump
-- (SQLFetches/schema_only.sql): it runs and returns exactly the report's
-- columns. Not yet rendered through Crystal.
-- One query per '-- Table: <name>' line; aliases must match the report's
-- field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at legacy behaviour.
-- Tables: DensityCodes_TTX
-- Source tables: densitycodes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: DensityCodes_TTX
-- Original data source: DensityCodes
-- ----------------------------------------------------------------------------
SELECT
    densitycode AS "DensityCode",
    lengthfactor::float8 AS "LengthFactor",
    weightfactor::float8 AS "WeightFactor",
    volumefactor::float8 AS "VolumeFactor",
    areafactor::float8 AS "AreaFactor",
    desctext AS "DescText"
FROM densitycodes
ORDER BY densitycode;
