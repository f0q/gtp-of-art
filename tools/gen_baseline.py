#!/usr/bin/env python3
"""Generate Resources/taste_baseline.json: a synthetic, seeded prior for taste rarity (spec §16-17).

Method (data lead, Part F): 8 archetype personas expressed as logit weights over the 9 bucket
families of spec §16.1; 5,000 synthetic users, each a Dirichlet(0.5) mixture of the personas plus a
little idiosyncratic noise; like-probability = sigmoid(bias + user·x_work) with the bias calibrated
so the population like-rate is ~55%. Sessions of 10/20/40/80 swipes are simulated over the real
dataset (both pools).
  pass 1 -> features{bucket: p_like, n}           (all simulated swipes)
  pass 2 -> distinctiveness percentiles per session length, using the §16.3 lift model with the
            pass-1 p_like and alpha=4; archetype shares from the §16.4 axes on 40-swipe sessions.
The output is labelled "estimated" in the app; phase 2 swaps it for real population data.

Usage: tools/.venv/bin/python tools/gen_baseline.py [--dataset Resources/dataset.json]
       [--out Resources/taste_baseline.json] [--users 5000] [--seed 20261011]
"""
from __future__ import annotations

import argparse
import json
import math
import random
import sys
from collections import Counter
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
from artpipe import derive  # noqa: E402

ALPHA = 4
SESSIONS = (10, 20, 40, 80)
TARGET_LIKE = 0.55
LN3 = math.log(3)

PERSONAS = {
    "old_master_devotee": {"era:pre1500": 1.2, "era:1500_1600": 1.0, "era:1600_1700": 0.8, "subject:religious_myth": 0.6,
                           "abstraction:low": 0.6, "era:1900_1930": -1.0, "subject:abstract": -1.2, "abstraction:high": -0.8},
    "light_chaser": {"category:impressionism": 1.4, "category:post_impressionism": 0.8, "category:pointillism": 0.8,
                     "brightness:light": 0.8, "saturation:vivid": 0.5, "subject:landscape": 0.6, "mood:serene": 0.4,
                     "mood:joyful": 0.4, "brightness:dark": -0.6},
    "modernist": {"abstraction:high": 1.5, "subject:abstract": 1.2, "era:1900_1930": 1.0, "category:early_abstraction": 1.0,
                  "category:cubism": 0.8, "category:expressionism": 0.6, "abstraction:low": -0.8, "subject:religious_myth": -0.6},
    "drama_seeker": {"mood:dramatic": 1.2, "brightness:dark": 0.8, "category:baroque": 1.0, "category:romanticism": 0.8,
                     "subject:religious_myth": 0.4, "mood:serene": -0.5, "brightness:light": -0.3},
    "quiet_interiors": {"subject:still_life": 1.2, "subject:genre": 0.6, "category:dutch_golden_age": 1.0,
                        "mood:serene": 0.6, "complexity:sparse": 0.4, "mood:dramatic": -0.5},
    "people_watcher": {"subject:portrait": 1.3, "subject:figure": 0.6, "subject:landscape": -0.6, "subject:abstract": -0.8,
                       "mood:melancholic": 0.3},
    "colourist": {"saturation:vivid": 1.2, "category:fauvism": 1.0, "category:expressionism": 0.6, "warmth:warm": 0.4,
                  "saturation:muted": -0.8, "brightness:dark": -0.5, "category:art_nouveau": 0.5},
    "contemplative": {"subject:landscape": 1.2, "category:ukiyo_e": 1.0, "category:chinese_ink": 1.0, "mood:serene": 0.6,
                      "mood:melancholic": 0.3, "complexity:sparse": 0.3, "subject:genre": -0.3, "warmth:cool": 0.3},
}

ERA_LOAD = {"era:pre1500": -1, "era:1500_1600": -0.75, "era:1600_1700": -0.5, "era:1700_1800": -0.25,
            "era:1800_1850": 0.25, "era:1850_1900": 0.75, "era:1900_1930": 1}
AXES = {
    "era": ERA_LOAD,
    "form": {"abstraction:low": -1, "abstraction:high": 1},
    "palette": {"saturation:muted": -1, "saturation:vivid": 1, "brightness:dark": -1, "brightness:light": 1,
                "warmth:warm": -0.5, "warmth:cool": 0.5},
    "mood": {"mood:serene": -1, "mood:joyful": -0.5, "mood:melancholic": 0.5, "mood:dramatic": 1},
}
LETTERS = {"era": ("O", "M"), "form": ("F", "A"), "palette": ("E", "V"), "mood": ("S", "D")}


def sigmoid(z: float) -> float:
    return 1 / (1 + math.exp(-z))


def dirichlet(rng: random.Random, k: int, a: float) -> list[float]:
    g = [rng.gammavariate(a, 1.0) for _ in range(k)]
    s = sum(g) or 1.0
    return [x / s for x in g]


def make_users(rng: random.Random, n: int, all_buckets: list[str]) -> list[dict]:
    names = list(PERSONAS)
    users = []
    for _ in range(n):
        mix = dirichlet(rng, len(names), 0.5)
        w = {b: rng.gauss(0, 0.3) for b in all_buckets}
        for m, name in zip(mix, names):
            for b, v in PERSONAS[name].items():
                w[b] = w.get(b, 0.0) + 1.6 * m * v
        users.append(w)
    return users


