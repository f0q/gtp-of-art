#!/usr/bin/env python3
"""Fetch every price source in works.csv (cached) and record whether the amount appears.

Writes tools/curation/price_checks.json; build_dataset.py reads it (and recomputes it when
missing). A price is 'verified' when a cited page contains the amount, or when a matching
Wikidata price statement carries a reference.

Usage: tools/.venv/bin/python tools/verify_prices.py [--only KEY] [--offline]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from artpipe import csvload, http, verify  # noqa: E402

OUT = Path(__file__).resolve().parent / "curation" / "price_checks.json"


def run(rows, only=None, log=print) -> dict:
    res = json.loads(OUT.read_text()) if OUT.exists() else {}
    for r in rows:
        if not r.get("price_amount") or (only and r["work_key"] != only):
            continue
        v = verify.verify_row(r)
        res[r["work_key"]] = v
        log(f"  {'OK ' if v['verified'] else 'NO '} {r['work_key']:<40} {v['verified_by'] or ''}")
    OUT.write_text(json.dumps(res, indent=1, ensure_ascii=False, sort_keys=True))
    return res


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=str(Path(__file__).resolve().parent / "curation" / "works.csv"))
    ap.add_argument("--only")
    ap.add_argument("--offline", action="store_true")
    a = ap.parse_args()
    http.OFFLINE = a.offline
    run(csvload.load(a.csv), a.only)
