param(
    [string]$BuildRoot,
    [string]$FlutterPath,
    [switch]$NoPub,
    [switch]$VerifyOnly,
    [string]$ApkPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $BuildRoot) { $BuildRoot = $repositoryRoot }
if (-not $ApkPath) {
    $ApkPath = Join-Path $repositoryRoot 'build\app\outputs\flutter-apk\app-release.apk'
}

if (-not $VerifyOnly) {
    if (-not $FlutterPath) {
        $bundledFlutter = Join-Path $repositoryRoot '.tooling\flutter\bin\flutter.bat'
        $FlutterPath = if (Test-Path -LiteralPath $bundledFlutter) {
            $bundledFlutter
        } else {
            'flutter'
        }
    }
    $tempDirectory = Join-Path $repositoryRoot '.tmp'
    New-Item -ItemType Directory -Path $tempDirectory -Force | Out-Null
    $previousTemp = $env:TEMP
    $previousTmp = $env:TMP
    try {
        $env:TEMP = $tempDirectory
        $env:TMP = $tempDirectory
        Push-Location -LiteralPath $BuildRoot
        try {
            $arguments = @('build', 'apk', '--release', '--no-tree-shake-icons')
            if ($NoPub) { $arguments += '--no-pub' }
            & $FlutterPath @arguments
            if ($LASTEXITCODE -ne 0) {
                throw "Flutter APK build failed with exit code $LASTEXITCODE"
            }
        } finally {
            Pop-Location
        }
    } finally {
        $env:TEMP = $previousTemp
        $env:TMP = $previousTmp
    }
}

if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
    throw "APK not found at $ApkPath"
}

Add-Type -AssemblyName System.IO.Compression
$archive = [System.IO.Compression.ZipFile]::OpenRead($ApkPath)
try {
    $font = $archive.GetEntry('assets/flutter_assets/fonts/MaterialIcons-Regular.otf')
    $fontManifest = $archive.GetEntry('assets/flutter_assets/FontManifest.json')
    $assetManifest = $archive.GetEntry('assets/flutter_assets/AssetManifest.bin')
    $flutterAssetCount = @($archive.Entries | Where-Object {
        $_.FullName.StartsWith('assets/flutter_assets/', [StringComparison]::Ordinal)
    }).Count
    if (-not $font -or $font.Length -lt 1000000 -or
        -not $fontManifest -or -not $assetManifest -or $flutterAssetCount -lt 10) {
        throw 'APK is missing Flutter assets or the complete Material Icons font. Do not install or share it.'
    }
} finally {
    $archive.Dispose()
}

Write-Host "Verified APK: $ApkPath"
Write-Host "Flutter assets: $flutterAssetCount; Material Icons font: $($font.Length) bytes"
Write-Host "SHA-256: $((Get-FileHash -LiteralPath $ApkPath -Algorithm SHA256).Hash)"
