# RPTConvert - outstanding work

Written 2026-10-08, after the second smoke test (62 of 78 reports rendering
through the Docker report API).

Items marked **you** need a decision or an action on the work machine.

## 1. Get the 16 failing reports rendering

| # | Task | Reports | Who | Notes |
|---|---|---|---|---|
| 1 | Fix the alternate-row shading rule (`Section_Back_Color`) | 12 | **you**: build + smoke test | Code done in the worker (`ReportColors.cs`, late-bound RAS, no new SDK references). Rebuild the worker, re-run the smoke test. If a report still fails, run `CrystalReportWrapper.exe --report <file.rpt> --section-rules` and send the output. |
| 2 | Supply `WorkCenterID` | 2 | done, needs rebuild | `Program.ApplyParameters`: a missing parameter takes an equals-filter value on the same column, else blank for `WorkCenterID` (and Tax Codes' `TaxCode` / `LiabilityAccount`). |
| 3 | Write the query for Job Summary | 1 | either | `JobSummary.sql` has a table section but no working query. |
| 4 | Map and write SQL for BOM with References | 1 | done | Mapped; `ItemSequence` / dates cast to the types the report wants. |

The 12 reports in item 1: Labor Router, Manual Parts List, SO Totals Graph,
PO Totals Graph, Shortage Report, Exception, Planned Orders, Intrastat
Reporting, Inventory Variance, Stockroom On Hand, Stock Status, Transaction
Report.

The 2 reports in item 2: Work Center Loads, Work Center Loads Graph.

## 2. Confirm the 62 "passing" reports are correct

| # | Task | Who | Notes |
|---|---|---|---|
| 5 | Check the 12 reports with little or no content | **you** | Start with the two Past Due Shipments reports. Their original record-selection rule is not applied by the SQL, so they may show the wrong rows or none. |
| 6 | Compare a few renders against the original program | **you** | Checks label wording, totals and layout. Sales Order, Purchase Order and Bill of Materials cover most cases. |
| 7 | Re-run the smoke test after each fix | **you** | `python smoke_test.py --port <port>`; results land in `Scratch\smoke\`. |

The 12 reports in item 5:

- Demand: Output Report, Credit Memo, Credit Memo Transaction, Customer Disc
  Level, Past Due Shipments By Part Number, Past Due Shipments By Required Date
- Supply: PO Commitment Graph, Return To Vendor List
- Inventory: Misc Unplanned Issues, Misc Unplanned Receipts, Part Count List,
  Part Count Tag

## 3. Reports not built yet

| # | Task | Who | Notes |
|---|---|---|---|
| 8 | The Codes menu, 21 reports | **you**: copy the .rpt files | SQL written for all 21 (checked against `schema_only.sql`) and mapped. The `.rpt` files are not in `reports/` here - copy them from the original install; `python pythonScripts/reports_map.py` lists what's missing. |
| 9 | `IntrastatRates.rpt` | **you** | Mapped, but the file is not in the `reports` folder. Copy it from the original install. |

## 4. Menu structure and query prompts

Designed, not started. The original program has three menu shapes: plain
reports, groups (Costed BOM -> Pending Cost / Standard Cost), and reports with
a "Queries" drop-down whose prompts change per query (text, number, date
range, checkbox).

| # | Task | Who | Notes |
|---|---|---|---|
| 10 | Answer two open questions | done | Asterisk = wildcards allowed. Date pickers left out (From/To text boxes, YYYY-MM-DD). |
| 11 | Add groups and query options to `reports_map.py` | done | `GROUPS` (Costed BOM) and `QUERIES` (Part Cross Reference so far) with prompt kinds text / number / date_range / checkbox; `query_filter()` turns answers into a filter. |
| 12 | Extend `/menus` and `/render` | done | `/menus` returns the tree (`?flat=1` for the old shape); `/render` takes `query` + `values`. |
| 13 | List every report's queries and prompts | **you** | Screenshots of each dialog; each becomes a `QUERIES` entry (template in `reports_map.py`). |
| 14 | Build the prompt dialog in ZMRP | done | Queries drop-down + typed fields for reports with `QUERIES`; the free-text rows stay for the rest until item 13 fills them in. ZMRP's `reports_map.py` is a copy of this one - keep them identical. |

## 5. Housekeeping

| # | Task | Who | Notes |
|---|---|---|---|
| 15 | Confirm the zoom toolbar works in ZMRP | **you** | The corrected `ReportPromptDialog.py` has not been run. |
| 16 | Give ZMRP-Server a fixed address | **you** | `.env` should hold its IP, since the container cannot resolve the name. |
| 17 | Commit the working state | **you** | New files: `ReportFormulas.cs`, `LegacyLabels.cs`, `smoke_test.py`, `dump_formulas.py`, plus the Dockerfile font step. |
| 18 | Remove `Scratch\CRUFLMFGFunctions.dll` | **you** | No longer needed. |

## Suggested order

1. Items 1 and 2, then re-run the smoke test. Expected: 76 of 78.
2. Items 3 to 6, to finish and verify the current report list.
3. Item 10, so the menu and prompt work (11, 12) can start while the dialogs
   for 13 are gathered.
4. Items 8 and 9 whenever the Codes reports matter.

## Done on 2026-10-08, for reference

- Container reaches Postgres on ZMRP-Server (`PG_HOST` in `.env`).
- Legacy label function replaced: `ReportFormulas.cs` swaps every
  `MFGFunctionsTranslationTranslate (N)` call for the real text in
  `LegacyLabels.cs` (565 labels, taken from the legacy add-on itself).
- Fonts installed in the image (Arial, Times New Roman, Courier New, Tahoma,
  Verdana); reports no longer render in the Crystal barcode font.
- `smoke_test.py` renders every report through the API; `dump_formulas.py`
  dumps report formulas and legacy labels.
