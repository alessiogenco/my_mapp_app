param(
    [string] $ProjectRef = "opqrdzjlunjhcdjlectr"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$cli = Join-Path $projectRoot ".local-tools\supabase-cli\supabase.exe"

if (-not (Test-Path -LiteralPath $cli)) {
    throw "Supabase CLI is not installed. Ask Codex to restore the local deploy tool."
}

$resolverPointer = [IntPtr]::Zero
$temporarySecretFile = $null

try {
    Write-Host ""
    Write-Host "Enter the two resolver values below. The key stays hidden and is cleared when this script ends." -ForegroundColor Cyan
    $resolverUrl = Read-Host -Prompt "Cloud Run resolver URL"
    $secureResolverKey = Read-Host -Prompt "Cloud Run resolver key" -AsSecureString

    $resolverPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureResolverKey)
    $resolverKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($resolverPointer)
    $resolverUrl = $resolverUrl.Trim().TrimEnd("/")

    if ([string]::IsNullOrWhiteSpace($resolverUrl) -or
        [string]::IsNullOrWhiteSpace($resolverKey)) {
        throw "Both resolver values are required."
    }

    $parsedResolverUrl = $null
    if (-not [System.Uri]::TryCreate($resolverUrl, [System.UriKind]::Absolute, [ref] $parsedResolverUrl) -or
        $parsedResolverUrl.Scheme -ne "https") {
        throw "The Cloud Run resolver URL must start with https://."
    }

    # This temporary file is stored outside the repository and removed as soon
    # as Supabase has received the two server-side secrets.
    $temporarySecretFile = Join-Path $env:TEMP ("my-locals-foursquare-resolver-" + [guid]::NewGuid().ToString("N") + ".env")
    [System.IO.File]::WriteAllText(
        $temporarySecretFile,
        ("FSQ_COORDINATE_RESOLVER_URL=$resolverUrl" + [Environment]::NewLine +
        "FSQ_COORDINATE_RESOLVER_KEY=$resolverKey" + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )

    & $cli secrets set `
        --env-file $temporarySecretFile `
        --remote=$ProjectRef `
        --yes

    if ($LASTEXITCODE -ne 0) {
        throw "The Foursquare resolver settings were not saved."
    }

    & $cli functions deploy place-search `
        --remote=$ProjectRef `
        --no-verify-jwt `
        --yes

    if ($LASTEXITCODE -ne 0) {
        throw "The Place Search deployment did not complete after the resolver update."
    }

    Write-Host ""
    Write-Host "Foursquare coordinate fallback is configured and place-search was deployed successfully." -ForegroundColor Green
}
finally {
    Remove-Variable resolverKey -ErrorAction SilentlyContinue
    Remove-Variable secureResolverKey -ErrorAction SilentlyContinue
    if ($temporarySecretFile) {
        Remove-Item -LiteralPath $temporarySecretFile -Force -ErrorAction SilentlyContinue
    }
    if ($resolverPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($resolverPointer)
    }
}
