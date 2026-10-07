-- ============================================================================
-- IndentedBOM.sql
-- Extracted from IndentedBOM.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; column aliases must match
-- the report's field names exactly (case-sensitive).
-- Lines marked INFERRED are best guesses at what the legacy program put in
-- that column - check them against a known-good printout.
-- Tables: IndentedBOM_TTX
-- Report parameters:
--   QuantityDecimals (NumberParameter)
--   CompanyName (StringParameter)
--   CompanyPhone (StringParameter)
--   CompanyEmail (StringParameter)
--   CompanyFAX (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: IndentedBOM_TTX
-- Original data source: IndentedBOM
-- ----------------------------------------------------------------------------
-- Every assembly exploded through all its levels. "Assembly" is the TOP
-- assembly of each explosion, so filter on Assembly to get one indented BOM.
-- ReportSection is the indent level (1 = direct component); the report
-- indents each line by it.
WITH RECURSIVE explosion AS (
    SELECT
        b.assembly AS top_assembly,
        b.component, b.itemsequence, b.quantityper, b.bomuomcode, b.obsoletedate, b.effectivedate,
        1 AS bom_level,
        ARRAY[upper(b.assembly), upper(b.component)] AS path,
        ARRAY[coalesce(b.itemsequence, '') || '|' || upper(b.component)] AS sort_path
    FROM bom b
    UNION ALL
    SELECT
        x.top_assembly,
        b.component, b.itemsequence, b.quantityper, b.bomuomcode, b.obsoletedate, b.effectivedate,
        x.bom_level + 1,
        x.path || upper(b.component),
        x.sort_path || (coalesce(b.itemsequence, '') || '|' || upper(b.component))
    FROM explosion x
    JOIN bom b ON upper(b.assembly) = upper(x.component)
    WHERE upper(b.component) <> ALL (x.path)   -- stops a circular BOM
      AND x.bom_level < 25
)
SELECT
    x.bom_level AS "ReportSection",
    x.top_assembly AS "Assembly",
    am.desctext AS "AssDescText",
    am.revision AS "AssRevision",
    am.stockuom AS "AssStockUOM",
    am.isc AS "AssISC",
    am.orderquantity AS "AssOrderQuantity",
    x.component AS "Component",
    x.itemsequence AS "ItemSequence",
    cm.desctext AS "CompDescText",
    cm.revision AS "CompRevision",
    x.quantityper AS "QuantityPer",
    x.bomuomcode AS "BOMUOMCode",
    cm.stockuom AS "CompStockUOM",
    x.obsoletedate AS "ObsoleteDate",
    x.effectivedate AS "EffectiveDate",
    cm.isc AS "CompISC",
    cm.orderquantity AS "CompOrderQuantity"
FROM explosion x
LEFT JOIN partmaster am ON upper(am.partnumber) = upper(x.top_assembly)
LEFT JOIN partmaster cm ON upper(cm.partnumber) = upper(x.component)
ORDER BY x.top_assembly, x.sort_path;
