# Report SQL status

Written 2026-10-07. 58 of the 59 unfinished report queries are now written; `JobSummary.sql` is not (see below).

## How these were checked

- Every query was run against a copy of the database restored from the schema dump (`BetaTranfer - Copy.sql`), on PostgreSQL 16.
- For each one: it executes; it returns exactly the columns the report expects, spelled the same; each column's type suits the report field (text, number, date, true/false); and it still runs when wrapped by the service's filter.
- **Not checked:** rendering through Crystal, and whether the values match what the legacy program printed. Lines marked `INFERRED` in the files are best guesses at legacy behaviour.

## Things that apply to every file

- **Joins ignore upper/lower case** (`upper(a) = upper(b)`). The data mixes case (`RAW` / `raw`, PO `18-0205P2` / `18-0205p2`); with exact matching, 60% of PO receipts found no PO. The legacy database compared without regard to case.
- **"Is null" flag columns are -1 / 0**, as the legacy program wrote them. Some reports test `= -1`.
- **Costs fall back to the part's current cost** where an issue or lot carries none (`materialcost` is 0 throughout this database).

## Not written

- **JobSummary** - its table is built in sections by the legacy program (`ReportSection` = J1-J3, S1-S5, W1-W5, L1-L11, P1-P6). The report file gives the section codes but not what goes in each, so it needs a known-good printout or the legacy source to reproduce.

## Needs attention before use

- **WorkCenterLoads, WorkCenterLoadsGraph** - the reports have a `WorkCenterID` parameter the service has no value for, so they fail with "needs parameter" until the request can carry it.
- **IndentedBOM, IndentedSTDCostedBOM** - return every assembly exploded through all levels (221,133 rows here). Always filter on `Assembly`; unfiltered they will time out.
- **Large when unfiltered:** BillOfMaterials (26,616), StandardCostBOM (26,616), TransactionReport (92,364), WOKitList (50,049), WhereUsed (26,616).
- **No data in this database, so only the shape was checked:** Forecast, IntrastatReporting, LaborDistrByEmployee, LaborDistrByWO, WorkCenterLoads, WorkCenterLoadsGraph.

## Per report

