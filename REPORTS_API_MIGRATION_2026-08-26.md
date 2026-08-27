# Reports Pipeline — Aug 26 Milestones

**Covers:** work done Wednesday, Aug 26, 2026, roughly 14:21–16:24 PDT, across both repos — diffed against `PROJECT_STATUS_AND_REPORTS_INTEGRATION.md`, prepared Aug 24 — the proposal doc, still sitting untouched in the SecureZMRP repo root.

Built from direct reads of both connected repos: on the **SecureZMRP** side, `report_service.py`, `report_client_config.py`, `menu_config.py`'s "report_service import" block, and the `ReportPromptDialog.py` / `.bak_before_https` pair (a clean before/after of the migration). On the **RPTConvert** side, `report_api_server.py`, `requirements_report_api.txt`, `generate_cert.py`, `report_renderer.py`, `Program.cs` and its three same-day `.bak_before_*` snapshots, and both repos' git logs.

---

## 1. The headline change: file-import → hosted server

**Before (what the Aug 24 doc still describes, and what `ReportPromptDialog.py.bak_before_https` shows in code):**

RPTConvert and SecureZMRP lived on the *same machine*. SecureZMRP got at RPTConvert's `report_service.py` by hardcoding RPTConvert's folder onto `sys.path` and importing it directly:

```python
# old ReportPromptDialog.py
_RPTCONVERT_DIR = Path(r"C:\Users\jbullock\OneDrive - Optical Zonu\Desktop\RPTConvert")
if str(_RPTCONVERT_DIR) not in sys.path:
    sys.path.insert(0, str(_RPTCONVERT_DIR))
```

`menu_config.py` and `mainView.py` did the same thing at their own import time. Three separate places, one hardcoded path, one implicit assumption: *both apps run on this box.*

**After (yesterday):**

RPTConvert now runs its own service — `report_api_server.py` — reachable over HTTPS. SecureZMRP no longer reaches across the filesystem for it; it got its **own** `report_service.py`, rewritten from scratch as a thin HTTPS client living in SecureZMRP's own repo root. Same public function names and signatures as the original (`render_report`, `render_report_for_record`, `reports_for_menu`, `reports_index_for_menu`, `all_reports_index`, `report_db_tables`, `reports_needing_prompt`, `reset`), so every call site — `ReportPromptDialog.py`, `BulkReportWorker.py`, `menu_config.py` — needed **zero changes**. Only the import bootstrap changed:

```python
# new ReportPromptDialog.py — the sys.path block above is just gone
# report_service.py is a normal top-level module in SecureZMRP's own repo
# root now (an HTTPS client for RPTConvert's report_api_server.py)
```

```python
# new report_service.py's own docstring, stated plainly:
# "the two apps now run on different machines, so that same-machine
#  bootstrap stopped being possible"
```

That's the real trigger: this wasn't a refactor for its own sake — RPTConvert and SecureZMRP stopped being deployable to the same box, so the cross-repo import *had* to become a network call.

### What the new client actually does

- `requests.Session` with `X-API-Key` header auth and `verify=` pinned to a **local copy of the server's cert** (`report_server_cert.pem`, copied in from RPTConvert's `report_api_certs/` folder) — not system CA trust, a pinned cert.
- Config lives in the new `report_client_config.py`: `API_BASE_URL` (`https://<host>:8443`), `API_KEY`, `CA_CERT_PATH`, `LOCAL_OUTPUT_DIR`, `TIMEOUT_SECONDS` — every one of them overridable by environment variable, so a shop-floor install and a test machine can point at different servers without a code change.
- Config is checked **lazily**, at first render call, not at import — an unconfigured install still boots normally; only the actual report action fails, exactly like a real network outage would.
- Server error codes map back onto the *same exception types* the old in-process version raised (`404→KeyError`, `400→MissingParameterError`, `409→RuntimeError`, `401→ReportServiceError` with a pointed "does your API key match the server's?" message) — so existing `except Exception` blocks in the three call sites needed no changes either.
- `requests>=2.31` is the one new dependency in `requirements.txt`.

### Endpoints the client calls (i.e., `report_api_server.py`'s surface)

