"""
reports_map.py

The two dictionaries that say which report is which. Edit these by hand;
nothing generates or overwrites this file.

    REPORTS     (menu, report name as shown in ZMRP) -> .rpt file in reports/
    REPORT_SQL  .rpt file -> .sql file in SQLqueries/
    GROUPS      (menu, report name) -> the sub-menu it sits in under Reports
                (the original's "Costed BOM" -> Pending Cost / Standard Cost)
    QUERIES     (menu, report name) -> the original's "Queries" drop-down:
                each query's label, its typed prompts (see PROMPT KINDS) and
                any fixed column values it always applies

A report can be rendered only if it has a REPORTS entry, and its .rpt has a
REPORT_SQL entry. The same .rpt may appear under more than one menu or name.

A report that uses several Crystal tables still has ONE .sql file - put
each table's query under its own "-- Table: <name>" line inside it (see
CrystalReportWrapper/ReportSql.cs).

Check the dictionaries against the files on disk with:
    python reports_map.py
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Optional


# (menu, report name in ZMRP) -> .rpt file name in reports/
REPORTS: dict[tuple[str, str], str] = {
    # ---- Products ----------------------------------------------------
    # Names taken from the original program's menu:
    ("Products", "Bill of Materials"): "BillOfMaterials.rpt",
    ("Products", "BOM with References"): "BOMWithReferences.rpt",
    ("Products", "Costed Bill of Materials (Pending Cost)"): "PendingCostBOM.rpt",
    ("Products", "Costed Bill of Materials (Standard Cost)"): "StandardCostBOM.rpt",
    ("Products", "Engineering Change Notice"): "EngineeringChangeNotice.rpt",
    ("Products", "Indented BOM"): "IndentedBOM.rpt",
    ("Products", "Indented Costed BOM"): "IndentedSTDCostedBOM.rpt",
    ("Products", "Part Master List"): "PartList.rpt",
    ("Products", "Part Cross Reference"): "PartCrossReference.rpt",
    ("Products", "Where Used"): "WhereUsed.rpt",
    # ---------------------- Demand --------------------------------
    ("Demand", "Acknowledgement"): "Acknowledgement.rpt",
    ("Demand", "Past Due Shipments By Part Number"): "PastDueShipmentsByPartNumber.rpt",
    ("Demand", "Past Due Shipments By Required Date"): "PastDueShipmentsByRequiredDate.rpt",

    ("Demand", "Bookings Report"): "SOBookings.rpt",
    ("Demand", "Contact List"): "CustomerContactList.rpt",
    ("Demand", "Customer List"): "CustomerListing.rpt",
    ("Demand", "Forecast"): "Forecast.rpt",
    ("Demand", "Job Summary"): "JobSummary.rpt",
    ("Demand", "Output Report"): "OutputReport.rpt",
    ("Demand", "Pick List"): "SOPickList.rpt",
    ("Demand", "Quotation"): "Quotation.rpt",
    ("Demand", "Sales Order"): "SalesOrder.rpt",

    ("Demand", "SO List by Customer"): "SOListByCustomerID.rpt",
    ("Demand", "Open SO List by Part"): "OpenSOListByPartNumber.rpt",
    ("Demand", "SO Totals Graph"): "SOTotalsGraph.rpt",

    # ---- Supply ------------------------------------------------------
    ("Supply", "Open PO Line Items"): "OpenPOLineItems.rpt",
    ("Supply", "Past Due PO Receipts"): "PastDuePOReceipts.rpt", 
    ("Supply", "PO List by Part Number"): "POByPartNumber.rpt",
    ("Supply", "PO List by Supplier"): "POBySupplier.rpt",
    ("Supply", "PO Totals Graph"): "POTotalsGraph.rpt",

    ("Supply", "PIP By Part Number"): "PIPByPartNumber.rpt",  # menu guessed
    ("Supply", "PIP By Purchase Order"): "PIPByPurchaseOrder.rpt",  # menu guessed
    ("Supply", "Purchase Commitment"): "PurchaseCommitment.rpt",  # menu guessed
    ("Supply", "Purchase Order"): "PurchaseOrder.rpt",
    ("Products", "Part Cross Reference"): "PartCrossReference.rpt",
    
    ("Supply", "Production Schedule"): "ProductionSchedule.rpt",  # menu guessed
    ("Supply", "PO Pick List"): "POPickList.rpt",
    ("Supply", "PO Receipt"): "POReceipt.rpt",

    ("Supply", "Sub Contract PO Kit List"): "SubContractPOKitList.rpt",
    ("Supply", "Supplier List"): "SupplierListing.rpt",
    ("Supply", "Work Order Traveler"): "WorkOrderTraveler.rpt",
    # ---- MRP ---------------------------------------------------------
    ("MRP", "Exception"): "Exception.rpt",  # menu guessed
    ("MRP", "Planned Orders"): "PlannedOrders.rpt",  # menu guessed
    # ---- Inventory ---------------------------------------------------
    ("Inventory", "Intrastat Reporting"): "IntrastatReporting.rpt",
    ("Inventory", "Part Cost List"): "InventoryPartCost.rpt",
    ("Inventory", "Stock Status"): "StockStatus.rpt",
    ("Inventory", "Stockroom On Hand"): "StockroomOnHand.rpt",
    ("Inventory", "Shortage Report"): "ShortageReport.rpt",
    ("Inventory", "Stockroom Locations"): "StockroomLocations.rpt",
    ("Inventory", "Transaction Report"): "TransactionReport.rpt",
    
    ("Inventory", "Inventory Variance"): "InventoryVariance.rpt",  # menu guessed
    ("Inventory", "Misc Unplanned Issues"): "MiscUnplannedIssues.rpt",  # menu guessed
    ("Inventory", "Misc Unplanned Receipts"): "MiscUnplannedReceipts.rpt",  # menu guessed
    ("Inventory", "Part Count List"): "PartCountList.rpt",  # menu guessed
    ("Inventory", "Part Count Tag"): "PartCountTag.rpt",  # menu guessed
      # menu guessed
    
    
    
    # ---- CRP ---------------------------------------------------------
    ("CRP", "Work Center Listing"): "WorkCenterListing.rpt",
    ("CRP", "Work Center Loads"): "WorkCenterLoads.rpt",
    ("CRP", "Labor Router"): "LaborRouter.rpt",  # menu guessed
   
    # ---- Shop --------------------------------------------------------
    ("Shop", "Labor Distr By Employee"): "LaborDistrByEmployee.rpt",
    ("Shop", "Labor Distr By WO"): "LaborDistrByWO.rpt",
    ("Shop", "Labor Utilization"): "LaborUtilization.rpt",  # menu guessed
    ("Shop", "Production Backlog"): "ProductionBacklog.rpt"}  # menu guessed
    # ("Shop", "Production Schedule"): "ProductionSchedule.rpt",  # menu guessed
    # ("Shop", "WIP By Part Number"): "WIPByPartNumber.rpt",
    # ("Shop", "WIP By Work Order"): "WIPByWorkOrder.rpt",
    # ("Shop", "WO Kit List"): "WOKitList.rpt",
    # ("Shop", "WO Pick List"): "WOPickList.rpt"}
    # ---- Codes -------------------------------------------------------
    # "Codes" is a holding menu for lookup lists whose real menu is unknown.
    # ("Codes", "Commodity Codes"): "CommodityCodes.rpt",  # menu guessed
    # ("Codes", "Currency Codes"): "CurrencyCodes.rpt",  # menu guessed
    # ("Codes", "Density Codes"): "DensityCodes.rpt",  # menu guessed
    # ("Codes", "Department Codes"): "DepartmentCodes.rpt",  # menu guessed
    # ("Codes", "ECN Class Codes"): "ECNClassCodes.rpt",  # menu guessed
    # ("Codes", "Employee Information List"): "EmployeeInformationList.rpt",  # menu guessed
    # ("Codes", "Employee List"): "EmployeeList.rpt",  # menu guessed
    # ("Codes", "F.O.B Codes"): "FOBCodes.rpt",  # menu guessed
    # ("Codes", "Holiday List"): "HolidayList.rpt",  # menu guessed
    # ("Codes", "Intrastat Codes"): "IntrastatCodes.rpt",  # menu guessed
    # ("Codes", "Intrastat Rates"): "IntrastatRates.rpt",  # menu guessed
    # ("Codes", "Operation Codes"): "OperationCodes.rpt",  # menu guessed
    # ("Codes", "Price Discount Codes"): "PriceDiscountCodes.rpt",  # menu guessed
    # ("Codes", "Product Discount Codes"): "ProductDiscountCodes.rpt",  # menu guessed
    # ("Codes", "Product Revenue Codes"): "ProductRevenueCodes.rpt",  # menu guessed
    # ("Codes", "Region Codes"): "RegionCodes.rpt",  # menu guessed
    # ("Codes", "Ship Via Codes"): "ShipViaCodes.rpt",  # menu guessed
    # ("Codes", "System Used On Codes"): "SystemUsedOnCodes.rpt",  # menu guessed
    # ("Codes", "Tax Codes"): "TaxCodes.rpt",  # menu guessed
    # ("Codes", "Terms Codes"): "TermsCodes.rpt",  # menu guessed
    # ("Codes", "UOM Codes"): "UOMCodes.rpt",  # menu guessed


# .rpt file name -> .sql file name in SQLqueries/
REPORT_SQL: dict[str, str] = {
    "Acknowledgement.rpt": "Acknowledgement.sql",
    "BillOfMaterials.rpt": "BillOfMaterials.sql",
    "BOMWithReferences.rpt": "BOMWithReferences.sql",
    "CustomerContactList.rpt": "CustomerContactList.sql",
    "CustomerDiscLevel.rpt": "CustomerDiscLevel.sql",
    "CustomerListing.rpt": "CustomerListing.sql",
    "CreditMemo.rpt": "CreditMemo.sql",
    "CreditMemoTransaction.rpt": "CreditMemoTransaction.sql",

    "EngineeringChangeNotice.rpt": "EngineeringChangeNotice.sql",
    "EngineeringPartMaster.rpt": "EngineeringPartMaster.sql",
    "ECNSummary.rpt": "ECNSummary.sql",

    "Exception.rpt": "Exception.sql",
    "Forecast.rpt": "Forecast.sql",
    "IndentedBOM.rpt": "IndentedBOM.sql",
    "IndentedSTDCostedBOM.rpt": "IndentedSTDCostedBOM.sql",
    "IntrastatReporting.rpt": "IntrastatReporting.sql",
    "IntrastatRates.rpt": "IntrastatRates.sql",
    
    "InventoryPartCost.rpt": "InventoryPartCost.sql",
    "Invoice.rpt": "Invoice.sql",
    "InvoiceTransaction.rpt": "InvoiceTransaction.sql",
    "InventoryVariance.rpt": "InventoryVariance.sql",

    "JobSummary.rpt": "JobSummary.sql",
    "LaborDistrByEmployee.rpt": "LaborDistrByEmployee.sql",
    "LaborDistrByWO.rpt": "LaborDistrByWO.sql",
    "LaborRouter.rpt": "LaborRouter.sql",
    "LaborUtilization.rpt": "LaborUtilization.sql",
    "ManualPartsList.rpt": "ManualPartsList.sql",
    "MiscUnplannedIssues.rpt": "MiscUnplannedIssues.sql",
    "MiscUnplannedReceipts.rpt": "MiscUnplannedReceipts.sql",
    "OpenPOLineItems.rpt": "OpenPOLineItems.sql",
    "OpenSOListByPartNumber.rpt": "OpenSOListByPartNumber.sql",
    "OutputReport.rpt": "OutputReport.sql",
    "PartCountList.rpt": "PartCountList.sql",
    "PartCountTag.rpt": "PartCountTag.sql",
    "PartCrossReference.rpt": "PartCrossReference.sql",
    "PartList.rpt": "PartList.sql",
    "PastDuePOReceipts.rpt": "PastDuePOReceipts.sql",
    "PastDueShipmentsByPartNumber.rpt": "PastDueShipmentsByPartNumber.sql",
    "PastDueShipmentsByRequiredDate.rpt": "PastDueShipmentsByRequiredDate.sql",
    "PendingCostBOM.rpt": "PendingCostBOM.sql",
    "PIPByPartNumber.rpt": "PIPByPartNumber.sql",
    "PIPByPurchaseOrder.rpt": "PIPByPurchaseOrder.sql",
    "PlannedOrders.rpt": "PlannedOrders.sql",
    "POByPartNumber.rpt": "POByPartNumber.sql",
    "POBySupplier.rpt": "POBySupplier.sql",
    "POCommitmentGraph.rpt": "POCommitmentGraph.sql",
    "POPickList.rpt": "POPickList.sql",
    "POReceipt.rpt": "POReceipt.sql",
    "POTotalsGraph.rpt": "POTotalsGraph.sql",
    "ProductionBacklog.rpt": "ProductionBacklog.sql",
    "ProductionSchedule.rpt": "ProductionSchedule.sql",
    "PurchaseCommitment.rpt": "PurchaseCommitment.sql",
    "PurchaseOrder.rpt": "PurchaseOrder.sql",
    "Quotation.rpt": "Quotation.sql",
    "ReturnToVendorList.rpt": "ReturnToVendorList.sql",
    "SalesOrder.rpt": "SalesOrder.sql",
    "ShipmentList.rpt": "ShipmentList.sql",
    "ShortageReport.rpt": "ShortageReport.sql",
    "SOBookings.rpt": "SOBookings.sql",
    "SOListByCustomerID.rpt": "SOListByCustomerID.sql",
    "SOListByPartNumber.rpt": "SOListByPartNumber.sql",
    "SOPickList.rpt": "SOPickList.sql",
    "SOTotalsGraph.rpt": "SOTotalsGraph.sql",
    "StandardCostBOM.rpt": "StandardCostBOM.sql",
    "StockroomLocations.rpt": "StockroomLocations.sql",
    "StockroomOnHand.rpt": "StockroomOnHand.sql",
    "StockStatus.rpt": "StockStatus.sql",
    "SubContractPOKitList.rpt": "SubContractPOKitList.sql",
    "SupplierListing.rpt": "SupplierListing.sql",
    "TransactionReport.rpt": "TransactionReport.sql",
    "WhereUsed.rpt": "WhereUsed.sql",
    "WIPByPartNumber.rpt": "WIPByPartNumber.sql",
    "WIPByWorkOrder.rpt": "WIPByWorkOrder.sql",
    "WOKitList.rpt": "WOKitList.sql",
    "WOPickList.rpt": "WOPickList.sql",
    "WorkCenterListing.rpt": "WorkCenterListing.sql",
    "WorkCenterLoads.rpt": "WorkCenterLoads.sql",
    "WorkCenterLoadsGraph.rpt": "WorkCenterLoadsGraph.sql",
    "WorkOrderTraveler.rpt": "WorkOrderTraveler.sql",}

    # ---- Codes menu (SQL written 2026-10-08; the .rpt files still need
    # copying from the original install's Reports folder) ----
    # "CommodityCodes.rpt": "CommodityCodes.sql",
    # "CurrencyCodes.rpt": "CurrencyCodes.sql",
    # "DensityCodes.rpt": "DensityCodes.sql",
    # "DepartmentCodes.rpt": "DepartmentCodes.sql",
    # "ECNClassCodes.rpt": "ECNClassCodes.sql",
    # "EmployeeInformationList.rpt": "EmployeeInformationList.sql",
    # "EmployeeList.rpt": "EmployeeList.sql",
    # "FOBCodes.rpt": "FOBCodes.sql",
    # "HolidayList.rpt": "HolidayList.sql",
    # "IntrastatCodes.rpt": "IntrastatCodes.sql",
    # "OperationCodes.rpt": "OperationCodes.sql",
    # "PriceDiscountCodes.rpt": "PriceDiscountCodes.sql",
    # "ProductDiscountCodes.rpt": "ProductDiscountCodes.sql",
    # "ProductRevenueCodes.rpt": "ProductRevenueCodes.sql",
    # "RegionCodes.rpt": "RegionCodes.sql",
    # "ShipViaCodes.rpt": "ShipViaCodes.sql",
    # "SystemUsedOnCodes.rpt": "SystemUsedOnCodes.sql",
    # "TaxCodes.rpt": "TaxCodes.sql",
    # "TermsCodes.rpt": "TermsCodes.sql",
    # "UOMCodes.rpt": "UOMCodes.sql",



# ============================================================================
# Menu shape: groups and query prompts
# ============================================================================
# The original program's Reports menus come in three shapes:
#   * a plain report        - click it, it prints (no entry below needed);
#   * a group               - a sub-menu of related reports (GROUPS);
#   * a report with queries - a sub-menu of its queries; each query opens
#                             a filter dialog asking for its own prompts
#                             (QUERIES). A report with one query opens that
#                             dialog directly.
# A report can be narrowed only through its queries. A report with no
# QUERIES entry prints every row.

# (menu, report name) -> group label. Reports in one group appear together, in
# the group's sub-menu, where the group's first report is listed in REPORTS.
GROUPS: dict[tuple[str, str], str] = {
    ("Products", "Costed Bill of Materials (Pending Cost)"): "Costed BOM",
    ("Products", "Costed Bill of Materials (Standard Cost)"): "Costed BOM",
    ("Demand", "Past Due Shipments By Part Number"): "Past Due Shipments",
    ("Demand", "Past Due Shipments By Required Date"): "Past Due Shipments",
    ("Shop", "Labor Distr By Employee"): "Labor Distribution",
    ("Shop", "Labor Distr By WO"): "Labor Distribution",
    # Off until these two are listed in REPORTS again:
    # ("Shop", "WIP By Part Number"): "Work In Progress",
    # ("Shop", "WIP By Work Order"): "Work In Progress",
}

# PROMPT KINDS - what a prompt asks for and how its answer becomes filter:
#   TEXT        one text box. * and ? wildcards allowed (the asterisk the
#               original shows beside a text prompt). Blank = no condition.
#   NUMBER      one text box that must hold a number. Blank = no condition.
#   DATE_RANGE  From and To boxes, dates as YYYY-MM-DD; either may be blank.
#               From -> column >= From, To -> column <= To (whole day).
#   CHECKBOX    ticked -> column = true. Unticked -> no condition, or
#               column = <"unchecked"> when the prompt sets that key.
#               "checked" changes what ticked means; "checked": None = no
#               condition. So "Include Closed" on closedflag is
#               "checked": None, "unchecked": False.
TEXT = "text"
NUMBER = "number"
DATE_RANGE = "date_range"
CHECKBOX = "checkbox"
PROMPT_KINDS = (TEXT, NUMBER, DATE_RANGE, CHECKBOX)

# (menu, report name) -> [query, ...]; a query is
#   {"label": "<as in the drop-down>",
#    "fixed": {"<filter column>": <value>, ...},        (optional)
#    "prompts": [{"label": "<as on screen>", "column": "<filter column>",
#                 "kind": TEXT | NUMBER | DATE_RANGE | CHECKBOX}, ...]}
# "column" is a column of the report's SQL output (matched without regard
# to case, like every filter column). Order = drop-down order; the first
# query is the default.
# "fixed" values always apply when that query is chosen. The user is not
# asked for them and cannot change them: Transaction Report's "Kitting" is
# every transaction of type KIT. A fixed column cannot also be a prompt.
# "prompts" may be [] - the query then prints without asking anything.
# A text or number prompt with "required": True must be answered: blank, or
# nothing but *, is refused. Used where a whole table is too much to print
# (every BOM report asks for its assembly).
#
# ZMRP picks the filter dialog from the kinds of the prompts, in order
# (ReportFilterDialogs.FILTER_DIALOG_BY_PROMPTS); a number counts as text:
#   [TEXT]                        one text box
#   [TEXT, TEXT]                  two text boxes
#   [DATE_RANGE]                  Start Date, End Date
#   [TEXT, CHECKBOX, DATE_RANGE]  text box, checkbox, Start Date, End Date

# Transaction Report: transaction type codes (transactionheader.transactiontype).
#   KIT kit            DKT dekit              CMP work order completion
#   UPR unplanned receipt                     UPL unplanned issue
#   REL relocation     PIP physical inventory +   PIN physical inventory -
#   SHP sales order shipment                  RMA sales order return
#   POR purchase order receipt                RTV return to vendor
_TRANSACTION_DATE = {"label": "Transaction Date", "column": "transactiondate", "kind": DATE_RANGE}

_INCLUDE_CLOSED = {"label": "Include Closed", "column": "closedflag", "kind": CHECKBOX,
                   "checked": None, "unchecked": False}

_ASSEMBLY = [
    {"label": "Query By Assembly",
     "prompts": [{"label": "Assembly", "column": "assembly", "kind": TEXT, "required": True}]},
]

QUERIES: dict[tuple[str, str], list[dict]] = {
    # Every BOM report must be narrowed to an assembly (wildcards allowed).
    ("Products", "Bill of Materials"): _ASSEMBLY,
    ("Products", "BOM with References"): _ASSEMBLY,
    ("Products", "Costed Bill of Materials (Pending Cost)"): _ASSEMBLY,
    ("Products", "Costed Bill of Materials (Standard Cost)"): _ASSEMBLY,
    ("Products", "Indented BOM"): _ASSEMBLY,
    ("Products", "Indented Costed BOM"): _ASSEMBLY,
    # Where Used reads the BOM the other way round: which assemblies use a part.
    ("Products", "Where Used"): [
        {"label": "Query By Component",
         "prompts": [{"label": "Component", "column": "component", "kind": TEXT, "required": True}]},
    ],
    ("Products", "Part Cross Reference"): [
        {"label": "Query By Part Number",
         "prompts": [{"label": "Part Number", "column": "partnumber", "kind": TEXT}]},
        {"label": "Query By Cross Reference",
         "prompts": [{"label": "Cross Reference", "column": "partxreference", "kind": TEXT}]},
    ],
    ("Demand", "Acknowledgement"): [
        {"label": "Query By Customer ID",
         "prompts": [{"label": "Customer ID", "column": "customerid", "kind": TEXT}]},
        {"label": "Query By Order Date",
         "prompts": [{"label": "Order Date", "column": "orderdate", "kind": DATE_RANGE}]},
         {"label": "Query By SO Number",
         "prompts": [{"label": "SO Number", "column": "sonumber", "kind": TEXT}]}
    ],
    # The two Past Due Shipments reports are one group (GROUPS), each with
    # its own .rpt and one query.
    ("Demand", "Past Due Shipments By Part Number"): [
        {"label": "Query By Part Number",
         "prompts": [{"label": "Part Number", "column": "partnumber", "kind": TEXT}]},
    ],
    ("Demand", "Past Due Shipments By Required Date"): [
        {"label": "Query By Scheduled Ship Date",
         "prompts": [{"label": "Scheduled Ship Date", "column": "scheduledshipdate", "kind": DATE_RANGE}]},
    ],
    ("Demand", "Pick List"): [
        {"label": "Query By Customer ID",
         "prompts": [{"label": "Customer ID", "column": "customerid", "kind": TEXT}]},
        {"label": "Query By Ship Date",
         "prompts": [{"label": "Ship Date", "column": "scheduledshipdate", "kind": DATE_RANGE}]},
         {"label": "Query By SO Number",
         "prompts": [{"label": "SO Number", "column": "sonumber", "kind": TEXT}]}
    ],
    ("Demand", "Quotation"): [
        {"label": "Query By Customer ID",
         "prompts": [{"label": "Customer ID", "column": "customerid", "kind": TEXT}]},
         {"label": "Query By Quote Number",
         "prompts": [{"label": "Quote Number", "column": "quotenumber", "kind": TEXT}]}
    ],
    ("Demand", "Sales Order"): [
        {"label": "Query By Customer ID",
         "prompts": [{"label": "Customer ID", "column": "customerid", "kind": TEXT}]},
        {"label": "Query By Order Date",
         "prompts": [{"label": "Order Date", "column": "orderdate", "kind": DATE_RANGE}]},
         {"label": "Query By SO Number",
         "prompts": [{"label": "SO Number", "column": "sonumber", "kind": TEXT}]}
    ],
    ("Demand", "SO Totals Graph"): [
        # The graph draws one bar per day, so it is only readable over a date
        # range: Start/End Date are on the date the chart plots.
        {"label": "Query By Customer ID",
         "prompts": [{"label": "Customer ID", "column": "customerid", "kind": TEXT},
                     _INCLUDE_CLOSED,
                     {"label": "Scheduled Ship Date", "column": "scheduledshipdate", "kind": DATE_RANGE}]},
         {"label": "Query By Order Date",
         "prompts": [{"label": "Order Date", "column": "orderdate", "kind": DATE_RANGE}]}
    ],
    ("Supply", "PO Totals Graph"): [
        {"label": "Query By Supplier ID",
         "prompts": [{"label": "Supplier ID", "column": "supplierid", "kind": TEXT},
                     _INCLUDE_CLOSED,
                     {"label": "Required Date", "column": "requireddate", "kind": DATE_RANGE}]}
    ],
    ("Inventory", "Transaction Report"): [
        {"label": "Completions", "fixed": {"transactiontype": "CMP"}, "prompts": [_TRANSACTION_DATE]},
        {"label": "Kitting", "fixed": {"transactiontype": "KIT"}, "prompts": [_TRANSACTION_DATE]},
        {"label": "Receipts", "fixed": {"transactiontype": "POR"}, "prompts": [_TRANSACTION_DATE]},
        {"label": "Shipments", "fixed": {"transactiontype": "SHP"}, "prompts": [_TRANSACTION_DATE]},
        {"label": "Transaction Date", "prompts": [_TRANSACTION_DATE]},
    ],
    ("Shop", "Labor Utilization"): [
        {"label": "Query by Employee ID",
         "prompts": [{"label": "Employee ID", "column": "employeeid", "kind": TEXT}]},
        {"label": "Query by WO Number",
         "prompts": [{"label": "WO Number", "column": "wonumber", "kind": TEXT}]},
    ],
}


class QueryInputError(ValueError):
    """A query's answers can't become a filter; the message says why, in
    words fit to show the user."""


_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def queries_for(menu: str, name: str) -> list[dict]:
    """The report's queries ([] for a report with none)."""
    return QUERIES.get((menu, name), [])


