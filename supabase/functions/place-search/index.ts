import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  // supabase_flutter adds x-client-info on browser calls. Omitting it lets the
  // preflight OPTIONS request pass but makes the browser block the real POST.
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "private, no-store",
};

// Applied separately to each signed-in member, not to the whole app.
const maxLookupsPerDay = 100;
const maxResults = 5;
const maxCoordinateLookupDurationMs = 30_000;
// A place search can use Text Search and, only when needed, Autocomplete.
// Keep their combined wait within the same user-visible limit.
const maxGoogleSearchDurationMs = 60_000;

type SearchRequest = {
  action?: unknown;
  name?: unknown;
  city?: unknown;
  address?: unknown;
  countryCode?: unknown;
  placeId?: unknown;
};

type GoogleTextSearchResponse = {
  places?: Array<{
    id?: string;
    displayName?: { text?: string };
    formattedAddress?: string;
  }>;
};

type GoogleAutocompleteResponse = {
  suggestions?: Array<{
    placePrediction?: {
      placeId?: string;
      text?: { text?: string };
      structuredFormat?: {
        mainText?: { text?: string };
        secondaryText?: { text?: string };
      };
    };
  }>;
};

type GooglePlaceDetailsResponse = {
  googleMapsUri?: string;
  formattedAddress?: string;
  addressComponents?: Array<{
    shortText?: string;
    types?: string[];
  }>;
};

type PlaceSearchResult = {
  placeId: string;
  name: string;
  address: string;
};

type GeoapifyGeocodingResponse = {
  results?: Array<{
    lat?: number;
    lon?: number;
    name?: string;
    formatted?: string;
  }>;
};

type GeoapifyPlacesResponse = {
  features?: Array<{
    properties?: {
      name?: string;
      formatted?: string;
    };
    geometry?: {
      coordinates?: unknown;
    };
  }>;
};

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

// Google uses ccTLDs for response formatting. Most countries have the same
// code as ISO 3166-1, but the United Kingdom is the important exception.
function googleRegionCode(countryCode: string): string {
  return countryCode === "GB" ? "uk" : countryCode.toLowerCase();
}

function countryCodeFromAddressComponents(
  addressComponents: GooglePlaceDetailsResponse["addressComponents"],
): string {
  const country = addressComponents?.find((component) =>
    component.types?.includes("country")
  );
  const countryCode = text(country?.shortText).toUpperCase();
  return /^[A-Z]{2}$/.test(countryCode) ? countryCode : "";
}

