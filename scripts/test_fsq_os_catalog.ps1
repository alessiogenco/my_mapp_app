$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$python = "C:\Users\180026675\AppData\Local\Programs\Python\Python39\python.exe"
$localPackages = Join-Path $projectRoot ".local-tools\fsq-os-test"
$testScript = Join-Path $projectRoot "tool\test_fsq_os_catalog.py"

if (-not (Test-Path -LiteralPath $python)) {
    throw "Python 3.9 was not found on this computer."
}

if (-not (Test-Path -LiteralPath (Join-Path $localPackages "pyiceberg"))) {
    throw "The local Foursquare test reader is not installed yet."
}

$tokenPointer = [IntPtr]::Zero
$proxyVariables = @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy")
$originalProxyValues = @{}
try {
    Write-Host "Enter the Foursquare Places Portal token. It stays hidden and is cleared after this check." -ForegroundColor Cyan
    $secureToken = Read-Host -Prompt "Foursquare token" -AsSecureString
    $tokenPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    $env:FSQ_OS_PLACES_TOKEN = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($tokenPointer)

    # This managed computer exposes a dead local proxy (127.0.0.1:9) to
    # command-line programs. It prevents Python from reaching Foursquare even
    # though the browser can access the internet. Ignore proxy variables only
    # for this short, direct HTTPS catalog check and restore them afterwards.
    foreach ($proxyVariable in $proxyVariables) {
        $originalProxyValues[$proxyVariable] = [Environment]::GetEnvironmentVariable(
            $proxyVariable,
            "Process"
        )
        Remove-Item ("Env:" + $proxyVariable) -ErrorAction SilentlyContinue
    }

    & $python $testScript
    if ($LASTEXITCODE -ne 0) {
        throw "The Foursquare catalog check did not complete."
    }
}
finally {
    if ($tokenPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($tokenPointer)
    }
    Remove-Item Env:FSQ_OS_PLACES_TOKEN -ErrorAction SilentlyContinue
    foreach ($proxyVariable in $proxyVariables) {
        if ($null -eq $originalProxyValues[$proxyVariable]) {
            Remove-Item ("Env:" + $proxyVariable) -ErrorAction SilentlyContinue
        }
        else {
            [Environment]::SetEnvironmentVariable(
                $proxyVariable,
                $originalProxyValues[$proxyVariable],
                "Process"
            )
        }
    }
}
