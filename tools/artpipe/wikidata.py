"""Wikidata helpers.

Prices are read from entity JSON (Special:EntityData) in both patterns from Part E1:
direct P2284 statements, and P2284 used as a qualifier on P793 "significant event".
Discovery uses SPARQL (rows first, labels later via VALUES).
"""
from __future__ import annotations

from . import http

CURRENCY_QID = {
    "Q4917": "USD", "Q25224": "GBP", "Q4916": "EUR", "Q4734": "FRF", "Q7953": "DEM",
    "Q788472": "NLG", "Q25344": "CHF", "Q132643": "NOK", "Q25417": "DKK", "Q123213": "PLN",
    "Q131016": "CZK", "Q39099": "CNY", "Q8146": "JPY", "Q31015": "HKD", "Q122922": "SEK",
    "Q1104069": "CAD", "Q259502": "AUD", "Q4730": "ITL", "Q61996": "ESP", "Q41044": "RUB",
    "Q177875": "AUD",
}
EVENT_AUCTION = "Q177923"


def entity(qid: str) -> dict:
    d = http.get_json(f"https://www.wikidata.org/wiki/Special:EntityData/{qid}.json")
    ents = d["entities"]
    return ents.get(qid) or next(iter(ents.values()))


def label(ent: dict, lang: str = "en") -> str | None:
    lab = ent.get("labels", {}).get(lang)
    return lab["value"] if lab else None


def _dv(snak: dict):
    if snak.get("snaktype") != "value":
        return None
    return snak["datavalue"]["value"]


def claim_values(ent: dict, pid: str) -> list:
    out = []
    for c in ent.get("claims", {}).get(pid, []):
        v = _dv(c["mainsnak"])
        if v is not None:
            out.append(v)
    return out


def first_qid(ent: dict, pid: str) -> str | None:
    for v in claim_values(ent, pid):
        if isinstance(v, dict) and "id" in v:
            return v["id"]
    return None


def year_of(timeval: dict | None) -> int | None:
    if not timeval:
        return None
    t = timeval["time"]
    sign = -1 if t.startswith("-") else 1
    return sign * int(t[1:].split("-")[0])


def first_year(ent: dict, pid: str) -> int | None:
    for v in claim_values(ent, pid):
        if isinstance(v, dict) and "time" in v:
            return year_of(v)
    return None


def _refs(stmt: dict) -> list[str]:
    out = []
    for ref in stmt.get("references", []):
        for pid in ("P854", "P248", "P973"):
            for s in ref.get("snaks", {}).get(pid, []):
                v = _dv(s)
                if isinstance(v, str):
                    out.append(v)
                elif isinstance(v, dict) and "id" in v:
                    out.append("wd:" + v["id"])
    return out


def _quals(stmt: dict, pid: str) -> list:
    return [_dv(s) for s in stmt.get("qualifiers", {}).get(pid, []) if _dv(s) is not None]


def prices(qid: str) -> list[dict]:
    """All price statements on a work, both patterns, with references and qualifiers."""
    ent = entity(qid)
    out = []

    def mk(amount_v, stmt, pattern, event=None):
        unit = amount_v["unit"].rsplit("/", 1)[-1]
        dates = _quals(stmt, "P585")
        methods = [m["id"] for m in _quals(stmt, "P459") if isinstance(m, dict)]
        venues = [m["id"] for m in _quals(stmt, "P276") + _quals(stmt, "P1640") + _quals(stmt, "P664")
                  if isinstance(m, dict)]
        out.append({
            "qid": qid, "pattern": pattern, "event": event,
            "amount": float(amount_v["amount"]), "currency_qid": unit,
            "currency": CURRENCY_QID.get(unit), "date": dates[0]["time"][1:11] if dates else None,
            "method_qids": methods, "venue_qids": venues, "refs": _refs(stmt),
            "statement_id": stmt["id"],
        })

    for c in ent.get("claims", {}).get("P2284", []):
        v = _dv(c["mainsnak"])
        if v:
            mk(v, c, "direct")
    for c in ent.get("claims", {}).get("P793", []):
        ev = _dv(c["mainsnak"])
        for q in c.get("qualifiers", {}).get("P2284", []):
            v = _dv(q)
            if v:
                mk(v, c, "event", ev["id"] if isinstance(ev, dict) else None)
    return out


def sparql_rows(query: str) -> list[dict]:
    res = http.sparql(query)
    rows = []
    for b in res["results"]["bindings"]:
        rows.append({k: (v["value"].rsplit("/", 1)[1] if v["value"].startswith("http://www.wikidata.org/entity/") else v["value"])
                     for k, v in b.items()})
    return rows
