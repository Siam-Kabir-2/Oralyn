param(
    [string]$RuntimeRoot = 'D:\oralyn-backend'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $RuntimeRoot '.env'
$failures = [System.Collections.Generic.List[string]]::new()

function Write-Check {
    param([bool]$Passed, [string]$Message)
    if ($Passed) {
        Write-Host "[OK]   $Message" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
        $script:failures.Add($Message)
    }
}

Write-Host 'Oralyn Phase 4 prerequisite check'
Write-Host 'This script performs file checks and read-only Supabase schema probes.'
Write-Host ''

$requiredFiles = @(
    (Join-Path $RuntimeRoot '.venv\Scripts\python.exe'),
    (Join-Path $RuntimeRoot 'cloudflared.exe'),
    (Join-Path $RuntimeRoot 'models\resnet50_smartom_best.pth'),
    (Join-Path $RuntimeRoot 'models\resnet50_bmiocd_binary_best.pth'),
    (Join-Path $repositoryRoot '.tooling\flutter\bin\flutter.bat'),
    $envPath
)
foreach ($path in $requiredFiles) {
    Write-Check (Test-Path -LiteralPath $path) "File exists: $path"
}

if (-not (Test-Path -LiteralPath $envPath)) {
    Write-Host ''
    Write-Host 'Create the private runtime .env before continuing.' -ForegroundColor Yellow
    exit 1
}

$config = @{}
Get-Content -LiteralPath $envPath | ForEach-Object {
    if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
        $config[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
    }
}

foreach ($name in @(
    'SUPABASE_URL',
    'SUPABASE_PUBLISHABLE_KEY',
    'SUPABASE_SECRET_KEY'
)) {
    Write-Check (-not [string]::IsNullOrWhiteSpace($config[$name])) ".env configures $name"
}

if ($failures.Count -eq 0) {
    $headers = @{
        apikey = $config['SUPABASE_SECRET_KEY']
        Accept = 'application/json'
        'User-Agent' = 'Oralyn-Backend/1.0'
    }
    $resources = @(
        'profiles?select=application_role&limit=0',
        'doctor_profiles?select=clerk_user_id&limit=0',
        'review_requests?select=id&limit=0',
        'case_assignments?select=id&limit=0',
        'doctor_reviews?select=id&limit=0',
        'case_audit_events?select=id&limit=0'
    )
    foreach ($resource in $resources) {
        $name = ($resource -split '\?')[0]
        try {
            $uri = $config['SUPABASE_URL'].TrimEnd('/') + '/rest/v1/' + $resource
            $response = Invoke-WebRequest `
                -Uri $uri `
                -Headers $headers `
                -Method Get `
                -UseBasicParsing `
                -TimeoutSec 15
            Write-Check ($response.StatusCode -eq 200) "Phase 3C schema exposes $name"
        } catch {
            Write-Check $false "Phase 3C schema exposes $name"
        }
    }
}

Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host 'Prerequisites are incomplete. Follow docs\PHASE4_MANUAL_TESTING.md.' `
        -ForegroundColor Yellow
    exit 1
}

Write-Host 'Phase 4 runtime files, configuration, and schema are ready.' `
    -ForegroundColor Green
exit 0
