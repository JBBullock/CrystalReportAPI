"""
report_api_server.py

HTTPS front door for report_service.py, so SecureZMRP (or any other
caller) can render reports over the network instead of importing this
module directly - built for the "connect the apps over HTTPS" step,
now that SecureZMRP and RPTConvert run on different machines.

This process must run on the SAME machine as CrystalReportWrapper.exe
and the Postgres connection Program.cs's TableQueryCatalog queries
against - it's a thin network wrapper around report_service.py, not a
new rendering engine. Every function this exposes already existed in
report_service.py; nothing here re-implements catalog/render logic.

RUNNING
-------
    pip install -r requirements_report_api.txt
    python generate_cert.py --host <this-machine's-LAN-hostname-or-IP>
    setx RPTCONVERT_API_KEY "<a long random string - share it with
        SecureZMRP's report_client_config.py, NOT by committing it to
        either repo>"
    python report_api_server.py

Defaults to 0.0.0.0:8443. Override with RPTCONVERT_API_HOST /
RPTCONVERT_API_PORT env vars. Uses report_api_certs/cert.pem + key.pem
from generate_cert.py by default - override with RPTCONVERT_API_CERT /
RPTCONVERT_API_KEY_FILE if you keep them elsewhere.

SECURITY
--------
This is LAN-only self-signed TLS (see generate_cert.py) plus a single
shared API key checked via the X-API-Key header (RPTCONVERT_API_KEY env
var here, must match SecureZMRP's report_client_config.py). That's
appropriate for "a shop-floor LAN, not the public internet" - if this
server ever needs to be reachable from outside your network, replace the
shared key with real per-user auth before doing that.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Optional

from fastapi import Depends, FastAPI, Header, HTTPException, Response

import report_service
from main import CrystalReportError
from reports_catalog import MissingParameterError

try:
    from pydantic import BaseModel
except ImportError as exc:
    raise ImportError(
        "pydantic is required (installed automatically with fastapi) - "
        "run: pip install -r requirements_report_api.txt"
    ) from exc

HERE = Path(__file__).parent

API_KEY = os.environ.get("RPTCONVERT_API_KEY")
HOST = os.environ.get("RPTCONVERT_API_HOST", "0.0.0.0")
PORT = int(os.environ.get("RPTCONVERT_API_PORT", "8443"))
CERT_FILE = os.environ.get("RPTCONVERT_API_CERT", str(HERE / "report_api_certs" / "cert.pem"))
KEY_FILE = os.environ.get("RPTCONVERT_API_KEY_FILE", str(HERE / "report_api_certs" / "key.pem"))

if not API_KEY:
    raise RuntimeError(
        "RPTCONVERT_API_KEY is not set - this server refuses to start "
        "without one, since it exposes report rendering (and therefore "
        "Postgres-backed data) to the network. Set it to a long random "
        "string before running this, and put the SAME value in "
        "SecureZMRP's report_client_config.py (or its RPTCONVERT_API_KEY "
        "environment variable)."
    )

app = FastAPI(title="RPTConvert Report API")


def _check_api_key(x_api_key: Optional[str] = Header(default=None)) -> None:
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="missing or invalid X-API-Key")


_AUTH = [Depends(_check_api_key)]


class RenderBody(BaseModel):
    context: Optional[dict[str, Any]] = None
    prompted: Optional[dict[str, Any]] = None
    export_format: str = "PDF"
    record_filters: Optional[dict[str, dict[str, Any]]] = None
    output_name: Optional[str] = None


class RenderForRecordBody(BaseModel):
    pk_column: str
    pk_value: Any
    context: Optional[dict[str, Any]] = None
    prompted: Optional[dict[str, Any]] = None
    export_format: str = "PDF"
    output_name: Optional[str] = None


def _run_catching(fn, *args, **kwargs):
    """Runs one report_service function and maps its exception types to
    HTTP status codes report_client_config.py's report_service.py shim
    knows how to translate back into the SAME exception types the local
    (in-process) report_service.py raises - see that file's
    _raise_for_error for the other half of this contract. Order matters:
    MissingParameterError and CrystalReportError are both RuntimeError
    subclasses, so they're listed before the bare RuntimeError catch.
    """
    try:
        return fn(*args, **kwargs)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except MissingParameterError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except CrystalReportError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"{type(exc).__name__}: {exc}") from exc


def _pdf_response(result) -> Response:
    if not result.success or not result.output_path:
        raise HTTPException(status_code=500, detail=result.error or "render failed with no error message")
    data = Path(result.output_path).read_bytes()
    stem = Path(result.output_path).stem
    return Response(
        content=data,
        media_type="application/pdf",
        headers={"X-Output-Stem": stem},
    )


@app.get("/health")
def health() -> dict:
    # Deliberately NOT behind _check_api_key - a plain liveness probe
    # ("is this machine up at all") shouldn't require the report-rendering
    # credential.
    return {"status": "ok"}


@app.get("/reports/index/menu/{menu_name}", dependencies=_AUTH)
def reports_index_for_menu(menu_name: str) -> dict:
    return _run_catching(report_service.reports_index_for_menu, menu_name)


@app.get("/reports/index/all", dependencies=_AUTH)
def all_reports_index() -> dict:
    return _run_catching(report_service.all_reports_index)


@app.get("/reports/menu/{menu_name}", dependencies=_AUTH)
def reports_for_menu(menu_name: str) -> list:
    return _run_catching(report_service.reports_for_menu, menu_name)


@app.get("/reports/{report_id}/db_tables", dependencies=_AUTH)
def report_db_tables(report_id: str) -> list:
    return _run_catching(report_service.report_db_tables, report_id)


@app.get("/reports/{report_id}/prompt_params", dependencies=_AUTH)
def reports_needing_prompt(report_id: str) -> list:
    return _run_catching(report_service.reports_needing_prompt, report_id)


@app.post("/reports/{report_id}/render", dependencies=_AUTH)
def render(report_id: str, body: RenderBody) -> Response:
    result = _run_catching(
        report_service.render_report,
        report_id,
        context=body.context,
        prompted=body.prompted,
        export_format=body.export_format,
        record_filters=body.record_filters,
        output_name=body.output_name,
    )
    return _pdf_response(result)


@app.post("/reports/{report_id}/render_for_record", dependencies=_AUTH)
def render_for_record(report_id: str, body: RenderForRecordBody) -> Response:
    result = _run_catching(
        report_service.render_report_for_record,
        report_id,
        body.pk_column,
        body.pk_value,
        context=body.context,
        prompted=body.prompted,
        export_format=body.export_format,
        output_name=body.output_name,
    )
    return _pdf_response(result)


if __name__ == "__main__":
    import uvicorn

    if not Path(CERT_FILE).exists() or not Path(KEY_FILE).exists():
        raise SystemExit(
            f"Certificate/key not found at {CERT_FILE} / {KEY_FILE} - run "
            f"generate_cert.py first (see this file's RUNNING section)."
        )

    uvicorn.run(
        app,
        host=HOST,
        port=PORT,
        ssl_certfile=CERT_FILE,
        ssl_keyfile=KEY_FILE,
    )
