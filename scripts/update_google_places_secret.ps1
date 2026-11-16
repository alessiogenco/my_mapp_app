param(
    [string] $ProjectRef = "opqrdzjlunjhcdjlectr"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$cli = Join-Path $projectRoot ".local-tools\supabase-cli\supabase.exe"

if (-not (Test-Path -LiteralPath $cli)) {
    throw "Supabase CLI is not installed. Ask Codex to restore the local deploy tool."
}

$googlePointer = [IntPtr]::Zero
$temporarySecretFile = $null

try {
    Write-Host ""
    Write-Host "Enter the Google Places key. It stays hidden and is cleared when this script ends." -ForegroundColor Cyan
    $secureGoogleKey = Read-Host -Prompt "Working Google Places API key" -AsSecureString

    $googlePointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureGoogleKey)
    $googleKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($googlePointer)

    if ([string]::IsNullOrWhiteSpace($googleKey)) {
        throw "A Google Places API key is required."
    }

    # The CLI accepts secrets via an env file. The file exists only for this
    # command, is deleted immediately, and is outside the Git repository.
    $temporarySecretFile = Join-Path $env:TEMP ("my-locals-places-" + [guid]::NewGuid().ToString("N") + ".env")
    [System.IO.File]::WriteAllText(
        $temporarySecretFile,
        "GOOGLE_PLACES_API_KEY=$googleKey" + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    & $cli secrets set `
        --env-file $temporarySecretFile `
        --remote=$ProjectRef `
        --yes

    if ($LASTEXITCODE -ne 0) {
        throw "The Google Places secret was not updated."
    }

    & $cli functions deploy place-search `
        --remote=$ProjectRef `
        --no-verify-jwt `
        --yes

    if ($LASTEXITCODE -ne 0) {
        throw "The function deployment did not complete after the secret update."
    }

    Write-Host ""
    Write-Host "Google Places secret updated and place-search deployed successfully." -ForegroundColor Green
}
finally {
    Remove-Variable googleKey -ErrorAction SilentlyContinue
    Remove-Variable secureGoogleKey -ErrorAction SilentlyContinue
    if ($temporarySecretFile) {
        Remove-Item -LiteralPath $temporarySecretFile -Force -ErrorAction SilentlyContinue
    }
    if ($googlePointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($googlePointer)
    }
}
