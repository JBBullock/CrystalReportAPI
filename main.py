"""
crystal_reports_pipeline.py

PURPOSE
-------
SAP Crystal Reports only ships a C#/.NET SDK - there is no native Python
SDK. This module bridges that gap by treating a small compiled C# worker
(CrystalReportWrapper.exe, see CrystalReportWrapper/Program.cs) as an
external tool: Python launches it as a subprocess, passes it what report
to run and with which parameters, and reads back a JSON result.

EXECUTION FLOW
---------------
  1. Caller invokes `generate_report(...)` with a report path, output
     path, export format, and an optional dict of report parameters.
  2. If parameters are given, they are written to a temporary JSON file
     (the C# side reads parameters from a file rather than inline args
     to avoid command-line length/escaping issues with complex values).
  3. The module builds a subprocess command line for the worker exe and
     runs it, capturing stdout/stderr.
  4. The worker prints exactly one JSON line describing success/failure;
     this module parses that line into a `ReportResult`.
  5. On success, `ReportResult.output_path` points to the exported file
     (PDF/XLSX/CSV/etc.) ready for the rest of the Python pipeline to
     pick up (e.g. attach to an email, upload to storage, etc.).
  6. On failure, a `CrystalReportError` is raised with the message the
     C# side reported, so calling code can handle/log it like any other
     Python exception.

WHY A SUBPROCESS INSTEAD OF PYTHONNET/COM INTEROP
--------------------------------------------------
pythonnet or COM interop (win32com) can call the Crystal Reports .NET
assemblies in-process, but that ties your Python process's bitness,
STA/threading model, and .NET runtime version to Crystal's requirements,
and a crash inside the SDK can take down the whole Python process. A
subprocess worker is slower to start per-call, but is isolated, easy to
retry, and easy to run on a machine where only the worker (not your full
Python app) needs to live on Windows.
"""

from __future__ import annotations

import json
import subprocess
import tempfile
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


class CrystalReportError(RuntimeError):
    """Raised when the Crystal Reports worker process reports a failure
    (bad report path, invalid parameter, licensing error, export failure,
    etc). The message is passed through verbatim from the C# side.
    """


@dataclass
class ReportResult:
    """Structured result of a single report generation call."""
    success: bool
    output_path: Optional[str]
    error: Optional[str]


