# Foursquare OS Places resolver

This Cloud Run service is a private fallback for My Locals coordinate lookups.
It reads Foursquare OS Places through its authenticated Iceberg catalog only
when Geoapify cannot return a safe match. It does not download or save the
full dataset.

## Required Cloud Run secrets

- `FSQ_OS_PLACES_TOKEN`: token created from **OS Places → Access Data**.
- `RESOLVER_SHARED_SECRET`: a long random value also stored in Supabase. The
  Supabase Edge Function sends it as `X-My-Locals-Resolver-Key`.

## Request contract

`POST /resolve`

```json
{
  "name": "Patina Bakery and Events",
  "city": "Edinburgh",
  "countryCode": "GB"
}
```

The caller must send `X-My-Locals-Resolver-Key`. Results contain only strict
name-and-city matches. Accent and punctuation variants are normalised, and a
short canonical business name is accepted only if it is the unique candidate
in the selected city and country.

## Updating the deployed resolver

After uploading a changed version of this folder to Google Cloud Shell, run:

```bash
bash redeploy_existing_cloud_shell.sh
```

It rebuilds the existing service without replacing either secret or changing
the public service URL.
