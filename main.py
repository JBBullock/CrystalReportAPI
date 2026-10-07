"""
main.py - try one report from the command line.

Calls report_service.render() directly (no HTTP, no API key), exactly as the
API's /render route does, and saves the PDF it returns so you can open it.
Saving the file is this test script's doing - the service itself writes
nothing.

    python main.py --port 5430 --menu Supply --report "Work Order Traveler" ^
                   --filter wonumber=WO00080002

    python main.py --port 5430 --menu Demand --report "Sales Order" ^
                   --filter "orderdate>=2026-01-01" --filter "orderdate<=2026-01-31" ^
                   --filter partnumber=CA03*
    (quote any filter that uses < or >, or the command prompt treats it as
    a file redirect)

    python main.py --list          # every menu and report name

Needs PG_HOST, PG_DATABASE, PG_USER and PG_PASSWORD in the project root's
.env file (report_service.py loads it), and a built CrystalReportWrapper.exe.
"""

from __future__ import annotations

import argparse
import logging
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if (HERE / "pythonScripts").is_dir():
    sys.path.insert(0, str(HERE / "pythonScripts"))

import report_service  # noqa: E402  (needs the path line above)


def parse_filter(items: list[str]) -> dict:
    """["sonumber=1234", "orderdate>=2026-01-01", "orderdate<=2026-01-31"]
    -> {"sonumber": "1234", "orderdate": {">=": "2026-01-01", "<=": "2026-01-31"}}
    """
    result: dict = {}
    for item in items:
        found = re.match(r"^([^<>=!]+)(<=|>=|!=|=|<|>)(.*)$", item)
        if not found:
            raise SystemExit(f"--filter takes COLUMN then one of = != < <= > >= then VALUE, got: {item}")
        column, operator, value = found.group(1).strip(), found.group(2), found.group(3)
        result.setdefault(column, {})[operator] = value
    # A lone "=" is sent in the short form, {"sonumber": "1234"}.
    return {c: (ops["="] if list(ops) == ["="] else ops) for c, ops in result.items()}


def main() -> int:
    parser = argparse.ArgumentParser(description="Render one report to a PDF file.")
    parser.add_argument("--list", action="store_true", help="print every menu and report name, then exit")
    parser.add_argument("--port", type=int, help="Postgres port of the database to render from")
    parser.add_argument("--menu", help='e.g. "Supply"')
    parser.add_argument("--report", help='e.g. "Work Order Traveler"')
    parser.add_argument("--filter", action="append", default=[], metavar="COLUMN=VALUE",
                        help='repeatable. Also != < <= > >=, and * ? wildcards. '
                             'Put quotes around one that uses < or >: "orderdate>=2026-01-01"')
    parser.add_argument("--out", default="test_render.pdf", help="where to save the PDF (default: test_render.pdf)")
    args = parser.parse_args()

    # Show the worker's diagnostics (rows fetched per table, filter applied).
    logging.basicConfig(level=logging.INFO, format="%(message)s")

    if args.list:
        for menu, names in report_service.menus().items():
            print(menu)
            for name in names:
                print(f"    {name}")
        return 0

    if args.port is None or not args.menu or not args.report:
        parser.error("--port, --menu and --report are required (or use --list)")

    try:
        pdf = report_service.render(args.port, args.menu, args.report, parse_filter(args.filter))
    except (report_service.ReportNotFound, report_service.BadRequest, report_service.RenderFailed) as exc:
        print(f"{type(exc).__name__}: {exc.args[0]}", file=sys.stderr)
        return 1

    Path(args.out).write_bytes(pdf)
    print(f"{len(pdf):,} bytes -> {Path(args.out).resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
