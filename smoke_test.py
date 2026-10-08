"""
smoke_test.py - render every report once through the report API.

Unlike `main.py --all`, which calls report_service directly on this machine,
this goes over HTTPS to the running service - so it tests what ZMRP actually
talks to: the Docker container, its fonts, its Crystal runtime and its
database connection.

    python smoke_test.py --port 5430
    python smoke_test.py --port 5430 --menu Products        # one menu only
    python smoke_test.py --port 5430 --url https://192.168.1.50:8443

Every report is requested unfiltered. For each one it prints a pass/fail
line, and it writes into Scratch/smoke/ :
    results.csv          one row per report: status, seconds, size, error
    <menu>__<report>.pdf every PDF that came back, to look at afterwards

Reports with very many rows unfiltered (the indented BOMs above all) may
show as timed out - that is the report being slow, not broken.

Needs only the standard library. The API key is read from .env.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import ssl
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT_DIR = HERE / "Scratch" / "smoke"


def api_key() -> str:
    for line in (HERE / ".env").read_text(encoding="utf-8").splitlines():
        name, _, value = line.partition("=")
        if name.strip() == "RPTCONVERT_API_KEY":
            return value.strip().strip('"')
    raise SystemExit("RPTCONVERT_API_KEY not found in .env")


def call(url: str, key: str, body: dict | None, timeout: int) -> tuple[int, bytes]:
    """One request. Returns (HTTP status, response body); status 0 = no answer."""
    request = urllib.request.Request(
        url,
        data=None if body is None else json.dumps(body).encode("utf-8"),
        headers={"X-API-Key": key, "Content-Type": "application/json"},
        method="GET" if body is None else "POST",
    )
    # The service's certificate is self-signed.
    context = ssl._create_unverified_context()
    try:
        with urllib.request.urlopen(request, timeout=timeout, context=context) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()
    except Exception as exc:  # timeout, connection refused, ...
        return 0, f"{type(exc).__name__}: {exc}".encode("utf-8")


def error_text(body: bytes) -> str:
    text = body.decode("utf-8", "replace")
    try:
        text = str(json.loads(text)["detail"])
    except Exception:
        pass
    return " ".join(text.split())


def main() -> int:
    parser = argparse.ArgumentParser(description="Render every report once through the report API.")
    parser.add_argument("--port", type=int, required=True, help="Postgres port of the database to render from")
    parser.add_argument("--url", default="https://localhost:8443", help="the report API (default: https://localhost:8443)")
    parser.add_argument("--menu", help="only this menu, e.g. Products")
    parser.add_argument("--timeout", type=int, default=180, help="seconds to wait per report (default: 180)")
    args = parser.parse_args()

    key = api_key()
    base = args.url.rstrip("/")

    status, body = call(f"{base}/menus", key, None, 30)
    if status != 200:
        print(f"Could not get the report list from {base}/menus: {status} {error_text(body)}", file=sys.stderr)
        return 1
    menus = json.loads(body)
    if args.menu:
        menus = {m: names for m, names in menus.items() if m.lower() == args.menu.lower()}
        if not menus:
            print(f"No menu named {args.menu!r}", file=sys.stderr)
            return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for old in OUT_DIR.glob("*.pdf"):
        old.unlink()

    rows = []
    for menu, names in menus.items():
        for name in names:
            started = time.time()
            status, body = call(
                f"{base}/render", key,
                {"port": args.port, "menu": menu, "report": name, "filter": {}},
                args.timeout,
            )
            seconds = round(time.time() - started, 1)
            if status == 200 and body.startswith(b"%PDF"):
                file_name = re.sub(r'[\\/:*?"<>|]+', "_", f"{menu}__{name}") + ".pdf"
                (OUT_DIR / file_name).write_bytes(body)
                rows.append([menu, name, "ok", status, seconds, len(body), file_name, ""])
                print(f"ok    {seconds:6.1f}s  {len(body):>10,} bytes  {menu} / {name}", flush=True)
            else:
                detail = error_text(body)
                rows.append([menu, name, "FAIL", status, seconds, 0, "", detail])
                print(f"FAIL  {seconds:6.1f}s  [{status}]  {menu} / {name}\n      {detail[:300]}", flush=True)

    with open(OUT_DIR / "results.csv", "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["menu", "report", "result", "http_status", "seconds", "bytes", "pdf_file", "error"])
        writer.writerows(rows)

    failed = sum(1 for row in rows if row[2] != "ok")
    print(f"\n{len(rows) - failed} of {len(rows)} rendered, {failed} failed")
    print(f"Results: {OUT_DIR / 'results.csv'}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