def query_filter(menu: str, name: str, query_label: str, values: dict) -> dict:
    """The filter object for one query's answers.

    values: {prompt column: answer}. TEXT/NUMBER answers are strings (a
    number may also be sent as a number), CHECKBOX answers true/false, and
    a DATE_RANGE answer is {"from": "YYYY-MM-DD", "to": "YYYY-MM-DD"}
    (either key may be missing or blank). Unknown columns are an error.
    The query's "fixed" values are added to the result as they are.
    """
    queries = queries_for(menu, name)
    query = next((q for q in queries if q["label"] == query_label), None)
    if query is None:
        known = ", ".join(q["label"] for q in queries) or "none"
        raise QueryInputError(f"'{name}' has no query '{query_label}' (its queries: {known})")

    values = dict(values or {})
    columns = {prompt["column"] for prompt in query["prompts"]}
    unknown = [column for column in values if column not in columns]
    if unknown:
        raise QueryInputError(f"Query '{query_label}' has no prompt for: {', '.join(unknown)}")

    result: dict = {}
    for prompt in query["prompts"]:
        column, kind, label = prompt["column"], prompt["kind"], prompt["label"]
        answer = values.get(column)
        if kind in (TEXT, NUMBER) and prompt.get("required"):
            if not str("" if answer is None else answer).strip().strip("*"):
                raise QueryInputError(f"{label} is required.")
        if kind == TEXT:
            text = "" if answer is None else str(answer).strip()
            if text and text.strip("*"):
                result[column] = text
        elif kind == NUMBER:
            text = "" if answer is None else str(answer).strip()
            if text:
                try:
                    number = float(text)
                except ValueError:
                    raise QueryInputError(f"{label} must be a number, not '{text}'.") from None
                result[column] = int(number) if number.is_integer() else number
        elif kind == DATE_RANGE:
            answer = answer or {}
            if not isinstance(answer, dict):
                raise QueryInputError(f"{label} needs From/To dates.")
            comparisons = {}
            for key, operator in (("from", ">="), ("to", "<=")):
                text = str(answer.get(key) or "").strip()
                if not text:
                    continue
                if not _DATE.match(text):
                    raise QueryInputError(f"{label} {key.title()} must be a date as YYYY-MM-DD, not '{text}'.")
                comparisons[operator] = text
            if comparisons.get(">=", "") > comparisons.get("<=", "9999"):
                raise QueryInputError(f"{label}: From is after To.")
            if comparisons:
                result[column] = comparisons
        elif kind == CHECKBOX:
            ticked = answer is True or str(answer).lower() in ("true", "1", "yes")
            value = prompt.get("checked", True) if ticked else prompt.get("unchecked")
            if value is not None:
                result[column] = value
        else:
            raise QueryInputError(f"Prompt '{label}' has unknown kind '{kind}'.")
    result.update(query.get("fixed", {}))
    return result