| Method | Path |
|---|---|
| POST | `/reports/{report_id}/render` |
| POST | `/reports/{report_id}/render_for_record` |
| GET | `/reports/menu/{menu_name}` |
| GET | `/reports/index/menu/{menu_name}` |
| GET | `/reports/index/all` |
| GET | `/reports/{report_id}/db_tables` |
| GET | `/reports/{report_id}/prompt_params` |

The `{"detail": "..."}` error-body shape and per-status-code semantics are the FastAPI `HTTPException` convention — worth confirming against the actual server file, but that's the strong signal in the client code.

---

## 2. Second milestone: Reports went from "proposal" to actually live

The Aug 24 doc's own status table said, in as many words: *"Reports (all 7 menus) — Not implemented. Falls through to `_fallback_handler`'s 'not yet implemented' dialog on every menu."*

That's no longer true. As of yesterday:

- `menu_config.py` builds a **real per-menu submenu** dynamically — `_reports_submenu()` calls `report_service.reports_index_for_menu(menu_name)` and turns RPTConvert's 101-report catalog into an arrow-submenu of actual report names, the same shape Kitting/DeKitting already use. Clicking "Reports" no longer shows a generic stub dialog.
- `mainView.py`'s `_special_dispatch` wires those dynamically-built `("<Menu>", display_name)` entries to a real `ReportPromptDialog` (imported lazily inside the dispatch handler, wrapped in its own try/except so one bad report entry can't take down the whole menu).
- `BulkReportWorker.py` exists — bulk rendering wasn't in the Aug 24 proposal's scope at all (that doc only sketched a single-report `ReportsDialog` + `QPdfView`); this is new ground beyond what was proposed.
- If `report_service` fails to import, `menu_config.py` degrades gracefully — a logged warning and empty Reports submenus everywhere, rather than an app-wide crash.

### Where this diverges from the Aug 24 proposal, specifically

