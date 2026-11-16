param(
    [string] $ProjectRef = "opqrdzjlunjhcdjlectr"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$cli = Join-Path $projectRoot ".local-tools\supabase-cli\supabase.exe"

if (-not (Test-Path -LiteralPath $cli)) {
    throw "Supabase CLI is not installed. Ask Codex to restore the local deploy tool."
}

$geoapifyPointer = [IntPtr]::Zero
$temporarySecretFile = $null

try {
    Write-Host ""
    Write-Host "Enter the Geoapify key. It stays hidden and is cleared when this script ends." -ForegroundColor Cyan
    $secureGeoapifyKey = Read-Host -Prompt "Geoapify API key" -AsSecureString

    $geoapifyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureGeoapifyKey)
    $geoapifyKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($geoapifyPointer)

    if ([string]::IsNullOrWhiteSpace($geoapifyKey)) {
        throw "A Geoapify API key is required."
    }

    # The temporary file is outside the repository and is deleted immediately
    # after Supabase receives the secret.
    $temporarySecretFile = Join-Path $env:TEMP ("my-locals-geoapify-" + [guid]::NewGuid().ToString("N") + ".env")
    [System.IO.File]::WriteAllText(
        $temporarySecretFile,
        "GEOAPIFY_API_KEY=$geoapifyKey" + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    & $cli secrets set `
        --env-file $temporarySecretFile `
        --remote=$ProjectRef `
        --yes

    if ($LASTEXITCODE -ne 0) {
        throw "The Geoapify key was not saved."
    }

    & $cli functions deploy place-search `
        --remote=$ProjectRef `
        --no-verify-jwt `
        --yes

    if ($LASTEXITCODE -ne 0) {
        throw "The function deployment did not complete after the Geoapify update."
    }

    Write-Host ""
    Write-Host "Geoapify is configured and place-search was deployed successfully." -ForegroundColor Green
}
finally {
    Remove-Variable geoapifyKey -ErrorAction SilentlyContinue
    Remove-Variable secureGeoapifyKey -ErrorAction SilentlyContinue
    if ($temporarySecretFile) {
        Remove-Item -LiteralPath $temporarySecretFile -Force -ErrorAction SilentlyContinue
    }
    if ($geoapifyPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($geoapifyPointer)
    }
}