def menu_tree() -> dict[str, list]:
    """{menu: [entry, ...]} with groups nested and queries attached, in the
    order REPORTS lists them. An entry is either
        {"report": name, "queries": [...]}                  a report
        {"group": label, "reports": [{"report": ...}, ...]} a group
    What /menus serves and what a client builds its Reports menus from."""
    tree: dict[str, list] = {}
    groups: dict[tuple[str, str], dict] = {}
    for menu, name in REPORTS:
        entries = tree.setdefault(menu, [])
        report = {"report": name, "queries": queries_for(menu, name)}
        label = GROUPS.get((menu, name))
        if label is None:
            entries.append(report)
            continue
        group = groups.get((menu, label))
        if group is None:
            group = groups[(menu, label)] = {"group": label, "reports": []}
            entries.append(group)
        group["reports"].append(report)
    return tree


def menus() -> dict[str, list[str]]:
    """{menu: [report names]} in the order written above."""
    result: dict[str, list[str]] = {}
    for menu, name in REPORTS:
        result.setdefault(menu, []).append(name)
    return result


def rpt_for(menu: str, name: str) -> str:
    """The .rpt file for one (menu, report name). KeyError if there is none."""
    try:
        return REPORTS[(menu, name)]
    except KeyError:
        raise KeyError(f"No report named '{name}' under menu '{menu}'") from None