function normalizeForComparison(value: string): string {
  return value
    // Geoapify and other open-map sources may record an otherwise identical
    // venue without its accents ("Cafe") while Google returns "Café". Fold
    // those variants before comparing; this affects matching only, never the
    // name shown to or stored by the app.
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase()
    // Providers vary between "Fish & Chips" and "Fish and Chips". Treat
    // these as the same name before removing punctuation.
    .replace(/&/g, " and ")
    .replace(/[’']/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/ +/g, " ");
}

function venueNameWithoutTrailingCity(name: string, city: string): string {
  const cleanName = name.trim();
  const cleanCity = city.trim();
  if (!cleanName || !cleanCity) return cleanName;

  const escapedCity = cleanCity.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const trailingCity = new RegExp(
    `(?:\\s*[-,–—]\\s*|\\s+)${escapedCity}\\s*$`,
    "i",
  );
  const venueName = cleanName.replace(trailingCity, "").trim();
  return venueName || cleanName;
}

// Google often indexes a venue by its short trading name, while people copy a
// longer Maps label such as "Grains Majorstuen - Bakeri & Crêperie". Use the
// meaningful part before a descriptive dash or pipe for the lookup only; the
// full name stays untouched in the app and in the returned result.
function venueNameForGoogleSearch(name: string): string {
  const cleanName = name.trim();
  const primaryName = cleanName.split(/\s+[-–—|]\s+/)[0]?.trim() ?? "";
  return primaryName.length >= 3 ? primaryName : cleanName;
}

function hasSimilarGooglePlaceName(
  places: PlaceSearchResult[],
  requestedName: string,
): boolean {
  const requested = normalizeForComparison(requestedName);
  if (!requested) return false;

  return places.some((place) => {
    const candidate = normalizeForComparison(place.name);
    return candidate === requested ||
      candidate.includes(requested) ||
      (candidate.length >= 5 && requested.includes(candidate));
  });
}

function hasValidCoordinates(
  candidate: { latitude: unknown; longitude: unknown },
): candidate is { latitude: number; longitude: number } {
  return (
    typeof candidate.latitude === "number" &&
    typeof candidate.longitude === "number" &&
    Number.isFinite(candidate.latitude) &&
    Number.isFinite(candidate.longitude) &&
    candidate.latitude >= -90 &&
    candidate.latitude <= 90 &&
    candidate.longitude >= -180 &&
    candidate.longitude <= 180
  );
}

// Give an exact venue-name match priority, but also support a result whose
// canonical name omits a neighbourhood. For example, a contributor may enter
// "Celino's Partick" while the open-data name is simply "Celino's" and the
// neighbourhood appears in the formatted address.
function venueMatchScore(
  expectedName: string,
  candidateName: string,
  candidateAddress: string,
): number {
  const expected = normalizeForComparison(expectedName);
  const name = normalizeForComparison(candidateName);
  const address = normalizeForComparison(candidateAddress);
  const combined = `${name} ${address}`.trim();

  if (!expected || !combined) return 0;
  if (name === expected) return 100;
  if (name.includes(expected)) return 95;
  if (combined.includes(expected)) return 90;

  // Do not treat a one- or two-letter fragment as a venue name. A shorter
  // canonical name can be accepted only when it is meaningful and is fully
  // contained in the submitted name.
  if (name.length >= 4 && expected.includes(name)) return 70;
  return 0;
}

function hasMatchingStreetAddress(
  candidateAddress: string,
  submittedAddress: string,
): boolean {
  // The fallback accepts an address only when the returned result contains
  // the submitted street/number. This lets a member provide a street address
  // instead of raw coordinates without silently placing a venue elsewhere.
  const submittedStreet = normalizeForComparison(
    submittedAddress.split(",")[0] ?? submittedAddress,
  );
  const candidate = normalizeForComparison(candidateAddress);
  return submittedStreet.length >= 4 && candidate.includes(submittedStreet);
}

function selectReliableGeocodingResult(
  results: GeoapifyGeocodingResponse["results"],
  venueName: string,
  city: string,
  address = "",
): { latitude: number; longitude: number } | null {
  const normalizedCity = normalizeForComparison(city);
  const matches = (results ?? [])
    .map((candidate) => {
      const latitude = candidate.lat;
      const longitude = candidate.lon;
      const score = venueMatchScore(
        venueName,
        candidate.name ?? "",
        candidate.formatted ?? "",
      );
      const addressMatches = address.length > 0 && hasMatchingStreetAddress(
        candidate.formatted ?? "",
        address,
      );
      const matchesCity = !normalizedCity ||
        normalizeForComparison(candidate.formatted ?? "").includes(
          normalizedCity,
        );
      return {
        latitude,
        longitude,
        score: addressMatches ? Math.max(score, 110) : score,
        matchesCity,
      };
    })
    .filter((candidate): candidate is {
      latitude: number;
      longitude: number;
      score: number;
      matchesCity: boolean;
    } =>
      hasValidCoordinates(candidate) &&
      candidate.score >= 90 &&
      // The city is included in the provider query, but verify it again in
      // its returned display address. This avoids accepting another branch
      // with the same name, without needing a separate city lookup first.
      candidate.matchesCity
    )
    .sort((first, second) => second.score - first.score);

  const best = matches[0];
  if (!best) return null;

  // Do not silently choose between equally suitable branches.
  const next = matches[1];
  if (next?.score === best.score) return null;

  return { latitude: best.latitude, longitude: best.longitude };
}

// Temporary diagnostic for one real lookup. It records only the open-data
// provider's candidate names and match scores—never API keys, Google content,
// a user's street-address fallback, or coordinates. This lets us distinguish
// "no Geoapify result" from "a result was rejected by our safety checks".
function logGeocodingCandidates(
  stage: string,
  results: GeoapifyGeocodingResponse["results"],
  venueName: string,
): void {
  const candidates = (results ?? []).slice(0, 5).map((candidate) => ({
    name: text(candidate.name),
    score: venueMatchScore(
      venueName,
      candidate.name ?? "",
      candidate.formatted ?? "",
    ),
  }));
  console.log("Geoapify coordinate diagnostic", {
    stage,
    venueName,
    candidateCount: (results ?? []).length,
    candidates,
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return json({ error: "Use POST for place search." }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const googlePlacesApiKey = Deno.env.get("GOOGLE_PLACES_API_KEY");
  const geoapifyApiKey = Deno.env.get("GEOAPIFY_API_KEY");

  if (
    !supabaseUrl ||
    !supabaseAnonKey ||
    !supabaseServiceRoleKey ||
    !googlePlacesApiKey
  ) {
    console.error("Place search is missing a required server secret.");
    return json({ error: "Place search is not configured yet." }, 503);
  }

  const authorization = request.headers.get("Authorization") ?? "";
  const authClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const {
    data: { user },
    error: authError,
  } = await authClient.auth.getUser();

  if (authError || !user) {
    return json({ error: "Sign in to search for a place." }, 401);
  }

  let payload: SearchRequest;
  try {
    payload = await request.json();
  } catch (_) {
    return json({ error: "The search request is not valid." }, 400);
  }

  const action = text(payload.action) || "search";
  if (
    action !== "search" &&
    action !== "details" &&
    action !== "coordinates"
  ) {
    return json({ error: "This place request is not supported." }, 400);
  }

  const placeId = text(payload.placeId);
  const name = text(payload.name);
  const city = text(payload.city);
  const address = text(payload.address);
  const countryCode = text(payload.countryCode).toUpperCase();
  if (action === "details" && (placeId.length < 8 || placeId.length > 220)) {
    return json({ error: "The selected Google Place ID is not valid." }, 400);
  }
  if (
    (action === "search" || action === "coordinates") &&
    (name.length < 2 || city.length < 2 || name.length > 160 || city.length > 120)
  ) {
    return json({ error: "Enter a place name and city before searching." }, 400);
  }
  if (countryCode.length > 0 && !/^[A-Z]{2}$/.test(countryCode)) {
    return json({ error: "Use a two-letter country code, such as GB or IT." }, 400);
  }
  if (address.length > 220) {
    return json({ error: "Use a shorter street address." }, 400);
  }

  const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey);
  // A member consciously starts a Google search once per place. Loading the
  // selected place details and resolving its marker are required follow-up
  // steps, so they must not silently consume the daily search allowance.
  if (action === "search") {
    const { data: maySearch, error: quotaError } = await adminClient.rpc(
      "consume_place_lookup_quota",
      { p_user_id: user.id, p_limit: maxLookupsPerDay },
    );
    if (quotaError) {
      console.error("Could not consume place lookup quota:", quotaError.message);
      return json({ error: "Place search is temporarily unavailable." }, 503);
    }
    if (maySearch != true) {
      return json(
        {
          error:
            `You have reached today’s ${maxLookupsPerDay} place searches. Try again tomorrow.`,
        },
        429,
      );
    }
  }

  if (action === "coordinates") {
    // First look up the selected venue by name. If open map data has no safe
    // match, the app asks only for a street address and retries this same
    // automatic lookup; raw latitude and longitude are never requested.
    const venueName = venueNameWithoutTrailingCity(name, city);

    if (!geoapifyApiKey) {
      return json({ error: "Map coordinates are not configured yet." }, 503);
    }
    // A selected Google Place normally supplies the country. A supplied
    // street address is also specific enough to retry safely when details
    // could not return a country code.
    if (!countryCode && !address) {
      return json({});
    }

    const searchUrl = new URL("https://api.geoapify.com/v1/geocode/search");
    searchUrl.searchParams.set(
      "text",
      address ? `${venueName}, ${address}` : `${venueName}, ${city}`,
    );
    searchUrl.searchParams.set("format", "json");
    searchUrl.searchParams.set("limit", "5");
    if (countryCode) {
      searchUrl.searchParams.set(
        "filter",
        `countrycode:${countryCode.toLowerCase()}`,
      );
    }
    searchUrl.searchParams.set("apiKey", geoapifyApiKey);

    let response: Response;
    try {
      response = await fetch(searchUrl, {
        // Give the provider enough time to answer on a slow connection while
        // still avoiding the long chain of fallback requests used previously.
        signal: AbortSignal.timeout(maxCoordinateLookupDurationMs),
      });
    } catch (error) {
      console.info("Fast coordinate lookup was unavailable", {
        name: venueName,
        city,
        message: error instanceof Error ? error.name : "unknown",
      });
      return json({});
    }

    if (!response.ok) {
      console.error("Fast coordinate lookup failed:", response.status);
      return json({});
    }

    const payload = (await response.json()) as GeoapifyGeocodingResponse;
    logGeocodingCandidates("fast-name-and-city", payload.results, venueName);
    const coordinates = selectReliableGeocodingResult(
      payload.results,
      venueName,
      city,
      address,
    );
    if (coordinates) {
      console.log("Fast coordinates resolved", { name: venueName, city });
      return json(coordinates);
    }

    console.log("Fast coordinate lookup found no reliable match", {
      name: venueName,
      city,
    });
    return json({});
  }

  if (action === "details") {
    let detailsResponse: Response;
    try {
      detailsResponse = await fetch(
        `https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}`,
        {
          headers: {
            "X-Goog-Api-Key": googlePlacesApiKey,
            // Google Maps URI is the official deep link to the selected place.
            "X-Goog-FieldMask":
              "googleMapsUri,formattedAddress,addressComponents",
          },
          signal: AbortSignal.timeout(5_000),
        },
      );
    } catch (error) {
      console.info("Place Details was unavailable", {
        placeId,
        message: error instanceof Error ? error.name : "unknown",
      });
      return json({ error: "Google could not load this place link right now." }, 502);
    }
    if (!detailsResponse.ok) {
      console.error(
        "Google Place Details failed:",
        detailsResponse.status,
        await detailsResponse.text(),
      );
      return json({ error: "Google could not load this place link right now." }, 502);
    }

    const detailsPayload =
      (await detailsResponse.json()) as GooglePlaceDetailsResponse;
    const googleMapsUrl = text(detailsPayload.googleMapsUri);
    const address = text(detailsPayload.formattedAddress);
    const countryCode = countryCodeFromAddressComponents(
      detailsPayload.addressComponents,
    );
    console.log("Place Details completed", {
      placeId,
      hasGoogleMapsUrl: googleMapsUrl.length > 0,
      hasAddress: address.length > 0,
      countryCode,
    });
    return json({ googleMapsUrl, countryCode, address });
  }

  // The documented Text Search format is a natural-language location query
  // (for example, "pizza in New York"). It is more reliable than a long
  // comma-separated address-style string for independent venues.
  const googleSearchName = venueNameForGoogleSearch(name);
  const searchQuery = `${googleSearchName} in ${city}`;
  const regionCode = countryCode.length > 0
    ? googleRegionCode(countryCode)
    : undefined;
  const googleSearchStartedAt = Date.now();

  let googleResponse: Response;
  try {
    googleResponse = await fetch(
      "https://places.googleapis.com/v1/places:searchText",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": googlePlacesApiKey,
          "X-Goog-FieldMask":
            "places.id,places.displayName,places.formattedAddress",
        },
        body: JSON.stringify({
          textQuery: searchQuery,
          pageSize: maxResults,
          languageCode: "en",
          ...(regionCode ? { regionCode } : {}),
        }),
        // Give the initial lookup the full user-visible search window. If it
        // does not identify the venue, Autocomplete receives only the time
        // left from this same 60-second window.
        signal: AbortSignal.timeout(maxGoogleSearchDurationMs),
      },
    );
  } catch (error) {
    console.error("Google Places search was unavailable:", error);
    return json({ error: "Google could not search for this place right now." }, 502);
  }

  if (!googleResponse.ok) {
    console.error(
      "Google Places search failed:",
      googleResponse.status,
      await googleResponse.text(),
    );
    return json({ error: "Google could not search for this place right now." }, 502);
  }

  const googlePayload = (await googleResponse.json()) as GoogleTextSearchResponse;
  let results: PlaceSearchResult[] = (googlePayload.places ?? [])
    .map((place) => ({
      placeId: place.id ?? "",
      name: place.displayName?.text?.trim() ?? "",
      address: place.formattedAddress?.trim() ?? "",
    }))
    .filter((place) => place.placeId.length > 0 && place.name.length > 0);
  console.log("Text Search completed", {
    query: searchQuery,
    countryCode,
    candidates: results.length,
  });

  // Text Search is precise, but can return no candidates for a venue that is
  // indexed under a slightly different spelling. Autocomplete is designed for
  // this name-entry step. Search the name and city together and constrain it
  // to the selected country instead of using the Supabase server's IP
  // location.
  // Text Search can return generic nearby businesses without including the
  // exact venue. In that case Autocomplete is still useful even though the
  // first request was not technically empty (for example, The Alfred
  // Tennyson in London).
  if (!hasSimilarGooglePlaceName(results, name)) {
    const remainingGoogleSearchTimeMs = maxGoogleSearchDurationMs -
      (Date.now() - googleSearchStartedAt);
    if (remainingGoogleSearchTimeMs <= 0) {
      console.info("Google search window ended before Autocomplete", {
        query: name,
        city,
        textSearchCandidates: results.length,
      });
      return json({ results });
    }

    let autocompleteResponse: Response;
    try {
      autocompleteResponse = await fetch(
        "https://places.googleapis.com/v1/places:autocomplete",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": googlePlacesApiKey,
            "X-Goog-FieldMask": [
              "suggestions.placePrediction.placeId",
              "suggestions.placePrediction.text.text",
              "suggestions.placePrediction.structuredFormat.mainText.text",
              "suggestions.placePrediction.structuredFormat.secondaryText.text",
            ].join(","),
          },
          body: JSON.stringify({
            input: `${googleSearchName}, ${city}`,
            ...(countryCode.length > 0
              ? { includedRegionCodes: [countryCode] }
              : {}),
            ...(regionCode ? { regionCode } : {}),
            languageCode: "en",
          }),
          signal: AbortSignal.timeout(remainingGoogleSearchTimeMs),
        },
      );
    } catch (error) {
      console.error("Google Places autocomplete was unavailable:", error);
      return json(
        { error: "Google could not search for this place right now." },
        502,
      );
    }

    if (!autocompleteResponse.ok) {
      console.error(
        "Google Places autocomplete failed:",
        autocompleteResponse.status,
        await autocompleteResponse.text(),
      );
      return json(
        { error: "Google could not search for this place right now." },
        502,
      );
    }

    const autocompletePayload =
      (await autocompleteResponse.json()) as GoogleAutocompleteResponse;
    const autocompleteResults = (autocompletePayload.suggestions ?? [])
      .map((suggestion) => {
        const prediction = suggestion.placePrediction;
        return {
          placeId: prediction?.placeId ?? "",
          name:
            prediction?.structuredFormat?.mainText?.text?.trim() ??
            prediction?.text?.text?.trim() ??
            "",
          address:
            prediction?.structuredFormat?.secondaryText?.text?.trim() ?? "",
        };
      })
      .filter((place) => place.placeId.length > 0 && place.name.length > 0);
    // Prefer an address that names the chosen city, but keep the broader
    // country result set if Google formats the address differently.
    const cityNeedle = city.toLocaleLowerCase();
    const cityResults = autocompleteResults.filter((place) =>
      place.address.toLocaleLowerCase().includes(cityNeedle)
    );
    const autocompleteMatches = cityResults.length > 0
      ? cityResults
      : autocompleteResults;
    const mergedByPlaceId = new Map<string, PlaceSearchResult>();
    for (const place of [...autocompleteMatches, ...results]) {
      mergedByPlaceId.set(place.placeId, place);
    }
    results = [...mergedByPlaceId.values()];
    console.log("Autocomplete fallback completed", {
      query: googleSearchName,
      city,
      countryCode,
      candidates: results.length,
    });
  }

  return json({ results });
});
