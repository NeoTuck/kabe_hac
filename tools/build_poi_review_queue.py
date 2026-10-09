#!/usr/bin/env python3
"""Prepare source-only OSM place records for human Turkish-name review."""

import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "offline_packages/osm-2026-10-08/travel/content/travel_catalog.v1.json"
OUTPUT = ROOT / "docs/content-review/2026-10-09-kritik-osm-yer-incelemesi.csv"
PRIORITY = {
    "hospital": 1,
    "pharmacy": 1,
    "police": 1,
    "transport": 1,
    "religiousSite": 2,
}


def main() -> None:
    source = json.loads(SOURCE.read_text(encoding="utf-8"))
    rows = [point for point in source["points"] if point["category"] in PRIORITY]
    rows.sort(key=lambda p: (PRIORITY[p["category"]], p["region"], p["category"], p["id"]))
    with OUTPUT.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow([
            "priority", "id", "region", "category", "source_name", "local_name",
            "proposed_turkish_name", "latitude", "longitude", "source_url",
            "source_snapshot_at", "reviewer", "reviewed_at", "review_status",
        ])
        for point in rows:
            writer.writerow([
                PRIORITY[point["category"]], point["id"], point["region"],
                point["category"], point["nameTr"], point.get("localName", ""),
                "", point["latitude"], point["longitude"], point["sourceUrl"],
                point["verifiedAt"], "", "", "needs_human_review",
            ])
    print(f"Prepared {len(rows)} source records for human review: {OUTPUT}")


if __name__ == "__main__":
    main()
