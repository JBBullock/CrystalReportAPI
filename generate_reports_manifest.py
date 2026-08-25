"""
generate_reports_manifest.py

PURPOSE
-------
Bootstraps reports_manifest.json (see CRYSTAL_REPORTS_PIPELINE_REVIEW.md, §6)
by recursively walking a directory of .rpt files and running
CrystalReportWrapper.exe's --inspect mode against each one via the existing
CrystalReportsPipeline wrapper - no new subprocess plumbing, per that
review's recommendation to reuse the pipeline you already have rather than
rewrite it. (That wrapper class's own docstring calls its file
crystal_reports_pipeline.py, but it actually lives in this project as
main.py - hence `from main import ...` below rather than
`from crystal_reports_pipeline import ...`. Harmless either way; rename
main.py if the mismatch bothers you.)

For each .rpt found, this pulls:
  - a stable "id" (slugified from the filename)
  - the file's path, relative to the reports root you point it at
  - a best-guess "menu" (the top-level subfolder name, if it matches one of
    --menus - leave --menus empty to skip this guess entirely)
  - every parameter the report (and its subreports) actually declares, with
    Crystal's own valueKind mapped to a simpler "type", and "source" set to
    "global" for known company-wide formatting parameters (CompanyName,
    CurrencySymbol, QuantityDecimals, etc. - see GLOBAL_PARAMETER_NAMES) or
    "prompt" for everything else - you edit source/label by hand afterward
    for anything that's actually contextual (should come from whatever
    ZMRP record is open) rather than a raw prompt; that's the one
    genuinely per-report step left, and it's now a much shorter list than
    "every parameter on every report."

Reports whose --inspect call itself fails (missing table, bad file, etc.)
still get an entry, with "error" set and "parameters": [] - so a failure
here is visible in the manifest instead of silently producing an empty file,
and you can fix the underlying cataloging issue (see TableQueryCatalog in
Program.cs) before spending any time on that report's parameter mapping.

USAGE
-----
    python generate_reports_manifest.py \
        --reports-dir "C:\\...\\Desktop\\RPTConvert\\reports" \
        --worker-exe "C:\\...\\CrystalReportWrapper\\bin\\Debug\\net48\\CrystalReportWrapper.exe" \
        --output reports_manifest.json \
        --menus Products Demand Supply Inventory

Only --reports-dir is required; --worker-exe defaults to the usual Debug
build location next to this script's own CrystalReportWrapper/ folder,
--output defaults to reports_manifest.json in the current directory, and
--menus defaults to Products/Demand/Supply/Inventory (your four live menus).

Must be run on the same Windows machine as the Crystal Reports SDK/runtime -
same requirement as CrystalReportWrapper.exe itself (see README_1.md).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Optional

from main import CrystalReportError, CrystalReportsPipeline

# Maps Crystal's ParameterValueKind (as returned by --inspect, e.g.
# "NumberParameter") onto a smaller vocabulary for the manifest's "type"
# field. Anything not listed here (TimeParameter is rare enough not to be
# worth a dedicated bucket, and any future enum value Crystal adds) falls
# back to "string" rather than failing the whole script over one odd
# parameter - see _map_value_kind.
VALUE_KIND_TO_TYPE = {
    "NumberParameter": "number",
    "CurrencyParameter": "currency",
    "BooleanParameter": "boolean",
    "DateParameter": "date",
    "DateTimeParameter": "datetime",
    "StringParameter": "string",
}

DEFAULT_MENUS = ["Products", "Demand", "Supply", "Inventory"]

# Parameter names that turned out, once real reports were inspected, to be
# company-wide formatting/contact values (decimal precision, currency
# symbol, company name/phone/fax/email, VAT numbers) rather than anything
# specific to one report run. These are the same on every report and for
# every user, so classifying them "global" instead of "prompt" means the
# Reports dialog only needs to prompt for parameters that are genuinely
# per-report (e.g. WorkCenterID, TaxCode) - see reports_catalog.py's
# "global" source, resolved from global_report_parameters.json. Matched
# case-insensitively against crystal_name. Extend this set if a future
# report turns up another shared formatting parameter under a new name.
GLOBAL_PARAMETER_NAMES = {
    "companyname", "companyphone", "companyfax", "companyemail",
    "vatregnumber", "vatbranchid", "quantitydecimals", "costdecimals",
    "currencysymbol",
}


def _slugify(name: str) -> str:
    """Turns a report filename into a stable, human-readable id.

    "SalesOrder - Copy.rpt" -> "salesorder_copy"
    "Backlog_RFoF_WO.rpt"   -> "backlog_rfof_wo"
    """
    stem = Path(name).stem
    slug = re.sub(r"[^a-zA-Z0-9]+", "_", stem).strip("_").lower()
    return slug or "report"


def _map_value_kind(value_kind: str) -> str:
    return VALUE_KIND_TO_TYPE.get(value_kind, "string")


def _guess_menu(rpt_path: Path, reports_root: Path, menus: list[str]) -> Optional[str]:
    """If the .rpt lives directly under a subfolder named after one of your
    menus (e.g. reports/Demand/Backlog.rpt), guess that as its menu. Case-
    insensitive since folder naming conventions drift. Returns None (leave
    it for manual fill-in) if nothing matches or --menus was passed empty.
    """
    if not menus:
        return None
    try:
        relative_parts = rpt_path.relative_to(reports_root).parts
    except ValueError:
        return None
    if len(relative_parts) < 2:
        # File sits directly in reports_root, no subfolder to guess from.
        return None
    top_folder = relative_parts[0]
    for menu in menus:
        if top_folder.lower() == menu.lower():
            return menu
    return None


def _is_legacy_staging_table(connection: dict[str, Any]) -> bool:
    """True if a table's --inspect connection info has the signature we
    found on SalesOrder_TTX/WorkOrderTraveler_TTX: Crystal only holds a
    cached FIELD-DEFINITIONS-ONLY snapshot of it, not a live connection.
    That means it isn't a table you can point a plain SELECT at - it was a
    per-report staging file the old (pre-Postgres) reporting engine
    generated at report-run-time, and needs the SalesOrder_TTX-style
    reconstruction (join + lookups + computed fields), not a one-line
    TableQueryCatalog entry.

    Checked on two keys rather than one because either alone has been
    observed on the real data: "Attr:Database DLL" == "crdb_fielddef.dll"
    is the mechanism (Crystal's field-definitions-only driver), and
    "Attr:QE_DatabaseType" == "Field Definitions Only" is Crystal's own
    label for the same thing - matching either is enough to flag it.
    """
    dll = connection.get("Attr:Database DLL", "")
    qe_type = connection.get("Attr:QE_DatabaseType", "")
    return dll.strip().lower() == "crdb_fielddef.dll" or qe_type.strip().lower() == "field definitions only"


def _collect_tables(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    """Flattens main-report tables and every subreport's tables into one
    list, same reasoning as _collect_parameters: a report's real table
    requirements are just as often on a subreport as on the main report,
    and BuildReportDataSet has to satisfy all of them regardless of which
    level declared them.
    """
    collected: list[dict[str, Any]] = []
    seen_names: set[str] = set()

    def add(table: dict[str, Any], subreport_name: Optional[str]) -> None:
        name = table.get("name", "")
        dedupe_key = name.lower()
        if dedupe_key in seen_names:
            return
        seen_names.add(dedupe_key)
        connection = table.get("connection", {})
        fields = table.get("fields", [])
        collected.append({
            "name": name,
            "location": table.get("location", ""),
            "field_count": len(fields),
            # Full name/type list, not just the count - writing a
            # TableQueryCatalog entry means aliasing to whatever field
            # name Crystal actually expects (baked into the legacy .rpt,
            # case-sensitive), which field_count alone can't tell you.
            # Guessing this from Postgres column names alone is exactly
            # what caused the earlier casing bug (see ResolveActualColumnAlias
            # in Program.cs) - don't repeat that mistake for 95 more tables.
            "fields": [
                {"name": f.get("name", ""), "value_type": f.get("valueType", "")}
                for f in fields
            ],
            "legacy_staging": _is_legacy_staging_table(connection),
            "subreport": subreport_name,
        })

    for table in manifest.get("tables", []):
        add(table, subreport_name=None)

    for subreport in manifest.get("subreports", []):
        for table in subreport.get("tables", []):
            add(table, subreport_name=subreport.get("name"))

    return collected


def _collect_parameters(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    """Flattens main-report parameters and every subreport's parameters into
    one list, each tagged with which subreport (if any) declares it - a
    report's real prompts are just as often defined on a subreport as on the
    main report (see ApplyParameters in Program.cs, which already searches
    both), so a manifest that only looked at top-level parameters would
    under-report what a legacy report actually asks for.
    """
    collected: list[dict[str, Any]] = []
    seen_names: set[str] = set()

    def add(param: dict[str, Any], subreport_name: Optional[str]) -> None:
        name = param.get("name", "")
        # A parameter genuinely redefined identically on two subreports only
        # needs one manifest entry - ApplyParameters matches by name across
        # the whole report, not per-subreport, so a duplicate here would
        # just be noise to review twice.
        dedupe_key = name.lower()
        if dedupe_key in seen_names:
            return
        seen_names.add(dedupe_key)
        value_kind = param.get("valueKind", "")
        # Known company-wide formatting parameters classify themselves as
        # "global" straight away (see GLOBAL_PARAMETER_NAMES above) - only
        # genuinely report-specific parameters default to "prompt" now.
        # TODO either way: change to "context" where a ZMRP record (open
        # PO, selected part, etc.) should supply this instead.
        source = "global" if name.lower() in GLOBAL_PARAMETER_NAMES else "prompt"
        collected.append({
            "crystal_name": name,
            "value_kind": value_kind,
            "type": _map_value_kind(value_kind),
            "source": source,
            "label": name,       # TODO: replace with a human-friendly label.
            "subreport": subreport_name,
        })

    for param in manifest.get("parameters", []):
        add(param, subreport_name=None)

    for subreport in manifest.get("subreports", []):
        for param in subreport.get("parameters", []):
            add(param, subreport_name=subreport.get("name"))

    return collected


def build_manifest(
    reports_dir: Path,
    worker_exe: Path,
    menus: list[str],
    pattern: str = "*.rpt",
) -> list[dict[str, Any]]:
    pipeline = CrystalReportsPipeline(worker_exe=str(worker_exe))

    # Print exactly which file is about to be launched, and sanity-check its
    # size. WinError 193 ("%1 is not a valid Win32 application") means
    # Windows found *something* at this path but refused to run it - most
    # often a OneDrive Files-On-Demand placeholder that hasn't downloaded
    # yet, or a stale/corrupted build. Printing this up front turns "every
    # report failed identically" from a mystery into an obvious next step,
    # instead of having to reason backward from 87 identical error strings.
    resolved_exe = Path(worker_exe).resolve()
    try:
        exe_size = resolved_exe.stat().st_size
    except OSError:
        exe_size = None
    size_note = f"{exe_size:,} bytes" if exe_size is not None else "could not stat"
    print(f"Using worker exe: {resolved_exe} ({size_note})", file=sys.stderr)
    if exe_size is not None and exe_size < 4096:
        print(
            "WARNING: worker exe is unusually small for a built .NET console "
            "app - this often means a stale/corrupted build or an un-hydrated "
            "OneDrive placeholder rather than the real executable.",
            file=sys.stderr,
        )

    rpt_files = sorted(reports_dir.rglob(pattern))
    if not rpt_files:
        print(f"No files matching '{pattern}' found under {reports_dir}", file=sys.stderr)

    entries: list[dict[str, Any]] = []
    used_ids: dict[str, int] = {}

    for rpt_path in rpt_files:
        relative_path = rpt_path.relative_to(reports_dir)
        base_id = _slugify(rpt_path.name)
        # Guard against two different reports slugifying to the same id
        # (e.g. "Sales Order.rpt" and "Sales_Order.rpt") rather than letting
        # a later entry silently shadow an earlier one in the manifest.
        if base_id in used_ids:
            used_ids[base_id] += 1
            report_id = f"{base_id}_{used_ids[base_id]}"
        else:
            used_ids[base_id] = 0
            report_id = base_id

        entry: dict[str, Any] = {
            "id": report_id,
            "file": str(relative_path).replace("\\", "/"),
            "display_name": rpt_path.stem,
            "menu": _guess_menu(rpt_path, reports_dir, menus),
            "parameters": [],
            "tables": [],
            "error": None,
        }

        print(f"Inspecting {relative_path} ...", file=sys.stderr)
        try:
            manifest = pipeline.inspect_report(str(rpt_path))
        except CrystalReportError as exc:
            entry["error"] = str(exc)
            print(f"  FAILED: {exc}", file=sys.stderr)
        except OSError as exc:
            # winerror is Windows-only (absent entirely on other platforms),
            # hence getattr rather than a plain attribute access.
            hint = ""
            if getattr(exc, "winerror", None) == 193:
                hint = (
                    " -- WinError 193 means Windows couldn't launch the worker "
                    "exe itself (this happens before your report is even read). "
                    "Check that --worker-exe points at a real, fully-downloaded "
                    ".exe: OneDrive Files-On-Demand placeholders and stale/"
                    "corrupted builds both produce exactly this error."
                )
            entry["error"] = f"{type(exc).__name__}: {exc}{hint}"
            print(f"  FAILED: {entry['error']}", file=sys.stderr)
        except Exception as exc:  # noqa: BLE001 - surface anything unexpected in the manifest too
            entry["error"] = f"{type(exc).__name__}: {exc}"
            print(f"  FAILED: {entry['error']}", file=sys.stderr)
        else:
            entry["parameters"] = _collect_parameters(manifest)
            entry["tables"] = _collect_tables(manifest)
            legacy_count = sum(1 for t in entry["tables"] if t["legacy_staging"])
            legacy_note = f", {legacy_count} legacy-staging" if legacy_count else ""
            print(
                f"  OK - {len(entry['parameters'])} parameter(s), "
                f"{len(entry['tables'])} table(s){legacy_note}",
                file=sys.stderr,
            )

        entries.append(entry)

    return entries


def build_table_summary(entries: list[dict[str, Any]]) -> dict[str, Any]:
    """Collapses every report's table list into one inventory keyed by
    distinct table name - this is the actual answer to "how many tables do
    we have to catalog": TableQueryCatalog is keyed by name and reused
    across every report that references it (see BuildReportDataSet), so
    the real unit of work is this dict's length, not len(entries).

    Splits that inventory into "real" tables (cheap - a live connection,
    write a SELECT with column aliases, same shape as the 5 already in
    TableQueryCatalog) and "legacy_staging" tables (expensive - a
    Field-Definitions-Only snapshot of a pre-Postgres per-report staging
    file, needs the SalesOrder_TTX-style reconstruction: joins, lookups,
    computed fields, informed by --inspect's field list, not guessed).
    """
    by_table: dict[str, dict[str, Any]] = {}
    for entry in entries:
        if entry["error"]:
            continue
        for table in entry["tables"]:
            name = table["name"]
            if name not in by_table:
                by_table[name] = {
                    "name": name,
                    "legacy_staging": table["legacy_staging"],
                    "sample_location": table["location"],
                    "field_count": table["field_count"],
                    "fields": table["fields"],
                    "used_by_report_ids": [],
                }
            # legacy_staging is a property of the table's connection, which
            # should be identical everywhere the same name is used - OR
            # lets one true observation win rather than a later false one
            # silently hiding an earlier flagged occurrence.
            by_table[name]["legacy_staging"] = by_table[name]["legacy_staging"] or table["legacy_staging"]
            by_table[name]["used_by_report_ids"].append(entry["id"])

    real_tables = sorted(n for n, t in by_table.items() if not t["legacy_staging"])
    legacy_tables = sorted(n for n, t in by_table.items() if t["legacy_staging"])

    return {
        "distinct_table_count": len(by_table),
        "real_table_count": len(real_tables),
        "legacy_staging_table_count": len(legacy_tables),
        "real_tables": real_tables,
        "legacy_staging_tables": legacy_tables,
        "tables": by_table,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--reports-dir",
        required=True,
        type=Path,
        help="Root folder to recursively search for .rpt files.",
    )
    parser.add_argument(
        "--worker-exe",
        type=Path,
        default=Path(__file__).parent / "CrystalReportWrapper" / "bin" / "Debug" / "net48" / "CrystalReportWrapper.exe",
        help="Path to CrystalReportWrapper.exe (default: the usual Debug build location next to this script).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("reports_manifest.json"),
        help="Where to write the manifest (default: ./reports_manifest.json).",
    )
    parser.add_argument(
        "--tables-output",
        type=Path,
        default=Path("tables_summary.json"),
        help=(
            "Where to write the deduplicated table inventory - the real "
            "answer to 'how many tables do we have to catalog' "
            "(default: ./tables_summary.json)."
        ),
    )
    parser.add_argument(
        "--menus",
        nargs="*",
        default=DEFAULT_MENUS,
        help=f"Menu names to guess from top-level subfolders (default: {' '.join(DEFAULT_MENUS)}). Pass --menus with no values to skip guessing.",
    )
    parser.add_argument(
        "--pattern",
        default="*.rpt",
        help="Glob pattern for report files (default: *.rpt).",
    )
    args = parser.parse_args()

    if not args.reports_dir.is_dir():
        print(f"--reports-dir does not exist or is not a directory: {args.reports_dir}", file=sys.stderr)
        return 1

    entries = build_manifest(
        reports_dir=args.reports_dir,
        worker_exe=args.worker_exe,
        menus=args.menus,
        pattern=args.pattern,
    )

    args.output.write_text(json.dumps(entries, indent=2), encoding="utf-8")

    table_summary = build_table_summary(entries)
    args.tables_output.write_text(json.dumps(table_summary, indent=2), encoding="utf-8")

    succeeded = sum(1 for e in entries if e["error"] is None)
    failed = len(entries) - succeeded
    print(f"\n{len(entries)} report(s) inspected: {succeeded} succeeded, {failed} failed.", file=sys.stderr)
    if failed:
        print("Reports with errors still have a manifest entry (error set, parameters empty) - "
              "review those against TableQueryCatalog before filling in their parameter mapping.", file=sys.stderr)
    print(
        f"\n{table_summary['distinct_table_count']} distinct table(s) across all inspected reports: "
        f"{table_summary['real_table_count']} real, "
        f"{table_summary['legacy_staging_table_count']} legacy-staging (TTX-pattern).",
        file=sys.stderr,
    )
    if table_summary["legacy_staging_tables"]:
        print("Legacy-staging tables (need SalesOrder_TTX-style reconstruction, not a plain SELECT):", file=sys.stderr)
        for name in table_summary["legacy_staging_tables"]:
            used_by = table_summary["tables"][name]["used_by_report_ids"]
            print(f"  - {name} (used by: {', '.join(used_by)})", file=sys.stderr)
    print(f"Manifest written to {args.output}", file=sys.stderr)
    print(f"Table inventory written to {args.tables_output}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