| SQL file | Menu / report name | Rows (dump) | INFERRED notes |
| --- | --- | ---: | ---: |
| BillOfMaterials.sql | Products / Bill of Materials | 26,616 | 2 |
| CustomerContactList.sql | Demand / Contact List | 2,262 | 1 |
| CustomerListing.sql | Demand / Customer List | 2,262 | 1 |
| Exception.sql | MRP / Exception | 181 | 1 |
| Forecast.sql | Demand / Forecast | 0 | 0 |
| IndentedBOM.sql | Products / Indented BOM | 221,133 | 0 |
| IndentedSTDCostedBOM.sql | Products / Indented Costed BOM | 221,133 | 2 |
| IntrastatReporting.sql | Inventory / Intrastat Reporting | 0 | 1 |
| InventoryPartCost.sql | Inventory / Inventory Part Cost | 8,081 | 1 |
| LaborDistrByEmployee.sql | Shop / Labor Distr By Employee | 0 | 2 |
| LaborDistrByWO.sql | Shop / Labor Distr By WO | 0 | 1 |
| LaborRouter.sql | Products / Labor Router | 3 | 0 |
| ManualPartsList.sql | Products / Manual Parts List | 58 | 1 |
| MiscUnplannedIssues.sql | Inventory / Misc Unplanned Issues | 2,961 | 0 |
| MiscUnplannedReceipts.sql | Inventory / Misc Unplanned Receipts | 2,678 | 0 |
| OpenPOLineItems.sql | Supply / Open PO Line Items | 222 | 3 |
| OpenSOListByPartNumber.sql | Demand / Open SO List by Part | 61 | 1 |
| OutputReport.sql | Demand / Output Report | 8,272 | 1 |
| PIPByPartNumber.sql | Supply / PIP By Part Number | 1,784 | 1 |
| PIPByPurchaseOrder.sql | Supply / PIP By Purchase Order | 1,784 | 0 |
| POByPartNumber.sql | Supply / PO By Part Number | 16,770 | 0 |
| POBySupplier.sql | Supply / PO By Supplier | 16,770 | 0 |
| POCommitmentGraph.sql | Supply / PO Commitment Graph | 40 | 1 |
| POPickList.sql | Supply / PO Pick List | 2,276 | 2 |
| POReceipt.sql | Supply / PO Receipt | 16,533 | 0 |
| POTotalsGraph.sql | Supply / PO Totals Graph | 16,770 | 0 |
| PartCountList.sql | Inventory / Part Count List | 10,731 | 0 |
| PartCountTag.sql | Inventory / Part Count Tag | 10,731 | 0 |
| PartCrossReference.sql | Products / Part Cross Reference | 5,257 | 0 |
| PastDuePOReceipts.sql | Supply / Past Due PO Receipts | 179 | 1 |
| PastDueShipmentsByPartNumber.sql | Demand / Past Due Shipments By Part Number | 23 | 1 |
| PastDueShipmentsByRequiredDate.sql | Demand / Past Due Shipments By Required Date | 23 | 1 |
| PlannedOrders.sql | MRP / Planned Orders | 104 | 1 |
| ProductionSchedule.sql | Shop / Production Schedule | 299 | 2 |
| PurchaseCommitment.sql | Supply / Purchase Commitment | 222 | 2 |
| ReturnToVendorList.sql | Supply / Return To Vendor List | 120 | 0 |
| SOBookings.sql | Demand / Bookings Report | 11,620 | 0 |
| SOListByCustomerID.sql | Demand / SO List by Customer | 11,620 | 0 |
| SOListByPartNumber.sql | Demand / SO List By Part Number | 11,620 | 0 |
| SOPickList.sql | Demand / SO Pick List | 23 | 1 |
| SOTotalsGraph.sql | Demand / SO Totals Graph | 11,620 | 0 |
| SalesOrder.sql (commoditycodes table) | Demand / Sales Order | 4 | 0 |
| ShipmentList.sql | Demand / Shipment List | 7,910 | 0 |
| ShortageReport.sql | Supply / Shortage Report | 3,630 | 2 |
| StandardCostBOM.sql | Products / Costed Bill of Materials (Standard Cost) | 26,616 | 5 |
| StockStatus.sql | Inventory / Stock Status | 8,081 | 0 |
| StockroomOnHand.sql | Inventory / Stockroom On Hand | 1,931 | 1 |
| SubContractPOKitList.sql | Supply / Sub Contract P O Kit List | 1,816 | 0 |
| SupplierListing.sql | Supply / Supplier Listing | 604 | 1 |
| TransactionReport.sql | Inventory / Transaction Report | 92,364 | 0 |
| WIPByPartNumber.sql | Shop / WIP By Part Number | 2,156 | 1 |
| WIPByWorkOrder.sql | Shop / WIP By Work Order | 2,156 | 0 |
| WOKitList.sql | Shop / WO Kit List | 50,049 | 0 |
| WOPickList.sql | Shop / WO Pick List | 4,016 | 2 |
| WhereUsed.sql | Products / Where Used | 26,616 | 0 |
| WorkCenterListing.sql | CRP / Work Center Listing | 9 | 1 |
| WorkCenterLoads.sql | CRP / Work Center Loads | 0 | 0 |
| WorkCenterLoadsGraph.sql | CRP / Work Center Loads Graph | 0 | 0 |

## Suggested follow-ups for the 11 files that were already written

- They join with exact case, so a lookup (description, name) is blank where the case differs. Row counts are unaffected.
- `Acknowledgement.sql` / `Quotation.sql` / others write "is null" flags as 1 / 0; the Acknowledgement report also tests `SOHeader_IsnullNotes = -1`.
