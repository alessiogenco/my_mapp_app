param(
    [string] $ProjectRef = "opqrdzjlunjhcdjlectr"
)

$ErrorActionPreference = "Stop"

# The CLI sits in an ignored local project folder, so it is available from
# this PowerShell session but is never committed. It uses the saved Supabase
# login, so an ordinary deploy does not need a Personal Access Token prompt.
$projectRoot = Split-Path -Parent $PSScriptRoot
$cli = Join-Path $projectRoot ".local-tools\supabase-cli\supabase.exe"

if (-not (Test-Path -LiteralPath $cli)) {
    throw "Supabase CLI is not installed. Ask Codex to restore the local deploy tool."
}

& $cli functions deploy place-search `
    --remote=$ProjectRef `
    --no-verify-jwt `
    --yes

if ($LASTEXITCODE -ne 0) {
    throw "The Place Search deployment did not complete. If your Supabase login has expired, run .\\.local-tools\\supabase-cli\\supabase.exe login and try again."
}

