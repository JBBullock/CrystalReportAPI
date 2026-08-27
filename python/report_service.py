"""
report_service.py

The single call-site wrapper the rest of this document's "how do I wire
this up" answer refers to. reports_catalog.ReportsCatalog and
report_renderer.ReportRenderer already do the real work; this module just
saves every caller (ReportsDialog.py, a standalone script, a scheduled
job, a REPL) from having to construct and wire those two objects itself
every time it wants to run one report. The goal is that calling code -
including code in a completely different repo, like SecureZMRP - never
needs to know ReportsCatalog or ReportRenderer exist at all:

    from report_service import render_report
    result = render_report("salesorder", context={"CustomerID": 42})
    print(result.output_path)   # -> .../out/rendered/salesorder.pdf

WHY A MODULE-LEVEL SINGLETON INSTEAD OF A CLASS CALLERS INSTANTIATE
---------------------------------------------------------------------
ReportsCatalog parses report_registry.json once, in __init__ - there's no
reason for two different call sites in the same process (e.g. ZMRP's
Products menu and its Demand menu) to each parse it separately and hold
their own copy. A lazily-built module-level instance means the first
render_report() call anywhere in the process pays the parse cost, and
every call after that (from anywhere) reuses it. reset() exists for the
one case where that caching is wrong: you edited report_registry.json or
global_report_parameters.json and want the *same running process* to pick
up the change without a restart (e.g. iterating on menu assignments with
ZMRP already open).

CONFIGURATION
-------------
REGISTRY_PATH / GLOBALS_PATH / REPORTS_DIR / WORKER_EXE / OUTPUT_DIR below
are resolved relative to this file, which is correct as long as this
module stays inside RPTConvert/. If/when this moves into the SecureZMRP
repo (or SecureZMRP imports it from here via a path/package reference),
swap these five for values SecureZMRP already has - e.g. a config object
or environment variables - rather than relative-to-this-file paths.
"""

from __future__ import annotations

import threading
from pathlib import Path
from typing import Any, Optional

from main import ReportResult
from report_renderer import ReportRenderer
from reports_catalog import ReportsCatalog

HERE = Path(__file__).parent

REGISTRY_PATH = HERE / "report_registry.json"
GLOBALS_PATH = HERE / "global_report_parameters.json"
REPORTS_DIR = HERE / "reports"  # matches the folder each report is
    # actually tested from (see ProgramCommands.md) - "TemplateRPTs" never
    # existed in this checkout, which would have made every report fail
    # through this module even though direct CrystalReportWrapper.exe CLI
    # tests (which always pass --report explicitly) never hit this path.
WORKER_EXE = HERE / "CrystalReportWrapper" / "bin" / "Debug" / "net48" / "CrystalReportWrapper.exe"
OUTPUT_DIR = HERE / "out" / "rendered"

_renderer: Optional[ReportRenderer] = None
# ZMRP's ReportPromptDialog renders through a background QThread
# (BulkReportWorker) rather than the UI thread, and its MDI design lets more
# than one Reports dialog be open at once - so two threads can call
# _get_renderer() concurrently. Without this lock, both could see
# `_renderer is None` and each construct their own ReportsCatalog/
# ReportRenderer (re-parsing report_registry.json) before either assignment
# lands; under CPython's GIL that can't corrupt _renderer itself, but it's
# still wasted work and, briefly, two callers could hold two different
# ReportsCatalog instances rather than the single shared one this module's
# docstring promises. The lock makes first-render initialization a genuine
# one-time cost regardless of how many report threads start at once.
_renderer_lock = threading.Lock()


def _get_renderer() -> ReportRenderer:
    global _renderer
    if _renderer is None:
        with _renderer_lock:
            if _renderer is None:  # re-check: lost the race, another thread already built it
                catalog = ReportsCatalog(registry_path=REGISTRY_PATH, globals_path=GLOBALS_PATH)
                _renderer = ReportRenderer(
                    catalog=catalog,
                    reports_dir=REPORTS_DIR,
                    worker_exe=WORKER_EXE,
                    output_dir=OUTPUT_DIR,
                )
    return _renderer


def render_report(
    report_id: str,
    context: Optional[dict[str, Any]] = None,
    prompted: Optional[dict[str, Any]] = None,
    export_format: str = "PDF",
    record_filters: Optional[dict[str, dict[str, Any]]] = None,
    output_name: Optional[str] = None,
) -> ReportResult:
    """Generate one report and return its ReportResult (output_path on
    success). This is the one function most callers need.

    context:  values pulled from whatever ZMRP record is currently open
              (e.g. {"CustomerID": 42} while a Sales Order is focused).
              Only consulted for parameters the registry marks
              source="context"; see ReportsCatalog.resolve_parameters.
    prompted: values the user typed into the Reports dialog's own input
              fields, for parameters the registry marks source="prompt".
              Call reports_needing_prompt(report_id) first to know which
              fields to render.
    record_filters: low-level - most callers want render_report_for_record()
              instead, which builds this dict for you from a single PK
              column/value. Passed straight through to
              ReportRenderer.render()/CrystalReportsPipeline.generate_report().
    output_name: override the output file's stem - see render_report_for_record,
              which uses this so a bulk run's N records don't collide on
              one output path.

    Raises:
        KeyError: report_id isn't in report_registry.json.
        RuntimeError: the report exists but failed --inspect (needs a
            TableQueryCatalog/data-source fix in Program.cs first).
        reports_catalog.MissingParameterError: a required parameter had
            no value from any source - raised before the C# worker is
            even invoked.
        main.CrystalReportError: the C# worker ran but reported failure.
    """
    return _get_renderer().render(
        report_id,
        context=context,
        prompted=prompted,
        export_format=export_format,
        record_filters=record_filters,
        output_name=output_name,
    )


