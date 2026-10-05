"""
report_renderer.py

The seam between "what a report needs" (reports_catalog.ReportsCatalog)
and "how to actually run it" (crystal_reports_pipeline.CrystalReportsPipeline).
This is the piece §10.5 of PROJECT_STATUS_AND_REPORTS_INTEGRATION.md called
ProcessReportRenderer - built here against the CLI contract
CrystalReportWrapper.exe actually implements (--output, --params
<jsonfile>) rather than the one that doc guessed at, and reusing
CrystalReportsPipeline directly instead of reimplementing subprocess
plumbing (see CRYSTAL_REPORTS_PIPELINE_REVIEW.md, §5.1).

Nothing here knows about PySide6 or MDI sub-windows - ReportsDialog.py
calls render(), gets back a ReportResult with a PDF path, and hands that
to QPdfDocument. That separation is what makes this testable without a
running ZMRP UI.
"""

from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING, Any, Optional

if TYPE_CHECKING:
    from db_profiles import DbProfile

# NOTE: the pipeline module's own docstring and README_1.md both call it
# "crystal_reports_pipeline.py", but the file on disk in this folder is
# actually named main.py - so it imports as `main`, not
# `crystal_reports_pipeline`. generate_reports_manifest.py was already
# adjusted to match this; matching it here too rather than assuming the
# "intended" name. Renaming main.py -> crystal_reports_pipeline.py (and
# updating both import lines back) is a harmless, optional cleanup
# whenever you want it - nothing here depends on which name wins.
from main import CrystalReportsPipeline, ReportResult
from reports_catalog import ReportEntry, ReportsCatalog


class ReportRenderer:
    def __init__(
        self,
        catalog: ReportsCatalog,
        reports_dir: Path | str,
        worker_exe: Path | str,
        output_dir: Path | str,
    ):
        self.catalog = catalog
        self.reports_dir = Path(reports_dir)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.pipeline = CrystalReportsPipeline(worker_exe=str(worker_exe))

    def render(self, report_id: str, **kwargs: Any) -> ReportResult:
        """render_entry for a registry id. KeyError if the id is unknown."""
        return self.render_entry(self.catalog.get(report_id), **kwargs)

    def render_entry(
        self,
        entry: ReportEntry,
        context: Optional[dict[str, Any]] = None,
        prompted: Optional[dict[str, Any]] = None,
        export_format: str = "PDF",
        record_filters: Optional[dict[str, dict[str, Any]]] = None,
        output_name: Optional[str] = None,
        db_profile: Optional["DbProfile"] = None,
        sql_file: Optional[Path | str] = None,
    ) -> ReportResult:
        """Resolves this report's parameters (see ReportsCatalog.resolve_parameters
        for what "context" and "prompted" mean) and renders it via the existing
        C# worker. Raises MissingParameterError (from reports_catalog) if a
        parameter can't be resolved, or CrystalReportError (from
        crystal_reports_pipeline) if the worker itself fails.

        record_filters: passed straight through to
            CrystalReportsPipeline.generate_report() - see its docstring.
            Callers normally get this from report_service.render_report_for_record()
            rather than building it by hand.
        output_name: override the output file's stem (default: entry.id) -
            report_service's bulk path uses this so N records don't all
            collide on the same output path.
        db_profile: which database to fetch from (see db_profiles.resolve).
            None = whatever PG_* this process already has (legacy). Output
            goes in a per-profile subfolder so two users on different
            databases rendering the same report can't overwrite each
            other's PDF.
        sql_file: the .sql file holding this report's queries (see
            reports_map.REPORT_SQL). None = the worker looks for
            SQLqueries/<report name>.sql itself.
        """
        if not entry.is_renderable:
            raise RuntimeError(
                f"Report '{entry.id}' failed --inspect ({entry.error}) - it needs "
                f"a TableQueryCatalog/data-source fix (see Program.cs) before it "
                f"can be rendered, independent of anything on the Python side."
            )

        parameters = self.catalog.resolve_entry_parameters(entry, context=context, prompted=prompted)
        report_path = self.reports_dir / entry.file
        stem = output_name or entry.id
        out_dir = self.output_dir / db_profile.name if db_profile else self.output_dir
        out_dir.mkdir(parents=True, exist_ok=True)
        output_path = out_dir / f"{stem}.{export_format.lower()}"

        return self.pipeline.generate_report(
            report_path=str(report_path),
            output_path=str(output_path),
            export_format=export_format,
            parameters=parameters,
            record_filters=record_filters,
            db_env=db_profile.worker_env() if db_profile else None,
            sql_file=str(sql_file) if sql_file else None,
        )
