# Usage: python3 Packages/ArtCore/Scripts/crosscheck_fixtures.py spec/fixtures
"""Independent re-implementation (from the C reference / textbook definitions) checked against spec/fixtures."""
import json, math, sys, datetime, os
D = sys.argv[1]
M = (1 << 64) - 1
def load(n): return json.load(open(os.path.join(D, n)))
fails = 0; checked = 0
def check(cond, msg):
    global fails, checked
    checked += 1
    if not cond:
        fails += 1; print("FAIL", msg)

# --- SplitMix64, transcribed from Vigna's splitmix64.c:
#   uint64_t z = (x += 0x9e3779b97f4a7c15);
#   z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9; z = (z ^ (z >> 27)) * 0x94d049bb133111eb; return z ^ (z >> 31);
class SM:
    def __init__(s, seed): s.x = seed & M
    def next(s):
        s.x = (s.x + 0x9e3779b97f4a7c15) & M
        z = s.x
        z = ((z ^ (z >> 30)) * 0xbf58476d1ce4e5b9) & M
        z = ((z ^ (z >> 27)) * 0x94d049bb133111eb) & M
        return z ^ (z >> 31)
    def nextint(s, b):
        t = (1 << 64) % b   # 2^64 mod b
        while True:
            r = s.next()
            if r >= t: return r % b

for c in load("prng.json")["cases"]:
    r = SM(int(c["input"]["seed"]))
    b = c["input"].get("bound")
    vals = [str(r.nextint(int(b)) if b else r.next()) for _ in range(c["input"]["count"])]
    check(vals == c["expected"]["values"] and str(r.x) == c["expected"]["state_after"], c["name"])
# Known published vector sanity: seed 1234567 (as quoted in the plan)
r = SM(1234567); print("seed 1234567 first outputs:", r.next(), r.next())

for c in load("shuffle.json")["cases"]:
    r = SM(int(c["input"]["seed"])); a = list(range(c["input"]["n"]))
    for i in range(len(a) - 1, 0, -1):
        j = r.nextint(i + 1); a[i], a[j] = a[j], a[i]
    check(a == c["expected"]["permutation"] and str(r.x) == c["expected"]["state_after"], c["name"])

def fnv(s):
    h = 0xcbf29ce484222325
    for b in s.encode("utf-8"): h = ((h ^ b) * 0x100000001b3) & M
    return h
for c in load("fnv.json")["cases"]:
    h = fnv(c["input"]["text"]); check(str(h) == c["expected"]["hash"] and "0x%016x" % h == c["expected"]["hash_hex"], c["name"])

for c in load("daykey.json")["cases"]:
    i = c["input"]
    try:
        d = datetime.date(i["year"], i["month"], i["day"]); valid = True
    except ValueError: valid = False
    e = c["expected"]
    check(e["valid"] == valid, c["name"] + " validity")
    if valid:
        check(e["day_number"] == d.toordinal() - datetime.date(1970, 1, 1).toordinal(), c["name"] + " daynum")
        check(e["iso"] == "%04d-%02d-%02d" % (d.year, d.month, d.day), c["name"] + " iso")

for c in load("streak.json")["cases"]:
    i = c["input"]; today = datetime.date.fromisoformat(i["today"])
    if i.get("last_day") is None: exp = (1, i["today"])
    else:
        gap = (today - datetime.date.fromisoformat(i.get("last_day"))).days
        exp = (i["streak"] + 1, i["today"]) if gap == 1 else ((i["streak"], i.get("last_day")) if gap <= 0 else (1, i["today"]))
    check((c["expected"]["streak"], c["expected"].get("last_day")) == exp, c["name"])

for c in load("daily.json")["cases"]:
    i = c["input"]; s = "artprice|daily|r%d|d%s|%s" % (i["rules_version"], i["dataset_version"], i["day"])
    check(s == c["expected"]["seed_string"] and str(fnv(s)) == c["expected"]["seed"], c["name"])

def tier(e):
    for lim, name, pts in [(97, "bullseye", 100), (301, "expert_eye", 70), (699, "good_instinct", 40), (1000, "in_the_room", 15)]:
        if e <= lim: return name, pts
    return "off_the_wall", 0
for c in load("bid_score.json")["cases"]:
    p = min(max(c["input"]["position"], 0), 700); g = 2000 + 10 * p; a = c["input"]["actual_milli"]; e = abs(g - a)
    t, pts = tier(e); ex = c["expected"]
    d = "under" if g < a else ("over" if g > a else "exact")
    check((ex["guess_milli"], ex["error_milli"], ex["tier"], ex["points"], ex["direction"]) == (g, e, t, pts, d), c["name"])
    check(abs(ex["factor"] - 10 ** (e / 1000)) <= 1e-9 * 10 ** (e / 1000), c["name"] + " factor")

