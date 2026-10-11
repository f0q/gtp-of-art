#!/usr/bin/env python3
"""Rebuild tools/curation/fx_annual.csv and cpi_u_annual.csv from public sources (cached).

FX: FRED H.10 monthly noon buying rates (Board of Governors of the Federal Reserve System, via
FRED, St. Louis Fed), averaged per calendar year; PLN and CZK from ECB euro reference rates
(annual, ECB Data Portal) crossed with EUR/USD. Pre-1971 sterling uses the official parity
(gold parity $4.8665 to 1914; IMF par values $2.80 from Sep 1949, $2.40 from Nov 1967).
CPI: BLS CPI-U, U.S. city average, all items, NSA (CPIAUCNS via FRED), annual mean of monthly values;
years before 1913 from the Minneapolis Fed historical CPI table, rescaled to 1982-84=100 at 1913.
A year with fewer than 12 months of data is marked partial (year-to-date mean).

Usage: tools/.venv/bin/python tools/fetch_reference_data.py [--offline]
"""
from __future__ import annotations

import argparse
import csv
import io
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from artpipe import http  # noqa: E402

CUR = Path(__file__).resolve().parent / "curation"
# FRED monthly series: (currency, series, invert) — invert=True when quoted as units per USD
FRED_FX = [("GBP", "EXUSUK", False), ("EUR", "EXUSEU", False), ("CHF", "EXSZUS", True),
           ("NOK", "EXNOUS", True), ("DKK", "EXDNUS", True), ("JPY", "EXJPUS", True),
           ("CNY", "EXCHUS", True), ("HKD", "EXHKUS", True), ("SEK", "EXSDUS", True),
           ("FRF", "EXFRUS", True), ("DEM", "EXGEUS", True), ("NLG", "EXNEUS", True),
           ("CAD", "EXCAUS", True), ("AUD", "EXUSAL", False)]
ECB_CROSS = ["PLN", "CZK"]


def fred_monthly(series: str) -> dict[int, list[float]]:
    b = http.get_bytes("https://fred.stlouisfed.org/graph/fredgraph.csv", {"id": series}, timeout=40)
    out: dict[int, list[float]] = defaultdict(list)
    for row in csv.reader(io.StringIO(b.decode())):
        if not row or not re.match(r"\d{4}-", row[0]):
            continue
        try:
            out[int(row[0][:4])].append(float(row[1]))
        except ValueError:
            continue
    return out


def ecb_monthly(cur: str) -> dict[int, list[float]]:
    b = http.get_bytes(f"https://data-api.ecb.europa.eu/service/data/EXR/M.{cur}.EUR.SP00.A",
                       {"format": "csvdata"}, timeout=40)
    rows = list(csv.DictReader(io.StringIO(b.decode())))
    out: dict[int, list[float]] = defaultdict(list)
    for r in rows:
        out[int(r["TIME_PERIOD"][:4])].append(float(r["OBS_VALUE"]))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--offline", action="store_true")
    a = ap.parse_args()
    http.OFFLINE = a.offline
    fx_rows = []
    src_fred = "FRED {s} (Federal Reserve H.10, monthly avg -> annual mean)"
    eurusd = {}
    for cur, sid, inv in FRED_FX:
        for y, vals in sorted(fred_monthly(sid).items()):
            m = sum(vals) / len(vals)
            usd = (1 / m) if inv else m
            if cur == "EUR":
                eurusd[y] = (usd, len(vals))
            fx_rows.append([y, cur, f"{usd:.8g}", len(vals) < 12, src_fred.format(s=sid)])
    for cur in ECB_CROSS:
        for y, vals in sorted(ecb_monthly(cur).items()):
            if y not in eurusd:
                continue
            per_eur = sum(vals) / len(vals)
            fx_rows.append([y, cur, f"{eurusd[y][0] / per_eur:.8g}", len(vals) < 12 or eurusd[y][1] < 12,
                            f"ECB EXR M.{cur}.EUR annual mean x FRED EXUSEU"])
    have_gbp = {r[0] for r in fx_rows if r[1] == "GBP"}
    for y in range(1880, 1971):
        if y in have_gbp:
            continue
        if y <= 1914 or 1925 <= y <= 1930:
            v, s = 4.8665, "Gold-standard parity (GBP 1 = USD 4.8665)"
        elif 1950 <= y <= 1966:
            v, s = 2.80, "IMF par value (GBP 1 = USD 2.80, Sep 1949-Nov 1967)"
        elif 1968 <= y <= 1970:
            v, s = 2.40, "IMF par value (GBP 1 = USD 2.40, Nov 1967-1971)"
        else:
            continue  # floating/war years not needed yet; add from MeasuringWorth if used
        fx_rows.append([y, "GBP", f"{v:.8g}", False, s])
    for y in range(1880, 2031):
        fx_rows.append([y, "USD", "1", False, "identity"]) if y <= 2026 else None
    fx_rows.sort(key=lambda r: (r[1], r[0]))
    with open(CUR / "fx_annual.csv", "w", newline="") as f:
        f.write("# USD per one unit of currency, calendar-year mean. Sources: FRED (Board of Governors of the\n"
                "# Federal Reserve System, H.10 noon buying rates, https://fred.stlouisfed.org), ECB Data Portal\n"
                "# euro reference rates (https://data.ecb.europa.eu), official sterling parities before 1971.\n"
                "# Regenerate with tools/fetch_reference_data.py. partial=True: year-to-date mean.\n")
        w = csv.writer(f)
        w.writerow(["year", "currency", "usd_per_unit", "partial", "source"])
        w.writerows(fx_rows)

    cpi = fred_monthly("CPIAUCNS")
    rows = [[y, f"{sum(v) / len(v):.4f}", len(v) < 12, "BLS CPI-U CPIAUCNS via FRED, annual mean"]
            for y, v in sorted(cpi.items())]
    base1913 = sum(cpi[1913]) / len(cpi[1913])
    t = http.get_bytes("https://www.minneapolisfed.org/about-us/monetary-policy/inflation-calculator/"
                       "consumer-price-index-1800-").decode("utf-8", "replace")
    t = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", t))
    mf = {int(y): float(v) for y, v in re.findall(r"\b(1[89]\d\d) (\d+(?:\.\d+)?) -?\d", t)}
    if 1913 not in mf:
        m = re.search(r"\b1913 (\d+(?:\.\d+)?)", t)
        mf[1913] = float(m.group(1))
    pre = [[y, f"{mf[y] * base1913 / mf[1913]:.4f}", False,
            "Minneapolis Fed CPI 1800- (rescaled to 1982-84=100 at 1913)"] for y in sorted(mf) if y < 1913]
    with open(CUR / "cpi_u_annual.csv", "w", newline="") as f:
        f.write("# US CPI-U annual average, 1982-84=100. Source: U.S. Bureau of Labor Statistics CPI-U (CPIAUCNS)\n"
                "# via FRED; pre-1913 from Federal Reserve Bank of Minneapolis 'Consumer Price Index, 1800-'.\n"
                "# Regenerate with tools/fetch_reference_data.py. partial=True: year-to-date mean.\n")
        w = csv.writer(f)
        w.writerow(["year", "cpi", "partial", "source"])
        w.writerows(pre + rows)
    print(f"fx rows {len(fx_rows)}, cpi rows {len(pre) + len(rows)}; cache hits {http.stats}")


if __name__ == "__main__":
    main()
