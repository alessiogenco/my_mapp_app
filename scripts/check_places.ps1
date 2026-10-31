$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$PlacesPath = Join-Path $ProjectRoot "assets\data\places.json"

$AllowedCategories = @(
    "restaurant",
    "sushi",
    "chinese",
    "indian",
    "pizzeria",
    "panzerotteria",
    "steakhouse",
    "pub",
    "coffee_bar",
    "cocktail_bar",
    "beer_bar",
    "bakery_sweet",
    "bakery_savory",
    "gelateria"
)

$AllowedAreas = @(
    "cityCentre",
    "historicalCentre",
    "periphery",
    "outsideCentre"
)

function Add-Issue {
    param([string] $Message)
    $script:Issues.Add($Message) | Out-Null
}

$Issues = [System.Collections.Generic.List[string]]::new()

try {
    $Places = Get-Content -Raw -Path $PlacesPath | ConvertFrom-Json
} catch {
    Write-Host "Invalid JSON:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

if ($null -eq $Places -or $Places.GetType().Name -ne "Object[]") {
    Write-Host "places.json must contain a JSON array." -ForegroundColor Red
    exit 1
}

$SeenIds = @{}

foreach ($Place in $Places) {
    $Label = if ($Place.name) { $Place.name } else { "<missing name>" }

    if ([string]::IsNullOrWhiteSpace($Place.id)) {
        Add-Issue "$Label has an empty id."
    } elseif ($SeenIds.ContainsKey($Place.id)) {
        Add-Issue "Duplicated id: $($Place.id)."
    } else {
        $SeenIds[$Place.id] = $true
    }

    if ([string]::IsNullOrWhiteSpace($Place.name)) {
        Add-Issue "$($Place.id) has an empty name."
    }

    if ($Place.countryCode -notmatch '^[A-Z]{2}$') {
        Add-Issue "$Label has invalid countryCode: $($Place.countryCode)."
    }

    if ($Place.currencyCode -notmatch '^[A-Z]{3}$') {
        Add-Issue "$Label has invalid currencyCode: $($Place.currencyCode)."
    }

    if ($AllowedCategories -notcontains $Place.category) {
        Add-Issue "$Label has invalid category: $($Place.category)."
    }

    if ($AllowedAreas -notcontains $Place.area) {
        Add-Issue "$Label has invalid area: $($Place.area)."
    }

    if ($Place.rating -lt 0 -or $Place.rating -gt 10) {
        Add-Issue "$Label has invalid rating: $($Place.rating)."
    }

    if ($Place.priceLevel -lt 1 -or $Place.priceLevel -gt 5) {
        Add-Issue "$Label has invalid priceLevel: $($Place.priceLevel)."
    }

    if ($null -ne $Place.ratingDetails) {
        foreach ($RatingDetail in $Place.ratingDetails.PSObject.Properties) {
            if ($RatingDetail.Name -eq "priceLevel") {
                Add-Issue "$Label has ratingDetails.priceLevel. Keep priceLevel only as a main field."
                continue
            }

            if ($RatingDetail.Value -lt 1 -or $RatingDetail.Value -gt 10) {
                Add-Issue "$Label has invalid ratingDetails.$($RatingDetail.Name): $($RatingDetail.Value)."
            }
        }
    }

    if ($Place.lat -lt -90 -or $Place.lat -gt 90) {
        Add-Issue "$Label has invalid latitude: $($Place.lat)."
    }

    if ($Place.lng -lt -180 -or $Place.lng -gt 180) {
        Add-Issue "$Label has invalid longitude: $($Place.lng)."
    }

    if ($null -eq $Place.vibes -or $Place.vibes.Count -eq 0) {
        Add-Issue "$Label has no vibes."
    }

    if ($null -ne $Place.foodTags) {
        foreach ($FoodTag in $Place.foodTags) {
            if ([string]::IsNullOrWhiteSpace($FoodTag) -or $FoodTag -notmatch '^[a-z0-9_]+$') {
                Add-Issue "$Label has invalid food tag: $FoodTag."
            }
        }
    }

    foreach ($UrlField in @("websiteUrl", "instagramUrl", "googleMapsUrl")) {
        $Url = $Place.$UrlField
        if (-not [string]::IsNullOrWhiteSpace($Url) -and $Url -notmatch "^https?://") {
            Add-Issue "$Label has invalid $UrlField`: $Url."
        }
        if ($UrlField -eq "instagramUrl" -and -not [string]::IsNullOrWhiteSpace($Url) -and $Url -notmatch "^https?://(www\.)?instagram\.com/") {
            Add-Issue "$Label has invalid instagramUrl host: $Url."
        }
    }
}

Write-Host "Places: $($Places.Count)" -ForegroundColor Cyan
Write-Host "Cities: $(( $Places.city | Sort-Object -Unique ) -join ', ')"
Write-Host "Countries: $(( $Places.countryCode | Sort-Object -Unique ) -join ', ')"
Write-Host "Currencies: $(( $Places.currencyCode | Sort-Object -Unique ) -join ', ')"
Write-Host "Categories: $(( $Places.category | Sort-Object -Unique ) -join ', ')"
Write-Host "Areas: $(( $Places.area | Sort-Object -Unique ) -join ', ')"

if ($Issues.Count -gt 0) {
    Write-Host ""
    Write-Host "Issues found:" -ForegroundColor Red
    foreach ($Issue in $Issues) {
        Write-Host "- $Issue"
    }
    exit 1
}

Write-Host ""
Write-Host "Dataset check passed." -ForegroundColor Green
