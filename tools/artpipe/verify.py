"""Price-source verification: fetch each cited URL (cached) and look for the amount in the text.

A price is "verified" for a URL when one of several renderings of the amount appears in the
fetched page (e.g. 450,312,500 | 450.3 million | $450m). Wikidata statement references are
handled separately (the statement itself is the structured source).
"""
from __future__ import annotations

import html
import re
import unicodedata

from . import http

_TAG = re.compile(r"<script.*?</script>|<style.*?</style>|<[^>]+>", re.S | re.I)


def page_raw(url: str) -> str | None:
    try:
        b = http.get_bytes(url, retries=2, timeout=30, allow_404=True)
    except http.OfflineMiss:
        raise
    except Exception:
        return None
    return None if b is None else b.decode("utf-8", "replace")


# Christie's lot pages render the price client-side; the page's own lot (not the "related lots")
# is the first price_realised written as a float, e.g. "price_realised":1808750.0,"price_realised_txt":"GBP 1,808,750"
_CHRISTIES_LOT = re.compile(r'"price_realised":([0-9]+\.[0-9]+),"price_realised_txt":"([A-Z]{3}) ([0-9,]+)"')


def structured_price(url: str, raw: str) -> tuple[float, str] | None:
    """(amount, currency) of the page's own lot where the auction house publishes it as data."""
    if "christies.com" in url:
        m = _CHRISTIES_LOT.search(raw)
        if m:
            return float(m.group(1)), m.group(2)
    return None


def page_text(url: str) -> str | None:
    t = page_raw(url)
    if t is None:
        return None
    t = html.unescape(_TAG.sub(" ", t)).replace("\xa0", " ").replace(" ", " ")
    return re.sub(r"\s+", " ", t).lower()


def _num_forms(x: float) -> list[str]:
    forms = []
    for d in (0, 1, 2, 3):
        s = f"{x:.{d}f}"
        if abs(float(s) - x) <= max(0.051 * (10 ** -d) * 10, 1e-9) and s not in forms:
            forms.append(s)
    return forms


def amount_patterns(amount: float) -> list[re.Pattern]:
    pats = []
    a = round(amount)
    sep_forms = {f"{a:,}", f"{a:,}".replace(",", "."), f"{a:,}".replace(",", " ")}
    if amount != int(amount):  # e.g. GBP 8,187.50: also match the exact figure with pence
        c = f"{amount:,.2f}"
        sep_forms |= {c, c.replace(",", "_").replace(".", ",").replace("_", "."), c.replace(",", " ").replace(".", ",")}
    for s in sep_forms:
        pats.append(re.compile(r"(?<![\d.,])" + re.escape(s) + r"(?![\d])"))
    for unit, words in ((1e6, r"(millionen|millions?|millones|miljoen|milioni|mio|mln|mn|m)\b"),
                        (1e9, r"(billion|milliarden|bn|b)\b"), (1e3, r"(thousand|k)\b")):
        if amount >= unit and amount / unit < 10000:
            for f in _num_forms(amount / unit):
                for f2 in {f, f.replace(".", ",")}:
                    pats.append(re.compile(r"(?<![\d.,])" + re.escape(f2) + r"\s*-?\s*" + words))
    return pats


def _fold(s: str) -> str:
    return unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()


def context_terms(artist: str, title: str) -> list[str]:
    """Words that must appear near the amount: artist surname(s) and distinctive title words."""
    stop = {"the", "and", "with", "from", "portrait", "study", "young", "still", "life", "elder",
            "younger", "attributed", "small", "version", "of", "de", "da", "van", "von", "der"}
    words = [w for w in re.findall(r"[a-z]+", _fold(artist)) if len(w) > 3 and w not in stop]
    words += [w for w in re.findall(r"[a-z]+", _fold(title)) if len(w) > 4 and w not in stop]
    return words


def check_url(url: str, amount: float, terms: list[str] | None = None, window: int = 700,
              currency: str | None = None) -> dict:
    raw = page_raw(url)
    if raw is None:
        return {"url": url, "fetched": False, "found": False}
    sp = structured_price(url, raw)
    if sp and abs(sp[0] - amount) <= max(1.0, 0.0005 * amount) and (currency is None or currency == sp[1]):
        return {"url": url, "fetched": True, "found": True, "match": f"lot data: price_realised {sp[1]} {sp[0]:,.0f}"}
    t = page_text(url)
    ft = _fold(t)
    near_miss = None
    for p in amount_patterns(amount):
        for m in p.finditer(t):
            s = max(0, m.start() - 90)
            snippet = t[s:m.end() + 60]
            ctx = ft[max(0, m.start() - window): m.end() + window]
            if not terms or any(w in ctx for w in terms):
                return {"url": url, "fetched": True, "found": True, "match": snippet}
            near_miss = near_miss or snippet
    out = {"url": url, "fetched": True, "found": False}
    if near_miss:
        out["amount_without_context"] = near_miss
    return out


def check_wikidata(qid: str, amount: float, currency: str) -> dict:
    """Is there a Wikidata price statement on `qid` matching amount (±1%) and currency?"""
    from . import wikidata
    best = None
    for p in wikidata.prices(qid):
        if p["currency"] != currency or not p["amount"]:
            continue
        if abs(p["amount"] - amount) / amount <= 0.01:
            estimate = any(m in ("Q37113960", "Q965330") for m in p["method_qids"])
            cand = {"qid": qid, "statement_id": p["statement_id"], "amount": p["amount"],
                    "date": p["date"], "refs": p["refs"], "has_reference": bool(p["refs"]),
                    "estimate_flag": estimate}
            if best is None or (cand["has_reference"] and not best["has_reference"]):
                best = cand
    return best or {"qid": qid, "matched": False}


def verify_row(row: dict) -> dict:
    """Evidence for one curation row's price."""
    amount = float(row["price_amount"])
    urls = [row[k] for k in ("source_url_1", "source_url_2", "source_url_3") if row.get(k)]
    terms = context_terms(row.get("artist", ""), row.get("title", ""))
    checks = [check_url(u, amount, terms, currency=row["price_currency"]) for u in urls]
    wd = check_wikidata(row["wikidata_price"], amount, row["price_currency"]) if row.get("wikidata_price") else None
    verified_url = next((c["url"] for c in checks if c["found"]), None)
    wd_ok = bool(wd and wd.get("has_reference"))
    return {"amount": amount, "currency": row["price_currency"], "urls": checks, "wikidata": wd,
            "verified": bool(verified_url or wd_ok), "verified_by": verified_url or (
                f"wikidata:{wd['qid']}#{wd['statement_id']}" if wd_ok else None)}
