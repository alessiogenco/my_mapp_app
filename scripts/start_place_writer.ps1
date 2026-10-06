$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host ""
Write-Host "Starting local place writer..." -ForegroundColor Cyan
Write-Host "Keep this terminal open while adding places from the app."
Write-Host ""

dart run tool/place_writer_server.dart
