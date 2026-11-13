param(
    [string]$RuntimeRoot = 'D:\oralyn-backend'
)

$ErrorActionPreference = 'Stop'

$backendRoot = $RuntimeRoot
$backendSource = Join-Path $PSScriptRoot 'backend'
$pythonPath = Join-Path $backendRoot '.venv\Scripts\python.exe'
$cloudflaredPath = Join-Path $backendRoot 'cloudflared.exe'
$serverOutput = Join-Path $PSScriptRoot 'oralyn-server.log'
$serverError = Join-Path $PSScriptRoot 'oralyn-server-error.log'

if (-not (Test-Path -LiteralPath $pythonPath)) {
    throw "Backend Python was not found at $pythonPath"
}
if (-not (Test-Path -LiteralPath $cloudflaredPath)) {
    throw "cloudflared was not found at $cloudflaredPath"
}
if (-not (Test-Path -LiteralPath (Join-Path $backendSource 'main.py'))) {
    throw "Tracked backend source was not found at $backendSource"
}

# Keep the runtime secret and trained checkpoints outside the Git repository.
# The child Uvicorn process inherits these paths, never the values in the logs.
$env:ORALYN_ENV_FILE = Join-Path $backendRoot '.env'
$env:ORALYN_MODEL_DIR = Join-Path $backendRoot 'models'
if (-not $env:CLERK_ISSUER) {
    # Public issuer of the existing Clerk development instance.
    $env:CLERK_ISSUER = 'https://balanced-mammal-1206.clerk.accounts.dev'
}

Write-Host 'Starting the Oralyn FastAPI model server...'
$server = Start-Process `
    -FilePath $pythonPath `
    -ArgumentList @(
        '-m', 'uvicorn', 'main:app',
        '--host', '127.0.0.1',
        '--port', '8000'
    ) `
    -WorkingDirectory $backendSource `
    -WindowStyle Hidden `
    -RedirectStandardOutput $serverOutput `
    -RedirectStandardError $serverError `
    -PassThru

try {
    $healthy = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        Start-Sleep -Seconds 1
        try {
            $health = Invoke-RestMethod `
                -Uri 'http://127.0.0.1:8000/health' `
                -TimeoutSec 2
            if ($health.status -eq 'healthy') {
                $healthy = $true
                break
            }
        } catch {
            # The model can take several seconds to load on CPU.
        }
        if ($server.HasExited) {
            break
        }
    }

    if (-not $healthy) {
        if (Test-Path -LiteralPath $serverError) {
            Get-Content -LiteralPath $serverError -Tail 80
        }
        throw 'The FastAPI server did not become healthy.'
    }

    Write-Host ''
    Write-Host 'FastAPI is healthy.' -ForegroundColor Green
    Write-Host 'Cloudflare will print a https://...trycloudflare.com URL below.'
    Write-Host 'In Oralyn, open Profile > Screening server and paste that URL.'
    Write-Host 'Oralyn will automatically use the /predict endpoint.'
    Write-Host 'Keep this window open. Press Ctrl+C to stop the server and tunnel.'
    Write-Host ''

    & $cloudflaredPath tunnel `
        --no-autoupdate `
        --protocol http2 `
        --url http://127.0.0.1:8000
} finally {
    if ($server -and -not $server.HasExited) {
        Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
    }
}
