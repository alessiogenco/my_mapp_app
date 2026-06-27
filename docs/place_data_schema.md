# Place data schema

Questo documento descrive il formato consigliato per ogni locale in
`assets/data/places.json`.

## Campi principali

```json
{
  "id": "nome_locale_in_minuscolo",
  "name": "Nome Locale",
  "city": "Alberobello",
  "category": "restaurant",
  "rating": 7,
  "priceLevel": 2,
  "lat": 40.78565142,
  "lng": 17.23836116,
  "vibes": ["cozy", "locals", "friends"],
  "notes": "Breve descrizione utile per l'utente.",
  "googleMapsUrl": "https://www.google.com/maps/search/?api=1&query=Nome%20Locale%20Alberobello",
  "googlePlaceId": "",
  "photoAsset": ""
}
```

## Regole

- `id`: unico, minuscolo, senza spazi. Usa `_` tra le parole.
- `name`: nome mostrato nell'app.
- `city`: città o zona principale.
- `category`: deve essere una delle categorie supportate.
- `rating`: numero da `0` a `10`.
- `priceLevel`: numero da `1` a `3`.
- `lat` e `lng`: coordinate del locale.
- `vibes`: tag brevi in inglese, minuscoli, senza duplicati.
- `notes`: descrizione breve e utile.
- `googleMapsUrl`: opzionale, ma consigliato se hai già il link esatto.
- `googlePlaceId`: opzionale; utile più avanti con Google Places API.
- `photoAsset`: opzionale; per ora può restare vuoto.

## Categorie supportate

- `restaurant`
- `steakhouse`
- `pub`
- `coffee_bar`
- `cocktail_bar`
- `beer_bar`
- `bakery_sweet`
- `bakery_savory`
- `gelateria`

## Vibes consigliate

Puoi aggiungerne altre, ma conviene riusare queste quando possibile:

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
- `panini`
- `solo`
- `street_food`
- `touristy`
- `wine`

Nota: l'app normalizza automaticamente `beers` in `beer`.
