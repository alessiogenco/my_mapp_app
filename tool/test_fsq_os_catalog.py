"""Checks the Foursquare OS Places catalog without saving the access token.

The PowerShell wrapper supplies FSQ_OS_PLACES_TOKEN only for this process.
This script intentionally reads table metadata only: it does not download or
write any POI records.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path


project_root = Path(__file__).resolve().parents[1]
local_packages = project_root / ".local-tools" / "fsq-os-test"
sys.path.insert(0, str(local_packages))

from pyiceberg.catalog import load_catalog  # noqa: E402


token = os.environ.get("FSQ_OS_PLACES_TOKEN", "").strip()
if not token:
    raise SystemExit("No Foursquare token was supplied.")

catalog = load_catalog(
    "places",
    **{
        "warehouse": "places",
        "uri": "https://catalog.h3-hub.foursquare.com/iceberg",
        "token": token,
        "header.content-type": "application/vnd.api+json",
        "rest-metrics-reporting-enabled": "false",
    },
)

# PyIceberg expects each namespace as a tuple. Passing the string "datasets"
# makes it treat the namespace as individual characters and therefore returns
# an empty list even when the catalog is connected correctly.
try:
    # The REST catalog can disclose namespaces while omitting table listings
    # from the generic metadata endpoint. Loading the two documented tables is
    # the authoritative permission check.
    catalog.load_table("datasets.places_os")
    catalog.load_table("datasets.categories_os")
except Exception as error:
    raise SystemExit(
        "Connected to Foursquare, but OS Places data is not available to this "
        f"token yet: {error}"
    ) from error

print("Foursquare OS Places catalog connected successfully.")
print("Available datasets include: places_os and categories_os.")