def render_report_for_record(
    report_id: str,
    pk_column: str,
    pk_value: Any,
    context: Optional[dict[str, Any]] = None,
    prompted: Optional[dict[str, Any]] = None,
    export_format: str = "PDF",
    output_name: Optional[str] = None,
) -> ReportResult:
    """Generate one report filtered to a single record: every table in
    report_db_tables(report_id) gets `WHERE "{pk_column}" = {pk_value}`
    applied in Postgres, before Crystal ever sees the data (see Program.cs's
    BuildReportDataSet/--record-filter).

    pk_column applies to every table in db_tables unless that table
    overrides it (see ReportEntry.filter_targets/db_tables) - this module
    doesn't know what a primary key is or consult any PK mapping itself.
    The caller (ZMRP, via its own PK_MAP - see
    mainDashboard/UI/menuBuilding/menu_config.py) is responsible for
    resolving which column name that should be, typically the scalar PK of
    whichever db_tables entry is the report's "header" table - the same
    column name works for that table's related detail tables too in this
    schema's convention (e.g. "sonumber" is SOHeader's whole PK AND the
    first element of SODetail's composite PK), except where a db_tables
    entry explicitly overrides its column (e.g. BOM's "Assembly").

    output_name: pass a per-record name (e.g. f"{report_id}_{pk_value}")
    when calling this in a loop for the "*" bulk case, so each record's
    PDF gets its own file instead of overwriting the last one.

    Raises:
        ValueError: report_db_tables(report_id) is empty - this report has
            no db_tables configured in report_registry.json yet, so there's
            nothing to filter (see ReportEntry.supports_record_filter).
        (plus everything render_report() can raise)
    """
    entry = _get_renderer().catalog.get(report_id)
    if not entry.supports_record_filter:
        raise ValueError(
            f"Report '{report_id}' has no db_tables configured in "
            f"report_registry.json - add its table name(s) there before "
            f"filtering by record (see ReportEntry.db_tables)."
        )

    record_filters = {
        table: {"column": column, "value": pk_value}
        for table, column in entry.filter_targets(pk_column).items()
    }
    return render_report(
        report_id,
        context=context,
        prompted=prompted,
        export_format=export_format,
        record_filters=record_filters,
        output_name=output_name,
    )


def reports_for_menu(menu_name: str) -> list[str]:
    """Report ids belonging to one ZMRP menu ("Products", "Demand", ...) -
    Unassigned-menu reports (see ReportsCatalog.unassigned_menu_reports)
    never appear here.
    """
    return [entry.id for entry in _get_renderer().catalog.for_menu(menu_name)]


def reports_index_for_menu(menu_name: str) -> dict[str, str]:
    """{display_name: report_id} for one ZMRP menu - what
    menu_config.py's Reports submenu is built from (the dict's keys become
    the arrow-submenu's item labels).
    """
    return {entry.display_name: entry.id for entry in _get_renderer().catalog.for_menu(menu_name)}


def all_reports_index() -> dict[str, str]:
    """{display_name: report_id} across every menu - what mainView.py's
    _special_dispatch builds its Reports entries from. One flat mapping is
    correct (not per-menu) because _MenuBuilder._recursive_add's nested-dict
    branch dispatches every menu's "Reports" submenu through the SAME
    breadcrumb prefix ("Reports", display_name), regardless of which
    top-level menu it's under - see menu_config.py's _with_kitting_submenus
    precedent and the comment on mainView.py's Kitting/DeKitting dispatch
    entries for the same pattern. Requires every renderable report's
    display_name to be unique across the whole registry - true today (52/52
    unique) but worth re-checking if report_registry.json ever gets two
    reports with the same display_name.
    """
    return {
        entry.display_name: entry.id
        for entry in _get_renderer().catalog.all_reports()
        if entry.is_renderable
    }


def report_db_tables(report_id: str) -> list[str]:
    """The TableQueryCatalog table names render_report_for_record() would
    filter for this report - what a Reports dialog checks (via
    ReportEntry.supports_record_filter, or just `bool(report_db_tables(...))`)
    to decide whether to show the record-key/`*` prompt at all, versus just
    running the report immediately the way it does today.
    """
    return list(_get_renderer().catalog.get(report_id).db_tables)


def reports_needing_prompt(report_id: str) -> list[dict[str, str]]:
    """[{"crystal_name": ..., "label": ..., "type": ...}, ...] for the
    parameters a Reports dialog needs to render an input field for, before
    calling render_report(report_id, prompted={...}) with the values the
    user typed in.
    """
    entry = _get_renderer().catalog.get(report_id)
    return [
        {"crystal_name": p.crystal_name, "label": p.label, "type": p.type}
        for p in entry.prompted_parameters()
    ]


def reset() -> None:
    """Drop the cached catalog/renderer so the next render_report() call
    re-reads report_registry.json and global_report_parameters.json from
    disk. Only needed if a long-running process must pick up a registry
    edit without restarting.
    """
    global _renderer
    with _renderer_lock:
        _renderer = None
