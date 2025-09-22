<#
Simple launcher for Windows development/distribution.
Usage (development):
  - Put this script in the Flutter project folder (frontend/scripts)
  - From PowerShell run: .\start_backend_and_app.ps1 -BackendScript "..\..\main.py" -AppReleaseFolder "..\build\windows\runner\Release"

Behavior:
 - If a backend exe (backend.exe) exists in the current folder it will be launched.
 - Otherwise it will attempt to run a Python backend using an existing venv (venv\Scripts\Activate.ps1) if present or plain `python` otherwise.
 - Waits for the backend to respond on http://127.0.0.1:8000/ (default) before launching the Flutter app executable found in the release folder.
 - This is intended for local packaging (copy backend.exe or a Python runtime + files next to the app exe) and for development convenience.

Notes:
 - Adjust timeouts, paths and the backend health endpoint as needed.
 - For distribution, include backend.exe (created by PyInstaller) or a bundled Python runtime in the same folder as the app.
#>
param(
    [string]$BackendExe = "backend.exe",
    [string]$BackendScript = "..\..\main.py",
    [string]$VenvActivate = "..\..\venv\Scripts\Activate.ps1",
    [string]$AppReleaseFolder = "..\build\windows\runner\Release",
    [string]$HealthUrl = "http://127.0.0.1:8000/",
    [int]$TimeoutSeconds = 60
)

function Write-Info($m) { Write-Host "[info] $m" -ForegroundColor Cyan }
function Write-ErrorLn($m) { Write-Host "[error] $m" -ForegroundColor Red }

Push-Location $PSScriptRoot

# 1) Launch backend
$backendProcess = $null
if (Test-Path $BackendExe) {
    Write-Info "Found backend executable: $BackendExe. Launching..."
    $backendProcess = Start-Process -FilePath (Resolve-Path $BackendExe) -PassThru
} else {
    # Try to use venv if available
    if (Test-Path $VenvActivate) {
        Write-Info "Activating venv at: $VenvActivate and launching backend script: $BackendScript"
        # Start a new powershell that activates venv and runs uvicorn
        $cmd = "powershell -NoExit -Command \"& '{0}'; python -m uvicorn main:app --host 127.0.0.1 --port 8000\"" -f (Resolve-Path $VenvActivate)
        $backendProcess = Start-Process -FilePath pwsh -ArgumentList "-NoProfile","-Command", "& { & '{0}' ; python -m uvicorn main:app --host 127.0.0.1 --port 8000 }" -PassThru -WindowStyle Hidden
        # Note: if pwsh is not present, the user may want to run the venv manually or adjust this script.
    } else {
        Write-Info "Launching python backend directly: python $BackendScript"
        if (-not (Test-Path $BackendScript)) {
            Write-ErrorLn "Backend script not found at path $BackendScript. Exiting."
            Pop-Location
            exit 1
        }
        # Start uvicorn as background process
        $backendProcess = Start-Process -FilePath python -ArgumentList "-m","uvicorn","main:app","--host","127.0.0.1","--port","8000" -PassThru -NoNewWindow
    }
}

# 2) Wait for health endpoint
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$ok = $false
while ((Get-Date) -lt $deadline) {
    try {
        $r = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) {
            Write-Info "Backend responded with status $($r.StatusCode). Proceeding to launch app."
            $ok = $true
            break
        }
    } catch {
        Start-Sleep -Milliseconds 500
    }
}

if (-not $ok) {
    Write-ErrorLn "Timed out waiting for backend to become ready at $HealthUrl. Launching app anyway."
}

# 3) Launch Flutter Windows release exe
# find the exe in the release folder (first exe)
$exe = Get-ChildItem -Path $AppReleaseFolder -Filter *.exe -File -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -ne $exe) {
    Write-Info "Launching frontend app: $($exe.FullName)"
    Start-Process -FilePath $exe.FullName
} else {
    Write-ErrorLn "No frontend executable found in $AppReleaseFolder. Please run 'flutter build windows' and supply the correct folder."
}

Pop-Location
