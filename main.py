"""
main.py - try one report from the command line.

Calls report_service.render() directly (no HTTP, no API key), exactly as the
API's /render route does, and saves the PDF it returns so you can open it.
Saving the file is this test script's doing - the service itself writes
nothing.

    python main.py --port 5430 --menu Supply --report "Work Order Traveler" ^
                   --filter wonumber=WO00080002

    python main.py --list          # every menu and report name

Needs PG_HOST, PG_DATABASE, PG_USER and PG_PASSWORD, and a built
CrystalReportWrapper.exe (see pythonScripts/report_service.py). The four
variables are read from the .env file beside this script; one already set in
your shell wins over the file. (In Docker, Compose loads .env instead.)
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if (HERE / "pythonScripts").is_dir():
    sys.path.insert(0, str(HERE / "pythonScripts"))

# Load .env into this process's environment. The worker is started by
# report_service and inherits it.
ENV_FILE = HERE / ".env"
if ENV_FILE.is_file():
    for line in ENV_FILE.read_text(encoding="utf-8-sig").splitlines():
        name, separator, value = line.strip().partition("=")
        if separator and name and not name.startswith("#"):
            os.environ.setdefault(name.strip(), value.strip().strip('"'))

import report_service  # noqa: E402  (needs the path and .env lines above)


def parse_filter(pairs: list[str]) -> dict[str, str]:
    """["sonumber=1234", ...] -> {"sonumber": "1234", ...}"""
    result = {}
    for pair in pairs:
        column, separator, value = pair.partition("=")
        if not separator or not column:
            raise SystemExit(f"--filter takes column=value, got: {pair}")
        result[column] = value
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Render one report to a PDF file.")
    parser.add_argument("--list", action="store_true", help="print every menu and report name, then exit")
    parser.add_argument("--port", type=int, help="Postgres port of the database to render from")
    parser.add_argument("--menu", help='e.g. "Supply"')
    parser.add_argument("--report", help='e.g. "Work Order Traveler"')
    parser.add_argument("--filter", action="append", default=[], metavar="COLUMN=VALUE",
                        help="repeat for more than one column")
    parser.add_argument("--out", default="test_render.pdf", help="where to save the PDF (default: test_render.pdf)")
    args = parser.parse_args()

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
