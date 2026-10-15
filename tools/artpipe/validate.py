"""Stage: validate — JSON Schema + the Part E9 checklist. Errors fail the build; warnings don't."""
from __future__ import annotations

import json
import math
from collections import Counter
from pathlib import Path

import jsonschema

from . import derive, onboarding, taxonomy

ROOT = Path(__file__).resolve().parent.parent.parent
SCHEMA = ROOT / "spec" / "dataset.schema.json"
SIGNOFF = ROOT / "tools" / "curation" / "signoff.json"
ONBOARDING_SCHEMA = ROOT / "spec" / "onboarding.schema.json"
ARTWORKS_DIR = ROOT / "Resources" / "Artworks"
LIMITS = {"full": 450_000, "card": 250_000, "thumb": 80_000}   # bytes per HEIC file (warn above)
BUNDLE_LIMIT = 100_000_000
MEDIUM_CATS = {"ukiyo_e": {"print"}, "print": {"print"}, "modern_print": {"print"}, "poster": {"print"},
               "early_photography": {"photograph"}, "watercolour_drawing": {"drawing", "works_on_paper"},
               "chinese_ink": {"ink_painting"}, "old_master_drawing": {"drawing", "works_on_paper"}}


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def err(self, m: str) -> None:
        self.errors.append(m)

    def warn(self, m: str) -> None:
        self.warnings.append(m)


def schema_errors(doc: dict) -> list[str]:
    v = jsonschema.Draft202012Validator(json.loads(SCHEMA.read_text()))
    return [f"schema {e.json_path}: {e.message[:200]}" for e in v.iter_errors(doc)]


def taxonomy_errors(tax: dict) -> list[str]:
    """Validate a taxonomy.json document against #/$defs/taxonomy_file of the dataset schema."""
    full = json.loads(SCHEMA.read_text())
    sub = {"$schema": full["$schema"], "$defs": full["$defs"], "$ref": "#/$defs/taxonomy_file"}
    v = jsonschema.Draft202012Validator(sub)
    return [f"taxonomy schema {e.json_path}: {e.message[:200]}" for e in v.iter_errors(tax)]


def onboarding_schema_errors(ob: dict) -> list[str]:
    v = jsonschema.Draft202012Validator(json.loads(ONBOARDING_SCHEMA.read_text()))
    return [f"onboarding schema {e.json_path}: {e.message[:200]}" for e in v.iter_errors(ob)]


def game_price(a: dict) -> dict | None:
    """Spec §8.2 game price rule."""
    gid = a.get("game_price_id")
    for p in a.get("prices", []):
        if p["id"] == gid and p["game_eligible"] and not p["type"].startswith("estimate") \
                and p["price_scope"] != "other_version" and p["confidence"] != "low":
            return p
    return None


