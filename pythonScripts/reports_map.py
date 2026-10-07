"""
reports_map.py

The two dictionaries that say which report is which. Edit these by hand;
nothing generates or overwrites this file.

    REPORTS     (menu, report name as shown in ZMRP) -> .rpt file in reports/
    REPORT_SQL  .rpt file -> .sql file in SQLqueries/

A report can be rendered only if it has a REPORTS entry, and its .rpt has a
REPORT_SQL entry. The same .rpt may appear under more than one menu or name.

A report that uses several Crystal tables still has ONE .sql file - put
each table's query under its own "-- Table: <name>" line inside it (see
CrystalReportWrapper/ReportSql.cs).

Check the dictionaries against the files on disk with:
    python reports_map.py
"""

from __future__ import annotations

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
    # Names generated from the file name:
    ("Products", "ECN Summary"): "ECNSummary.rpt",  # menu guessed
    ("Products", "Engineering Part Master"): "EngineeringPartMaster.rpt",  # menu guessed
    ("Products", "Labor Router"): "LaborRouter.rpt",  # menu guessed
    ("Products", "Manual Parts List"): "ManualPartsList.rpt",  # menu guessed
    # ---- Demand ------------------------------------------------------
    # Names taken from the original program's menu:
    ("Demand", "Bookings Report"): "SOBookings.rpt",
    ("Demand", "Contact List"): "CustomerContactList.rpt",
    ("Demand", "Customer List"): "CustomerListing.rpt",
    ("Demand", "Forecast"): "Forecast.rpt",
    ("Demand", "Job Summary"): "JobSummary.rpt",
    ("Demand", "Output Report"): "OutputReport.rpt",
    ("Demand", "SO List by Customer"): "SOListByCustomerID.rpt",
    ("Demand", "Open SO List by Part"): "OpenSOListByPartNumber.rpt",
    # Names generated from the file name:
    ("Demand", "Acknowledgement"): "Acknowledgement.rpt",
    ("Demand", "Credit Memo"): "CreditMemo.rpt",  # menu guessed
    ("Demand", "Credit Memo Transaction"): "CreditMemoTransaction.rpt",  # menu guessed
    ("Demand", "Customer Disc Level"): "CustomerDiscLevel.rpt",  # menu guessed
    ("Demand", "Invoice"): "Invoice.rpt",  # menu guessed
    ("Demand", "Invoice Transaction"): "InvoiceTransaction.rpt",  # menu guessed
    ("Demand", "Past Due Shipments By Part Number"): "PastDueShipmentsByPartNumber.rpt",
    ("Demand", "Past Due Shipments By Required Date"): "PastDueShipmentsByRequiredDate.rpt",
    ("Demand", "Quotation"): "Quotation.rpt",
    ("Demand", "Sales Order"): "SalesOrder.rpt",
    ("Demand", "Shipment List"): "ShipmentList.rpt",  # menu guessed
    ("Demand", "SO List By Part Number"): "SOListByPartNumber.rpt",  # menu guessed
    ("Demand", "SO Pick List"): "SOPickList.rpt",
    ("Demand", "SO Totals Graph"): "SOTotalsGraph.rpt",
    # ---- Supply ------------------------------------------------------
    ("Supply", "Open PO Line Items"): "OpenPOLineItems.rpt",
    ("Supply", "Past Due PO Receipts"): "PastDuePOReceipts.rpt",  # menu guessed
    ("Supply", "PIP By Part Number"): "PIPByPartNumber.rpt",  # menu guessed
    ("Supply", "PIP By Purchase Order"): "PIPByPurchaseOrder.rpt",  # menu guessed
    ("Supply", "PO By Part Number"): "POByPartNumber.rpt",
    ("Supply", "PO By Supplier"): "POBySupplier.rpt",  # menu guessed
    ("Supply", "PO Commitment Graph"): "POCommitmentGraph.rpt",  # menu guessed
    ("Supply", "PO Pick List"): "POPickList.rpt",
    ("Supply", "PO Receipt"): "POReceipt.rpt",
    ("Supply", "PO Totals Graph"): "POTotalsGraph.rpt",  # menu guessed
    ("Supply", "Purchase Commitment"): "PurchaseCommitment.rpt",  # menu guessed
    ("Supply", "Purchase Order"): "PurchaseOrder.rpt",
    ("Supply", "Return To Vendor List"): "ReturnToVendorList.rpt",  # menu guessed
    ("Supply", "Shortage Report"): "ShortageReport.rpt",
    ("Supply", "Sub Contract PO Kit List"): "SubContractPOKitList.rpt",
    ("Supply", "Supplier Listing"): "SupplierListing.rpt",
    ("Supply", "Work Order Traveler"): "WorkOrderTraveler.rpt",
    # ---- MRP ---------------------------------------------------------
    ("MRP", "Exception"): "Exception.rpt",  # menu guessed
    ("MRP", "Planned Orders"): "PlannedOrders.rpt",  # menu guessed
    # ---- Inventory ---------------------------------------------------
    ("Inventory", "Intrastat Reporting"): "IntrastatReporting.rpt",
    ("Inventory", "Inventory Part Cost"): "InventoryPartCost.rpt",
    ("Inventory", "Inventory Variance"): "InventoryVariance.rpt",  # menu guessed
    ("Inventory", "Misc Unplanned Issues"): "MiscUnplannedIssues.rpt",  # menu guessed
    ("Inventory", "Misc Unplanned Receipts"): "MiscUnplannedReceipts.rpt",  # menu guessed
    ("Inventory", "Part Count List"): "PartCountList.rpt",  # menu guessed
    ("Inventory", "Part Count Tag"): "PartCountTag.rpt",  # menu guessed
    ("Inventory", "Stockroom Locations"): "StockroomLocations.rpt",  # menu guessed
    ("Inventory", "Stockroom On Hand"): "StockroomOnHand.rpt",
    ("Inventory", "Stock Status"): "StockStatus.rpt",
    ("Inventory", "Transaction Report"): "TransactionReport.rpt",
    # ---- CRP ---------------------------------------------------------
    ("CRP", "Work Center Listing"): "WorkCenterListing.rpt",
    ("CRP", "Work Center Loads"): "WorkCenterLoads.rpt",
    ("CRP", "Work Center Loads Graph"): "WorkCenterLoadsGraph.rpt",
    # ---- Shop --------------------------------------------------------
    ("Shop", "Labor Distr By Employee"): "LaborDistrByEmployee.rpt",
    ("Shop", "Labor Distr By WO"): "LaborDistrByWO.rpt",  # menu guessed
    ("Shop", "Labor Utilization"): "LaborUtilization.rpt",  # menu guessed
    ("Shop", "Production Backlog"): "ProductionBacklog.rpt",  # menu guessed
    ("Shop", "Production Schedule"): "ProductionSchedule.rpt",  # menu guessed
    ("Shop", "WIP By Part Number"): "WIPByPartNumber.rpt",
    ("Shop", "WIP By Work Order"): "WIPByWorkOrder.rpt",
    ("Shop", "WO Kit List"): "WOKitList.rpt",
    ("Shop", "WO Pick List"): "WOPickList.rpt",
    # ---- Codes -------------------------------------------------------
    # "Codes" is a holding menu for lookup lists whose real menu is unknown.
    ("Codes", "Commodity Codes"): "CommodityCodes.rpt",  # menu guessed
    ("Codes", "Currency Codes"): "CurrencyCodes.rpt",  # menu guessed
    ("Codes", "Density Codes"): "DensityCodes.rpt",  # menu guessed
    ("Codes", "Department Codes"): "DepartmentCodes.rpt",  # menu guessed
    ("Codes", "ECN Class Codes"): "ECNClassCodes.rpt",  # menu guessed
    ("Codes", "Employee Information List"): "EmployeeInformationList.rpt",  # menu guessed
    ("Codes", "Employee List"): "EmployeeList.rpt",  # menu guessed
    ("Codes", "F.O.B Codes"): "FOBCodes.rpt",  # menu guessed
    ("Codes", "Holiday List"): "HolidayList.rpt",  # menu guessed
    ("Codes", "Intrastat Codes"): "IntrastatCodes.rpt",  # menu guessed
    ("Codes", "Intrastat Rates"): "IntrastatRates.rpt",  # menu guessed
    ("Codes", "Operation Codes"): "OperationCodes.rpt",  # menu guessed
    ("Codes", "Price Discount Codes"): "PriceDiscountCodes.rpt",  # menu guessed
    ("Codes", "Product Discount Codes"): "ProductDiscountCodes.rpt",  # menu guessed
    ("Codes", "Product Revenue Codes"): "ProductRevenueCodes.rpt",  # menu guessed
    ("Codes", "Region Codes"): "RegionCodes.rpt",  # menu guessed
    ("Codes", "Ship Via Codes"): "ShipViaCodes.rpt",  # menu guessed
    ("Codes", "System Used On Codes"): "SystemUsedOnCodes.rpt",  # menu guessed
    ("Codes", "Tax Codes"): "TaxCodes.rpt",  # menu guessed
    ("Codes", "Terms Codes"): "TermsCodes.rpt",  # menu guessed
    ("Codes", "UOM Codes"): "UOMCodes.rpt",  # menu guessed
}

# .rpt file name -> .sql file name in SQLqueries/
REPORT_SQL: dict[str, str] = {
    "Acknowledgement.rpt": "Acknowledgement.sql",
    "BillOfMaterials.rpt": "BillOfMaterials.sql",
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
    "WorkOrderTraveler.rpt": "WorkOrderTraveler.sql",
}


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
