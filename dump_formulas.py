"""
dump_formulas.py - list every report formula that calls the legacy program's
Crystal add-on (CRUFLMFGFunctions.dll), and ask that add-on what each label
number means.

Run it on a machine where the ORIGINAL Alliance/MFG program is installed
(this work PC), not in the container:

    python dump_formulas.py

It writes two files into Scratch/smoke/ :
    formulas.json   per report: the formulas that call MFGFunctions..., in full
    formulas_all.json   per report: every formula, for reading a failing one
    labels.json     label number -> the text the legacy program shows for it,
                    plus its alternate-row colour and decimal preferences

ReportFormulas.cs needs both to replace those calls with plain text, so the
reports render where the legacy program is not installed.

The second file is best effort: if the add-on cannot answer without the
legacy program running, labels.json says why and formulas.json is still
written.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT_DIR = HERE / "Scratch" / "smoke"
WORKER_CANDIDATES = [
    HERE / "CrystalReportWrapper" / "bin" / "Release" / "net48" / "CrystalReportWrapper.exe",
    HERE / "CrystalReportWrapper" / "bin" / "Debug" / "net48" / "CrystalReportWrapper.exe",
    HERE / "CrystalReportWrapper" / "bin" / "Release" / "net48" / "publish" / "CrystalReportWrapper.exe",
]
PREFERENCES = ["AlternateRowColor_R", "AlternateRowColor_G", "AlternateRowColor_B", "QuantityDecimals", "CostDecimals"]


def inspect(worker: Path, report: Path) -> dict:
    done = subprocess.run([str(worker), "--report", str(report), "--inspect"], capture_output=True, timeout=120)
    lines = [line for line in done.stdout.decode("utf-8", "replace").splitlines() if line.strip().startswith("{")]
    if not lines:
        return {"success": False, "error": done.stderr.decode("utf-8", "replace").strip()[-400:] or "no output"}
    return json.loads(lines[-1])


def legacy_formulas(result: dict) -> list[dict]:
    found = []
    sections = [("", result)] + [(sub.get("name", ""), sub) for sub in result.get("subreports") or []]
    for subreport, section in sections:
        for formula in section.get("formulas") or []:
            text = formula.get("text") or ""
            if "mfgfunctions" in text.lower():
                found.append({"subreport": subreport, "name": formula.get("name", ""), "text": text})
    return found


def all_formulas(result: dict) -> list[dict]:
    """Every formula, legacy or not - for reading a failing one in full."""
    found = []
    sections = [("", result)] + [(sub.get("name", ""), sub) for sub in result.get("subreports") or []]
    for subreport, section in sections:
        for formula in section.get("formulas") or []:
            found.append({"subreport": subreport, "name": formula.get("name", ""), "text": formula.get("text") or ""})
    return found


def ask_addon(ids: list[int]) -> dict:
    """Ask CRUFLMFGFunctions.dll (32-bit COM) for the labels, via 32-bit PowerShell."""
    powershell = Path(os.environ.get("WINDIR", r"C:\Windows")) / "SysWOW64" / "WindowsPowerShell" / "v1.0" / "powershell.exe"
    if not powershell.exists():
        return {"errors": [f"32-bit PowerShell not found at {powershell}"]}
    result_path = OUT_DIR / "_labels_raw.json"
    script_path = OUT_DIR / "_labels.ps1"
    script = f"""
$out = @{{ labels = @{{}}; preferences = @{{}}; errors = @() }}
try {{
    $t = New-Object -ComObject CRUFLMFGFunctions.Translation
    foreach ($id in @({",".join(str(i) for i in ids) or "0"})) {{
        try {{ $out.labels["$id"] = [string]$t.Translate([int]$id) }}
        catch {{ $out.errors += "Translate($id): " + $_.Exception.Message }}
    }}
}} catch {{ $out.errors += "Translation: " + $_.Exception.Message }}
try {{
    $p = New-Object -ComObject CRUFLMFGFunctions.Preferences
    foreach ($n in @({",".join("'" + n + "'" for n in PREFERENCES)})) {{
        try {{ $out.preferences[$n] = $p.GetType().InvokeMember($n, 'InvokeMethod,GetProperty', $null, $p, @()) }}
        catch {{ $out.errors += "Preferences.$n : " + $_.Exception.Message }}
    }}
}} catch {{ $out.errors += "Preferences: " + $_.Exception.Message }}
$out | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 -LiteralPath '{result_path}'
"""
    script_path.write_text(script, encoding="utf-8-sig")
    try:
        done = subprocess.run(
            [str(powershell), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script_path)],
            capture_output=True, timeout=90,
        )
    except subprocess.TimeoutExpired:
        return {"errors": ["The add-on did not answer within 90 seconds (it may be waiting on a login window)."]}
    finally:
        script_path.unlink(missing_ok=True)
    if not result_path.exists():
        return {"errors": ["PowerShell wrote no result: " + done.stderr.decode("utf-8", "replace").strip()[-400:]]}
    answer = json.loads(result_path.read_text(encoding="utf-8-sig"))
    result_path.unlink(missing_ok=True)
    return answer


def main() -> int:
    worker = next((path for path in WORKER_CANDIDATES if path.exists()), None)
    if worker is None:
        print("CrystalReportWrapper.exe not found - build it first.", file=sys.stderr)
        return 1
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    formulas: dict[str, object] = {}
    everything: dict[str, object] = {}
    ids: set[int] = set()
    functions: set[str] = set()
    reports = sorted((HERE / "reports").glob("*.rpt"))
    for report in reports:
        result = inspect(worker, report)
        if not result.get("success"):
            formulas[report.name] = {"error": result.get("error")}
            print(f"FAIL  {report.name}: {result.get('error')}")
            continue
        found = legacy_formulas(result)
        formulas[report.name] = found
        everything[report.name] = all_formulas(result)
        for formula in found:
            ids.update(int(n) for n in re.findall(r"TranslationTranslate\s*\(\s*(\d+)\s*\)", formula["text"], re.I))
            functions.update(re.findall(r"MFGFunctions\w+", formula["text"]))
        print(f"ok    {report.name}: {len(found)} formula(s)")

    (OUT_DIR / "formulas.json").write_text(json.dumps(formulas, indent=1), encoding="utf-8")
    (OUT_DIR / "formulas_all.json").write_text(json.dumps(everything, indent=1), encoding="utf-8")
    print(f"\n{len(reports)} reports, {len(ids)} label numbers, functions used: {', '.join(sorted(functions)) or 'none'}")

    answer = ask_addon(sorted(ids))
    (OUT_DIR / "labels.json").write_text(json.dumps(answer, indent=1, ensure_ascii=False), encoding="utf-8")
    got = sum(1 for text in (answer.get("labels") or {}).values() if text)
    print(f"Labels answered by the add-on: {got} of {len(ids)}")
    for error in (answer.get("errors") or [])[:5]:
        print(f"  note: {error}")
    print(f"Wrote {OUT_DIR / 'formulas.json'} and {OUT_DIR / 'labels.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
