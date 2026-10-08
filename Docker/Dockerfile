# syntax: Windows containers ONLY - see the writeup in chat for why.
# Crystal Reports for .NET only ever shipped classic .NET Framework
# assemblies (CrystalReportWrapper.csproj targets net48, x86), backed by
# a proprietary, COM-based runtime installed system-wide (GAC + registry) -
# there is no Linux equivalent, so this cannot be a Linux image no matter
# how it's built.
#
# Before building:
#   1. Docker Desktop must be in "Windows containers" mode (right-click
#      the Docker tray icon -> "Switch to Windows containers...").
#   2. The base OS tag below (ltsc2022) should match your Docker host's
#      Windows build for the default `process` isolation mode - check
#      with `winver`. If it doesn't match, either change the tag or add
#      `--isolation=hyperv` to `docker build`/`docker run` (Windows 10/11
#      Pro or Enterprise only - Hyper-V isolation tolerates a version
#      mismatch that process isolation won't).
#   3. Put whichever SAP Crystal Reports runtime installer(s) (.msi) you
#      used to get this working on your dev machine into a `crruntime/`
#      folder next to this Dockerfile - see that step below, it's the one
#      part of this file I could not verify (no Windows container host
#      available to actually build/run this from here).
# Stage 1 exists only to donate one file: oledlg.dll, which Server Core
# doesn't ship and the Crystal runtime needs (see the install step). It
# has to come from the SAME Windows build as the final image (Server 2022,
# 20348) - a copy taken from a Windows 11 PC (build 26100) made the
# installer fail with HRESULT 0x800700C1 "not a valid Win32 application".
# This full-Windows image is a large one-time download; nothing else from
# it ends up in the final image.
FROM mcr.microsoft.com/windows/server:ltsc2022 AS fullwin

FROM mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2022

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# ── Python ──────────────────────────────────────────────────────────────
# report_api_server.py runs on Python; the base image above only carries
# the .NET Framework 4.8 runtime CrystalReportWrapper.exe needs. Installed
# silently via the official Windows installer. Pinned to a stable release
# rather than matching your dev .venv's 3.14.5 exactly - bump
# PYTHON_VERSION if you want them to match.
ARG PYTHON_VERSION=3.12.7
RUN Invoke-WebRequest -Uri "https://www.python.org/ftp/python/$env:PYTHON_VERSION/python-$env:PYTHON_VERSION-amd64.exe" -OutFile C:\python-installer.exe ; \
    Start-Process -FilePath C:\python-installer.exe -ArgumentList '/quiet', 'InstallAllUsers=1', 'PrependPath=1', 'Include_test=0', 'Include_launcher=0' -Wait ; \
    Remove-Item C:\python-installer.exe


RUN Invoke-WebRequest -Uri https://aka.ms/vs/17/release/vc_redist.x86.exe -OutFile C:\vc_redist.x86.exe ; \
    $p = Start-Process C:\vc_redist.x86.exe -ArgumentList @('/install', '/quiet', '/norestart') -Wait -PassThru ; \
    if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) { throw ('vc_redist.x86 exited ' + $p.ExitCode) } ; \
    Remove-Item C:\vc_redist.x86.exe ; \
    if (-not (Test-Path C:\Windows\SysWOW64\vcruntime140.dll)) { throw 'vcruntime140.dll (32-bit) still missing after vc_redist install' }

COPY crruntime/ C:/crruntime/
# Build-matched 32-bit oledlg.dll from stage 1 - deliberately AFTER the
# line above so it replaces any oledlg.dll sitting in the local folder.
COPY --from=fullwin C:/Windows/SysWOW64/oledlg.dll C:/crruntime/oledlg.dll
# No double quotes anywhere in this RUN: Docker hands the line to
# `powershell -Command` through cmd-style parsing, which strips them, so
# "Installing $($_.Name)..." arrived as bare words and broke ForEach-Object
# ("A positional parameter cannot be found"). Single quotes + an argument
# array survive intact. Paths here have no spaces, so nothing needs
# embedded quoting. No -ErrorAction SilentlyContinue either: a missing
# .msi should fail the build, not produce an image with no Crystal runtime.
#
# oledlg.dll: Server Core images don't ship it, and the Crystal runtime's
# crtslv.dll needs it to self-register - the classic cause of this MSI
# failing with 1603 in a container. If crruntime\oledlg.dll exists (copy
# it from C:\Windows\SysWOW64\oledlg.dll on any normal Windows PC - the
# 32-bit one, to match this 32-bit runtime) it's dropped into SysWOW64
# before the install runs.
#
# On failure this prints the lines around the installer's real error
# ("Return value 3" marks the action that failed) rather than the log's
# tail, which is only the property dump.
RUN if (Test-Path C:\crruntime\oledlg.dll) { \
        Copy-Item C:\crruntime\oledlg.dll C:\Windows\SysWOW64\oledlg.dll -Force; \
        Write-Host 'Copied oledlg.dll into SysWOW64' \
    } else { Write-Host 'No crruntime\oledlg.dll supplied' }; \
    $msis = @(Get-ChildItem C:\crruntime\*.msi); \
    if ($msis.Count -eq 0) { throw 'No Crystal Reports runtime .msi found in C:\crruntime' }; \
    foreach ($m in $msis) { \
        Write-Host ('Installing ' + $m.Name); \
        $p = Start-Process msiexec.exe -ArgumentList @('/i', $m.FullName, '/qn', '/norestart', '/l*v', 'C:\crruntime\install.log') -Wait -PassThru; \
        if ($p.ExitCode -ne 0) { \
            Select-String -Path C:\crruntime\install.log -Pattern 'Return value 3', 'Error 1\d\d\d', 'failed to register', 'CustomAction .* returned actual error' -Context 8,2 | Select-Object -First 6 | Out-String -Width 250 | Write-Host; \
            throw ('msiexec exited ' + $p.ExitCode + ' installing ' + $m.Name) \
        } \
    }

