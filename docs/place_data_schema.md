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
  "lat": 40.78565142,
  "lng": 17.23836116,
  "vibes": ["cozy", "locals", "friends"],
  "notes": "A short useful description for the user.",
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
- `priceLevel`: number from `1` to `3`.
- `lat` and `lng`: place coordinates.
- `vibes`: short lowercase English tags, without duplicates.
- `notes`: short useful description.
- `googleMapsUrl`: optional, but recommended when you have the exact link.
- `googlePlaceId`: optional; useful later with Google Places API.
- `photoAsset`: optional; it can stay empty for now.

## Supported categories

- `restaurant`
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

Note: the app automatically normalizes `beers` to `beer`.
