<#
diagnose_colors.ps1 - find out why the alternate-row shading fix
(CrystalReportWrapper\ReportColors.cs) is not taking effect.

    .\diagnose_colors.ps1 -Port 5434      # the Postgres port you log into in ZMRP

Runs the worker on this PC (not in the container) and writes everything to
Scratch\color_diag.txt:
  1. the section condition formulas of six failing reports and one working one
  2. one render of Stock Status, with the worker's own messages
Rebuilds the worker first (Release), so it tests the current C# - the build
output goes in the file too. Changes nothing else.
#>
param([Parameter(Mandatory = $true)][int]$Port)

Set-Location $PSScriptRoot
$out = "Scratch\color_diag.txt"
$exe = "CrystalReportWrapper\bin\Release\net48\CrystalReportWrapper.exe"
"== $(Get-Date)   building the worker" | Set-Content $out
cmd /c "dotnet build CrystalReportWrapper\CrystalReportWrapper.csproj -c Release -nologo -v q 2>&1" | Add-Content $out
if (-not (Test-Path $exe)) { Write-Host "Not found: $exe - the build failed, see $out" -ForegroundColor Red; exit 1 }
"== worker built $((Get-Item $exe).LastWriteTime)" | Add-Content $out
# WorkCenterListing renders fine: it is the comparison that shows whether an
# empty list means "no shading rule" or "the rules could not be read".
foreach ($report in "StockStatus", "POTotalsGraph", "SOTotalsGraph", "IntrastatReporting",
                    "ShortageReport", "StockroomOnHand", "WorkCenterListing") {
    "`r`n== section rules: $report" | Add-Content $out
    cmd /c "`"$exe`" --report `"reports\$report.rpt`" --section-rules 2>&1" | Add-Content $out
}
"`r`n== render: Inventory / Stock Status, port $Port" | Add-Content $out
cmd /c ".venv\Scripts\python.exe main.py --port $Port --menu Inventory --report `"Stock Status`" --out Scratch\color_diag.pdf 2>&1" | Add-Content $out

Write-Host "Wrote $out" -ForegroundColor Green
