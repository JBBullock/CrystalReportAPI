"""
reports_catalog.py

The "registry" half of the dynamic reporting pipeline (see
CRYSTAL_REPORTS_PIPELINE_REVIEW.md, section 6). This loads
report_registry.json (built by generate_reports_manifest.py) and
global_report_parameters.json, and answers three questions for whatever
calls it - a script, a test, or eventually ReportsDialog.py:

  1. What reports exist, and which ones belong to a given ZMRP menu?
  2. For one report, what parameters does it need, and where does each
     one's value come from?
  3. Given whatever values the caller actually has on hand (global
     settings, the currently-open record, what the user typed into a
     prompt), what's the final {crystal_name: value} dict to hand
     CrystalReportsPipeline.generate_report()?

Nothing here imports CrystalReportsPipeline or touches Crystal Reports
itself - that's report_renderer.py's job. Keeping this file free of that
dependency means the registry logic (which parameters, from where) can be
unit-tested on any machine, not just one with the Crystal Reports SDK
installed.

PARAMETER SOURCES
------------------
  "global"  - a company-wide formatting value (CompanyName, CurrencySymbol,
              QuantityDecimals, ...) that's the same for every report and
              every user. Comes from global_report_parameters.json.
              generate_reports_manifest.py now classifies these
              automatically at --inspect time (see GLOBAL_PARAMETER_NAMES
              there); apply_global_classification.py upgrades a registry
              that predates that change.
  "context" - comes from whatever record is currently open in ZMRP (e.g.
              opening Reports while a Purchase Order is focused should
              pre-fill PONumber). Looked up in the `context` dict passed
              to resolve_parameters(), keyed by the parameter's
              context_key (falling back to its crystal_name if no
              context_key was set in the registry).
  "prompt"  - anything left over: something genuinely specific to this one
              report run that only a person can supply (e.g. WorkCenterID,
              TaxCode). The Reports dialog should render one input field
              per prompted_parameters() entry, using `label` as the field
              caption.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional


class MissingParameterError(RuntimeError):
    """A parameter had no value available from any source. Raised before
    ever shelling out to CrystalReportWrapper.exe, so a misconfigured
    report fails with a clear "which parameter, which source" message
    instead of a vague ApplyParameters error from the C# side, or - worse
    - a silently-wrong PDF with a blank field in it.
    """


@dataclass
class ReportParameter:
    crystal_name: str
    type: str
    source: str  # "global" | "context" | "prompt"
    label: str
    context_key: Optional[str] = None


@dataclass
class ReportEntry:
    id: str
    file: str
    display_name: str
    menu: Optional[str]
    parameters: list[ReportParameter]
    error: Optional[str] = None
    # TableQueryCatalog table names this report's data is pulled from - the
    # subset that a single-record filter should apply to, not necessarily
    # every table --inspect found. Matched case-insensitively against
    # Crystal's own table names (see Program.cs's TableQueryCatalog /
    # RecordFilter dictionaries), so the lowercase style already in use
    # here (matching PK_MAP's own keys, e.g. "soheader") is fine as-is.
    #
    # Each entry is normally a bare table-name string, meaning "filter this
    # table on the same PK column name as the report's header table" (true
    # for every header/detail pair in this schema - e.g. SOHeader and
    # SODetail both have a "sonumber" column). For a table whose linking
    # column is named differently from the header PK - e.g. billofmaterials
    # lists ["partmaster", "bom"], but BOM's linking column is "Assembly",
    # not PartMaster's PK name "PartNumber" - use a dict instead:
    # {"table": "bom", "column": "Assembly"}. See filter_targets().
    #
    # Empty by default: report_registry.json entries don't have this
    # populated for every report yet (2026-08-25) - it's a manual fill-in
    # pass the user is doing by hand, same as "menu" was, cross-referencing
    # each report's tables (--inspect / CRYSTAL_REPORTS_PIPELINE_REVIEW.md /
    # TableQueryCatalog in Program.cs) against SecureZMRP's PK_MAP. See
    # report_service.render_report_for_record(), which refuses to run for
    # a report with no db_tables rather than silently fetching everything.
    db_tables: list[Any] = field(default_factory=list)

    @property
    def is_renderable(self) -> bool:
        """False for a report whose --inspect call itself failed (see
        generate_reports_manifest.py) - showing these in a picker but
        refusing to open them is more useful than silently omitting them,
        since "why isn't my report in the list" is a harder bug to notice
        than "why does this one show an error".
        """
        return self.error is None

    def filter_targets(self, pk_column: str) -> dict[str, str]:
        """{table_name: column_to_filter_on} for every db_tables entry,
        given the resolved header PK column name (pk_column). A bare
        string entry filters on pk_column as-is; a {"table":..., "column":...}
        entry overrides the column for that one table. See db_tables'
        docstring above for why BOM needs the override form.
        """
        targets: dict[str, str] = {}
        for t in self.db_tables:
            if isinstance(t, dict):
                targets[t["table"]] = t.get("column") or pk_column
            else:
                targets[t] = pk_column
        return targets

    def prompted_parameters(self) -> list[ReportParameter]:
        """What the Reports dialog needs to render an input field for."""
        return [p for p in self.parameters if p.source == "prompt"]

    @property
    def supports_record_filter(self) -> bool:
        """True once db_tables has at least one table filled in - what the
        Reports dialog checks before showing the "record key / *" prompt at
        all. A report with no db_tables (the default today) just runs
        unfiltered, same as before this feature existed.
        """
        return bool(self.db_tables)


class ReportsCatalog:
    def __init__(self, registry_path: Path | str, globals_path: Optional[Path | str] = None):
        self.registry_path = Path(registry_path)
        self._entries: dict[str, ReportEntry] = {}
        self._globals: dict[str, Any] = {}
        self._load_registry()
        if globals_path is not None:
            self._load_globals(Path(globals_path))

    def _load_registry(self) -> None:
        raw = json.loads(self.registry_path.read_text(encoding="utf-8"))
        for item in raw:
            params = [
                ReportParameter(
                    crystal_name=p["crystal_name"],
                    type=p.get("type", "string"),
                    source=p.get("source", "prompt"),
                    label=p.get("label", p["crystal_name"]),
                    context_key=p.get("context_key"),
                )
                for p in item.get("parameters", [])
            ]
            entry = ReportEntry(
                id=item["id"],
                file=item["file"],
                display_name=item.get("display_name", item["id"]),
                menu=item.get("menu"),
                parameters=params,
                error=item.get("error"),
                db_tables=list(item.get("db_tables", [])),
            )
            self._entries[entry.id] = entry

    def _load_globals(self, path: Path) -> None:
        if path.exists():
            self._globals = json.loads(path.read_text(encoding="utf-8"))

    def get(self, report_id: str) -> ReportEntry:
        try:
            return self._entries[report_id]
        except KeyError:
            raise KeyError(f"No report registered with id '{report_id}'") from None

    def for_menu(self, menu_name: str) -> list[ReportEntry]:
        """Reports belonging to one ZMRP menu, renderable ones only - this
        is what ReportsDialog(menu_name=...) should list. Reports whose
        "menu" field hasn't been assigned yet in report_registry.json
        won't show up under any menu until you fill that in by hand; see
        the review's phased plan, step 1.
        """
        return [e for e in self._entries.values() if e.menu == menu_name and e.is_renderable]

    def all_reports(self) -> list[ReportEntry]:
        return list(self._entries.values())

    def unassigned_menu_reports(self) -> list[ReportEntry]:
        """Renderable reports with no menu set yet - the manual cleanup
        queue after a fresh generate_reports_manifest.py run."""
        return [e for e in self._entries.values() if e.menu is None and e.is_renderable]

    def resolve_parameters(
        self,
        report_id: str,
        context: Optional[dict[str, Any]] = None,
        prompted: Optional[dict[str, Any]] = None,
    ) -> dict[str, Any]:
        """Builds the final {crystal_name: value} dict for
        CrystalReportsPipeline.generate_report()'s `parameters` argument.
        Raises MissingParameterError naming exactly which parameter and
        which source came up empty, rather than sending Crystal a partial
        params file and surfacing whatever ApplyParameters' own error
        looks like for that case.
        """
        context = context or {}
        prompted = prompted or {}
        resolved: dict[str, Any] = {}

        for param in self.get(report_id).parameters:
            if param.source == "global":
                if param.crystal_name not in self._globals:
                    raise MissingParameterError(
                        f"'{param.crystal_name}' is marked source=global but has no "
                        f"entry in global_report_parameters.json"
                    )
                resolved[param.crystal_name] = self._globals[param.crystal_name]

            elif param.source == "context":
                key = param.context_key or param.crystal_name
                if key not in context:
                    raise MissingParameterError(
                        f"'{param.crystal_name}' needs context key '{key}' "
                        f"(no record open, or the active record doesn't expose it)"
                    )
                resolved[param.crystal_name] = context[key]

            else:  # "prompt"
                if param.crystal_name not in prompted:
                    raise MissingParameterError(
                        f"'{param.crystal_name}' ({param.label}) needs a value from "
                        f"the Reports dialog's prompt fields"
                    )
                resolved[param.crystal_name] = prompted[param.crystal_name]

        return resolved