class CrystalReportsPipeline:
    """
    Thin Python-side client for the CrystalReportWrapper worker process.

    Usage:
        pipeline = CrystalReportsPipeline(worker_exe="C:/tools/CrystalReportWrapper.exe")
        result = pipeline.generate_report(
            report_path="C:/reports/sales.rpt",
            output_path="C:/out/sales.pdf",
            export_format="PDF",
            parameters={"Region": "West", "Year": 2026},
        )
        print(result.output_path)
    """

    def __init__(self, worker_exe: str, timeout_seconds: int = 120):
        """
        Args:
            worker_exe: Absolute path to the published CrystalReportWrapper.exe.
            timeout_seconds: How long to wait for a single report export
                before treating it as hung and raising a TimeoutExpired.
        """
        self.worker_exe = worker_exe
        self.timeout_seconds = timeout_seconds

        if not Path(worker_exe).exists():
            # Fail fast and clearly rather than letting subprocess raise a
            # less-obvious "file not found" error later.
            raise FileNotFoundError(
                f"Crystal Reports worker not found at: {worker_exe}"
            )

    def generate_report(
        self,
        report_path: str,
        output_path: str,
        export_format: str = "PDF",
        parameters: Optional[dict] = None,
    ) -> ReportResult:
        """
        Run a single Crystal Reports export end-to-end.

        Args:
            report_path: Path to the .rpt file to render.
            output_path: Where the exported file should be written.
            export_format: One of "PDF", "EXCEL"/"XLSX", "CSV", "WORD"/"DOCX"
                (matched case-insensitively by the C# worker).
            parameters: Optional dict of report parameter name -> value,
                e.g. {"Region": "West", "Year": 2026}. Keys must match the
                parameter names defined inside the .rpt file.

        Returns:
            ReportResult with success=True and output_path set on success.

        Raises:
            CrystalReportError: if the worker process reports a failure.
            subprocess.TimeoutExpired: if the worker hangs past timeout_seconds.
        """
        params_file = None
        try:
            # Step 1: stage parameters as a temp JSON file, if provided.
            # A file (rather than an inline --params '{"a": 1}' arg) sidesteps
            # shell-quoting headaches with special characters/unicode values.
            if parameters:
                print("Parameters are True")
                params_file = self._write_params_file(parameters)

            # Step 2: build and run the subprocess command.
            # print("OUTPUT PATH", out_path)
            command = self._build_command(report_path, output_path, export_format, params_file)
            # print("Command sent to sub process", command)
            completed = subprocess.run(
                command,
                capture_output=True,
                text=True,
                timeout=self.timeout_seconds,
            )
            print(completed.stdout)
            # print(completed.stderr)

            # Step 3: parse the single JSON line the worker printed.
            return self._parse_worker_output(completed.stdout, completed.stderr)

        finally:
            # Step 4: always clean up the temp params file, success or failure.
            if params_file and os.path.exists(params_file):
                os.remove(params_file)

    def inspect_report(self, report_path: str) -> dict:
        """
        Runs the worker in --inspect mode: loads report_path but never
        touches Postgres or exports anything. Returns the parsed JSON
        manifest describing the report's tables (name, location, and
        each field's name/type), formula field text (so UFL-dependent
        formulas like MFGFunctionsTranslationTranslate are visible),
        and parameters - for the main report and every subreport.

        Use this to build/verify a mock table's schema against what a
        legacy report actually expects, instead of discovering column
        name/case mismatches one export failure at a time.

        Raises:
            CrystalReportError: if the worker itself failed (e.g. bad
                report path, corrupt .rpt). Note this is independent of
                whether the report could actually be *exported* -
                --inspect never attempts data binding/export.
        """
        command = [self.worker_exe, "--report", str(report_path), "--inspect"]
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=self.timeout_seconds,
        )
        return self._parse_json_line(completed.stdout, completed.stderr)

    def _parse_json_line(self, stdout: str, stderr: str) -> dict:
        """Shared helper: takes the last non-empty stdout line, parses it
        as JSON, and raises CrystalReportError on any failure signal.
        """
        lines = [line for line in stdout.strip().splitlines() if line.strip()]
        if not lines:
            raise CrystalReportError(
                f"Worker produced no output. stderr: {stderr.strip()}"
            )

        try:
            payload = json.loads(lines[-1])
        except json.JSONDecodeError as exc:
            raise CrystalReportError(
                f"Could not parse worker output as JSON: {lines[-1]!r}. "
                f"stderr: {stderr.strip()}"
            ) from exc

        if not payload.get("success", False):
            raise CrystalReportError(payload.get("error") or "Unknown Crystal Reports worker error")

        return payload

    def _write_params_file(self, parameters: dict) -> str:
        """Writes report parameters to a temp JSON file and returns its path."""
        fd, path = tempfile.mkstemp(suffix=".json", prefix="crystal_params_")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(parameters, f)
        return path

    def _build_command(
        self,
        report_path: str,
        output_path: str,
        export_format: str,
        params_file: Optional[str],
    ) -> list[str]:
        """Assembles the argv list passed to subprocess.run for the worker exe."""
        command = [
            self.worker_exe,
            "--report", report_path,
            "--output", output_path,
            "--format", export_format,
        ]
        if params_file:
            command += ["--params", params_file]
        return command

    def _parse_worker_output(self, stdout: str, stderr: str) -> ReportResult:
        """
        Parses the worker's stdout JSON line into a ReportResult, raising
        CrystalReportError if the worker signaled failure (or produced no
        parseable JSON at all, e.g. it crashed before reaching its own
        try/catch).
        """
        # The worker prints exactly one line of JSON; take the last
        # non-empty line defensively in case anything else got written
        # to stdout (e.g. SDK warnings).
        lines = [line for line in stdout.strip().splitlines() if line.strip()]
        if not lines:
            raise CrystalReportError(
                f"Worker produced no output. stderr: {stderr.strip()}"
            )

        try:
            payload = json.loads(lines[-1])
        except json.JSONDecodeError as exc:
            raise CrystalReportError(
                f"Could not parse worker output as JSON: {lines[-1]!r}. "
                f"stderr: {stderr.strip()}"
            ) from exc

        result = ReportResult(
            success=payload.get("success", False),
            output_path=payload.get("outputPath"),
            error=payload.get("error"),
        )

        if not result.success:
            raise CrystalReportError(result.error or "Unknown Crystal Reports error")

        return result


# -----------------------------------------------------------------------
# Example usage / manual smoke test.
# Run directly with: python crystal_reports_pipeline.py
# -----------------------------------------------------------------------
if __name__ == "__main__":
    parent_folder_path = Path(__file__).parents[0]

    worker_path = parent_folder_path / "CrystalReportWrapper"/"bin"/"Debug"/"net48" / "CrystalReportWrapper.exe"
    # worker_path = Path("C:\\Users\\jbullock\\OneDrive - Optical Zonu\\Desktop\\RPTConvert\\CrystalReportWrapper\\bin\\Debug\\net48\\CrystalReportWrapper.exe").as_posix()
    report_path = parent_folder_path / "CrystalReportWrapper" / "2016-RegionCodes.rpt"
    out_path = parent_folder_path / "out" / "output.json"
    
    pipeline = CrystalReportsPipeline(
        worker_path
    )
    manifest = pipeline.inspect_report(report_path)
    print(json.dumps(manifest, indent=2))

    # out_path was "output.json" with export_format="PDF" - mismatched
    # extension, fixed to match the actual export format below.
    out_path = parent_folder_path / "out" / "output.pdf"

    result = pipeline.generate_report(
        report_path,
        out_path,
        export_format="PDF",
        params={"Month_req": "March", "Month_ordered": "August", "Year_ordered": 2026}
    )

    print(f"Report generated at: {result.output_path}")
