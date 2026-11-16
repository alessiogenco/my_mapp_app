"""My Locals Foursquare OS Places coordinate resolver.

This is intentionally a narrow server-to-server fallback. It never returns a
bulk dataset, never persists Foursquare data, and responds only after the
existing Geoapify lookup has no reliable result.
"""

from __future__ import annotations

import hmac
import os
import re
import threading
import unicodedata
from typing import Any

import duckdb
from flask import Flask, jsonify, request


app = Flask(__name__)

CATALOG_ENDPOINT = "https://catalog.h3-hub.foursquare.com/iceberg"
# A slightly broader candidate set is fetched only inside the already matched
# city and country. Python then accepts a result only when it is unambiguous.
MAX_RESULTS = 12
MAX_NAME_LENGTH = 160
MAX_CITY_LENGTH = 120

_connection: duckdb.DuckDBPyConnection | None = None
_connection_lock = threading.Lock()
_query_lock = threading.Lock()


def _text(value: Any) -> str:
    return value.strip() if isinstance(value, str) else ""


_NAME_STOP_WORDS = {
    "a",
    "an",
    "and",
    "bar",
    "cafe",
    "caffe",
    "coffee",
    "da",
    "de",
    "del",
    "di",
    "e",
    "la",
    "le",
    "pizzeria",
    "pizza",
    "restaurant",
    "the",
}


def _ascii_fold(value: str) -> str:
    """Make accent variants comparable without changing the stored data."""
    decomposed = unicodedata.normalize("NFKD", value)
    return "".join(
        character
        for character in decomposed
        if not unicodedata.combining(character)
    ).lower()


def _normalise_name(value: str) -> str:
    """Compare names independently of accents, spacing and punctuation."""
    # Catalog entries may spell an ampersand out ("Fish and Chips") while
    # Google returns "Fish & Chips". Canonicalise that distinction before
    # removing punctuation.
    canonical = _ascii_fold(value).replace("&", " and ")
    return re.sub(r"[^a-z0-9]+", "", canonical)


def _search_token(value: str) -> str:
    """Choose a meaningful name token for a safely bounded catalog search."""
    tokens = re.findall(r"[a-z0-9]+", _ascii_fold(value))
    for token in tokens:
        # A leading three-letter business token (for example, "Ben's") is
        # often far more distinctive than a later generic word such as
        # "traditional". The exact name scorer below still prevents this
        # broader catalog query from accepting a different venue.
        if len(token) >= 3 and token not in _NAME_STOP_WORDS:
            return token
    return max(tokens, key=len, default="")


def _name_match_score(expected_name: str, candidate_name: str) -> int:
    """Score only exact or clearly contained canonical-name variants."""
    expected = _normalise_name(expected_name)
    candidate = _normalise_name(candidate_name)
    if not expected or not candidate:
        return 0
    if expected == candidate:
        return 100
    if len(expected) >= 5 and expected in candidate:
        return 90
    if len(candidate) >= 5 and candidate in expected:
        return 80
    return 0


def _is_authorised() -> bool:
    expected = os.environ.get("RESOLVER_SHARED_SECRET", "")
    provided = request.headers.get("X-My-Locals-Resolver-Key", "")
    return bool(expected) and bool(provided) and hmac.compare_digest(
        expected,
        provided,
    )


def _catalog_connection() -> duckdb.DuckDBPyConnection:
    """Create one in-memory, read-only connection to the FSQ Iceberg catalog."""
    global _connection

    with _connection_lock:
        if _connection is not None:
            return _connection

        token = os.environ.get("FSQ_OS_PLACES_TOKEN", "").strip()
        if not token:
            raise RuntimeError("FSQ_OS_PLACES_TOKEN is not configured.")

        connection = duckdb.connect(":memory:")
        try:
            connection.execute("LOAD httpfs")
            connection.execute("LOAD iceberg")

            # The token comes from Secret Manager. Escaping protects the SQL
            # statement without writing the token to logs or to disk.
            escaped_token = token.replace("'", "''")
            connection.execute(
                "CREATE SECRET fsq_os_portal "
                f"(TYPE iceberg, TOKEN '{escaped_token}')"
            )
            connection.execute(
                "ATTACH 'places' AS places "
                "(TYPE iceberg, SECRET fsq_os_portal, "
                f"ENDPOINT '{CATALOG_ENDPOINT}')"
            )
        except Exception:
            connection.close()
            raise

        _connection = connection
        return connection