def run(doc: dict, credits: dict | None, strict: bool = False, check_bytes: bool = False,
        onboarding_doc: dict | None = None) -> Report:
    r = Report()
    for e in schema_errors(doc):
        r.err(e)
    cats = {c["id"]: c for c in taxonomy.categories()}
    for e in taxonomy.check():
        r.err("taxonomy: " + e)
    for e in taxonomy_errors({"schema_version": 1, "departments": taxonomy.departments(),
                              "categories": taxonomy.categories()}):
        r.err(e)
    if onboarding_doc is not None:
        for e in onboarding_schema_errors(onboarding_doc) + onboarding.check(doc, onboarding_doc, ARTWORKS_DIR):
            r.err(e)
    ids = Counter(a["id"] for a in doc["artworks"])
    for k, n in ids.items():
        if n > 1:
            r.err(f"duplicate artwork id {k}")
    qids = Counter(a.get("external_ids", {}).get("wikidata") for a in doc["artworks"])
    for k, n in qids.items():
        if k and n > 1:
            r.err(f"duplicate wikidata QID {k}")
    shas = Counter(a["images"]["primary"].get("sha256") for a in doc["artworks"])
    for k, n in shas.items():
        if k and n > 1:
            r.err(f"duplicate image sha256 {k[:12]}")
    signoff = json.loads(SIGNOFF.read_text()) if SIGNOFF.exists() else {}
    per_cat = Counter()
    decade = Counter()
    total_bytes = 0
    credit_ids = {c["artwork_id"] for c in (credits or {}).get("images", [])}
    for a in doc["artworks"]:
        aid = a["id"]
        im = a["images"]["primary"]
        # PD basis
        rt = a.get("rights", {})
        if not rt.get("work_pd"):
            r.err(f"{aid}: work not public domain ({rt.get('pd_basis')})")
        # image licence / attribution / landing
        if im.get("licence") not in ("CC0", "PD", "PD-Art"):
            r.err(f"{aid}: image licence {im.get('licence')}")
        if not im.get("attribution") or not im.get("landing_url"):
            r.err(f"{aid}: image attribution/landing_url missing")
        if not im.get("sha256"):
            r.err(f"{aid}: image sha256 missing")
        if im.get("lg_missing"):
            r.warn(f"{aid}: source image smaller than 1600 px (lg_missing)")
        for tag in ("lg", "sm"):
            rend = im[tag]
            kind = "thumb" if tag == "sm" else ("full" if rend["file"].endswith("_full.heic") else "card")
            b = rend.get("bytes", 0)
            total_bytes += b
            if check_bytes and not b:
                r.err(f"{aid}: {rend['file']} missing (run make assets)")
            elif not b:
                r.warn(f"{aid}: {rend['file']} bytes unknown (run make assets)")
            elif b > LIMITS[kind]:
                (r.err if b > 2 * LIMITS[kind] else r.warn)(f"{aid}: {rend['file']} {b} bytes > {LIMITS[kind]}")
        if aid not in credit_ids and credits is not None:
            r.err(f"{aid}: missing from credits")
        if signoff.get(aid) != im.get("sha256"):
            r.warn(f"{aid}: contact sheet not signed off for this image")
        # categories
        if a["category_id"] not in cats:
            r.err(f"{aid}: unknown category {a['category_id']}")
        elif not cats[a["category_id"]]["active"]:
            r.err(f"{aid}: category {a['category_id']} inactive")
        for s in a.get("secondary_category_ids", []):
            if s not in cats or s == a["category_id"]:
                r.err(f"{aid}: bad secondary category {s}")
        if a.get("department_id") != taxonomy.DEPT_OF.get(a["category_id"]):
            r.err(f"{aid}: department_id {a.get('department_id')} != department of {a['category_id']}")
        mc = a["medium"]["medium_class"]
        for c in [a["category_id"]] + a.get("secondary_category_ids", []):
            if c in MEDIUM_CATS and mc not in MEDIUM_CATS[c]:
                r.err(f"{aid}: medium_class {mc} incompatible with category {c}")
        if a["category_id"] in MEDIUM_CATS or True:
            per_cat[a["category_id"]] += 1
        # taste
        t = a["taste"]
        for f in ("abstraction", "warmth", "saturation", "brightness", "complexity", "subject", "mood", "era_bucket"):
            if t.get(f) in (None, ""):
                r.err(f"{aid}: taste.{f} missing")
        year = a["date"].get("start", a["date"].get("end"))
        if t.get("era_bucket") != derive.era_bucket(year):
            r.err(f"{aid}: era_bucket {t.get('era_bucket')} != {derive.era_bucket(year)}")
        # prices
        pids = [p["id"] for p in a["prices"]]
        if len(set(pids)) != len(pids):
            r.err(f"{aid}: duplicate price ids")
        if a["game_price_id"] is not None and a["game_price_id"] not in pids:
            r.err(f"{aid}: game_price_id not among prices")
        for p in a["prices"]:
            for f in ("nominal", "adjusted"):
                if p[f"log10_usd_{f}_milli"] != derive.milli(p[f"usd_{f}"]):
                    r.err(f"{aid}/{p['id']}: log10_usd_{f}_milli inconsistent")
            if p["currency"] != "USD" and not p.get("fx_source"):
                r.err(f"{aid}/{p['id']}: FX source missing")
            if not p.get("cpi_source"):
                r.err(f"{aid}/{p['id']}: CPI source missing")
            if p["game_eligible"]:
                if not p["source_urls"]:
                    r.err(f"{aid}/{p['id']}: game-eligible price without source")
                if not p.get("verified_by"):
                    r.err(f"{aid}/{p['id']}: game-eligible price not verified against a fetched source")
                if p["confidence"] == "low":
                    r.err(f"{aid}/{p['id']}: game-eligible price with low confidence")
                if p["type"].startswith("estimate"):
                    r.err(f"{aid}/{p['id']}: estimate marked game-eligible")
                if p["price_scope"] == "other_version":
                    r.err(f"{aid}/{p['id']}: other_version marked game-eligible")
                if p["type"].startswith("auction") and "premium_included" not in p:
                    r.err(f"{aid}/{p['id']}: premium flag missing")
                if im["depicts_scope"] != p["price_scope"]:
                    r.err(f"{aid}: image depicts_scope {im['depicts_scope']} != price_scope {p['price_scope']}")
        gp = game_price(a)
        if a["game_price_id"] is not None and gp is None:
            r.err(f"{aid}: game_price_id points at a non-game price")
        if gp:
            d = int(math.floor(math.log10(gp["usd_nominal"])))
            decade[d] += 1
    for cid, c in cats.items():
        if c["active"] and per_cat[cid] < c["min_quiz_items"]:
            (r.err if strict else r.warn)(f"category {cid}: {per_cat[cid]} works < {c['min_quiz_items']}")
    for d in range(4, 8):  # $10K-$100M: log-decades 10^4..10^7
        if decade[d] < 10:
            (r.err if strict else r.warn)(f"price decade 1e{d}-1e{d+1}: {decade[d]} works < 10")
    if total_bytes > BUNDLE_LIMIT:
        r.err(f"bundle {total_bytes} bytes > {BUNDLE_LIMIT}")
    r.stats = {"per_category": dict(per_cat), "per_decade": {f"1e{k}": v for k, v in sorted(decade.items())},
               "bundle_bytes": total_bytes}
    return r
