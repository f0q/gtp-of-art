"""Stage: derive — money (FX, CPI, logs), era bucket, PD check, slugs."""
from __future__ import annotations

import csv
import math
import re
import unicodedata
from pathlib import Path

CUR = Path(__file__).resolve().parent.parent / "curation"
REF_YEAR = 2025
ZERO_DECIMAL = {"JPY", "KRW", "ITL", "ESP"}
PD_DEATH_MAX = 1955
PD_PUBLISHED_MAX = 1930
EXCLUDED_ARTISTS = {"pablo picasso", "jackson pollock", "mark rothko", "francis bacon", "andy warhol",
                    "jean-michel basquiat", "edward hopper", "rene magritte", "qi baishi", "frida kahlo"}


def slug(s: str) -> str:
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "-", s).strip("-")


def _read(name: str) -> list[dict]:
    with open(CUR / name, newline="") as f:
        return list(csv.DictReader(ln for ln in f if not ln.startswith("#")))


class Money:
    def __init__(self) -> None:
        self.fx = {(int(r["year"]), r["currency"]): (float(r["usd_per_unit"]), r["source"], r["partial"] == "True")
                   for r in _read("fx_annual.csv")}
        self.cpi = {int(r["year"]): (float(r["cpi"]), r["source"], r["partial"] == "True")
                    for r in _read("cpi_u_annual.csv")}

    def fx_rate(self, currency: str, year: int):
        if (year, currency) not in self.fx:
            raise KeyError(f"no FX rate for {currency} {year} in fx_annual.csv")
        return self.fx[(year, currency)]

    def price(self, amount: float, currency: str, year: int) -> dict:
        rate, fx_src, fx_partial = self.fx_rate(currency, year)
        if year not in self.cpi or REF_YEAR not in self.cpi:
            raise KeyError(f"no CPI for {year} or {REF_YEAR}")
        usd = amount * rate
        usd_nominal = int(round(usd))
        adj = usd * self.cpi[REF_YEAR][0] / self.cpi[year][0]
        usd_adjusted = int(round(adj))
        minor = int(round(amount)) if currency in ZERO_DECIMAL else int(round(amount * 100))
        return {
            "amount_minor": minor, "usd_nominal": usd_nominal, "usd_adjusted": usd_adjusted,
            "adjust_ref_year": REF_YEAR, "fx_rate_to_usd": round(rate, 8),
            "fx_source": "identity" if currency == "USD" else fx_src + (" (partial year)" if fx_partial else ""),
            "cpi_source": f"BLS CPI-U annual average {year}->{REF_YEAR} (tools/curation/cpi_u_annual.csv)"
                          + (" [year-to-date]" if self.cpi[year][2] else ""),
            "log10_usd_nominal_milli": milli(usd_nominal),
            "log10_usd_adjusted_milli": milli(usd_adjusted),
            "_warn": [w for w, c in (("fx partial year", fx_partial), ("cpi partial year", self.cpi[year][2])) if c],
        }


def milli(x: int) -> int:
    """floor(1000*log10(x) + 0.5) — spec §8.2."""
    return int(math.floor(1000 * math.log10(x) + 0.5))


def era_bucket(year: int) -> str:
    if year < 1500: return "pre1500"
    if year < 1600: return "1500_1600"
    if year < 1700: return "1600_1700"
    if year < 1800: return "1700_1800"
    if year < 1850: return "1800_1850"
    if year < 1900: return "1850_1900"
    return "1900_1930"


def level(v: int, names: tuple[str, str, str]) -> str:
    return names[0] if v <= 33 else names[1] if v <= 66 else names[2]


SCALAR_LEVELS = {"abstraction": ("low", "mid", "high"), "warmth": ("cool", "neutral", "warm"),
                 "saturation": ("muted", "mid", "vivid"), "brightness": ("dark", "mid", "light"),
                 "complexity": ("sparse", "mid", "busy")}


def buckets(category_id: str, taste: dict) -> list[str]:
    """The 9 `family:value` bucket keys of spec §16.1."""
    b = [f"era:{taste['era_bucket']}", f"category:{category_id}", f"subject:{taste['subject']}",
         f"mood:{taste['mood']}"]
    for fam, names in SCALAR_LEVELS.items():
        b.append(f"{fam}:{level(taste[fam], names)}")
    return sorted(b)


def pd_check(artist: str, death_year: int | None, date_end: int | None, override: str = "") -> tuple[bool, str]:
    if override:
        return True, f"override: {override}"
    if slug(artist).replace("-", " ") in EXCLUDED_ARTISTS:
        return False, "artist on exclusion list"
    if date_end is None:
        return False, "no date"
    if date_end > PD_PUBLISHED_MAX:
        return False, f"dated {date_end} > {PD_PUBLISHED_MAX}"
    if death_year is None:
        if date_end < 1800:
            return True, f"created by {date_end}; author long dead (anonymous/unknown death year)"
        return False, "unknown death year"
    if death_year > PD_DEATH_MAX:
        return False, f"author died {death_year} > {PD_DEATH_MAX}"
    return True, f"author died {death_year} (life+70 expired) and work dated {date_end} (<= {PD_PUBLISHED_MAX})"
