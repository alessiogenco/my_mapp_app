# Social & Taste Affinity

## Product direction

The map stays curated: a place appears only after someone deliberately adds it.
Social features explain *who recommends a place* and help friends discover
recommendations from people whose tastes are compatible. They do not publish
every Google Maps place or turn the map into a public review feed.

## The member experience

1. A member creates an account and adds a friend by username or invitation.
2. After visiting a curated place, they give a private 1--10 overall rating and
   may add food, location, service and value details.
3. They can optionally mark the rating as a recommendation for accepted
   friends.
4. A place card can then say `Recommended by Marco · strong taste match`.
5. The friend page shows an affinity label, evidence and a short explanation;
   for example: `82% · reliable · 9 places rated in common`.

## Affinity model, version 1

The first version is deliberately explainable and uses three signals:

| Signal | Weight | What it compares |
| --- | ---: | --- |
| Same places | 60% | Difference between the two 1--10 ratings for places both members rated. |
| Categories | 25% | Average ratings for common categories, weighted by how many places support each category. |
| Cities | 15% | Average ratings for common cities, also weighted by evidence. |

The score is 0--100. It is **reliable only after at least five places have
been rated by both people**. Until then the app labels it as preliminary, even
if the numerical score happens to be high. This prevents a superficial match
from looking more certain than it is.

Future signals can be added only after enough real data exists: vibe patterns,
price preference, rating-detail agreement and recommendation acceptance. They
should not silently replace the initial three signals.

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
