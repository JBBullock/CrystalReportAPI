"""
report_service.py

Renders one report: render(port, menu, report, filter) -> PDF bytes.

Stateless. Nothing is written to disk and nothing is kept between calls;
every call runs the same five steps, top to bottom:

    1. Check the port.
    2. Look up (menu, report) in reports_map.py -> the .rpt and .sql files.
    3. Start CrystalReportWrapper.exe and send it one JSON request on stdin.
    4. The worker loads the report, runs its SQL against Postgres on that
       port, and writes the PDF to stdout (see CrystalReportWrapper/Program.cs).
    5. Return those bytes.

Crystal Reports has no Python SDK, which is why step 4 is a separate C#
process. A fresh process per request also means a crash inside the Crystal
runtime cannot take the API down or leak anything into the next request.

CONFIGURATION (environment variables, read once at startup)
    PG_HOST, PG_DATABASE, PG_USER, PG_PASSWORD
        The Postgres server and the report service's own login. Read by the
        worker, which inherits this process's environment. The port is the
        only connection value that comes from the request.
    RPTCONVERT_ALLOWED_PORTS
        Optional. Comma-separated ports the service may connect to, e.g.
        "5430,5431". Unset = any port.
    RPTCONVERT_WORKER_EXE
        Optional. Path to CrystalReportWrapper.exe.

jsonInspections/global_report_parameters.json holds the values for report
parameters (CompanyName, QuantityDecimals, ...). It is sent whole with every
request; the worker uses the ones the report defines.
"""

from __future__ import annotations

import json
import logging
import os
import subprocess
from pathlib import Path
from typing import Any, Mapping, Optional

import reports_map

log = logging.getLogger("report_service")

HERE = Path(__file__).resolve().parent
# pythonScripts/ on the host; flattened into the app root in the Docker image.
ROOT = HERE.parent if (HERE.parent / "reports").is_dir() else HERE

REPORTS_DIR = ROOT / "reports"
SQL_DIR = ROOT / "SQLqueries"
PARAMETERS_PATH = ROOT / "jsonInspections" / "global_report_parameters.json"
WORKER_EXE = Path(os.environ.get(
    "RPTCONVERT_WORKER_EXE",
    str(ROOT / "CrystalReportWrapper" / "bin" / "Release" / "net48" / "CrystalReportWrapper.exe"),
))
WORKER_TIMEOUT_SECONDS = 120

ALLOWED_PORTS = frozenset(
    int(p) for p in os.environ.get("RPTCONVERT_ALLOWED_PORTS", "").replace(",", " ").split()
)
# utf-8-sig: tolerate a BOM if the file was saved from a Windows editor.
REPORT_PARAMETERS: dict[str, Any] = json.loads(PARAMETERS_PATH.read_text(encoding="utf-8-sig"))

# Worker exit codes - see Program.cs.
_EXIT_RENDERED = 0
_EXIT_BAD_REQUEST = 2


class ReportNotFound(KeyError):
    """No report with that (menu, name) in reports_map.REPORTS."""


class BadRequest(ValueError):
    """The request itself is wrong: bad port, bad filter value, or a filter
    column that no table in the report has."""


class RenderFailed(RuntimeError):
    """The request was fine but the report could not be rendered."""


def render(port: int, menu: str, report: str, filter: Optional[Mapping[str, Any]] = None) -> bytes:
    """Render one report to PDF and return the bytes.

    port:   the Postgres port of the database to render from.
    menu, report: the report's menu and display name, as in reports_map.REPORTS
            (e.g. "Products", "Bill of Materials").
    filter: {column name: value}, e.g. {"sonumber": 1234}. Narrows every table
            in the report that has that column. More than one key means AND.
            Empty or None renders the whole report.
    """
    filter = dict(filter or {})

    # 1. Check the request.
    if isinstance(port, bool) or not isinstance(port, int) or not 1 <= port <= 65535:
        raise BadRequest(f"port must be a whole number from 1 to 65535, got {port!r}")
    if ALLOWED_PORTS and port not in ALLOWED_PORTS:
        raise BadRequest(f"port {port} is not one of this service's databases")
    for column, value in filter.items():
        if not isinstance(value, (str, int, float, bool)):
            raise BadRequest(f"filter value for '{column}' must be text, a number or true/false")

    # 2. Which files is this report?
    try:
        rpt_file = reports_map.REPORTS[(menu, report)]
    except KeyError:
        raise ReportNotFound(f"No report named '{report}' under menu '{menu}'") from None
    sql_file = reports_map.sql_for(rpt_file)
    if sql_file is None:
        raise RenderFailed(f"{rpt_file} has no entry in reports_map.REPORT_SQL")

    # 3-4. Run the worker: request on stdin, PDF on stdout.
    request = {
        "reportPath": str(REPORTS_DIR / rpt_file),
        "sqlPath": str(SQL_DIR / sql_file),
        "port": port,
        "filter": filter,
        "parameters": REPORT_PARAMETERS,
    }
    try:
        worker = subprocess.run(
            [str(WORKER_EXE)],
            input=json.dumps(request).encode("utf-8"),
            capture_output=True,
            timeout=WORKER_TIMEOUT_SECONDS,
        )
    except FileNotFoundError:
        raise RenderFailed(f"Crystal Reports worker not found at {WORKER_EXE}") from None
    except subprocess.TimeoutExpired:
        raise RenderFailed(f"Report did not finish within {WORKER_TIMEOUT_SECONDS} seconds") from None

    if worker.stderr:
        log.info("worker [%s / %s]:\n%s", menu, report, worker.stderr.decode("utf-8", "replace").rstrip())

    # 5. The PDF, or the worker's error.
    if worker.returncode == _EXIT_RENDERED:
        return worker.stdout
    message = _worker_error(worker)
    if worker.returncode == _EXIT_BAD_REQUEST:
        raise BadRequest(message)
    raise RenderFailed(message)


def menus() -> dict[str, list[str]]:
    """{menu: [report names]} - what a client builds its Reports menus from."""
    return reports_map.menus()


def _worker_error(worker: subprocess.CompletedProcess) -> str:
    """On failure the worker's stdout is {"error": "..."} instead of a PDF."""
    try:
        return str(json.loads(worker.stdout.decode("utf-8"))["error"])
    except (ValueError, KeyError, TypeError):
        # It died before it could report (e.g. the Crystal runtime is missing).
        detail = worker.stderr.decode("utf-8", "replace").strip() or "no output"
        return f"Worker exited with code {worker.returncode}: {detail}"
