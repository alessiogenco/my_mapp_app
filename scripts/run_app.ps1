param(
    [ValidateSet("chrome", "edge", "windows")]
    [string] $Device = "chrome",

    [switch] $Release
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $ProjectRoot "mapbox.env.json"

Set-Location $ProjectRoot

if (-not (Test-Path $EnvFile)) {
    Write-Host ""
    Write-Host "Non trovo mapbox.env.json, quindi lo creo ora." -ForegroundColor Yellow
    Write-Host "Questo file resta solo sul tuo PC ed e' escluso da Git."
    Write-Host ""

    $Token = Read-Host "Incolla qui il tuo Mapbox public token, quello che inizia con pk."

    if ([string]::IsNullOrWhiteSpace($Token)) {
        throw "Token vuoto. Rilancia lo script e incolla il token Mapbox."
    }

    if (-not $Token.StartsWith("pk.")) {
        Write-Host ""
        Write-Host "Attenzione: di solito un Mapbox public token inizia con pk." -ForegroundColor Yellow
        Write-Host "Continuo comunque, ma se la mappa resta grigia controlla il token."
        Write-Host ""
    }

    $Config = [ordered]@{
        MAPBOX_ACCESS_TOKEN = $Token
    }

    $Config | ConvertTo-Json | Set-Content -Path $EnvFile -Encoding UTF8

    Write-Host ""
    Write-Host "Creato mapbox.env.json." -ForegroundColor Green
}

$FlutterArgs = @(
    "run",
    "-d",
    $Device,
    "--dart-define-from-file=mapbox.env.json"
)

if ($Release) {
    $FlutterArgs += "--release"
}

Write-Host ""
Write-Host "Avvio Flutter su $Device usando il token salvato in mapbox.env.json..." -ForegroundColor Cyan
Write-Host ""

flutter @FlutterArgs
