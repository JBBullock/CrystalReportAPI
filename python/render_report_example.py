"""
render_report_example.py

Minimal end-to-end smoke test for the registry -> renderer -> PDF path,
in the same spirit as main.py's own __main__ demo block. Run this after
filling in global_report_parameters.json to confirm the whole chain works
before wiring ReportsDialog.py into ZMRP's menu system.

    python render_report_example.py

Renders "partlist" (a report with zero parameters - proves the basic path
end to end; "regioncodes" was the original example here but it - along
with 6 other reports that never got a menu assigned - was deleted from
report_registry.json on 2026-08-25) and "salesorder" (a report whose
parameters are entirely "global" now - proves global_report_parameters.json
is actually wired up). Swap in "workcenterloads" and pass
prompted={"WorkCenterID": "..."} to also exercise the "prompt" path once
you have a real work center id to test with.
"""

from pathlib import Path

from reports_catalog import ReportsCatalog
from report_renderer import ReportRenderer

HERE = Path(__file__).parent

catalog = ReportsCatalog(
    registry_path=HERE / "report_registry.json",
    globals_path=HERE / "global_report_parameters.json",
)

renderer = ReportRenderer(
    catalog=catalog,
    reports_dir=HERE / "TemplateRPTs",
    worker_exe=HERE / "CrystalReportWrapper" / "bin" / "Debug" / "net48" / "CrystalReportWrapper.exe",
    output_dir=HERE / "out" / "rendered",
)

for report_id in ("partlist", "salesorder"):
    print(f"Rendering '{report_id}' ...")
    result = renderer.render(report_id)
    print(f"  -> {result.output_path}")

print("\nDone. Open the PDFs in out/rendered/ to confirm they look right -"
      " especially salesorder.pdf, since its CompanyName/Phone/etc. fields"
      " are still empty placeholders until you fill in"
      " global_report_parameters.json.")