| Aug 24 doc proposed | What actually got built |
|---|---|
| §10.2: choose between a CLI/subprocess renderer (Option A) or a **local** HTTP microservice on `127.0.0.1` (Option B) | Neither exactly — landed on a **remote** HTTPS service across two machines, with TLS + API-key auth. More than Option B anticipated. |
| §10.5: `ReportRenderer` ABC with `ProcessReportRenderer`/`HttpReportRenderer` implementations, isolating "how the C# side runs" behind one seam | Not built — the HTTP concern is just `report_service.py` directly. Reasonable, since RPTConvert's own `report_service.py` was already the established contract; adding a renderer-abstraction layer on top would have been extra indirection for a decision that's no longer live (it's HTTP, full stop). |
| §10.5: new `ReportsDialog.py` widget using `QPdfDocument`/`QPdfView` | Built as `ReportPromptDialog.py` instead — different name/shape than sketched, plus the unplanned `BulkReportWorker.py`. |
| §10.7: server started as a child process from `main.py`'s `AppController`, lifecycle tied to the app | Moot under the current design — the server isn't local anymore, so SecureZMRP can't start/stop it; it's a standing service on RPTConvert's machine now. |
| §10.4: config file proposed as `%APPDATA%\ManufacturingDatabase\reports_config.json` | Landed as `report_client_config.py`, a plain Python module with env-var overrides, sitting in the repo root next to the new `report_service.py` — simpler, no JSON file. |

Nothing here is a correction to the proposal so much as reality overtaking it mid-implementation: the proposal was written assuming one machine, and that assumption broke before the Option A/B decision even mattered.

### C# side (confirmed directly against RPTConvert's repo — now connected)

`report_api_server.py` is exactly what §1 described: FastAPI + uvicorn, `/health` unauthenticated, everything else behind an `X-API-Key` header check, self-signed TLS from `generate_cert.py` (10-year cert, LAN-only by design — the file's own docstring says to replace the shared key with real per-user auth if this server is ever exposed past the LAN). It's a pure network wrapper — it imports RPTConvert's own `report_service.py` and calls the exact same functions the old in-process SecureZMRP import used to call directly. New dependencies for this piece live in their own `requirements_report_api.txt` (`fastapi`, `uvicorn`, `cryptography`) — kept separate from RPTConvert's main `requirements.txt` on purpose, per that file's own comment, so it's not confused with the also un-pinned deps the rendering pipeline already had.

Below `report_api_server.py`, the actual Crystal Reports rendering path (`CrystalReportWrapper.exe`, invoked via `main.py`'s `CrystalReportsPipeline` / `report_renderer.py`) did get real changes yesterday, per `Program.cs`'s own `.bak_before_*` snapshots (three of them, all from the same ~15:00 PDT window):

1. **Fixed a `LogOnException: Database logon failed` bug.** `report.SetDataSource(reportDataSet)` (the whole-DataSet call) only reliably clears a table's original design-time connection binding for tables authored against an ADO.NET/XML-schema connection. Other tables — including some of the legacy Alliance reports, whose `.rpt` files still point at a `C:\Alliance32\Reports\*.TTX` path that hasn't existed since roughly 2002 — kept trying to log into their *original* provider during `Export()`, unrelated to the Postgres query that already ran successfully. Fix: loop over `report.Database.Tables` and call the **per-table** `SetDataSource()` overload for each one, forcing the swap regardless of the table's original driver.
2. **Added `ORDER BY r.sequenceid`** to the work-order router query (routers/partmaster/workcenters/operationcodes join) — rows were coming back unordered before.
3. Commit `ce6b66b` — *"Reports show in ZMRP"*, 2026-08-26 16:24 PDT — is the culminating commit for the day; `f606308`/`9d579c9` the same afternoon covered "working on pipeline" / "dynamic cr approach" ahead of it.

**Worth flagging, not just noting:** `Program.cs` hardcodes its Postgres connection —

```csharp
private const string PgHost = "127.0.0.1";
private const string PgPort = "5430";
private const string PgDatabase = "postgres";
private const string PgUser = "postgres";
private const string PgPassword = "engineer123";
```

Two separate issues here, both worth a look before this goes further:

- **A plaintext superuser credential is committed to source control**, not a report-scoped, minimally-privileged role. This directly contradicts §10.3 of the Aug 24 proposal doc, which specifically recommended a "push" model precisely to avoid reports having their own separately-managed DB credentials outside the app's own role/table-grant system — and what actually got built is a pull-model connection using the Postgres **`postgres`** superuser, which is a step past what that section was warning against, not a step toward it.
- **`PgHost = "127.0.0.1"` assumes Postgres is reachable on the same machine as `CrystalReportWrapper.exe`.** That's fine today if Postgres genuinely runs on RPTConvert's box, but it's exactly the kind of same-machine assumption that already broke once this year (§1) — worth confirming deliberately rather than by accident, especially since it's directly relevant to §3's containerization question below.

---

## 3. Docker: containerizing `report_api_server`

One hard constraint shapes everything else here: **`report_api_server.py` shells out to `CrystalReportWrapper.exe`, a .NET Framework 4.8 console app built against the SAP Crystal Reports SDK** (confirmed — `CrystalReportWrapper.csproj` targets `net48`, and `bin/Debug/net48/` carries `CrystalDecisions.CrystalReports.Engine.dll` and the other SAP Crystal Reports assemblies alongside it). That SDK is COM-based and Windows-only — there is no Linux build, and no realistic way to run it under Wine reliably for production use. That rules out the usual `python:3.12-slim` Linux image outright. This has to be a **Windows container**, and specifically one built for **.NET Framework** (not .NET Core/5+ — net48 doesn't run on the cross-platform `mcr.microsoft.com/dotnet/runtime` images at all; it needs the `dotnet/framework` family, which only ships as Windows images).

**Before any of the Dockerfile below matters, resolve the `PgHost = "127.0.0.1"` issue from §2.** A container gets its own network namespace — `127.0.0.1` inside the container is the container itself, not whatever machine Postgres actually runs on. If Postgres is NOT on this same machine today, `CrystalReportWrapper.exe` will fail to connect the moment this moves into a container, even though it works fine un-containerized right now (where "127.0.0.1" happens to resolve correctly by accident of both processes sharing one machine). Either confirm Postgres is co-located and plan to keep it that way (e.g. a second container on the same Docker network, or `host.docker.internal`/an explicit LAN IP instead of a loopback address), or parameterize `PgHost` into an environment variable read at startup — small C# change, but one that has to happen before this ships in a container, not after something breaks in prod.

### Recommended shape

```
report-api-server/
├── Dockerfile
├── docker-compose.yml
├── requirements.txt          # fastapi, uvicorn[standard], python-multipart, etc.
├── report_api_server.py
├── report_api_certs/         # cert.pem + key.pem, generated by generate_cert.py
└── CrystalReportWrapper/     # the published C# .exe + its runtime deps
    └── CrystalReportWrapper.exe
```

### Dockerfile

Confirmed against the real files: `report_api_server.py` is FastAPI, run via `uvicorn.run(app, host=HOST, port=PORT, ssl_certfile=CERT_FILE, ssl_keyfile=KEY_FILE)` directly in its own `if __name__ == "__main__"` block (no separate ASGI entrypoint needed), reading `RPTCONVERT_API_KEY` / `RPTCONVERT_API_HOST` / `RPTCONVERT_API_PORT` / `RPTCONVERT_API_CERT` / `RPTCONVERT_API_KEY_FILE` from the environment, and refusing to start at all without `RPTCONVERT_API_KEY` set. Its own extra deps are pinned nowhere (`requirements_report_api.txt`: `fastapi`, `uvicorn`, `cryptography`, deliberately unpinned per that file's own comment) — kept separate from RPTConvert's main `requirements.txt` so this API layer's deps don't get confused with the rendering pipeline's.

```dockerfile
# escape=`
# Windows container — REQUIRED because CrystalReportWrapper.exe is a .NET
# FRAMEWORK 4.8 console app (confirmed via CrystalReportWrapper.csproj's
# net48 target) using the SAP Crystal Reports SDK (COM-based, Windows-only).
# .NET Framework 4.8 does NOT run on the cross-platform dotnet/runtime
# images (those are .NET Core/5+ only) — this must be built on a Windows
# Server Core base with the .NET Framework runtime, not python:slim.
FROM python:3.12-windowsservercore-ltsc2022 AS final

# --- .NET Framework 4.8 runtime for CrystalReportWrapper.exe --------------
# python:*-windowsservercore images don't include .NET Framework. Install
# it explicitly — either via the redistributable installer, or by basing an
# earlier stage on mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2022
# and copying its Framework install into this stage. The installer route is
# shown here for clarity:
COPY ndp48-x86-x64-allos-enu.exe C:\install\
RUN C:\install\ndp48-x86-x64-allos-enu.exe /q /norestart

# --- SAP Crystal Reports runtime -------------------------------------------
# The Crystal Reports runtime redistributable (CRRuntime_64bit_*.msi) has to
# be installed inside the image — it is NOT bundled with the .NET Framework
# runtime, and CrystalDecisions.CrystalReports.Engine.dll (already vendored
# under CrystalReportWrapper/bin/) still needs the native SAP runtime
# registered on the machine it runs on. Stage the installer next to this
# Dockerfile (keep it out of source control — it's a large SAP-licensed
# binary, same as the DLLs already sitting in CrystalReportWrapper/bin/,
# which arguably shouldn't be in git either) and run it here:
COPY CRRuntime_64bit_13_0_38.msi C:\install\
RUN msiexec /i C:\install\CRRuntime_64bit_13_0_38.msi /quiet /norestart

WORKDIR C:\app

# Python side — report_api_server.py's own deps
COPY requirements_report_api.txt .
RUN pip install --no-cache-dir -r requirements_report_api.txt

# report_api_server.py imports report_service.py directly (in-process, same
# repo) - bring the whole set of modules it depends on, not just the
# server file itself.
COPY report_api_server.py report_service.py reports_catalog.py report_renderer.py main.py .
COPY report_api_certs\ .\report_api_certs\
COPY CrystalReportWrapper\bin\Debug\net48\ .\CrystalReportWrapper\bin\Debug\net48\

# API key is deliberately NOT baked in — report_api_server.py refuses to
# start without RPTCONVERT_API_KEY set, by design (see that file's own
# top-of-file docstring). Pass it at `docker run`/compose time.
ENV RPTCONVERT_API_HOST="0.0.0.0"
ENV RPTCONVERT_API_PORT="8443"

EXPOSE 8443

# report_api_server.py already knows how to run itself (uvicorn.run(...)
# inside its own __main__ block) - no separate ASGI command needed.
CMD ["python", "report_api_server.py"]
```

### docker-compose.yml

```yaml
services:
  report-api-server:
    build: .
    image: report-api-server:latest
    ports:
      - "8443:8443"
    environment:
      RPTCONVERT_API_KEY: ${RPTCONVERT_API_KEY}      # from a .env file, not committed
      # See the PgHost note above this Dockerfile — Program.cs currently
      # hardcodes 127.0.0.1 for Postgres and does NOT read this env var
      # yet. Parameterizing it is a prerequisite for this compose file to
      # actually work once Postgres isn't literally co-located.
    volumes:
      # Mount the actual .rpt files and report_registry.json from wherever
      # they live on the host — don't bake 101 report files into the image;
      # they change independently of the server code. reports_catalog.py /
      # report_service.py's REPORTS_DIR-equivalent config should point here.
      - D:\CrystalReports\ZMRP:C:\reports:ro
      # Mount certs read-only too, so rotating the cert doesn't require a
      # rebuild — just a container restart.
      - .\report_api_certs:C:\app\report_api_certs:ro
    restart: unless-stopped
```

### Things worth deciding before this goes to prod, not after

1. **`PgHost = "127.0.0.1"` (§2) — fix or confirm before containerizing.** The one blocker most likely to cause a "works standalone, breaks in the container" surprise. Resolve this first; everything else here is secondary to it.
2. **Windows container host required.** This needs a Windows Server host with the container feature enabled (Docker Desktop in Windows-container mode locally, or a Windows Server 2022 host / Azure Windows container instance in prod) — it will not run on a standard Linux Docker host, EKS/GKE Linux node pools, etc.
3. **Crystal Reports licensing** — confirm the SAP Crystal Reports runtime's license terms permit this kind of redistribution/containerized deployment; that's a licensing question, not a technical one, worth a quick check before baking the MSI into an image that might get pushed to a registry. Worth the same check for the `CrystalDecisions.*.dll` files already committed under `CrystalReportWrapper/bin/` in source control, independent of Docker.
4. **Image size** — Windows Server Core base images are large (multiple GB) before you even add .NET Framework and the Crystal Reports runtime. Budget registry storage and pull time accordingly; this won't behave like a typical slim Python container.
5. **Cert rotation** — `report_client_config.py` on the ZMRP side reads a **local copy** of the cert (`report_server_cert.pem`), not a live fetch — `generate_cert.py`'s own printed instructions say as much ("Copy cert.pem to every SecureZMRP client machine"). Regenerating the server's cert means manually re-copying it to every ZMRP install — worth a runbook entry or a small distribution script once this is containerized and cert rotation becomes more routine.
6. **Health check** — confirmed: `report_api_server.py` already has `GET /health`, deliberately left outside the API-key check ("a plain liveness probe shouldn't require the report-rendering credential"). Wire it into a Dockerfile `HEALTHCHECK` / compose healthcheck block directly — no server-side work needed, just container config:
   ```dockerfile
   HEALTHCHECK --interval=30s --timeout=5s CMD `
     powershell -Command "try { (Invoke-WebRequest -Uri https://localhost:8443/health -SkipCertificateCheck).StatusCode -eq 200 } catch { exit 1 }"
   ```
7. **Don't containerize the credentials along with the code.** Since `PgUser`/`PgPassword` are compiled directly into `Program.cs` today (§2's flagged finding) rather than read from environment/config, baking `CrystalReportWrapper.exe` into an image means the Postgres superuser password ships inside that image layer, in the clear, wherever the image goes (registry, backups, anyone with `docker save`). Worth fixing on the C# side — moving `PgUser`/`PgPassword` to environment variables, same pattern `report_client_config.py` already uses on the SecureZMRP side — before this image exists anywhere beyond a laptop.