# -- Fonts ----------------------------------------------------------------
# Server Core ships almost no fonts - no Arial, which every report uses. With
# Arial missing, Crystal substituted the only other font it could find, the
# Code 39 BARCODE font its own runtime installs, so reports rendered with
# every letter drawn as a barcode. These come from the same full-Windows
# image that donates oledlg.dll above. Copying a font into C:\Windows\Fonts
# is not enough on its own: Windows only loads the ones listed in the
# registry, and reads that list when the container starts.
# One file per line, no wildcards: a wildcard in COPY --from fails on Windows
# containers with 'GetFileInformationByHandle ... Incorrect function'.
COPY --from=fullwin C:/Windows/Fonts/arial.ttf C:/fonts/arial.ttf
COPY --from=fullwin C:/Windows/Fonts/arialbd.ttf C:/fonts/arialbd.ttf
COPY --from=fullwin C:/Windows/Fonts/arialbi.ttf C:/fonts/arialbi.ttf
COPY --from=fullwin C:/Windows/Fonts/ariali.ttf C:/fonts/ariali.ttf
COPY --from=fullwin C:/Windows/Fonts/times.ttf C:/fonts/times.ttf
COPY --from=fullwin C:/Windows/Fonts/timesbd.ttf C:/fonts/timesbd.ttf
COPY --from=fullwin C:/Windows/Fonts/timesbi.ttf C:/fonts/timesbi.ttf
COPY --from=fullwin C:/Windows/Fonts/timesi.ttf C:/fonts/timesi.ttf
COPY --from=fullwin C:/Windows/Fonts/cour.ttf C:/fonts/cour.ttf
COPY --from=fullwin C:/Windows/Fonts/courbd.ttf C:/fonts/courbd.ttf
COPY --from=fullwin C:/Windows/Fonts/courbi.ttf C:/fonts/courbi.ttf
COPY --from=fullwin C:/Windows/Fonts/couri.ttf C:/fonts/couri.ttf
COPY --from=fullwin C:/Windows/Fonts/tahoma.ttf C:/fonts/tahoma.ttf
COPY --from=fullwin C:/Windows/Fonts/tahomabd.ttf C:/fonts/tahomabd.ttf
COPY --from=fullwin C:/Windows/Fonts/verdana.ttf C:/fonts/verdana.ttf
COPY --from=fullwin C:/Windows/Fonts/verdanab.ttf C:/fonts/verdanab.ttf
COPY --from=fullwin C:/Windows/Fonts/verdanai.ttf C:/fonts/verdanai.ttf
COPY --from=fullwin C:/Windows/Fonts/verdanaz.ttf C:/fonts/verdanaz.ttf


WORKDIR C:/app
RUN $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'; \
    $fonts = @(Get-ChildItem C:\fonts\*.ttf); \
    if ($fonts.Count -eq 0) { throw 'No fonts were copied from the full Windows image' }; \
    foreach ($f in $fonts) { \
        Copy-Item $f.FullName C:\Windows\Fonts -Force; \
        New-ItemProperty -Path $key -Name ($f.BaseName + ' (TrueType)') -Value $f.Name -PropertyType String -Force | Out-Null \
    }; \
    Write-Host ('Installed ' + $fonts.Count + ' fonts'); \
    Remove-Item C:\fonts -Recurse -Force
# ── Python dependencies ────────────────────────────────────────────────
# fastapi/uvicorn per report_api_server.py's own RUNNING section
# (Scratch/requirements_report_api.txt) - pydantic comes in as fastapi's
# own dependency. cryptography (also in that file) is deliberately NOT
# installed here - it's only used by generate_cert.py, which this image
# doesn't run (see docker-compose.yml: the cert is generated on the host
# and mounted in, not regenerated inside the container).
RUN pip install --no-cache-dir fastapi uvicorn

# ── Application code + data ─────────────────────────────────────────────
# .dockerignore keeps this to what report_service.py's HERE-relative
# paths actually need: the Python modules, jsonInspections/, reports/
# (.rpt files), and CrystalReportWrapper/bin/Release/net48/publish/ (the
# compiled worker + its DLLs) - see that file.
COPY . .
COPY pythonScripts/ .
# report_service.py defaults WORKER_EXE to the Debug build path for local
# dev (see that file's own comment) - point this container at the
# Release publish output actually shipped above instead.
ENV RPTCONVERT_WORKER_EXE="C:/app/CrystalReportWrapper/bin/Release/net48/publish/CrystalReportWrapper.exe"

EXPOSE 8443

CMD ["python", "report_api_server.py"]