def calibrate(users, works) -> float:
    scores = [[sum(u.get(b, 0.0) for b in wb) for wb in works] for u in users[:800]]
    lo, hi = -5.0, 5.0
    for _ in range(50):
        mid = (lo + hi) / 2
        rate = sum(sigmoid(mid + s) for row in scores for s in row) / (len(scores) * len(works))
        lo, hi = (mid, hi) if rate < TARGET_LIKE else (lo, mid)
    return (lo + hi) / 2


def session(rng, user, works, bias, n):
    idx = rng.sample(range(len(works)), n) if n <= len(works) else [rng.randrange(len(works)) for _ in range(n)]
    out = []
    for i in idx:
        wb = works[i]
        liked = rng.random() < sigmoid(bias + sum(user.get(b, 0.0) for b in wb))
        out.append((wb, liked))
    return out


def contributions(sw, p):
    S, L = Counter(), Counter()
    for wb, liked in sw:
        for b in wb:
            S[b] += 1
            if liked:
                L[b] += 1
    c = {}
    for b, s in S.items():
        if b not in p:
            continue
        pd = min(max(p[b], 0.001), 0.999)
        a = (L[b] + ALPHA * pd) / (s + ALPHA)
        ell = max(-LN3, min(LN3, math.log(a / pd)))
        c[b] = (s / (s + ALPHA)) * ell
    return c


def dst(c: dict) -> float:
    return math.sqrt(sum(v * v for v in c.values()) / len(c)) if c else 0.0


def archetype(c: dict) -> str:
    out = ""
    for ax, loads in AXES.items():
        num = sum(l * c[b] for b, l in loads.items() if b in c)
        den = sum(abs(l) for b, l in loads.items() if b in c)
        v = 0.0 if den == 0 else max(-1.0, min(1.0, num / (LN3 * den)))
        out += LETTERS[ax][1] if v >= 0 else LETTERS[ax][0]
    return out


def pct(sorted_vals, q):
    i = (len(sorted_vals) - 1) * q
    lo = int(math.floor(i))
    hi = min(lo + 1, len(sorted_vals) - 1)
    return sorted_vals[lo] + (sorted_vals[hi] - sorted_vals[lo]) * (i - lo)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", default=str(TOOLS.parent / "Resources" / "dataset.json"))
    ap.add_argument("--out", default=str(TOOLS.parent / "Resources" / "taste_baseline.json"))
    ap.add_argument("--users", type=int, default=5000)
    ap.add_argument("--seed", type=int, default=20261011)
    a = ap.parse_args()
    doc = json.loads(Path(a.dataset).read_text())
    works = [derive.buckets(w["category_id"], w["taste"]) for w in sorted(doc["artworks"], key=lambda w: w["id"])]
    all_b = sorted({b for wb in works for b in wb} | {b for p in PERSONAS.values() for b in p})
    rng = random.Random(a.seed)
    users = make_users(rng, a.users, all_b)
    bias = calibrate(users, works)

    # pass 1: population like-rates per bucket
    S, L, likes, total = Counter(), Counter(), 0, 0
    sessions_by_user = []
    for u in users:
        per = {}
        for n in SESSIONS:
            sw = session(rng, u, works, bias, n)
            per[n] = sw
            for wb, liked in sw:
                total += 1
                likes += liked
                for b in wb:
                    S[b] += 1
                    L[b] += liked
        sessions_by_user.append(per)
    p = {b: L[b] / S[b] for b in S}
    features = {b: {"p_like": round(p[b], 4), "n": S[b]} for b in sorted(S)}

    # pass 2: distinctiveness + archetypes with fresh sessions
    rng2 = random.Random(a.seed + 1)
    dsts = {n: [] for n in SESSIONS}
    arche = Counter()
    for u in users:
        for n in SESSIONS:
            c = contributions(session(rng2, u, works, bias, n), p)
            dsts[n].append(dst(c))
            if n == 40:
                arche[archetype(c)] += 1
    perc = {}
    for n in SESSIONS:
        v = sorted(dsts[n])
        perc[f"swipes_{n}"] = {f"p{q}": round(pct(v, q / 100), 4) for q in (50, 75, 90, 95, 99)}
    ids = [e + f + pl + m for e in "OM" for f in "FA" for pl in "EV" for m in "SD"]
    shares = {i: round(arche[i] / a.users, 4) for i in sorted(ids)}
    out = {
        "schema_version": 1,
        "baseline_id": f"synthetic-{doc['dataset_id']}-s{a.seed}",
        "source": ("estimated: synthetic population (8 personas, Dirichlet(0.5) mixtures, "
                   f"{a.users} users, like-rate {likes / total:.3f}); tools/gen_baseline.py"),
        "alpha": ALPHA,
        "features": features,
        "distinctiveness_percentiles": perc,
        "archetype_shares": shares,
    }
    Path(a.out).write_text(json.dumps(out, indent=1) + "\n")
    print(f"users {a.users}, works {len(works)}, buckets {len(features)}, bias {bias:.3f}, like-rate {likes / total:.3f}")
    print("percentiles", json.dumps(perc))
    print("archetypes", json.dumps(dict(arche.most_common())))


if __name__ == "__main__":
    main()
