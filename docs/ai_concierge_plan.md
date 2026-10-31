# My Locals Concierge — future feature

## Goal

Offer a chat-style search that builds plans from **only** the places and social
data stored in My Locals. It must never invent a place, price, opening time or
recommendation that is absent from the app's approved data.

Example request:

> I want meat in Locorotondo, up to 35 EUR per person, then somewhere for a drink.

Example answer:

1. Dinner: an approved meat/grill place that matches city and budget.
2. After dinner: a nearby approved cocktail/bar place that is open.
3. Clear reasons for each pick: estimated price, vibes, curated rating and
   authorized friend recommendations.

## Product rules

- Use the map's approved places as the source of truth; do not use an open web
  search to fill gaps.
- Explain every proposed place with its stored facts.
- If no place matches, say so and suggest which constraint to relax.
- Use friend ratings or recommendations only where the friendship and sharing
  permissions allow it.
- Mark opening status as live data and include a last-checked time.
- Keep the final decision with the user; never present a venue as guaranteed
  available or open.

## Required data

The curated places database will need stable fields for:

- city, coordinates, category and cuisine/tags such as `meat`, `grill` or
  `steakhouse`;
- price range per person;
- vibes and curated notes;
- Google Place ID, where a Google lookup has been intentionally linked;
- later: opening status and current/regular opening hours, stored with a
  refresh time rather than treated as permanent data.

## Ranking and combinations

1. Convert the natural-language request into structured filters: city, budget,
   cuisine/category, vibes, people and desired moment of the evening.
2. Apply hard filters to approved My Locals places.
3. Rank the remaining places using curated rating, the member's rating,
   authorized friends' recommendations and taste affinity.
4. For multi-stop requests, choose compatible nearby places, for example
   dinner + cocktails or aperitivo + dinner + gelato.
5. Explain the plan and display the source data for every suggestion.

## Google Places integration (later)

When a place has a verified Google Place ID, a server-side integration can ask
Google Places API (New) for current opening hours and business status. It may
use `currentOpeningHours.openNow`, next opening/closing time and exceptional
hours, then show a clear "open now" or "check again" status in the app.

The Google key must stay in a server-side function, never in the Flutter app.
Only the fields actually needed should be requested, because Google Places
fields have distinct billing levels and attribution/terms requirements.

## Delivery order

1. Complete and migrate the approved places catalogue from JSON to Supabase.
2. Add friend contributions, duplicate detection and a review workflow.
3. Add personal ratings, recommendations and affinity display.
4. Add structured search and deterministic multi-stop suggestions without AI.
5. Add the chat interface backed by the same search/ranking engine.
6. Add a server-side Google Places enrichment for opening status and hours.
