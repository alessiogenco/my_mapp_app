# Social & Taste Affinity

## Product direction

The map stays curated: a place appears only after someone deliberately adds it.
Social features explain *who recommends a place* and help friends discover
recommendations from people whose tastes are compatible. They do not publish
every Google Maps place or turn the map into a public review feed.

## Authentication priority

Before inviting friends broadly, add **Continue with Google** as the primary
account path. It should create or link a My Locals profile, prefill available
name/avatar information only with the member's consent, and always leave the
member in control of their visible name, username and privacy settings.

Add **Sign in with Apple** as the equivalent path for iPhone users. Apple does
not normally provide an avatar, so initials or a member-chosen image remain a
safe fallback. Existing email/password accounts need an explicit provider-link
flow to prevent duplicate profiles.

## The member experience

1. A member creates an account and adds a friend by username or invitation.
2. After visiting a curated place, they give a private 1--10 overall rating and
   may add food, location, service and value details.
3. They can optionally mark the rating as a recommendation for accepted
   friends.
4. A place card can then say `Recommended by Marco · strong taste match`.
5. The friend page shows an affinity label, evidence and a short explanation;
   for example: `82% · reliable · 9 places rated in common`.

## Affinity model, version 2

Affinity is calculated only from places that both friends rated. City is useful
for filtering the map, but is not itself a taste signal, so it does not affect
the score. A missing optional detail is excluded rather than interpreted as a
disagreement.

| Signal | Weight | What it compares |
| --- | ---: | --- |
| Overall | 35% | Difference between the two 1--10 ratings for the same places. |
| Food | 25% | Difference between optional food ratings on the same places. |
| Location | 20% | Difference between optional location ratings on the same places. |
| Service | 10% | Difference between optional service ratings on the same places. |
| Value | 10% | Difference between optional value-for-money ratings on the same places. |

The app displays one global score and four separate dimensions. For example,
two friends can have `Location 92%` and `Food 48%`; the difference is useful
information, not an error hidden inside a single average.

Each comparison uses the distance between two 1--10 values: equal values give
100%, a one-point difference gives about 89%, and opposite values give 0%.
The global score only uses components for which both people supplied data and
normalizes their weights again.

A dimension becomes reliable after five detailed ratings in common. The global
score is **reliable after at least five places have been rated by both people**.
Its separate evidence value keeps growing with the shared sample: two matching
ratings can show a strong match but low evidence, while 100 matching ratings
show the same match with very high evidence. Until five shared places it is
labelled preliminary.

Future signals such as shared vibes and price preferences can be displayed as
context, but should not silently change the affinity score without an explicit
product decision.

## Data needed in the backend

The current `places.json` remains the source for curated places during this
stage. Its stable `id` becomes the link to social data.

| Entity | Purpose | Important fields |
| --- | --- | --- |
| `profiles` | Member identity | `id`, `handle`, `display_name`, `avatar_url` |
| `friendships` | Mutual social graph | requester, addressee, status, timestamps |
| `place_ratings` | A member's rating of a curated place | user, place id, overall rating, optional details, note, recommended flag |
| `place_submissions` | Simple contributions from friends | author, name, city, Maps URL, status |

The first account system should enforce that ratings and affinity are visible
only to the owner and accepted friends. Ratings must never be used to create a
public leaderboard.

## Delivery order

1. **Now:** validate the local place dataset and keep stable place IDs. The
   pure affinity calculator and its tests can evolve without an account.
2. **Next:** choose and configure an authentication/database service, then add
   sign in and profiles.
3. **Then:** friend requests and private per-place ratings.
4. **After real ratings exist:** show affinity and `Recommended by` in the
   place sheet.
5. **Last:** simple friend submissions: name, city and Maps link first; the
   owner reviews them before they enter the curated map.
