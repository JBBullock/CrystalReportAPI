-- ============================================================================
-- Invoice.sql
-- Written for Invoice.rpt by CrystalReportWrapper --extract-sql.
-- CrystalReportWrapper runs the queries in this file at render time - edit
-- them here. One query per '-- Table: <name>' line; aliases must match the
-- report's field names exactly (case-sensitive).
-- Tables: InvoiceReport_TTX
-- Report parameters:
--   CostDecimals (NumberParameter)
--   QuantityDecimals (NumberParameter)
--   CompanyName (StringParameter)
--   VATBranchID (StringParameter)
--   VATRegNumber (StringParameter)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table: InvoiceReport_TTX
-- Original data source: Invoice
-- NO QUERY YET - TODO: replace the commented-out skeleton below with the
-- real query (remove the /* and */ lines).
-- Skeleton below lists every column the report expects; aliases must
-- match exactly (case-sensitive) for Crystal to bind them.
-- ----------------------------------------------------------------------------
/*
SELECT
    NULL AS "InvoiceNumber", -- StringField -> text
    NULL AS "TrackingNumber", -- StringField -> text
    NULL AS "Carrier", -- StringField -> text
    NULL AS "FreightAmount", -- NumberField -> numeric
    NULL AS "ShipmentDate", -- DateTimeField -> timestamp
    NULL AS "InvoiceLine", -- StringField -> text
    NULL AS "PartNumber", -- StringField -> text
    NULL AS "SOLine", -- StringField -> text
    NULL AS "Quantity", -- NumberField -> numeric
    NULL AS "Price", -- NumberField -> numeric
    NULL AS "SalesUOM", -- StringField -> text
    NULL AS "TaxableFlag", -- BooleanField -> boolean
    NULL AS "BaseTaxCode", -- StringField -> text
    NULL AS "BaseTaxRate", -- NumberField -> numeric
    NULL AS "TaxFlag2", -- BooleanField -> boolean
    NULL AS "TaxCode2", -- StringField -> text
    NULL AS "TaxRate2", -- NumberField -> numeric
    NULL AS "TaxFlag3", -- BooleanField -> boolean
    NULL AS "TaxCode3", -- StringField -> text
    NULL AS "TaxRate3", -- NumberField -> numeric
    NULL AS "ExtendedAmount", -- NumberField -> numeric
    NULL AS "BaseTaxAmount", -- NumberField -> numeric
    NULL AS "Tax2Amount", -- NumberField -> numeric
    NULL AS "Tax3Amount", -- NumberField -> numeric
    NULL AS "LineSubtotal", -- NumberField -> numeric
    NULL AS "LineTotal", -- NumberField -> numeric
    NULL AS "SONumber", -- StringField -> text
    NULL AS "JobNumber", -- StringField -> text
    NULL AS "CustomerPO", -- StringField -> text
    NULL AS "CurrencyCode", -- StringField -> text
    NULL AS "CurrencyRate", -- NumberField -> numeric
    NULL AS "PartXReference", -- StringField -> text
    NULL AS "Customer_AddressLine1", -- StringField -> text
    NULL AS "Customer_AddressLine2", -- StringField -> text
    NULL AS "Customer_AddressLine3", -- StringField -> text
    NULL AS "Customer_AddressLine4", -- StringField -> text
    NULL AS "Customer_City", -- StringField -> text
    NULL AS "Customer_State", -- StringField -> text
    NULL AS "Customer_ZIPCode", -- StringField -> text
    NULL AS "Customer_Country", -- StringField -> text
    NULL AS "Customer_Postal", -- StringField -> text
    NULL AS "Company_AddressLine1", -- StringField -> text
    NULL AS "Company_AddressLine2", -- StringField -> text
    NULL AS "Company_AddressLine3", -- StringField -> text
    NULL AS "Company_AddressLine4", -- StringField -> text
    NULL AS "Company_City", -- StringField -> text
    NULL AS "Company_State", -- StringField -> text
    NULL AS "Company_ZipCode", -- StringField -> text
    NULL AS "Company_Country", -- StringField -> text
    NULL AS "Company_Postal", -- StringField -> text
    NULL AS "CustomerID", -- StringField -> text
    NULL AS "CustomerName", -- StringField -> text
    NULL AS "PartMaster_DescText", -- StringField -> text
    NULL AS "StockUOM", -- StringField -> text
    NULL AS "CurrencySymbol", -- StringField -> text
    NULL AS "FOBCodes_DescText", -- StringField -> text
    NULL AS "TermsCodes_DescText", -- StringField -> text
    NULL AS "InvoiceHeader_Notes", -- PersistentMemoField -> ?
    NULL AS "InvoiceDetail_Notes", -- PersistentMemoField -> ?
    NULL AS "BillOfLading", -- StringField -> text
    NULL AS "IsNull_InvoiceHeaderNotes", -- Int16sField -> integer
    NULL AS "IsNull_InvoiceDetailNotes" -- Int16sField -> integer
FROM ???;
*/