def r2(v):
    if v < 100: return v
    p = 10 ** (len(str(v)) - 2)
    return (v + p // 2) // p * p
def compact(v):
    r = r2(v)
    unit, suf = (10**9, "B") if r >= 10**9 else (10**6, "M") if r >= 10**6 else (1000, "K") if r >= 1000 else (1, "")
    w, t = r // unit, (r % unit) * 10 // unit
    return "$%d%s%s" % (w, ("." + str(t)) if t else "", suf)
for c in load("price_format.json")["cases"]:
    i = c["input"]; ex = c["expected"]
    text = ("~" if i["reported"] else "≈" if i["approximate"] else "") + compact(i["usd"]) + ("+" if i["lower_bound"] else "")
    check((ex["rounded"], ex["compact"], ex["text"]) == (r2(i["usd"]), compact(i["usd"]), text), c["name"])

# distractor constraint audit (not a re-implementation of selection, just the invariants)
for c in load("distractors.json")["cases"]:
    ex = c["expected"]
    if ex.get("options") is None: continue
    o = ex["options"]; s = ex["correct_index"]
    check(o[s] == r2(c["input"]["truth_usd"]), c["name"] + " truth")
    check(all(500 <= v <= 2_000_000_000 for v in o) and all(o[k-1]*18 <= o[k]*10 for k in range(1, 4)), c["name"] + " band/ratio")
    check(all(r2(v) == v for v in o) and all(o[k] not in (10**6, 10**9) for k in range(4) if k != s), c["name"] + " sf/forbidden")

# --- Taste: recompute from the fixture's integer counts and the mini baseline with math.log
mini = load("mini_dataset.json"); base = mini["taste_baseline"]; alpha = base["alpha"]
L = {"era:pre1500": (0, -1.0), "era:1500_1600": (0, -0.75), "era:1600_1700": (0, -0.5), "era:1700_1800": (0, -0.25),
     "era:1800_1850": (0, .25), "era:1850_1900": (0, .75), "era:1900_1930": (0, 1.0), "abstraction:low": (1, -1.0),
     "abstraction:high": (1, 1.0), "saturation:muted": (2, -1.0), "saturation:vivid": (2, 1.0), "brightness:dark": (2, -1.0),
     "brightness:light": (2, 1.0), "warmth:warm": (2, -.5), "warmth:cool": (2, .5), "mood:serene": (3, -1.0),
     "mood:joyful": (3, -.5), "mood:melancholic": (3, .5), "mood:dramatic": (3, 1.0)}
for c in load("taste.json")["cases"]:
    ex = c["expected"]; prof = ex["profile"]; cs = {}
    for b, s in prof["exposures"].items():
        if s < 1 or b not in base["features"]: continue
        p = min(max(base["features"][b]["p_like"], .001), .999); l = prof["likes"].get(b, 0)
        a = (l + alpha * p) / (s + alpha); lift = max(-math.log(3), min(math.log(3), math.log(a / p)))
        cs[b] = s / (s + alpha) * lift
    dst = math.sqrt(sum(v * v for v in cs.values()) / len(cs)) if cs else 0
    num = [0.0] * 4; w = [0.0] * 4
    for b, v in cs.items():
        if b in L: k, ld = L[b]; num[k] += ld * v; w[k] += abs(ld)
    ax = [0 if w[k] == 0 else max(-1, min(1, num[k] / (math.log(3) * w[k]))) for k in range(4)]
    tol = ex["tolerance"]
    check(abs(dst - ex["distinctiveness"]) <= tol, c["name"] + " dst %r vs %r" % (dst, ex["distinctiveness"]))
    names = ["era", "form", "palette", "mood"]
    check(all(abs(ax[k] - ex["axes"][names[k]]) <= tol for k in range(4)), c["name"] + " axes")
    arch = ("O" if ax[0] < 0 else "M") + ("F" if ax[1] < 0 else "A") + ("E" if ax[2] < 0 else "V") + ("S" if ax[3] < 0 else "D")
    check(arch == ex["archetype_id"], c["name"] + " archetype")
    # recompute counts from the swipes in the dataset
    works = {a["id"]: a for a in mini["artworks"]}
    def lvl(v, names): return names[0 if v <= 33 else 1 if v <= 66 else 2]
    def buckets(a):
        t = a["taste"]
        return ["era:" + t["era_bucket"], "category:" + a["category_id"], "subject:" + t["subject"],
                "abstraction:" + lvl(t["abstraction"], ["low", "mid", "high"]), "warmth:" + lvl(t["warmth"], ["cool", "neutral", "warm"]),
                "saturation:" + lvl(t["saturation"], ["muted", "mid", "vivid"]), "brightness:" + lvl(t["brightness"], ["dark", "mid", "light"]),
                "complexity:" + lvl(t["complexity"], ["sparse", "mid", "busy"]), "mood:" + t["mood"]]
    sw = c["input"]["swipes"]; keep = sw[:len(sw) - c["input"]["undo_last"]]
    E = {}; Lk = {}
    for s in keep:
        for b in buckets(works[s["artwork_id"]]):
            E[b] = E.get(b, 0) + 1
            if s["liked"]: Lk[b] = Lk.get(b, 0) + 1
    check(E == prof["exposures"] and Lk == prof["likes"] and prof["swipe_count"] == len(keep), c["name"] + " counts")

for c in load("rarity.json")["cases"]:
    i = c["input"]; ex = c["expected"]; n = i["swipe_count"]
    bks = sorted(int(k.split("_")[1]) for k in base["distinctiveness_percentiles"])
    bk = min(bks, key=lambda b: (abs(b - n), b))
    k = base["distinctiveness_percentiles"]["swipes_%d" % bk]
    pts = [(0, 0), (k["p50"], 50), (k["p75"], 75), (k["p90"], 90), (k["p95"], 95), (k["p99"], 99)]
    d = i["distinctiveness"]; pct = 99
    if d <= 0: pct = 0
    else:
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            if d <= x1: pct = y0 + (y1 - y0) * (d - x0) / (x1 - x0); break
    vis = "hidden" if n < 12 else "band" if n < 40 else "exact"
    check(abs(pct - ex["percentile"]) <= ex["tolerance"] and vis == ex["visibility"] and bk == ex.get("swipe_bucket"), c["name"])


# --- Weighted picker
def wpick(ws, r):
    tot = sum(w for w in ws if w > 0)
    if tot <= 0: return None
    x = r.nextint(tot); cum = 0
    for i, w in enumerate(ws):
        if w > 0:
            cum += w
            if x < cum: return i
for c in load("weighted_pick.json")["cases"]:
    i = c["input"]; r = SM(int(i["seed"])); picks = []
    for _ in range(i["count"]):
        k = wpick(i["weights"], r)
        if k is None: picks = None; break
        picks.append(k)
    check(picks == c["expected"].get("picks") and str(r.x) == c["expected"]["state_after"], "weighted " + c["name"])

# --- Onboarding prior (re-implemented from spec), seeds, and prior-weighted swipe sessions
ERA_DEPTS = {"classic": ["nineteenth_century", "old_masters"], "modern": ["impressionist_modern"]}
SUBJ = {"landscape": ["landscape"], "people": ["portrait", "figure", "genre"], "still_life": ["still_life"]}
MOOD = {"serene": ["serene", "joyful"], "dramatic": ["dramatic", "melancholic"]}
DEPT_ERAS = {"old_masters": ["pre1500", "1500_1600", "1600_1700", "1700_1800"], "nineteenth_century": ["1800_1850", "1850_1900"],
             "impressionist_modern": ["1850_1900", "1900_1930"]}
cat_dept = {c["id"]: c.get("department_id") for c in mini["taxonomy"]}
art_sorted = sorted(mini["artworks"], key=lambda a: a["id"].encode())
def prior_from(ans):
    depts = sorted(ans.get("departments", [])) or ERA_DEPTS.get(ans.get("era"), [])
    sw = {t: 3 for s in ans.get("subjects", []) for t in SUBJ[s]}
    mw = {m: 3 for m in MOOD.get(ans.get("mood"), [])}
    diff, mode = {"learn": ("easy", "category"), "test_my_eye": ("hard", "bid")}.get(ans.get("intent"), ("medium", "pick_price"))
    seeds = {"era:" + e for d in depts for e in DEPT_ERAS.get(d, [])} | {"subject:" + t for t in sw} | {"mood:" + m for m in mw}
    return {"department_weights": {d: 3 for d in depts}, "subject_weights": sw, "mood_weights": mw,
            "default_difficulty": diff, "highlighted_mode": mode, "seed_buckets": sorted(seeds, key=str.encode)}
for c in load("prior.json")["cases"]:
    pr = prior_from(c["input"]["answers"]); ex = c["expected"]
    check(pr == ex["prior"], "prior " + c["name"])
    sp = ex["seeded_profile"]; sd = {b: 2 for b in pr["seed_buckets"]}
    check(sp["exposures"] == sd and sp["likes"] == sd and sp.get("seeds", {}) == sd and sp["swipe_count"] == 0, "seeded " + c["name"])
    if c["input"]["mode"] == "swipe" and c["input"].get("recipe") is None:
        r = SM(int(c["input"]["seed"])); used = set(); got = []
        for _ in range(20):
            E = [a for a in art_sorted if a["id"] not in used]
            ws = [pr["department_weights"].get(cat_dept[a["category_id"]], 1) + pr["subject_weights"].get(a["taste"]["subject"], 1)
                  + pr["mood_weights"].get(a["taste"]["mood"], 1) for a in E]
            k = wpick(ws, r); got.append(E[k]["id"]); used.add(E[k]["id"])
        check(got == [x["payload"]["artwork"] for x in ex["rounds"]], "prior swipe session " + c["name"])

# --- Category: truth quiz-eligible, distractors active (rule v2)
counts = {}
for a in mini["artworks"]: counts[a["category_id"]] = counts.get(a["category_id"], 0) + 1
cats = {c["id"]: c for c in mini["taxonomy"]}
quiz = {i for i, c in cats.items() if c["active"] and counts.get(i, 0) >= c["min_quiz_items"]}
for c in load("category.json")["cases"]:
    rd = c["expected"].get("round")
    if not rd: continue
    t = rd["options"][rd["correct_index"]]
    check(t in quiz and all(cats[o]["active"] for o in rd["options"]) and len(set(rd["options"])) == 4, "category rule " + c["name"])

print("checked %d assertions, %d failures" % (checked, fails))
sys.exit(1 if fails else 0)
