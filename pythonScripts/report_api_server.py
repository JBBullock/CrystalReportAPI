"""
report_api_server.py

HTTPS front door for report_service.render(). Stateless: a request comes in,
a PDF (or an error) goes out, and nothing is stored.

    POST /render      X-API-Key: <key>
        {"port": 5430, "menu": "Demand", "report": "Sales Order",
         "filter": {"sonumber": 1234}}
        or, for a report with queries (reports_map.QUERIES):
        {"port": 5430, "menu": "Products", "report": "Part Cross Reference",
         "query": "Query By Part Number", "values": {"partnumber": "CA03*"}}
        filter forms (see CrystalReportWrapper/ReportFilter.cs):
            {"sonumber": 1234}                            equals
            {"partnumber": "CA03*"}                       * any, ? one character
            {"orderdate": {">=": "2026-01-01",            =  !=  <  <=  >  >=
                           "<=": "2026-01-31"}}
        -> 200 application/pdf
        -> 400 bad port / bad filter     -> 404 no such (menu, report)
        -> 401 bad API key               -> 500 the render failed
           (errors are JSON: {"detail": "..."})

    GET /menus        X-API-Key: <key>
        -> {"Products": [{"report": "Bill of Materials", "queries": []},
                         {"group": "Costed BOM", "reports": [{"report": ..., "queries": [...]}]},
                         ...], ...}
           each query: {"label": ..., "prompts": [{"label", "column", "kind"}]}
           (reports_map.menu_tree())
        ?flat=1 -> {"Demand": ["Sales Order", ...], ...}   (the old shape)

    GET /health       (no key)
        -> {"status": "ok"}

RUNNING
    Set RPTCONVERT_API_KEY, PG_HOST, PG_DATABASE, PG_USER and PG_PASSWORD
    (see report_service.py), generate a certificate with generate_cert.py,
    then:  python report_api_server.py
    Listens on 0.0.0.0:8443; override with RPTCONVERT_API_HOST /
    RPTCONVERT_API_PORT, and the certificate paths with RPTCONVERT_API_CERT /
    RPTCONVERT_API_KEY_FILE.

SECURITY
    LAN-only: self-signed TLS plus one shared key in the X-API-Key header.
    Replace the shared key with per-user auth before exposing this beyond
    the shop network.
"""

from __future__ import annotations

import hmac
import os
from pathlib import Path
from typing import Any, Optional

from fastapi import Depends, FastAPI, Header, HTTPException, Response
from pydantic import BaseModel

import report_service

API_KEY = os.environ.get("RPTCONVERT_API_KEY")
HOST = os.environ.get("RPTCONVERT_API_HOST", "0.0.0.0")
PORT = int(os.environ.get("RPTCONVERT_API_PORT", "8443"))
CERT_FILE = os.environ.get("RPTCONVERT_API_CERT", str(report_service.ROOT / "report_api_certs" / "cert.pem"))
KEY_FILE = os.environ.get("RPTCONVERT_API_KEY_FILE", str(report_service.ROOT / "report_api_certs" / "key.pem"))

if not API_KEY:
    raise RuntimeError(
        "RPTCONVERT_API_KEY is not set - this server refuses to start without "
        "one, since it exposes database-backed reports to the network."
    )

app = FastAPI(title="RPTConvert Report API")


def _check_api_key(x_api_key: Optional[str] = Header(default=None)) -> None:
    if x_api_key is None or not hmac.compare_digest(x_api_key.encode(), API_KEY.encode()):
        raise HTTPException(status_code=401, detail="missing or invalid X-API-Key")


_AUTH = [Depends(_check_api_key)]


class RenderRequest(BaseModel):
    port: int
    menu: str
    report: str
    filter: dict[str, Any] = {}
    query: Optional[str] = None
    values: dict[str, Any] = {}


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get("/menus", dependencies=_AUTH)
def menus(flat: bool = False) -> dict:
    return report_service.menus() if flat else report_service.menu_tree()


@app.post("/render", dependencies=_AUTH)
def render(body: RenderRequest) -> Response:
    try:
        pdf = report_service.render(
            body.port, body.menu, body.report, body.filter, query=body.query, values=body.values,
        )
    except report_service.ReportNotFound as exc:
        raise HTTPException(status_code=404, detail=exc.args[0]) from exc
    except report_service.BadRequest as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except report_service.RenderFailed as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    return Response(content=pdf, media_type="application/pdf")


if __name__ == "__main__":
    import uvicorn

    if not Path(CERT_FILE).exists() or not Path(KEY_FILE).exists():
        raise SystemExit(
            f"Certificate/key not found at {CERT_FILE} / {KEY_FILE} - run "
            f"generate_cert.py first."
        )

    uvicorn.run(app, host=HOST, port=PORT, ssl_certfile=CERT_FILE, ssl_keyfile=KEY_FILE)
