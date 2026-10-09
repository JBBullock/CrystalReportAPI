# RPTConvert - outstanding work

Written 2026-10-08, after the second smoke test (62 of 78 reports rendering
through the Docker report API).

Items marked **you** need a decision or an action on the work machine.

## 1. Get the 16 failing reports rendering

| # | Task | Reports | Who | Notes |
|---|---|---|---|---|
| 1 | Fix the alternate-row shading rule (`Section_Back_Color`) | 12 | **you** decide, then either | If the Crystal designer is installed, edit the 12 `.rpt` files (Section Expert -> Color). If not, add it to the C# worker, which needs four more SDK references and likely a couple of build rounds. |
| 2 | Supply `WorkCenterID` | 2 | Claude | Pass the filter's work center if present, otherwise blank. Waiting on go-ahead. |
| 3 | Write the query for Job Summary | 1 | either | `JobSummary.sql` has a table section but no working query. |
| 4 | Map and write SQL for BOM with References | 1 | either | No entry in `REPORT_SQL`. |

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
| 8 | The Codes menu, about 21 reports | either | In the first smoke run with no SQL mapped; not in the latest report list. Each needs a `.sql` file and a map entry. |
| 9 | `IntrastatRates.rpt` | **you** | Mapped, but the file is not in the `reports` folder. Copy it from the original install. |

## 4. Menu structure and query prompts

Designed, not started. The original program has three menu shapes: plain
reports, groups (Costed BOM -> Pending Cost / Standard Cost), and reports with
a "Queries" drop-down whose prompts change per query (text, number, date
range, checkbox).

| # | Task | Who | Notes |
|---|---|---|---|
| 10 | Answer two open questions | **you** | What the asterisk beside text prompts means (required, or wildcards allowed), and whether the date pickers can be left out. |
| 11 | Add groups and query options to `reports_map.py` | Claude | Covers Costed BOM sub-items and the Queries drop-down with typed prompts. |
| 12 | Extend `/menus` and `/render` | Claude | `/menus` returns the nesting and prompt list; `/render` accepts the chosen query. |
| 13 | List every report's queries and prompts | **you** | Screenshots of each dialog, as done for the first four. |
| 14 | Build the prompt dialog in ZMRP | Claude, with the ZMRP folder | Replaces the free-text column boxes in `ReportPromptDialog.py` with the Queries drop-down and typed fields. |

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
