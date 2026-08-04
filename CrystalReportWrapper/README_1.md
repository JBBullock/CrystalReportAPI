# Crystal Reports <-> Python Pipeline

Crystal Reports' SDK is C#/.NET-only. This pipeline bridges it into Python
via a subprocess worker instead of trying to run Crystal Reports in-process
inside Python (which isn't supported).

```
Python code
   │  generate_report(report_path, output_path, params)
   ▼
crystal_reports_pipeline.py  ──spawns──►  CrystalReportWrapper.exe (C#)
   ▲                                            │
   │        JSON on stdout: {success, outputPath, error}
   └────────────────────────────────────────────┘
```

## 1. Build the C# worker

Requires Windows + the Crystal Reports SDK installed (the SDK is Windows-only,
so this step can't be done on Linux/macOS).

```bash
cd CrystalReportWrapper
# Point the <Reference HintPath> entries in CrystalReportWrapper.csproj at
# your local Crystal Reports SDK DLLs first, then:
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

This produces `CrystalReportWrapper.exe` under
`bin/Release/net48/win-x64/publish/`.

## 2. Call it from Python

```python
from crystal_reports_pipeline import CrystalReportsPipeline

pipeline = CrystalReportsPipeline(worker_exe=r"C:\tools\CrystalReportWrapper.exe")

result = pipeline.generate_report(
    report_path=r"C:\reports\sales_summary.rpt",
    output_path=r"C:\out\sales_summary.pdf",
    export_format="PDF",
    parameters={"Region": "West", "Year": 2026},
)

print(result.output_path)  # -> C:\out\sales_summary.pdf
```

## Why this shape

- **Isolation**: a crash inside the Crystal Reports SDK kills the worker
  process, not your Python app.
- **Simple contract**: one JSON line on stdout is the entire interface -
  changing internal C# logic never breaks the Python side.
- **No COM/pythonnet dependency**: avoids matching bitness/threading model
  between Python and the .NET runtime.

## Trade-offs to be aware of

- Each call pays for process startup - fine for scheduled/batch reporting,
  less ideal for high-frequency, low-latency calls (in that case, consider
  turning the C# worker into a long-lived local HTTP service instead of a
  per-call subprocess, and having Python call it with `requests`).
- The worker (and therefore Crystal Reports itself) only runs on Windows.
  Your Python code can run anywhere, but wherever `generate_report()`
  actually executes needs Windows + the CR runtime redistributable installed.