def sql_for(rpt_file: str) -> Optional[str]:
    """The .sql file name for one .rpt, or None if it has no entry.
    Matched without regard to case, like Windows file names."""
    wanted = rpt_file.lower()
    for rpt, sql in REPORT_SQL.items():
        if rpt.lower() == wanted:
            return sql
    return None


def validate(reports_dir: Path, sql_dir: Path) -> list[str]:
    """Problems found comparing the dictionaries to the files on disk."""
    problems: list[str] = []
    for (menu, name), rpt in REPORTS.items():
        if not (reports_dir / rpt).is_file():
            problems.append(f"REPORTS[({menu!r}, {name!r})]: {rpt} is not in {reports_dir}")
        elif sql_for(rpt) is None:
            problems.append(f"REPORTS[({menu!r}, {name!r})]: {rpt} has no REPORT_SQL entry")
    for rpt, sql in REPORT_SQL.items():
        if not (reports_dir / rpt).is_file():
            problems.append(f"REPORT_SQL[{rpt!r}]: {rpt} is not in {reports_dir}")
        if not (sql_dir / sql).is_file():
            problems.append(f"REPORT_SQL[{rpt!r}]: {sql} is not in {sql_dir}")
    for key in GROUPS:
        if key not in REPORTS:
            problems.append(f"GROUPS[{key!r}]: no such report in REPORTS")
    for key, queries in QUERIES.items():
        if key not in REPORTS:
            problems.append(f"QUERIES[{key!r}]: no such report in REPORTS")
        for query in queries:
            for prompt in query.get("prompts", []):
                if prompt.get("kind") not in PROMPT_KINDS:
                    problems.append(f"QUERIES[{key!r}] '{query.get('label')}': prompt "
                                    f"'{prompt.get('label')}' has unknown kind {prompt.get('kind')!r}")
                if prompt.get("column") in query.get("fixed", {}):
                    problems.append(f"QUERIES[{key!r}] '{query.get('label')}': "
                                    f"'{prompt.get('column')}' is both fixed and a prompt")
    return problems


if __name__ == "__main__":
    here = Path(__file__).resolve().parent
    # pythonScripts/ on the host; flattened into the app root in the image.
    root = here.parent if (here.parent / "reports").is_dir() else here
    found = validate(root / "reports", root / "SQLqueries")
    print(f"{len(REPORTS)} menu entries, {len(REPORT_SQL)} SQL mappings")
    for line in found:
        print(f"  {line}")
    if not found:
        print("  all files found")
    raise SystemExit(1 if found else 0)
