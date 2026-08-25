# Crystal Reports Pipeline — Code Review & Dynamic Reporting Plan

**Scope:** `RPTConvert/CrystalReportWrapper/Program.cs`, `RPTConvert/main.py` (really `crystal_reports_pipeline.py`), cross-referenced against `SecureZMRP-Home`'s own `PROJECT_STATUS_AND_REPORTS_INTEGRATION.md` (the "Reports" feature proposal already sitting in that repo) and the live `mainView.py` / `menu_config.py` / `DialogRegistry.py` wiring.

---

## 1. Bottom line

You don't need to tweak the pipeline per report. The two functions that do the actual work — `BuildReportDataSet` and `ApplyParameters` in `Program.cs` — are already written to be report-agnostic: they read what a `.rpt` needs (its tables, its parameters, its subreports' parameters) directly off the loaded report object, not off anything hardcoded per report. What's missing isn't dynamic *rendering* — it's a **registry** that tells your Python/ZMRP side which Crystal parameter names each of your ~40 reports actually expects, and where those values come from (a date picker, the currently-open Purchase Order, etc.). That registry is a data problem, not a C# problem, and §6 below gives you a concrete shape for it that reuses metadata your `--inspect` mode already produces.

Separately: SecureZMRP already has a fairly detailed integration plan for wiring a Reports feature into the menu system (`PROJECT_STATUS_AND_REPORTS_INTEGRATION.md`, §10). I verified its file/line citations against the live code and they check out. But it was written without seeing `Program.cs`, so it guesses at a CLI contract that doesn't quite match what you actually built, and recommends a data-access model your C# side doesn't currently follow. §5 reconciles the two.

---

## 2. What's already dynamic (the good news, in detail)

**`BuildReportDataSet` (Program.cs:964)** doesn't take a report name or a list of tables as a parameter — it takes whatever `report.Database.Tables` says a *just-loaded* `.rpt` needs (see the loop at line 492 in `RunExportPipeline`), looks each table name up in `TableQueryCatalog`, and only fetches those. A report that touches tables you've already cataloged (`SOHeader`, `SODetail`, `Customers`, `PartMaster`, `WOHeader`) works with **zero C# changes**, no matter which of your 40 `.rpt` files it is.

