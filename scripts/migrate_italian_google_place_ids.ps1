param(
    [switch] $Apply
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$PlacesPath = Join-Path $ProjectRoot "assets\data\places.json"
$BackupDirectory = Join-Path $ProjectRoot "assets\data\backups"
$GoogleTextSearchUri = "https://places.googleapis.com/v1/places:searchText"

function ConvertTo-NormalizedText {
    param([AllowNull()][string] $Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    $decomposed = $Value.Normalize([Text.NormalizationForm]::FormD)
    $withoutMarks = -join ($decomposed.ToCharArray() | Where-Object {
        [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne
            [Globalization.UnicodeCategory]::NonSpacingMark
    })

    $normalized = $withoutMarks.ToLowerInvariant() `
        -replace "&", " and " `
        -replace "\bpanificio\b", "bakery" `
        -replace "\bpasticceria\b", "bakery" `
        -replace "[^a-z0-9]+", " "
    return (($normalized.Trim()) -replace "\s+", " ")
}

function Get-DistanceMeters {
    param(
        [double] $FirstLatitude,
        [double] $FirstLongitude,
        [double] $SecondLatitude,
        [double] $SecondLongitude
    )

    $degreesToRadians = [Math]::PI / 180
    $latitudeDelta = ($SecondLatitude - $FirstLatitude) * $degreesToRadians
    $longitudeDelta = ($SecondLongitude - $FirstLongitude) * $degreesToRadians
    $firstLatitudeRadians = $FirstLatitude * $degreesToRadians
    $secondLatitudeRadians = $SecondLatitude * $degreesToRadians
    $haversine = [Math]::Sin($latitudeDelta / 2) * [Math]::Sin($latitudeDelta / 2) +
        [Math]::Cos($firstLatitudeRadians) * [Math]::Cos($secondLatitudeRadians) *
        [Math]::Sin($longitudeDelta / 2) * [Math]::Sin($longitudeDelta / 2)
    return 6371000 * 2 * [Math]::Atan2([Math]::Sqrt($haversine), [Math]::Sqrt(1 - $haversine))
}

function Get-GoogleMapsCid {
    param([AllowNull()][string] $Url)

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return ""
    }

    try {
        $uri = [Uri] $Url
        foreach ($part in $uri.Query.TrimStart('?').Split('&')) {
            $pair = $part.Split('=', 2)
            if ($pair.Count -eq 2 -and $pair[0] -eq 'cid') {
                return [Uri]::UnescapeDataString($pair[1])
            }
        }
    } catch {
        # Continue with the CID representation embedded in older Maps URLs.
    }

    $hexMatch = [regex]::Match($Url, ':0x([0-9a-fA-F]+)')
    if (-not $hexMatch.Success) {
        return ""
    }

    try {
        # The second hexadecimal number in older /maps/place links is the
        # same CID shown as decimal in Google's current direct Maps link.
        return [System.Numerics.BigInteger]::Parse(
            "0$($hexMatch.Groups[1].Value)",
            [Globalization.NumberStyles]::AllowHexSpecifier
        ).ToString()
    } catch {
        return ""
    }
}

function Get-MeaningfulTokens {
    param(
        [string] $Value,
        [string] $City
    )

    $ignoredTokens = @(
        "bar", "cafe", "caffe", "coffee", "gelateria", "osteria", "pizzeria",
        "pub", "restaurant", "ristorante", "trattoria"
    )
    $normalizedCity = ConvertTo-NormalizedText $City
    return @(ConvertTo-NormalizedText $Value -split " " |
        Where-Object {
            $_.Length -ge 3 -and $_ -notin $ignoredTokens -and $_ -ne $normalizedCity
        } |
        Select-Object -Unique)
}

function Get-PlaceMatch {
    param(
        [pscustomobject] $Place,
        [pscustomobject] $Candidate
    )

    $candidateName = [string] $Candidate.displayName.text
    $candidateAddress = [string] $Candidate.formattedAddress
    $candidateMapsUrl = [string] $Candidate.googleMapsUri
    $candidateLatitude = $Candidate.location.latitude
    $candidateLongitude = $Candidate.location.longitude

    if ($null -eq $candidateLatitude -or $null -eq $candidateLongitude) {
        return $null
    }

    $placeName = ConvertTo-NormalizedText $Place.name
    $googleName = ConvertTo-NormalizedText $candidateName
    $city = ConvertTo-NormalizedText $Place.city
    $address = ConvertTo-NormalizedText $candidateAddress
    $savedCid = Get-GoogleMapsCid $Place.googleMapsUrl
    $candidateCid = Get-GoogleMapsCid $candidateMapsUrl
    $mapsLinkMatches = $savedCid.Length -gt 0 -and $savedCid -eq $candidateCid
    $distanceMeters = Get-DistanceMeters `
        -FirstLatitude ([double] $Place.lat) `
        -FirstLongitude ([double] $Place.lng) `
        -SecondLatitude ([double] $candidateLatitude) `
        -SecondLongitude ([double] $candidateLongitude)

    $exactName = $placeName -eq $googleName
    $containsName = $placeName.Length -ge 4 -and
        ($googleName.Contains($placeName) -or $placeName.Contains($googleName))
    $cityMatches = $city.Length -lt 3 -or $address.Contains($city)

    $placeTokens = @(Get-MeaningfulTokens -Value $Place.name -City $Place.city)
    $googleTokens = @(Get-MeaningfulTokens -Value $candidateName -City $Place.city)
    $matchingTokens = @($placeTokens | Where-Object { $_ -in $googleTokens }).Count
    $tokenCoverage = if ($placeTokens.Count -eq 0) {
        0
    } else {
        $matchingTokens / $placeTokens.Count
    }

    # An ID is assigned only when both the name and the existing map point
    # make the Google result unambiguous. We deliberately leave uncertain
    # venues in the report rather than attaching a badge to the wrong place.
    $accepted = $mapsLinkMatches -or
        ($exactName -and (
            ($cityMatches -and $distanceMeters -le 3000) -or
            $distanceMeters -le 250
        )) -or
        ($cityMatches -and (
        ($containsName -and $distanceMeters -le 800) -or
        ($placeTokens.Count -ge 2 -and $tokenCoverage -ge 0.8 -and $distanceMeters -le 250)
        ))

    $confidence =
        $(if ($exactName) { 100 } elseif ($containsName) { 80 } else { [Math]::Round($tokenCoverage * 60) }) +
        $(if ($mapsLinkMatches) { 1000 } elseif ($cityMatches) { 15 } else { 0 }) -
        [Math]::Min(50, [Math]::Round($distanceMeters / 100))

    return [pscustomobject]@{
        Accepted = $accepted
        Confidence = $confidence
        DistanceMeters = [Math]::Round($distanceMeters)
        GooglePlaceId = [string] $Candidate.id
        GoogleName = $candidateName
        GoogleAddress = $candidateAddress
        MapsLinkMatches = $mapsLinkMatches
    }
}

function Copy-PlacesBackup {
    param([string] $Timestamp)

    New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
    $backupPath = Join-Path $BackupDirectory "places_before_google_id_migration_$Timestamp.json"
    Copy-Item -LiteralPath $PlacesPath -Destination $backupPath -Force
    return $backupPath
}

Set-Location $ProjectRoot

$secureKey = Read-Host -Prompt "Google Places API key (hidden)" -AsSecureString
$keyPointer = [IntPtr]::Zero

try {
    $keyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
    $apiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPointer)
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw "No Google Places API key was entered."
    }

    # Windows PowerShell 5 can expose a JSON root array as one pipeline item,
    # while newer PowerShell versions enumerate it. Expand it explicitly so
    # both versions inspect every saved place rather than one array wrapper.
    $decodedPlaces = Get-Content -LiteralPath $PlacesPath -Raw -Encoding UTF8 |
        ConvertFrom-Json
    $places = [System.Collections.ArrayList]::new()
    if ($decodedPlaces -is [System.Collections.IEnumerable] -and
        $decodedPlaces -isnot [string]) {
        foreach ($decodedPlace in $decodedPlaces) {
            [void] $places.Add($decodedPlace)
        }
    } else {
        [void] $places.Add($decodedPlaces)
    }
    $italianPlaces = @($places | Where-Object { $_.countryCode -eq "IT" })
    $targets = @($places | Where-Object {
        $_.countryCode -eq "IT" -and [string]::IsNullOrWhiteSpace($_.googlePlaceId)
    })
    $withGooglePlaceId = $italianPlaces.Count - $targets.Count

    Write-Host ""
    Write-Host "Reading: $PlacesPath" -ForegroundColor DarkCyan
    Write-Host "Italian places: $($italianPlaces.Count)  |  IDs already saved: $withGooglePlaceId  |  IDs missing: $($targets.Count)" -ForegroundColor DarkCyan

    if ($targets.Count -eq 0) {
        Write-Host "All Italian places already have a Google Place ID." -ForegroundColor Green
        exit 0
    }

    Write-Host ""
    Write-Host "Italian places without a Google Place ID: $($targets.Count)" -ForegroundColor Cyan
    Write-Host "The script checks Google name, city, and the saved map position before assigning an ID." -ForegroundColor Cyan
    Write-Host ""

    if (-not $Apply) {
        Write-Host "No files changed. Re-run with -Apply to perform the migration." -ForegroundColor Yellow
        exit 0
    }

    $confirmation = Read-Host "This makes $($targets.Count) Google Places searches and updates places.json. Type MIGRATE to continue"
    if ($confirmation -cne "MIGRATE") {
        Write-Host "Migration cancelled. No files were changed." -ForegroundColor Yellow
        exit 0
    }

    $headers = @{
        "Content-Type" = "application/json"
        "X-Goog-Api-Key" = $apiKey
        "X-Goog-FieldMask" = "places.id,places.displayName,places.formattedAddress,places.location,places.googleMapsUri"
    }
    $matched = @()
    $unresolved = @()
    $failed = @()

    foreach ($place in $targets) {
        Write-Host "Searching: $($place.name) · $($place.city)"
        $body = @{
            textQuery = "$($place.name), $($place.city), Italy"
            pageSize = 5
            languageCode = "it"
            regionCode = "it"
            locationBias = @{
                circle = @{
                    center = @{
                        latitude = [double] $place.lat
                        longitude = [double] $place.lng
                    }
                    radius = 3000.0
                }
            }
        } | ConvertTo-Json -Depth 8 -Compress

        try {
            $response = Invoke-RestMethod -Method Post -Uri $GoogleTextSearchUri -Headers $headers -Body $body
            $sortProperties = @(
                @{ Expression = 'Confidence'; Descending = $true }
                @{ Expression = 'DistanceMeters'; Descending = $false }
            )
            $candidates = @($response.places | ForEach-Object {
                Get-PlaceMatch -Place $place -Candidate $_
            } | Where-Object { $null -ne $_ } | Sort-Object -Property $sortProperties)

            $safeMatches = @($candidates | Where-Object Accepted)
            $safeMatch = $null
            if ($safeMatches.Count -eq 1) {
                $safeMatch = $safeMatches[0]
            } elseif ($safeMatches.Count -gt 1) {
                $first = $safeMatches[0]
                $second = $safeMatches[1]
                if ($first.MapsLinkMatches -or
                    $first.Confidence - $second.Confidence -ge 10 -or
                    ($first.DistanceMeters -le 50 -and
                        $second.DistanceMeters - $first.DistanceMeters -ge 50)) {
                    $safeMatch = $first
                }
            }

            if ($null -ne $safeMatch) {
                $place | Add-Member -NotePropertyName 'googlePlaceId' -NotePropertyValue $safeMatch.GooglePlaceId -Force
                $matched += [pscustomobject]@{
                    Id = $place.id
                    Name = $place.name
                    City = $place.city
                    GooglePlaceId = $safeMatch.GooglePlaceId
                    GoogleName = $safeMatch.GoogleName
                    DistanceMeters = $safeMatch.DistanceMeters
                }
                Write-Host "  Matched: $($safeMatch.GoogleName) ($($safeMatch.DistanceMeters)m)" -ForegroundColor Green
            } else {
                $unresolved += [pscustomobject]@{
                    Id = $place.id
                    Name = $place.name
                    City = $place.city
                    Candidates = @($candidates | Select-Object -First 3 GoogleName, GoogleAddress, DistanceMeters, Confidence)
                }
                Write-Host "  Skipped: no single safe Google match." -ForegroundColor Yellow
            }
        } catch {
            $failed += [pscustomobject]@{
                Id = $place.id
                Name = $place.name
                City = $place.city
                Error = $_.Exception.Message
            }
            Write-Host "  Failed: $($_.Exception.Message)" -ForegroundColor Red
        }

        Start-Sleep -Milliseconds 120
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $reportPath = Join-Path $BackupDirectory "google_id_migration_report_$timestamp.json"
    New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
    [pscustomobject]@{
        migratedAt = (Get-Date).ToString("o")
        matched = $matched
        unresolved = $unresolved
        failed = $failed
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reportPath -Encoding UTF8

    $backupPath = $null
    if ($matched.Count -gt 0) {
        $backupPath = Copy-PlacesBackup -Timestamp $timestamp
        $places | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $PlacesPath -Encoding UTF8
    }

    Write-Host ""
    Write-Host "Migration complete." -ForegroundColor Green
    Write-Host "Matched: $($matched.Count)  |  Needs review: $($unresolved.Count)  |  Failed: $($failed.Count)"
    if ($backupPath) {
        Write-Host "Backup: $backupPath"
    }
    Write-Host "Report: $reportPath"
}
finally {
    Remove-Variable apiKey -ErrorAction SilentlyContinue
    Remove-Variable secureKey -ErrorAction SilentlyContinue
    if ($keyPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPointer)
    }
}
