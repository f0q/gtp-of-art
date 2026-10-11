"""Stage 1: load_csv — read tools/curation/works.csv (lines starting with '#' are comments)."""
from __future__ import annotations

import csv
from pathlib import Path

REQUIRED = ["work_key", "kind", "title", "artist", "date_display", "category_id", "medium",
            "medium_class", "image_pref", "subject", "abstraction", "mood", "alt_text", "teaser"]


def load(path: str | Path) -> list[dict]:
    with open(path, newline="", encoding="utf-8") as f:
        lines = [ln for ln in f if not ln.startswith("#")]
    rows = list(csv.DictReader(lines))
    for i, r in enumerate(rows):
        for k, v in list(r.items()):
            r[k] = (v or "").strip()
        r["_line"] = i + 3
    return rows
