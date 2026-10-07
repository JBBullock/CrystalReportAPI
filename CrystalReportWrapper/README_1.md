# CrystalReportWrapper

Crystal Reports only has a .NET SDK, so the Python report service
(`pythonScripts/report_service.py`) starts this exe once per request.

```
POST /render {port, menu, report, filter}
   |
report_api_server.py -> report_service.render()
   |   one JSON request on stdin
   v
CrystalReportWrapper.exe      (Program.cs)
   |   PDF bytes on stdout
   v
HTTP response: application/pdf
```

Nothing is written to disk and nothing is kept between requests.

## Files

| File | What it does |
| --- | --- |
| `Program.cs` | The render flow: load report, read SQL, query Postgres, bind, set parameters, export. |
| `ReportFilter.cs` | Turns the request's filter (equals, `*`/`?` wildcards, operators, dates) into SQL conditions. |
| `ReportSql.cs` | Reads a report's `.sql` file (one query per Crystal table). |
| `DevTools.cs` | `--inspect` and `--extract-sql`, run by hand when setting up a report. Not used by the service. |

## Worker contract

- **stdin**: `{"reportPath", "sqlPath", "port", "filter": {column: match}, "parameters": {name: value}}`
- **stdout**: the PDF (exit code 0), or `{"error": "..."}` (exit code 1 or 2)
- **stderr**: diagnostics only
- **exit code**: 0 rendered, 1 failed, 2 bad request (a malformed filter, or a filter column no table in the report has)
- **environment**: `PG_HOST`, `PG_DATABASE`, `PG_USER`, `PG_PASSWORD`. The port comes from the request.

## Build

Windows, .NET Framework 4.8 and the 32-bit SAP Crystal Reports runtime (13.0.4000):

```
dotnet publish CrystalReportWrapper\CrystalReportWrapper.csproj -c Release
```

## Try one report

```
python main.py --port 5430 --menu Supply --report "Work Order Traveler" --filter wonumber=WO00080002
```