def _unique_best_row(
    rows: list[dict[str, Any]],
    name: str,
    *,
    minimum_score: int,
) -> dict[str, Any] | None:
    """Return one uniquely strongest candidate, otherwise no candidate."""
    scored_rows = [
        (row, _name_match_score(name, _text(row.get("name"))))
        for row in rows
    ]
    accepted_rows = [
        item for item in scored_rows if item[1] >= minimum_score
    ]
    if not accepted_rows:
        return None

    best_score = max(score for _, score in accepted_rows)
    best_rows = [row for row, score in accepted_rows if score == best_score]
    return best_rows[0] if len(best_rows) == 1 else None


def _query_places(name: str, city: str, country_code: str) -> list[dict[str, Any]]:
    """Return one safe name-and-city match from the open FSQ dataset."""
    connection = _catalog_connection()
    search_token = _search_token(name)
    if not search_token:
        return []

    # Keep this query bounded to the requested city. A country-wide Iceberg
    # scan can exceed the function deadline for a venue that simply is not in
    # the open catalog, creating a long wait without a useful result.
    select_sql = """
        SELECT
          fsq_place_id,
          name,
          latitude,
          longitude,
          address,
          locality,
          post_town,
          postcode,
          country,
          date_refreshed
        FROM places.datasets.places_os
        WHERE country = ?
          AND date_closed IS NULL
          AND latitude IS NOT NULL
          AND longitude IS NOT NULL
          AND lower(name) LIKE ?
    """
    city_sql = select_sql + """
          AND (
            lower(coalesce(locality, '')) = lower(?)
            OR lower(coalesce(post_town, '')) = lower(?)
          )
        LIMIT ?
    """

    with _query_lock:
        cursor = connection.execute(
            city_sql,
            [country_code, f"%{search_token}%", city, city, MAX_RESULTS],
        )
        columns = [column[0] for column in cursor.description]
        city_rows = [dict(zip(columns, row)) for row in cursor.fetchall()]

    city_scores = [
        _name_match_score(name, _text(row.get("name")))
        for row in city_rows
    ]
    print(
        "Foursquare coordinate diagnostic: "
        f"city_candidates={len(city_rows)} "
        f"names={[_text(row.get('name')) for row in city_rows[:5]]} "
        f"scores={city_scores[:5]}",
        flush=True,
    )
    row = _unique_best_row(city_rows, name, minimum_score=1)

    if row is None:
        return []

    return [
        {
            "id": _text(row.get("fsq_place_id")),
            "name": _text(row.get("name")),
            "latitude": row.get("latitude"),
            "longitude": row.get("longitude"),
            "address": _text(row.get("address")),
            "city": _text(row.get("locality")) or _text(row.get("post_town")),
            "postcode": _text(row.get("postcode")),
            "countryCode": _text(row.get("country")),
            "refreshedAt": str(row.get("date_refreshed") or ""),
        }
    ]


@app.get("/health")
def health() -> tuple[Any, int]:
    """A non-sensitive Cloud Run health endpoint."""
    configured = bool(
        os.environ.get("FSQ_OS_PLACES_TOKEN")
        and os.environ.get("RESOLVER_SHARED_SECRET")
    )
    return jsonify({"status": "ok", "configured": configured}), 200


@app.post("/resolve")
def resolve() -> tuple[Any, int]:
    if not _is_authorised():
        return jsonify({"error": "Unauthorised resolver request."}), 401

    payload = request.get_json(silent=True) or {}
    name = _text(payload.get("name"))
    city = _text(payload.get("city"))
    country_code = _text(payload.get("countryCode")).upper()

    if not (2 <= len(name) <= MAX_NAME_LENGTH and 2 <= len(city) <= MAX_CITY_LENGTH):
        return jsonify({"error": "A place name and city are required."}), 400
    if not re.fullmatch(r"[A-Z]{2}", country_code):
        return jsonify({"error": "Use a two-letter country code."}), 400

    try:
        results = _query_places(name, city, country_code)
    except Exception as error:
        # Keep implementation details and credentials out of the response; the
        # full exception remains available only in Cloud Run's protected logs.
        app.logger.exception("Foursquare OS Places lookup failed: %s", error)
        return jsonify({"error": "The Foursquare lookup is temporarily unavailable."}), 502

    return jsonify({"source": "foursquare_os_places", "results": results}), 200
