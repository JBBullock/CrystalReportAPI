<#
start_report_api.ps1 - build (if needed) and start the RPTConvert report API
as a background Docker service.

USAGE (from anywhere, in PowerShell):
    .\start_report_api.ps1            # republish the C# worker, rebuild the image, start
    .\start_report_api.ps1 -NoBuild   # just start the existing image (nothing changed)
    .\start_report_api.ps1 -Stop      # stop the service
    .\start_report_api.ps1 -Logs      # follow the service's logs (Ctrl+C to exit)

If PowerShell refuses to run scripts, run this once first:
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

Rebuild whenever Program.cs, any .py file, a report, or the registry JSON
changed - the container runs a frozen copy of this folder from its last build.
#>
param(
    [switch]$NoBuild,
    [switch]$Stop,
    [switch]$Logs
)

# 'Continue', not 'Stop': in Windows PowerShell 5.1, a native command's
# stderr output (docker/curl progress, warnings) becomes a terminating error
# under 'Stop'. Failures are checked explicitly via $LASTEXITCODE instead.
$ErrorActionPreference = 'Continue'
Set-Location $PSScriptRoot

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

# --- Docker must be running, in Windows-container mode ----------------------
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Fail "docker not found - install/start Docker Desktop first."
}
$osType = (docker info --format '{{.OSType}}' 2>$null)
if (-not $osType) { Fail "Docker isn't running - start Docker Desktop and try again." }
if ($osType.Trim() -ne 'windows') {
    Fail "Docker is in '$osType' mode. Right-click the Docker tray icon -> 'Switch to Windows containers...', then re-run."
}

if ($Stop) { docker compose stop; exit $LASTEXITCODE }
if ($Logs) { docker compose logs -f report-api; exit $LASTEXITCODE }

# --- Pre-flight: files the build/run needs -----------------------------------
if (-not (Test-Path .env)) { Fail ".env missing - copy .env.example to .env and fill in RPTCONVERT_API_KEY and PG_PASSWORD." }
if (-not (Test-Path report_api_certs\cert.pem) -or -not (Test-Path report_api_certs\key.pem)) {
    Fail "report_api_certs\cert.pem/key.pem missing - run: python generate_cert.py --host <this machine's name or IP>"
}

if (-not $NoBuild) {
    if (-not (Get-ChildItem crruntime\*.msi -ErrorAction SilentlyContinue)) {
        Fail "No Crystal Reports runtime .msi in crruntime\ - the image build needs it."
    }

    # The image ships bin\Release\net48\publish, NOT the Debug build you run
    # day to day - so republish it every time, or the container runs stale C#.
    Write-Host "Publishing CrystalReportWrapper (Release)..." -ForegroundColor Cyan
    dotnet publish CrystalReportWrapper\CrystalReportWrapper.csproj -c Release
    if ($LASTEXITCODE -ne 0) { Fail "dotnet publish failed - fix the build errors above first." }

    Write-Host "Building image and starting service..." -ForegroundColor Cyan
    $compose=@('compose', '-f', 'Docker\docker-compose.yml', '--env-file', ".env")
    docker @compose up -d --build
} else {
    Write-Host "Starting service (no rebuild)..." -ForegroundColor Cyan
    $compose=@('compose', '-f', 'Docker\docker-compose.yml', '--env-file', ".env")
    docker @compose up -d
}
if ($LASTEXITCODE -ne 0) { Fail "docker compose failed - see output above." }
  

# --- Wait for /health ---------------------------------------------------------
Write-Host "Waiting for https://localhost:8443/health ..." -ForegroundColor Cyan
for ($i = 0; $i -lt 30; $i++) {
    $resp = & curl.exe -k -s --max-time 5 https://localhost:8443/health 2>$null
    if ($resp -match '"ok"') {
        Write-Host "Report API is up: $resp" -ForegroundColor Green
        Write-Host "It will restart automatically after crashes and reboots (while Docker Desktop is running)."
        exit 0
    }
    Start-Sleep -Seconds 4
}
Write-Host "Service didn't answer /health within 2 minutes. Last log lines:" -ForegroundColor Yellow
docker compose logs --tail 40 report-api
exit 1
