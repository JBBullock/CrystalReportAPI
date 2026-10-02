-- ============================================================================
-- PastDueShipmentsByPartNumber.sql
-- Extracted from PastDueShipmentsByPartNumber.rpt by CrystalReportWrapper --extract-sql.
-- Source of truth: TableQueryCatalog in CrystalReportWrapper\Program.cs -
-- edit the query there, then re-run --extract-sql to refresh this file.
-- Tables: BackOrderListing_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CurrencySymbol (StringParameter)
-- Crystal record selection formula (NOT applied by the SQL below):
--   If ({BackOrderListing_TTX.ActualShipDate} < {BackOrderListing_TTX.ScheduledShipDate}) Then
--       {BackOrderListing_TTX.ScheduledShipDate} = AllDatesToYesterday
--   
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: BackOrderListing_TTX
-- Original data source: PastDueShipmentsByPartNumber
-- NO TableQueryCatalog ENTRY - TODO: write this query, add it to
-- TableQueryCatalog in Program.cs, then re-run --extract-sql.
-- Skeleton below lists every column the report expects; aliases must
-- match exactly (case-sensitive) for Crystal to bind them.
-- ----------------------------------------------------------------------------
/*
SELECT
    NULL AS "SONumber", -- StringField -> text
    NULL AS "SOLine", -- StringField -> text
    NULL AS "PartNumber", -- StringField -> text
    NULL AS "CustomerID", -- StringField -> text
    NULL AS "ScheduledShipDate", -- DateTimeField -> timestamp
    NULL AS "QuantityOrdered", -- NumberField -> numeric
    NULL AS "QuantityShipped", -- NumberField -> numeric
    NULL AS "QuantityReturned", -- NumberField -> numeric
    NULL AS "CustomerPrice", -- NumberField -> numeric
    NULL AS "DescText", -- StringField -> text
    NULL AS "ActualShipDate", -- DateTimeField -> timestamp
    NULL AS "BackOrderQuantity", -- NumberField -> numeric
    NULL AS "BackOrderCost" -- NumberField -> numeric
FROM ???;
*/
