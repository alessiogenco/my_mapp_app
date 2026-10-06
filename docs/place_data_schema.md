# Place data schema

This document describes the recommended format for each place in
`assets/data/places.json`.

## Main fields

```json
{
  "id": "place_name_lowercase",
  "name": "Place Name",
  "city": "Alberobello",
  "category": "restaurant",
  "area": "cityCentre",
  "neighborhood": "",
  "rating": 7,
  "priceLevel": 2,
  "ratingDetails": {
    "food": 8,
    "location": 8,
    "service": 9,
    "value": 8
  },
  "lat": 40.78565142,
  "lng": 17.23836116,
  "vibes": ["cozy", "locals", "friends"],
  "notes": "A short useful description for the user.",
  "websiteUrl": "https://www.example.com",
  "instagramUrl": "https://www.instagram.com/place_profile/",
  "googleMapsUrl": "https://www.google.com/maps/search/?api=1&query=Place%20Name%20Alberobello",
  "googlePlaceId": "",
  "photoAsset": ""
}
```

## Rules

- `id`: unique, lowercase, no spaces. Use `_` between words.
- `name`: the name shown in the app.
- `city`: the main city.
- `category`: must be one of the supported categories.
- `area`: must be one of the supported areas.
- `neighborhood`: optional district or sub-area.
- `rating`: number from `0` to `10`.
- `priceLevel`: number from `1` to `5`, based on average spend per person.
- `ratingDetails`: optional detailed ratings from `1` to `10`.
- `lat` and `lng`: place coordinates.
- `vibes`: short lowercase English tags, without duplicates.
- `notes`: short useful description.
- `websiteUrl`: optional official website for the place.
- `instagramUrl`: optional official Instagram profile for the place.
- `googleMapsUrl`: optional, but recommended when you have the exact link.
- `googlePlaceId`: optional; useful later with Google Places API.
- `photoAsset`: optional; it can stay empty for now.

## Supported categories

- `restaurant`
- `sushi`
- `chinese`
- `indian`
- `pizzeria`
- `panzerotteria`
- `steakhouse`
- `pub`
- `coffee_bar`
- `cocktail_bar`
- `beer_bar`
- `bakery_sweet`
- `bakery_savory`
- `gelateria`

## Supported areas

- `cityCentre`: city centre
- `historicalCentre`: historic centre
- `periphery`: periphery
- `outsideCentre`: outside centre

## Recommended vibes

You can add more, but it is better to reuse these when possible:

- `aperitif`
- `authentic`
- `beer`
- `breakfast`
- `casual`
- `cocktails`
- `coffee`
- `cozy`
- `coworkers`
- `date`
- `family`
- `friends`
- `late-night`
- `locals`
- `lunch`
- `panini`
- `solo`
- `street_food`
- `touristy`
- `wine`

## Detailed rating suggestion

For now the app supports these optional detailed rating keys:

- `food`: food or drink quality.
- `location`: atmosphere, view, position and general setting.
- `service`: staff, waiting time and hospitality.
- `value`: value for money.

Use `rating` for the quick overall score from `0` to `10`. Use
`ratingDetails` for more specific scores from `1` to `10`. Leaving it empty is
fine.

## Price level ranges

`priceLevel` means average spend per person:

- `1`: `€` = 0–15€
- `2`: `€€` = 15–35€
- `3`: `€€€` = 35–70€
- `4`: `€€€€` = 70–100€
- `5`: `€€€€€` = 100€+

Note: the app automatically normalizes `beers` to `beer`.
