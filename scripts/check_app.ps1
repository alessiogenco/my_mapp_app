$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "== Dataset ==" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot "check_places.ps1")
if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "== Git status ==" -ForegroundColor Cyan
Push-Location $ProjectRoot
try {
    git status --short
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "Check complete." -ForegroundColor Green
