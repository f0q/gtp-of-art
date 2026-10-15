#!/usr/bin/env python3
"""Build Resources/dataset.json (+ taxonomy, credits, contact sheet) from tools/curation/works.csv.

Stages (Part E9): load_csv -> resolve_metadata -> download -> process_images -> palette_features
-> derive -> validate -> emit. Every HTTP response is cached under tools/cache/, per-image work is
cached under tools/out/work_cache/, so a fully cached rerun takes seconds.

Usage:
  tools/.venv/bin/python tools/build_dataset.py [--csv PATH] [--out Resources] [--limit N]
         [--only WORK_KEY] [--offline] [--strict] [--reverify]
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
import time
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
from artpipe import csvload, derive, emit, http, images, onboarding, sources, taxonomy, validate, verify, wikidata  # noqa: E402

PIPELINE_VERSION = 3
WORK_CACHE = TOOLS / "out" / "work_cache"
CHECKS = TOOLS / "curation" / "price_checks.json"
DATASET_ID_PREFIX = "artprice-v1"
T0 = time.monotonic()


def log(msg: str) -> None:
    print(f"[{time.monotonic() - T0:6.1f}s] {msg}", flush=True)


def yesno(v: str) -> bool:
    return v.strip().lower() in ("y", "yes", "true", "1")


def parse_dims(s: str | None) -> dict | None:
    if not s:
        return None
    m = re.search(r"\(([\d.]+)\s*[×x]\s*([\d.]+)(?:\s*[×x]\s*([\d.]+))?\s*cm\)", s)
    if not m:
        return None
    d = {"h": float(m.group(1)), "w": float(m.group(2))}
    if m.group(3):
        d["d"] = float(m.group(3))
    return d


# ---------------------------------------------------------------- resolve_metadata
def resolve_image(row: dict) -> dict:
    pref = row["image_pref"]
    ident = row[{"met": "met_id", "aic": "aic_id", "cma": "cma_id", "rijks": "rijks_id",
                 "commons": "commons_file"}[pref]]
    try:
        return sources.RESOLVERS[pref](ident)
    except Exception as e:
        if pref == "commons" and row.get("wikidata_qid"):
            p18 = wikidata.claim_values(wikidata.entity(row["wikidata_qid"]), "P18")
            if p18:
                log(f"   {row['work_key']}: commons '{ident[:50]}' failed ({e}); using Wikidata P18 '{p18[0][:50]}'")
                return sources.commons(p18[0])
        raise


def resolve_people(row: dict, img: dict) -> dict:
    """Artist facts: Wikidata (work P170 -> creator) with Met fallback."""
    out = {"provenance": {}}
    qid = row.get("wikidata_qid")
    raw = img.get("raw") or {}
    if not qid and img["source"] == "met" and raw.get("objectWikidata_URL"):
        qid = raw["objectWikidata_URL"].rsplit("/", 1)[-1]
    out["work_qid"] = qid or None
    work = wikidata.entity(qid) if qid else None
    a_qid = row.get("artist_wikidata") or (wikidata.first_qid(work, "P170") if work else None)
    if not a_qid and img["source"] == "met" and raw.get("artistWikidata_URL"):
        a_qid = raw["artistWikidata_URL"].rsplit("/", 1)[-1]
    if not a_qid:
        a_qid = search_artist(row["artist"])
        if a_qid:
            out["provenance"]["artist.wikidata"] = "wikidata search (name match)"
    if a_qid and a_qid.startswith("Q"):
        ae = wikidata.entity(a_qid)
        out["artist_qid"] = a_qid
        out["birth"] = wikidata.first_year(ae, "P569")
        out["death"] = wikidata.first_year(ae, "P570")
        out["provenance"]["artist.death_year"] = f"wikidata:{a_qid}"
    if out.get("death") is None and img["source"] == "met" and str(raw.get("artistEndDate", "")).isdigit():
        out["death"] = int(raw["artistEndDate"])
        out["provenance"]["artist.death_year"] = f"met:{raw['objectID']}"
    if out.get("birth") is None and img["source"] == "met" and str(raw.get("artistBeginDate", "")).isdigit():
        out["birth"] = int(raw["artistBeginDate"])
    out["inception"] = wikidata.first_year(work, "P571") if work else None
    return out


def search_artist(name: str) -> str | None:
    """Find a creator QID by name: first human hit whose description mentions an art profession."""
    name = re.sub(r"\s*\(attributed\)", "", name).split(" and ")[0]
    d = http.get_json("https://www.wikidata.org/w/api.php", {"action": "wbsearchentities", "search": name,
                      "language": "en", "type": "item", "limit": "7", "format": "json"})
    for hit in d.get("search", []):
        desc = (hit.get("description") or "").lower()
        if any(w in desc for w in ("painter", "artist", "photographer", "printmaker", "engraver", "draughtsman")):
            return hit["id"]
    return None


# ---------------------------------------------------------------- per-work image work (cached)
def image_stage(work_id: str, img: dict, offline: bool) -> dict:
    """download -> process_images -> palette_features, cached by source URL + pipeline version."""
    WORK_CACHE.mkdir(parents=True, exist_ok=True)
    cp = WORK_CACHE / f"{work_id}.json"
    if cp.exists():
        c = json.loads(cp.read_text())
        if c.get("source_url") == img["source_url"] and c.get("v") == PIPELINE_VERSION and \
                all(Path(c[t]["path"]).exists() for t in ("lg", "sm")):
            return c
    data, sha = images.download(img["source_url"])
    proc = images.process(work_id, data)
    feats = images.features(proc.pop("image"))
    c = {"v": PIPELINE_VERSION, "source_url": img["source_url"], "sha256": sha, **proc, **feats}
    cp.write_text(json.dumps(c, indent=1))
    return c


# ---------------------------------------------------------------- derive
def build_price(row: dict, work_id: str, money: derive.Money, checks: dict, warns: list) -> dict | None:
    if not row.get("price_amount"):
        return None
    amount = float(row["price_amount"])
    cur = row["price_currency"]
    year = int(row["price_date"][:4])
    m = money.price(amount, cur, year)
    for w in m.pop("_warn"):
        warns.append(f"{work_id}: {w} ({year})")
    chk = checks.get(row["work_key"]) or {}
    same = chk.get("amount") == amount and chk.get("currency") == cur
    verified_by = chk.get("verified_by") if same else None
    conf = row["confidence"] or "low"
    elig = yesno(row["game_eligible"])
    if elig and not verified_by:
        warns.append(f"{work_id}: price not verified against any fetched source -> confidence low, not game-eligible")
        conf, elig = "low", False
    if conf == "low":
        elig = False
    if row["price_type"].startswith("estimate") or row["price_scope"] == "other_version":
        elig = False
    urls = [row[k] for k in ("source_url_1", "source_url_2", "source_url_3") if row.get(k)]
    if row.get("wikidata_price"):
        wd = (chk.get("wikidata") or {}) if same else {}
        urls.append(f"https://www.wikidata.org/wiki/{row['wikidata_price']}#P2284"
                    if not wd.get("statement_id") else
                    f"https://www.wikidata.org/wiki/{row['wikidata_price']}#{wd['statement_id'].replace('$', '-')}")
    p = {"id": f"{work_id}-p1", "type": row["price_type"], "amount_minor": m["amount_minor"], "currency": cur,
         "premium_included": yesno(row["premium_included"]), "approximate": yesno(row["approximate"]),
         "lower_bound": yesno(row["lower_bound"]), "date": row["price_date"]}
    if row.get("price_venue"):
        p["venue"] = row["price_venue"]
    if row.get("price_lot"):
        p["lot"] = row["price_lot"]
    p.update({k: m[k] for k in ("usd_nominal", "usd_adjusted", "adjust_ref_year", "fx_rate_to_usd",
                                "fx_source", "cpi_source", "log10_usd_nominal_milli", "log10_usd_adjusted_milli")})
    p["source_urls"] = urls
    if urls:
        p["primary_citation"] = urls[0]
    if verified_by:
        p["verified_by"] = verified_by
    p.update({"confidence": conf, "game_eligible": elig, "price_scope": row["price_scope"] or "this_object"})
    return p


_MANIFEST: dict | None = None


def heic_manifest() -> dict:
    """{file: {w, h, bytes}} written by make_assets.py, so rebuilds keep the real HEIC sizes."""
    global _MANIFEST
    if _MANIFEST is None:
        p = TOOLS / "out" / "heic_manifest.json"
        _MANIFEST = json.loads(p.read_text()) if p.exists() else {}
    return _MANIFEST


def attribution(img: dict) -> str:
    if img["source"] == "commons":
        credit = img["credit"] or "Wikimedia Commons"
        credit = re.sub(r"\s+", " ", credit)[:160]
        if img["licence"] == "CC0":
            return f"Photo via Wikimedia Commons (CC0); source: {credit}"
        return f"Photo via Wikimedia Commons ({img['licence']}); source: {credit}"
    return img["credit"] + ("" if "CC0" in img["credit"] or "public domain" in img["credit"] else " (CC0)")


def build_work(row: dict, money, checks, warns, offline) -> tuple[dict, str]:
    wid = row["work_key"]
    img = resolve_image(row)
    ppl = resolve_people(row, img)
    ic = image_stage(wid, img, offline)
    ds = int(row["date_start"]) if row.get("date_start") else None
    de = int(row["date_end"]) if row.get("date_end") else ds
    ds = ds if ds is not None else de
    if ppl.get("inception") and ds and abs(ppl["inception"] - ds) > 10:
        warns.append(f"{wid}: CSV date {ds} vs Wikidata inception {ppl['inception']}")
    death = ppl.get("death")
    work_pd, basis = derive.pd_check(row["artist"], death, de, row.get("pd_override", ""))
    price = build_price(row, wid, money, checks, warns)
    priced = bool(price and price["game_eligible"])
    if price and not work_pd:
        price["game_eligible"] = False
        priced = False
    taste = {"era_bucket": derive.era_bucket(ds if ds is not None else de), "subject": row["subject"],
             "mood": row["mood"], "abstraction": int(row["abstraction"])}
    # scalar image features are filled after the whole set is known (complexity is a percentile)
    big = "full" if priced else "card"
    lg_edge = 1440 if priced else 1080
    def fit(w, h, edge):
        s = min(1.0, edge / max(w, h))
        return max(1, round(w * s)), max(1, round(h * s))
    lw, lh = fit(ic["lg"]["w"], ic["lg"]["h"], lg_edge)
    sw, sh = fit(ic["sm"]["w"], ic["sm"]["h"], 480)
    res = TOOLS.parent / "Resources" / "Artworks"
    manifest = heic_manifest()
    def rend(fname, w, h):
        f = res / fname
        m = manifest.get(fname)
        if f.exists() and m and m["bytes"] == f.stat().st_size:
            return {"file": fname, "w": m["w"], "h": m["h"], "bytes": m["bytes"]}
        return {"file": fname, "w": w, "h": h, "bytes": f.stat().st_size if f.exists() else 0}
    image = {
        "sm": rend(f"{wid}_thumb.heic", sw, sh), "lg": rend(f"{wid}_{big}.heic", lw, lh),
        "source_url": img["source_url"], "landing_url": img["landing_url"], "licence": img["licence"],
        "attribution": attribution(img),
        "depicts_scope": price["price_scope"] if price else "this_object",
        "alt_text": row["alt_text"], "sha256": ic["sha256"],
        "focus": {"x": int(row.get("focus_x") or 500), "y": int(row.get("focus_y") or 450)},
        "dominant_hex": ic["dominant_hex"], "palette": ic["palette"],
    }
    if ic["lg_missing"]:
        image["lg_missing"] = True
    artist = {"id": derive.slug(row["artist"]), "display_name": row["artist"]}
    if ppl.get("birth") is not None:
        artist["birth_year"] = ppl["birth"]
    if death is not None:
        artist["death_year"] = death
    if row.get("nationality"):
        artist["nationality"] = row["nationality"]
    if ppl.get("artist_qid"):
        artist["wikidata"] = ppl["artist_qid"]
    date = {"display": row["date_display"]}
    if ds is not None:
        date["start"] = ds
    if de is not None:
        date["end"] = de
    date["circa"] = yesno(row["circa"])
    ext = {}
    for k, t in (("met_id", "met"), ("aic_id", "aic"), ("cma_id", "cma")):
        if row.get(k):
            ext[t] = int(row[k])
    if row.get("rijks_id"):
        ext["rijks"] = row["rijks_id"]
    if ppl.get("work_qid"):
        ext["wikidata"] = ppl["work_qid"]
    if img["source"] == "commons":
        ext["commons_file"] = img["raw"]["title"]
    a = {"id": wid, "kind": row["kind"] or "pd_masterpiece", "status": "active", "title": row["title"]}
    if row.get("title_alt"):
        a["title_alt"] = row["title_alt"]
    a.update({"artist": artist, "date": date, "category_id": row["category_id"],
              "department_id": taxonomy.DEPT_OF.get(row["category_id"]),
              "secondary_category_ids": [s for s in row["secondary_categories"].split(";") if s],
              "medium": {"display": row["medium"], "medium_class": row["medium_class"]}})
    dims = parse_dims(img.get("dimensions"))
    if dims:
        a["dimensions_cm"] = dims
    holder = row.get("holder") or img.get("holder")
    if holder:
        a["holder"] = holder
    a["external_ids"] = ext
    a["images"] = {"primary": image}
    a["prices"] = [price] if price else []
    a["game_price_id"] = price["id"] if priced else None
    a["taste"] = taste
    a["copy"] = {"teaser": row["teaser"], "copy_licence": "original (ArtPrice project)"}
    prov = {"image": f"{img['source']}:{img['landing_url']}", "taste.subject": "curated (works.csv)",
            "taste.mood": "curated (works.csv)", "taste.abstraction": "curated (works.csv)",
            "taste.warmth": "image analysis", "taste.saturation": "image analysis",
            "taste.brightness": "image analysis", "taste.complexity": "image analysis (dataset percentile)",
            "category_id": "curated (works.csv)", "date": "curated (works.csv)"}
    prov.update(ppl["provenance"])
    if price:
        prov["price"] = price.get("verified_by") or "works.csv (unverified)"
    a["provenance"] = prov
    a["rights"] = {"work_pd": work_pd, "pd_basis": basis, "image_licence_verified": True}
    return a, ic


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--csv", default=str(TOOLS / "curation" / "works.csv"))
    ap.add_argument("--out", default=str(TOOLS.parent / "Resources"))
    ap.add_argument("--limit", type=int)
    ap.add_argument("--only")
    ap.add_argument("--offline", action="store_true", help="fail on any cache miss instead of fetching")
    ap.add_argument("--strict", action="store_true", help="treat v1 coverage targets as errors")
    ap.add_argument("--reverify", action="store_true", help="re-run price verification for all rows")
    ap.add_argument("--skip-failed", action="store_true",
                    help="drop a row whose metadata/image cannot be fetched (listed at the end) instead of aborting")
    a = ap.parse_args()
    http.OFFLINE = a.offline
    out = Path(a.out)

    log("load_csv")
    rows = csvload.load(a.csv)
    bad = [f"line {r['_line']}: missing {k}" for r in rows for k in csvload.REQUIRED if not r.get(k)]
    if bad:
        print("\n".join(bad)); return 2
    if a.only:
        rows = [r for r in rows if r["work_key"] == a.only]
    if a.limit:
        rows = rows[: a.limit]
    log(f"  {len(rows)} rows")

    log("verify price sources")
    checks = json.loads(CHECKS.read_text()) if CHECKS.exists() else {}
    need = [r for r in rows if r.get("price_amount") and (a.reverify or r["work_key"] not in checks or
            checks[r["work_key"]].get("amount") != float(r["price_amount"]) or
            [c["url"] for c in checks[r["work_key"]].get("urls", [])] !=
            [r[k] for k in ("source_url_1", "source_url_2", "source_url_3") if r.get(k)])]
    if need:
        import verify_prices
        checks = verify_prices.run(need, log=log)

    money = derive.Money()
    warns: list[str] = []
    works, cache = [], {}
    dropped: list[tuple[str, str]] = []
    log("resolve_metadata / download / process_images / palette_features / derive")
    for i, r in enumerate(rows, 1):
        try:
            w, ic = build_work(r, money, checks, warns, a.offline)
        except http.OfflineMiss as e:
            print(f"OFFLINE cache miss for {r['work_key']}: {e}"); return 3
        except Exception as e:
            if a.skip_failed:
                dropped.append((r["work_key"], str(e)[:200]))
                log(f"  DROPPED {r['work_key']}: {str(e)[:200]}")
                continue
            print(f"ERROR {r['work_key']}: {e}"); return 4
        works.append(w); cache[w["id"]] = ic
        log(f"  [{i}/{len(rows)}] {w['id']}: {w['images']['primary']['licence']} "
            f"{ic['lg']['w']}x{ic['lg']['h']} {'priced' if w['game_price_id'] else 'unpriced'}")

    # complexity = dataset percentile of edge density; other scalars from fixed maps
    eds = sorted(c["edge_density"] for c in cache.values())
    for w in works:
        c = cache[w["id"]]
        rank = sum(1 for e in eds if e < c["edge_density"]) + 0.5 * (sum(1 for e in eds if e == c["edge_density"]) - 1)
        pct = 100 * rank / max(1, len(eds) - 1)
        w["taste"].update(images.scale_scalars(c, pct))
        t = w["taste"]
        w["taste"] = {k: t[k] for k in ("era_bucket", "subject", "mood", "abstraction", "warmth",
                                        "saturation", "brightness", "complexity")}
    works.sort(key=lambda w: w["id"])

    now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    doc = {"schema_version": 1, "dataset_id": f"{DATASET_ID_PREFIX}-{dt.date.today():%Y%m%d}",
           "generated_at": now, "ref_year": derive.REF_YEAR, "disclaimer": emit.DISCLAIMER, "artworks": works}
    cred = emit.credits(works, now)

    ob = onboarding.build(doc["dataset_id"])
    log("validate")
    rep = validate.run(doc, cred, strict=a.strict, onboarding_doc=None if (a.only or a.limit) else ob)
    for w in warns:
        rep.warn(w)
    priced = [w for w in works if w["game_price_id"]]
    per_dept = {d["id"]: {"priced": sum(1 for w in priced if w["department_id"] == d["id"]),
                          "unpriced": sum(1 for w in works if w["department_id"] == d["id"] and not w["game_price_id"])}
                for d in taxonomy.departments()}
    stats = {**rep.stats, "per_department": per_dept, "works": len(works), "priced": len(priced), "unpriced": len(works) - len(priced),
             "image_sources": dict(sorted({s: sum(1 for w in works if w['provenance']['image'].startswith(s + ':'))
                                           for s in ("met", "aic", "cma", "rijks", "commons")}.items())),
             "licences": {l: sum(1 for w in works if w['images']['primary']['licence'] == l) for l in ("CC0", "PD", "PD-Art")},
             "http_cache": dict(http.stats)}
    for w in rep.warnings:
        log("  WARN " + w)
    for e in rep.errors:
        log("  ERROR " + e)

    log("emit")
    if a.only or a.limit:
        log("  partial run (--only/--limit): not writing Resources/")
    else:
        # keep generated_at stable when nothing else changed (idempotent output)
        old = out / "dataset.json"
        if old.exists():
            prev = json.loads(old.read_text())
            if prev.get("dataset_id", "").startswith(DATASET_ID_PREFIX + "-") and \
                    {**prev, "generated_at": "", "dataset_id": ""} == {**doc, "generated_at": "", "dataset_id": ""}:
                doc["generated_at"], doc["dataset_id"] = prev["generated_at"], prev["dataset_id"]
                cred["generated_at"] = prev["generated_at"]
        emit.write_json(out / "dataset.json", doc)
        emit.write_json(out / "taxonomy.json", {"schema_version": 1, "departments": taxonomy.departments(),
                                                "categories": taxonomy.categories()})
        ob["dataset_id"] = doc["dataset_id"]
        emit.write_json(out / "onboarding.json", ob)
        emit.write_json(out / "credits.json", cred)
        md = emit.credits_md(cred)
        if not (out / "CREDITS.md").exists() or (out / "CREDITS.md").read_text() != md:
            (out / "CREDITS.md").write_text(md)
        masters = {w["id"]: cache[w["id"]]["sm"]["path"] for w in works}
        rh = emit.report_html(works, masters, rep, stats)
        report_dir = TOOLS / "out"; report_dir.mkdir(parents=True, exist_ok=True)
        if not (report_dir / "report.html").exists() or (report_dir / "report.html").read_text() != rh:
            (report_dir / "report.html").write_text(rh)
    for k, e in dropped:
        log(f"  DROPPED (fetch failed): {k}: {e}")
    log(f"done: {len(works)} works ({len(priced)} priced), {len(rep.errors)} errors, {len(rep.warnings)} warnings")
    log("stats " + json.dumps(stats))
    return 1 if rep.errors else 0


if __name__ == "__main__":
    sys.exit(main())