**`ApplyParameters` (Program.cs:814)** does the same thing for parameters: it builds one combined list of `ParameterFieldDefinition`s from the main report *and every subreport* (line 831–836 — this subreport handling is not optional boilerplate; a lot of legacy Access-era Crystal reports define their prompts on a subreport, not the main report, and a naive implementation that only checks `report.DataDefinition.ParameterFields` would silently find nothing), then matches each key in your `params.json` against a parameter by name (case-insensitive, and stripping Crystal's internal `?` prefix via `TrimStart('?')`). It even coerces JSON values into the exact CLR type Crystal wants per parameter (`CoerceToParameterType`, line 887) using `ParameterValueKind` — so a report expecting a `DateTime` parameter and one expecting a `Number` parameter both work through the same code path.

**`--inspect` mode (Program.cs:587)** is the piece that makes the above two facts *actionable* rather than just reassuring. It loads a `.rpt`, does no data binding, and dumps every table (with columns + types), every formula's raw text, and every parameter (name + kind) for the main report and every subreport, as one JSON manifest. This is exactly the metadata a registry needs — you don't have to hand-inspect 40 `.rpt` files in the Crystal designer to find out what each one expects; you already built the tool that tells you.

So: adding report #41 costs you C# work only if it touches a table that isn't in `TableQueryCatalog` yet (a one-time, reusable cost — see §4.4) or needs a UFL formula function your machine doesn't have registered. It never costs you a Program.cs change just because it's *a different report*.

---

## 3. Where the "manual per-report" work is actually coming from

Given §2, the tweaking you've been doing per report is almost certainly one (or both) of:

1. **Building the right `params.json` by hand for each report**, because nothing currently maps "the user picked August 2026 in the Demand Reports screen" to `{"Month_req": "August", "Month_Ordered": 8, "Year_Ordered": 2026}` — three keys, in a shape idiosyncratic to *this* report. Another report might want a single `AsOfDate` ISO string, or a `CustomerID` int, or nothing at all. There's no way around *some* per-report mapping existing somewhere (two different report authors will never name a date parameter the same thing), but it should live in one small data file, not in code you edit and republish per report.
2. **A new table showing up in `TableQueryCatalog`** — real work, but it's per-*table*, not per-*report*, and it's already the minimum necessary since nobody but you knows the Postgres column names for a table Crystal has never seen queried directly before.

Once you have (1) as an explicit, inspectable file instead of tribal knowledge in your head, "dynamic" report generation is really just: given a report id, look up its manifest entry, resolve each declared parameter from either ZMRP's currently-open record or a small prompt UI, write `params.json`, call `generate_report()`. That's one function, not forty.

---

## 4. `Program.cs` maintainability review

The project instructions for this workspace ask me to review for maintainability/organization and explain C# as I go — so this section is deliberately more didactic than a terse review would be.

### 4.1 File size and organization

`Program.cs` is 1,054 lines / ~51 KB doing five distinct jobs: CLI parsing, the export pipeline, the inspect pipeline, the Postgres data-catalog (which is really *data*, not *code*), and JSON result serialization. None of that is wrong today, but it's the kind of file where the next feature (say, a third mode, or a second database) turns into a very long scroll to find the right spot. A natural split, with no behavior change:

```
CrystalReportWrapper/
├── Program.cs          Main() + CLI parsing only
├── ExportPipeline.cs   RunExportPipeline, ExportReport
├── InspectPipeline.cs  RunInspect, InspectTables/Formulas/Parameters, CollectConnectionAttributes
├── ParameterBinding.cs ApplyParameters, CoerceToParameterType, EnumerateParameterFields
├── DataCatalog.cs      TableQueryCatalog, RelationCatalog, BuildReportDataSet
└── ResultTypes.cs      ExportResult, InspectResult, TableInfo, FieldInfo, FormulaInfo, ParameterInfo, SubreportInfo
```
`internal` classes and `static` methods don't care what file they're physically in as long as they stay in the same `namespace CrystalReportWrapper` — C# resolves everything at the project/namespace level, not per-file, so this is a pure organizational move with zero risk.

### 4.2 Nullable reference types — a real inconsistency worth knowing about

Your `.csproj` sets:
```xml
<Nullable>disable</Nullable>
```
That turns *off* C#'s nullable-reference-type analysis for the whole project. But `Program.cs` is written throughout as if it's *on* — e.g. `public string? OutputPath { get; set; }`, `public string? Error { get; set; }`, `Exception? current = ex`. The `?` after a reference type (`string?`, `Exception?`) is C#'s way of saying "this can legitimately be null, and the compiler should warn you if you dereference it without checking." With `<Nullable>disable</Nullable>`, the compiler treats the whole file in the older "everything is nullable, nothing is checked" mode — so those `?` annotations still compile (they're syntactically legal either way) but they're **not doing anything**: the compiler isn't flagging any of the many places where, say, `result.OutputPath` gets used without a null check.

This isn't breaking anything today, but it's worth a deliberate choice rather than an accident: either flip `<Nullable>enable</Nullable>` in the `.csproj` and let the compiler actually check the annotations you've already written (you'll get a batch of warnings the first time — that's the tool doing its job, not a regression), or strip the `?` annotations to match the disabled setting so the code doesn't visually promise a safety net that isn't there. Given how much of this file is exception handling around external SDK calls, I'd lean toward enabling it.

### 4.3 A few C# idioms worth naming, since they recur throughout the file

- **`using var report = new ReportDocument();`** (line 460) is a *using declaration* (C# 8+), shorthand for wrapping the rest of the enclosing block in a `using (var report = ...) { ... }`. `ReportDocument` implements `IDisposable` because it holds unmanaged Crystal Reports engine resources; without `using`, those wouldn't be released until the GC got around to it, which for a short-lived CLI process might be "never, because the process exits first" — usually harmless here since the OS reclaims everything on exit, but it's the right habit regardless.
- **Switch expressions** (`ExportReport`, line 939; `CoerceToParameterType`, line 887) — the `x switch { pattern => value, ... }` form is an *expression* that evaluates to a value, distinct from the older `switch (x) { case ...: }` *statement* form. It reads well here because every branch is "map this input to that output," which is exactly what an expression should do rather than a statement with `break`s.
- **`yield return` in `EnumerateParameterFields`** (line 870) makes that method an *iterator* — C# generates a hidden state machine behind the scenes so the `foreach` in `ApplyParameters` can pull one `ParameterFieldDefinition` at a time without you manually building a `List<T>` first. Small win here since `ParameterFieldDefinitions` (the Crystal type) isn't itself a generic `IEnumerable<ParameterFieldDefinition>` — it predates generics — so this adapts an old-style enumerable collection into a modern one.
- **The tuple-typed `List<(string ParentTable, string ParentColumn, string ChildTable, string ChildColumn)>`** for `RelationCatalog` (line 399) is a *named tuple* — lighter weight than defining a whole class for four strings that always travel together, and `rel.ParentTable` etc. reads as clearly as a property would.

### 4.4 Hardcoded Postgres credentials (flagging for your awareness, not just style)

```csharp
private const string PgPassword = "engineer123";
```
This is compiled directly into `CrystalReportWrapper.exe` and will ship inside it wherever that `.exe` goes (§10.4 of your own SecureZMRP proposal calls out that this project already has a documented allergy to credentials scattered across config files for exactly this reason). Two independent concerns: it's a real credential sitting in source control in plaintext, and — separately — it means this worker connects to Postgres as whatever role `postgres`/`engineer123` is, **not** as the ZMRP user who clicked the report, which sidesteps the table-level grant system `DatabaseManager` already enforces everywhere else in the app (see §5.2). At minimum, move these five constants to an environment variable or a local config file excluded from source control before this goes anywhere near production; §5.2 discusses the bigger architectural question underneath this.

### 4.5 `TableQueryCatalog` / `RelationCatalog` are data, compiled as code

Every time a genuinely new table needs cataloging, it requires editing `Program.cs` and re-running `dotnet publish` (per `README_1.md`'s build step). That's a much heavier operation than adding a table should be — a recompile-and-redistribute cycle for what's fundamentally "here's a SQL query and a name." Moving these two catalogs into a JSON file the `.exe` reads at startup (next to the executable, or at a path passed via `--catalog`) means:
- Adding a table becomes editing JSON, not recompiling C#.
- The same catalog file could in principle be shared/diffed/reviewed independently of the C# source.
- It sets up the natural pairing with the Python-side report registry in §6 — one JSON file per side, both human-editable, neither requiring a rebuild.

This is optional (the current approach isn't *broken*), but it's the one change that would make the *data-fetching* half of this pipeline as dynamic as the *parameter*-handling half already is.

### 4.6 Minor: CLI parsing edge case

`ParseArgs` does `options.ReportPath = args[++i];` for every flag. If `--report` is the last token with no value after it, `++i` walks past the end of `args` and throws `IndexOutOfRangeException`. This is caught by `Main`'s `try/catch` (line 429-437) and still produces a valid JSON error line rather than crashing raw — so Python won't hang or get garbage — but the message Python sees will be the generic `"IndexOutOfRangeException: Index was outside the bounds of the array."` rather than something like `"--report requires a value"`. Not urgent, but a `if (i + 1 >= args.Length) throw new ArgumentException($"{args[i]} requires a value")` guard before each `args[++i]` would make failures self-explanatory from the Python side without needing to open the C# source.

### 4.7 Minor: diagnostics on stdout

Every `Console.WriteLine` diagnostic (`"Report Loaded Successfully"`, per-table row counts, per-arg echoes) shares stdout with the one JSON result line. `crystal_reports_pipeline.py` defends against this correctly today by taking only the *last* non-empty line (`_parse_worker_output`, `crystal_reports_pipeline.py:241`), so nothing is broken. But it's a slightly fragile contract to lean on long-term — if the Crystal SDK itself ever writes a warning to stdout *after* your JSON line (some COM components do this on shutdown), the "last line" assumption breaks. Routing your own diagnostics to `Console.Error.WriteLine` instead keeps stdout as a clean single-purpose channel (exactly the JSON contract your own header comment describes) and stderr as the debug log — a low-effort change that removes a class of future flakiness.

---

## 5. Reconciling with SecureZMRP's own integration proposal

`PROJECT_STATUS_AND_REPORTS_INTEGRATION.md` (dated Aug 24, 2026, already in your `SecureZMRP` repo) independently designed most of the menu-side wiring for this feature, and I checked its citations against the live source — `MENU_STRUCTURE` really does append `"Reports"` to Products/Demand/Supply/MRP/Inventory/CRP/Shop at `menu_config.py:518-524`, `_special_dispatch` really is the property at `mainView.py:1054`, and `DialogRegistry.py` really does have four commented-out stub entries (`("Products", "Reports")`, etc.) anticipating this. That plan's §10.6 (bypass `DialogFactory`, add one `_special_dispatch` entry per menu pointing at a single parameterized `open_reports(menu_name)`, matching the existing `open_cost_roll_up`/`open_gui_window` pattern) is sound and I'd keep it as-is — it's the smallest possible diff and it's consistent with how this codebase already handles "not quite CRUD" screens.

Two things in that doc don't match what `Program.cs` actually does, though, because it was written without seeing this repo:

### 5.1 CLI contract mismatch

The proposal's `ProcessReportRenderer` (§10.5) assumes:
```python
args = [self._exe, "--report", ..., "--out", str(out_path)]
for k, v in params.items():
    args += ["--param", f"{k}={v}"]
```
Your actual `CrystalReportWrapper.exe` takes `--output` (not `--out`) and `--params <path-to-a-json-file>` (not repeated `--param k=v` flags) — see `ParseArgs`, Program.cs:766. This isn't a flaw in either side, it's just two documents that never talked to each other. **Don't hand-write a new `ProcessReportRenderer`** per that doc's sketch — you already have a correct, tested one: `CrystalReportsPipeline` in `crystal_reports_pipeline.py`. The Reports feature's `report_renderer.py` (§10.5 of the proposal) should be a thin adapter around that existing class, not a reimplementation of subprocess plumbing.

### 5.2 Data-access model mismatch

The proposal's §10.3 recommends a **push** model specifically so that report data flows through the same `DatabaseManager` role/grant checks every other ZMRP screen already goes through — its stated worry is exactly the scenario in §4.4 above, a report bypassing the app's own permission system. Your C# wrapper already does *fetch data itself and hand it to Crystal* (so it's push-shaped, not pointing Crystal at a live ODBC connection per report) — but it does so via its own hardcoded Npgsql connection, under its own Postgres role, entirely independent of whichever ZMRP user actually clicked the report. That's push in mechanism but not in the access-control sense the proposal cares about.

This is a real decision, not a bug: do you want per-report data access governed by ZMRP's existing table-level grants, or is a single dedicated "reports" Postgres role (scoped read-only, minimally privileged, distinct from the app's interactive-user role) an acceptable simplification? Either is defensible; I'd just make it a deliberate choice rather than an accident of how the pipeline evolved. If you want the former, the C# side would need to accept ZMRP's already-authenticated connection info (or a short-lived token) from Python per call instead of using fixed constants — a larger change than anything else in this document, so I'd treat it as a later phase, not a blocker for shipping dynamic reports.

---

## 6. The registry: closing the actual gap

Extend the proposal's `reports_manifest.json` idea (§10.4) with one more field per report — the parameter mapping — and generate it semi-automatically from `--inspect` instead of hand-typing 40 entries blind. Concretely, for your three known reports today:

```json
[
  {
    "id": "sales_order",
    "menu": "Demand",
    "display_name": "Sales Order",
    "file": "SalesOrder - Copy.rpt",
    "parameters": []
  },
  {
    "id": "work_order_traveler",
    "menu": "Supply",
    "display_name": "Work Order Traveler",
    "file": "WorkOrderTraveler.rpt",
    "parameters": []
  },
  {
    "id": "backlog_rfof_wo",
    "menu": "Demand",
    "display_name": "Backlog Report",
    "file": "Backlog_RFoF_WO.rpt",
    "parameters": [
      { "crystal_name": "Month_req",     "source": "prompt", "type": "string", "label": "Month" },
      { "crystal_name": "Month_Ordered", "source": "prompt", "type": "number", "label": "Order Month" },
      { "crystal_name": "Year_Ordered",  "source": "prompt", "type": "number", "label": "Order Year" }
    ]
  }
]
```
`crystal_name` is exactly what `--inspect` reports for that parameter (so it's guaranteed to match what `ApplyParameters` looks up — no guessing at Crystal's internal naming). `source: "context"` (per the original proposal) pulls a value from whatever record is currently open in ZMRP; `source: "prompt"` gets a small input row in the Reports dialog. A report with an empty `parameters` list — like your two sample reports today, which take none — needs no mapping at all; it Just Works the moment its tables are cataloged.

**Bootstrapping this for 40 reports:** write a short one-off Python script that walks your reports folder, calls `pipeline.inspect_report()` on each `.rpt`, and emits a manifest skeleton with every discovered parameter pre-filled as `"source": "prompt"` and a TODO label — turning "hand-write 40 entries" into "review and fill in 40 mostly-generated entries," and flagging any report whose `--inspect` call itself fails (missing table, missing UFL) before you've invested any mapping work in it.

---

## 7. Suggested phased plan

1. **Bootstrap the manifest.** Run `--inspect` against every `.rpt` across your four menus; generate the skeleton above; fill in `source`/`label` for each parameter by hand (this is the one genuinely per-report step, and it's a data-entry pass, not a coding pass).
2. **Catalog any missing tables.** For each `--inspect` failure or "NO MATCHING TABLE" warning (Program.cs already logs these explicitly — see §4.5's note on how loud `BuildReportDataSet` already is about this), add the table to `TableQueryCatalog` (or its externalized JSON form, if you do §4.5 first).
3. **Build the thin registry + renderer adapter in Python** — `ReportsCatalog` loads the manifest; a small `render(report_id, context)` function resolves each parameter's value, writes the params file, and calls `CrystalReportsPipeline.generate_report()` directly (§5.1 — no new subprocess code needed).
4. **Wire into `mainView.py`** per the existing proposal's §10.6 — one `open_reports(menu_name)` method, one `_special_dispatch` entry per menu, no `menu_config.py` changes needed since `"Reports"` is already appended everywhere.
5. **Decide on §5.2** (shared reports role vs. per-user grants) before this goes past your own machine — cheap to defer, not cheap to retrofit once report access patterns are baked into a shipped `.exe`.
6. **(Optional, anytime)** Split `Program.cs` per §4.1 and address §4.2/§4.4/§4.6/§4.7 — none of these block the registry work, they're independent cleanup.

---

## 8. Open questions for you

- Do you want `TableQueryCatalog`/`RelationCatalog` externalized to JSON now (§4.5), or is a recompile-per-new-table acceptable for a while longer given you're not adding new tables that often?
- For §5.2: is a single dedicated read-only Postgres "reports" role an acceptable simplification for now, or does per-user grant enforcement need to be there from day one?
- Where will `reports_dir` actually live once this isn't just your Desktop — a shared network path (as the SecureZMRP proposal assumes) or bundled per-workstation?
