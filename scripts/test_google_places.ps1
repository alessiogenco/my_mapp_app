param(
    [string] $Name = "Empire State Coffee",
    [string] $City = "Dundee",
    [string] $CountryCode = "GB"
)

$ErrorActionPreference = "Stop"

$secureKey = Read-Host -Prompt "Google Places API key" -AsSecureString
$keyPointer = [IntPtr]::Zero

try {
    $keyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
    $apiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPointer)
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw "No API key was entered."
    }

    # The request intentionally mirrors the first lookup made by the Edge
    # Function. It isolates Google configuration from Flutter and Supabase.
    $regionCode = if ($CountryCode.Trim().ToUpperInvariant() -eq "GB") {
        "uk"
    } else {
        $CountryCode.Trim().ToLowerInvariant()
    }
    $query = "$($Name.Trim()) in $($City.Trim())"
    $body = @{
        textQuery = $query
        pageSize = 5
        languageCode = "en"
        regionCode = $regionCode
    } | ConvertTo-Json -Compress
    $headers = @{
        "Content-Type" = "application/json"
        "X-Goog-Api-Key" = $apiKey
        "X-Goog-FieldMask" = "places.id,places.displayName,places.formattedAddress"
    }

    $response = Invoke-RestMethod `
        -Method Post `
        -Uri "https://places.googleapis.com/v1/places:searchText" `
        -Headers $headers `
        -Body $body

    $places = @($response.places)
    Write-Host ""
    Write-Host "Google Places direct test completed." -ForegroundColor Green
    Write-Host "Query: $query"
    Write-Host "Usable results: $($places.Count)"

    if ($places.Count -gt 0) {
        $first = $places[0]
        Write-Host "First result: $($first.displayName.text)"
        Write-Host "Address: $($first.formattedAddress)"
        Write-Host ""
        Write-Host "Conclusion: Google is working. The remaining issue is in the Supabase path." -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Conclusion: Google accepted the request but returned no places. We must inspect the Google project/key configuration, not change Flutter code." -ForegroundColor Yellow
    }
}
catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode
    }
    $statusSuffix = if ($statusCode) { " (HTTP $statusCode)" } else { "" }
    Write-Host ""
    Write-Host "Google Places direct test failed$statusSuffix." -ForegroundColor Red
    Write-Host "Conclusion: this is a Google API key, billing, or API-activation issue; Flutter and Supabase are not the cause." -ForegroundColor Yellow
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor DarkYellow
    exit 1
}
finally {
    Remove-Variable apiKey -ErrorAction SilentlyContinue
    Remove-Variable secureKey -ErrorAction SilentlyContinue
    if ($keyPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPointer)
    }
}
