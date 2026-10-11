# Game logic specification

Platform-neutral rules for ArtPrice (working title). The Swift reference implementation is
`Packages/ArtCore`; the Android port must reproduce it from this document and pass every case in
`spec/fixtures/*.json`. Where this document and the code disagree, the fixtures decide and the
disagreement is a bug to fix in one or the other.

Rules version: **daily rules 2** (2: category distractors from any active category), fixture schema 1.

---

## 1. Principles

1. **Selection and scoring are integer-only and deterministic.** Every random choice comes from one
   SplitMix64 stream (§3). No floating point, no platform math, no platform shuffle or random API is
   used to pick artworks, build options, place answers or award points.
2. **Logarithms are precomputed** by the dataset pipeline as integers (`log10_*_milli`, §8.2). Game
   logic never computes a logarithm for selection or scoring.
3. **Display-only values may use doubles**: the bid "factor" (§12), taste and rarity (§16, §17).
   Their fixtures carry a tolerance.
4. **Input order never matters.** Artworks and categories are sorted by id (§6) before use.

## 2. Numeric conventions

- `u64` = unsigned 64-bit integer; all `u64` arithmetic **wraps modulo 2^64** (`&+`, `&*` in Swift;
  plain `+`, `*` on `ULong` in Kotlin).
- `i64` = signed 64-bit; `int` = signed 64-bit on iOS (Swift `Int`), use `Long` in Kotlin wherever a
  value can exceed 2^31 (prices, day numbers are safe as `Int` but `Long` is fine).
- Integer division `a / b` truncates toward zero and `a % b` has the sign of `a` (Swift and Kotlin
  agree). Every division in these rules has non-negative operands unless stated.
- `abs`, `min`, `max`, `clamp(x, lo, hi) = min(max(x, lo), hi)` are the usual integer functions.

## 3. PRNG: SplitMix64

State: one `u64` `s`. Constructed from a `u64` seed: `s = seed`.

```
next():
    s = s + 0x9E3779B97F4A7C15            (wrapping)
    z = s
    z = (z XOR (z >>> 30)) * 0xBF58476D1CE4E5B9   (wrapping)
    z = (z XOR (z >>> 27)) * 0x94D049BB133111EB   (wrapping)
    return z XOR (z >>> 31)
```
`>>>` is a logical (unsigned) shift. This is S. Vigna's reference `splitmix64.c`. After `n` calls
`s = seed + n·0x9E3779B97F4A7C15 (mod 2^64)`; fixtures record this as `state_after`.

Reference values (verified against an independent Python transcription of the C code):
seed 0 → 16294208416658607535 (0xE220A8397B1DCDAF), 7960286522194355700, …;
seed 1234567 → 6457827717110365317, 3203168211198807973, …

### 3.1 `nextInt(bound)` — unbiased integer in `0 ..< bound`

`bound > 0` (it may be as large as 2^63 − 1).
```
b = u64(bound)
t = (0 - b) mod b              (wrapping subtraction, then unsigned remainder; t = 2^64 mod b)
loop:
    r = next()
    if r >= t (unsigned): return r mod b
```
Every rejected draw consumes one `next()`. `nextInt(1)` returns 0 and consumes one draw.

## 4. Shuffle: Fisher–Yates (Durstenfeld)

```
shuffle(a):
    i = len(a) − 1
    while i > 0:
        j = nextInt(i + 1)
        swap a[i], a[j]
        i = i − 1
```
Arrays of length 0 or 1 consume no draws.

## 5. Hash: FNV-1a 64

Over the UTF-8 bytes of a string:
```
h = 0xCBF29CE484222325
for each byte c: h = (h XOR c) * 0x100000001B3      (wrapping)
```

## 6. Ordering of ids

Every sort that feeds selection compares strings **lexicographically by UTF-8 bytes** (unsigned).
Ids are expected to be ASCII slugs, for which this equals ordinary string order on both platforms,
but implement the byte comparison explicitly.

## 7. Calendar, daily seed, streak

### 7.1 DayKey
A proleptic-Gregorian date `{year, month, day}` taken from the device's **local** calendar date
(not a timestamp). Valid when `1 ≤ year ≤ 9999`, `1 ≤ month ≤ 12`, `1 ≤ day ≤ daysInMonth`
(February has 29 days when `year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)`).
Text form `yyyy-MM-dd`, zero-padded (`2026-01-05`); parsing accepts exactly that form.

`dayNumber` (days since 1970-01-01) — H. Hinnant `days_from_civil`:
```
y   = month <= 2 ? year − 1 : year
era = (y >= 0 ? y : y − 399) / 400
yoe = y − era·400
mp  = month > 2 ? month − 3 : month + 9
doy = (153·mp + 2) / 5 + day − 1
doe = yoe·365 + yoe/4 − yoe/100 + doy
dayNumber = era·146097 + doe − 719468
```
Inverse (`civil_from_days`, used to add days):
```
z = n + 719468;  era = (z >= 0 ? z : z − 146096) / 146097;  doe = z − era·146097
yoe = (doe − doe/1460 + doe/36524 − doe/146096) / 365
doy = doe − (365·yoe + yoe/4 − yoe/100);  mp = (5·doy + 2)/153
day = doy − (153·mp + 2)/5 + 1;  month = mp < 10 ? mp + 3 : mp − 9
year = yoe + era·400 + (month <= 2 ? 1 : 0)
```
DayKeys compare by `dayNumber`.

### 7.2 Daily seed
```
seedString = "artprice|daily|r" + dailyRulesVersion + "|d" + datasetVersion + "|" + yyyy-MM-dd
seed       = fnv1a64(seedString)
```
`dailyRulesVersion` is a decimal integer (currently 1). `datasetVersion` is the dataset's
`dataset_id` string. Example: `artprice|daily|r1|dmini-2026.10|2026-10-11`.

### 7.3 Streak update (on completing a daily challenge)
Inputs: stored `streak`, stored `lastDay` (may be absent), `today`.
- no `lastDay` → `streak = 1`, `lastDay = today`
- `gap = today.dayNumber − lastDay.dayNumber`
  - `gap == 1` → `streak + 1`, `lastDay = today`
  - `gap <= 0` → nothing changes (`lastDay` kept) — replay, or the clock/time zone went backwards
  - `gap > 1` → `streak = 1`, `lastDay = today`

Displayed streak on a given day: the stored streak if `today − lastDay ≤ 1`, else 0. Completing a
day that already has a score is practice and changes nothing (`DailyState.completing`).

## 8. Data used by the rules

Field names are the JSON names (snake_case). Only fields the rules read are listed.

### 8.1 Artwork
`id` (slug), `date.start`/`date.end` (years; **year = start, else end**), `category_id` (primary
category; Swift `category`), `secondary_category_ids` (accepted alternates; Swift `acceptedAlso`;
missing = empty), `prices[]`, `game_price_id`, `taste` (§16.1).
The work's **category set** = `[category_id] + secondary_category_ids` without duplicates, in that order.

### 8.2 Price record
`id`, `type` (`auction_premium | auction_hammer | private_sale | ask_price | self_reported |
estimate_low | estimate_high`), `approximate`, `lower_bound`, `currency`, `usd_nominal`,
`usd_adjusted` (whole USD), `log10_usd_nominal_milli`, `log10_usd_adjusted_milli`, `confidence`
(`high|medium|low`), `game_eligible`, `price_scope` (`this_object | same_edition_other_impression |
other_version`). Also present: `amount_minor`, `premium_included`, `date` (`YYYY-MM-DD`, `YYYY-MM`
or `YYYY`), `venue`, `adjust_ref_year`, `source_urls`.

`log10_x_milli = floor(1000·log10(x) + 0.5)` computed by the pipeline (round half up; ties do not
occur in practice). These two integers are the only values selection and bid scoring compare.

**Game price** of an artwork = the record whose `id == game_price_id`, provided
`game_eligible && type is not an estimate && price_scope != other_version && confidence != low`;
otherwise the artwork has no game price (it is "unpriced").

**Basis** (Part E8): pick-the-price and bid use **nominal** USD; which-is-pricier uses **adjusted** USD.

### 8.3 Category (taxonomy)
`id`, `axis` (`movement | medium`), `era {start, end}`, `parent` (optional), `neighbours[]`,
`confusers[]`, `min_quiz_items`, `active`, `department_id` (optional).
Era gap between categories A and B: `max(0, max(A.start, B.start) − min(A.end, B.end))`.

### 8.4 Departments
`taxonomy.json` → `departments[]`: `{id, label, categories[]}` (plan Part I1: `old_masters`,
`nineteenth_century`, `impressionist_modern`, `asian_art`, `prints_photographs`). An artwork's
department = its own optional `department_id`, else its primary category's `department_id`, else the
first department (id order) whose `categories` lists the primary category; otherwise none.

### 8.5 Game pool
`GamePool(artworks, categories, departments)` sorts all lists by id (§6).
**Quiz-eligible categories** (may be a question's truth): `active` and with at least
`min_quiz_items` artworks in the pool whose **primary** category it is.
**Active categories**: `active` (any may be a distractor). The pool also indexes artworks by
department (sorted by id).

## 9. Picking an artwork for a single-artwork round

Used by pick-the-price, bid, category and swipe rounds.
```
E = eligible artworks not in `used`, in pool order (sorted by id)
loop while E not empty:
    k = nextInt(|E|)
    try to build the round for E[k] (may consume more draws)
    if it succeeds: return it
    remove E[k] from E           (draws consumed by the failed attempt stay consumed)
fail with pool_exhausted
```
**With an onboarding prior** (§17A), `k = WeightedPicker.pick(weights of E)` (§17A.3) instead of
`nextInt(|E|)`; everything else is identical. Without a prior the rule above is unchanged.

Eligibility: pick-the-price — has a game price with `500 ≤ usd_nominal ≤ 2,000,000,000`;
bid — has a game price; category — has a truth category (§11.1); swipe — any artwork.

## 10. Pick the price

Constants: band `[500, 2,000,000,000]`; forbidden distractor values `1,000,000` and
`1,000,000,000`; attempts 8. Step ratios (`num/den`) by difficulty, in this order:
easy `4/1, 5/1, 6/1`; medium `5/2, 3/1, 4/1`; hard `2/1, 5/2`.

**2 significant figures** (`round2`, half up, for `v ≥ 0`): if `v < 100` return `v`; else let
`p = 10^(digits(v) − 2)`; return `((v + p/2) / p)·p`. (1,950,000 → 2,000,000; 1,949,999 → 1,900,000.)

Algorithm for truth price `P` (whole USD, nominal):
```
T = round2(P); if T < 500 or T > 2e9: fail price_out_of_band
repeat 8 times:
    s = nextInt(4)                               # truth slot
    v[s] = T
    for i = s+1 .. 3:   r = steps[nextInt(|steps|)];  v[i] = v[i−1]·r.num / r.den
    for i = s−1 .. 0:   r = steps[nextInt(|steps|)];  v[i] = v[i+1]·r.den / r.num
    v = map(round2, v)                           # every option, truth included
    if valid(v, s): return (v, correctIndex = s, usedFallback = false)
fallback (no draws):
    for s = 0..3, for each step r in list order:
        build as above with every step = r; if valid: return (v, s, usedFallback = true)
fail no_valid_price_options
```
Upward steps are drawn first (from the truth outward), then downward steps.
`valid(v, s)`: every `v[i]` in the band; for `i ≠ s`, `v[i]` is not a forbidden value; for
`i = 1..3`, `v[i−1]·18 ≤ v[i]·10` (adjacent ratio ≥ 1.8×; implies strictly ascending and distinct).
Options are shown ascending (they are built ascending); the answer index is `s`.

## 11. Category quiz

### 11.1 Truth
The first id in the work's category set (§8.1) that is quiz-eligible (§8.5). None → the work is
not eligible (`no_quiz_category`). `accepted` = the category set minus the truth (order kept).

### 11.2 Candidates
**Active** categories (rules v2: they need not be quiz-eligible, so thin categories still teach),
in id order, excluding: the truth; every id in the work's category set;
`medium`-axis categories when the truth's axis is `movement` (a painting never gets "Print");
the truth's parent and the truth's children (`c.parent == truth.id`) **unless difficulty is hard**.

### 11.3 Slots
easy `[era_adjacent, far, far]`; medium `[neighbour, era_adjacent, era_adjacent]`;
hard `[neighbour, neighbour, confuser]`.
- neighbour: `c.id ∈ truth.neighbours` **or** `truth.id ∈ c.neighbours`
- confuser: `c.id ∈ truth.confusers`
- era_adjacent: era gap ≤ 60 years
- far: era gap > 150 years

### 11.4 Algorithm
```
chosen = []
for slot in slots:
    open = candidates not in chosen               (id order)
    if open empty: fail not_enough_distractors
    bucket = open filtered by slot
    src = bucket if non-empty else open
    chosen.append(src[nextInt(|src|)])
s = nextInt(4)
options = chosen ids with the truth inserted at index s
```
Answer: index `s` → correct; an option in `accepted` → alternate (counts as correct, flagged);
otherwise incorrect. (Accepted categories are never offered as distractors, so "alternate" can
only arise from data where the primary category is not quiz-eligible.)

## 12. Bid / estimate

Slider position `p` is clamped to `0..700`. `guessMilli = 2000 + 10·p` ($100 … $1B, 0.01 decade per
step). `actualMilli` = game price `log10_usd_nominal_milli`. `e = |guessMilli − actualMilli|`.

| e (milli-decades) | tier | points |
|---|---|---|
| ≤ 97 | `bullseye` | 100 |
| ≤ 301 | `expert_eye` | 70 |
| ≤ 699 | `good_instinct` | 40 |
| ≤ 1000 | `in_the_room` | 15 |
| otherwise | `off_the_wall` | 0 |

`direction` = `under` if guess < actual, `over` if guess > actual, else `exact`.
Display-only: `factor = 10^(e/1000)` as a double ("You were 3.1× under"). A bid counts as correct
(for streaks) unless it is off the wall. Nearest position for a milli value `m`:
`clamp((m − 2000 + 5) / 10, 0, 700)` for `m ≥ 2000`, else 0.

## 13. Which is pricier? (stacked top/bottom)

Compares game-price `log10_usd_adjusted_milli`. Min gap by difficulty: easy 1000 (10×),
medium 477 (3×), hard 301 (2×); hard also requires the two works to **share a category** (any id
in both category sets). Era window: 60 years (`|year_a − year_b| ≤ 60`; a work without a year fails
the era test) — rounds use it for medium and hard, not easy.

**Passes** (relaxation order: era first, then difficulty). Levels: easy `[(1000,–), (477,–), (301,–)]`;
medium `[(477,–), (301,–)]`; hard `[(301, shared), (301,–)]`. Passes =
`[level0 + era window]` (only if a window is requested) followed by every level without era;
consecutive duplicates removed. The pass index is reported as `relaxation`.

```
eligible = pool artworks with a game price, not in used, not the anchor   (id order)
perm = shuffle([0, 1, …, |eligible|−1])
for each pass (index k):
    examined = 0
    if anchor:  for x in perm:                  candidate (anchor, eligible[x])
    else:       for i < j over perm (row-major): candidate (eligible[perm[i]], eligible[perm[j]])
    each candidate: examined += 1; if examined > 2000: stop this pass
                    if it meets the pass: select it
if none: fail pool_exhausted   (invalid anchor: invalid_anchor)
placement: with an anchor, top = anchor, bottom = challenger (no draw);
           otherwise pricierOnTop = (nextInt(2) == 0)
pricier_side = top if top_milli > bottom_milli else bottom
```
The gap test is `|Δ| ≥ minGap`, so the two milli values always differ.

**With an onboarding prior** that has preferred departments `P` (weight > 1, sorted): each base pass
`p` is replaced by two passes, `[p restricted to departments P, p]`, so the department preference is
the first thing relaxed at every level (order: department, then era, then difficulty). A
department-restricted pass accepts a pair only if both works resolve (§8.4) to the **same**
department and it is in `P` (with an anchor, the anchor's department must qualify). `relaxation`
indexes this expanded list. No preferred departments → base passes.

## 14. Scoring (`Scorer.score(round, answer, streak)`) — pure and total

`streak` = consecutive correct answers in the session **before** this one.
- pick the price: correct → `100 + (streak + 1 ≥ 3 ? 25 : 0)`; wrong → 0.
- which is pricier: correct → 100; wrong → 0.
- category: correct or alternate → 100; incorrect → 0.
- bid: tier points (§12); `is_correct = tier != off_the_wall`.
- swipe: 0 points, `is_correct` absent, `liked` recorded.
- An answer of the wrong kind or an out-of-range index → `{is_correct: false, points: 0}`.

## 15. Sessions and the daily challenge

Session RNG = `SplitMix64(seed)`. All rounds of a session come from this one stream in order, with a
`used` set (every artwork shown so far) so nothing repeats.

| mode | rounds |
|---|---|
| `pick_price` | 3 easy, 4 medium, 3 hard |
| `category` | 3 easy, 4 medium, 3 hard |
| `bid` | 10 medium |
| `swipe` | 20 |
| `daily` | `[pick_price easy, higher_lower medium, category medium, bid medium, pick_price hard]` |
| `higher_lower` | endless, batches of 10 |

Fixed recipes generate every round at creation; any failure fails the session.
**Custom recipe** (`make(mode:recipe:pool:seed:prior:)`): for fixed modes it replaces the default
recipe (an empty or absent recipe = default); for `higher_lower`, round `i` uses
`recipe[min(i, count − 1)].difficulty` instead of the ramp. A **prior** switches single-artwork
picks to weighted sampling (§9) and pairs to department-preferring passes (§13). `daily` ignores both.
**Endless (`higher_lower`)**: difficulty of round `i` = easy (`i < 5`), medium (`i < 15`), hard.
Each batch generates up to 10 rounds; each pair is anchored on the previous round's **pricier**
work (higher-or-lower chaining, independent of the player's answers). A failed round attempt does not
advance the RNG (the attempt runs on a copy) and ends the batch; if a batch adds nothing and no round is
pending, the session ends. The client requests a batch when at most one unanswered round remains.
One wrong answer ends a `higher_lower` run.
Session streak: +1 on correct, reset on incorrect, unchanged on swipes. **Daily sessions score with
streak 0** (max 100 per round, 500 total).

**Daily challenge** = the `daily` recipe from `seed = DailySeed(day, dataset_id, rulesVersion)`.
**Validator**: for each of `days` consecutive days from a start day (730 by default) generate the
challenge and require: no failure, round kinds equal the recipe, no artwork repeated within the day.

## 16. Taste profile (display-only; doubles allowed)

### 16.1 Buckets
Each artwork falls in exactly one bucket of each of 9 families, key `family:value`:
`era:<taste.era_bucket>`, `category:<category_id>`, `subject:<taste.subject>`,
`abstraction:low|mid|high`, `warmth:cool|neutral|warm`, `saturation:muted|mid|vivid`,
`brightness:dark|mid|light`, `complexity:sparse|mid|busy`, `mood:<taste.mood>`.
Scalar features are integers 0…100; level = `0..33 → first`, `34..66 → second`, `67..100 → third`.
Era buckets (from the work's year): `<1500 pre1500`, `<1600 1500_1600`, `<1700 1600_1700`,
`<1800 1700_1800`, `<1850 1800_1850`, `<1900 1850_1900`, else `1900_1930`.
Subjects: `portrait, figure, landscape, still_life, religious_myth, genre, abstract`.
Moods: `serene, dramatic, melancholic, joyful`.

### 16.2 Profile (persisted, integers)
`swipe_count`, `like_count`, `exposures{bucket: S_d}`, `likes{bucket: L_d}`. Applying a swipe adds 1
to `S_d` for each of the work's 9 buckets and to `L_d` too if liked. Undo subtracts the same and
removes keys whose count reaches 0, so apply-then-undo restores the profile exactly.

### 16.3 Lift model
Baseline `p_d = clamp(features[d].p_like, 0.001, 0.999)`, `α = baseline.alpha` (4). For every bucket
with `S_d ≥ 1` that exists in the baseline:
```
a_d = (L_d + α·p_d) / (S_d + α)
ℓ_d = clamp(ln(a_d / p_d), −ln 3, +ln 3)
w_d = S_d / (S_d + α)
c_d = w_d · ℓ_d
DST = sqrt( mean over those d of c_d² )        (0 when there are none)
```
Contributions are ranked by `|c_d|` descending, ties by bucket key (§6); the top ones explain the profile.

### 16.3a Onboarding seeds
`seeded(prior)`: first remove any previous seed (subtract each `seeds[d]` from `S_d` and `L_d`,
dropping zero keys), then for each `prior.seed_buckets` entry add 2 to `S_d` and to `L_d` and record
`seeds[d] = 2`. `swipe_count`/`like_count` are unchanged (seeds are not swipes). Undo never takes a
bucket's `S_d` or `L_d` below `seeds[d]`, so undo never removes seeds. `seeds` is persisted (omitted
when empty).

### 16.4 Display axes and archetype
Each axis is a weighted mean of `c_d` over its loaded buckets with `S_d ≥ 1`, normalised by ln 3:
`axis = clamp( Σ load·c_d / (ln 3 · Σ |load|), −1, 1 )`, 0 if no loaded bucket has exposure.

| axis (− ↔ +) | loadings |
|---|---|
| Era: Old Masters ↔ Modern | `era:pre1500 −1, 1500_1600 −0.75, 1600_1700 −0.5, 1700_1800 −0.25, 1800_1850 +0.25, 1850_1900 +0.75, 1900_1930 +1` |
| Form: Figurative ↔ Abstract | `abstraction:low −1, abstraction:high +1` |
| Palette: Earthy/Muted ↔ Vivid/Luminous | `saturation:muted −1, saturation:vivid +1, brightness:dark −1, brightness:light +1, warmth:warm −0.5, warmth:cool +0.5` |
| Mood: Serene ↔ Dramatic | `mood:serene −1, joyful −0.5, melancholic +0.5, dramatic +1` |

Archetype id = 4 letters from the axis signs (0 counts as +): Era `O`/`M`, Form `F`/`A`,
Palette `E`/`V`, Mood `S`/`D` — e.g. `OFES`. 16 ids; names/copy belong to design.

## 17A. Onboarding prior (integer)

### 17A.1 Answers (`OnboardingAnswers`, every step optional)
`era`: `classic | modern`; `departments`: set of department ids (step 2); `subjects`: set of
`landscape | people | still_life`; `mood`: `serene | dramatic`; `intent`: `learn | play | test_my_eye`.
JSON: sets are arrays (sorted when written).

### 17A.2 `TastePrior.from(answers)` (pure)
- Preferred departments `P` = `departments` if non-empty, else by era: classic →
  `old_masters, nineteenth_century`; modern → `impressionist_modern`; none → empty.
  `department_weights = {d: 3 for d in P}`; any department not listed weighs **1** (never 0).
- `subject_weights`: each chosen subject's taste subjects → 3 (landscape → `landscape`; people →
  `portrait, figure, genre`; still_life → `still_life`); others 1.
- `mood_weights`: serene → `serene, joyful`; dramatic → `dramatic, melancholic` → 3; others 1.
- intent → (`default_difficulty`, `highlighted_mode`): learn → (easy, category); play or none →
  (medium, pick_price); test_my_eye → (hard, bid).
- `seed_buckets` (sorted, §6): `era:<b>` for the typical era buckets of each preferred department
  (old_masters `pre1500, 1500_1600, 1600_1700, 1700_1800`; nineteenth_century `1800_1850, 1850_1900`;
  impressionist_modern `1850_1900, 1900_1930`; asian_art and prints_photographs none), plus
  `subject:<s>` for every weighted subject and `mood:<m>` for every weighted mood.
- Stored weights ≤ 0 are read as 1.

### 17A.3 Artwork weight and weighted pick
`weight(artwork) = department_weight(dept(artwork)) + subject_weight(taste.subject) +
mood_weight(taste.mood)` — an integer in 3…9 (**additive**: a full match is 3× a non-match).
Departments without a typical era (asian_art, prints_photographs) contribute no era seeds; every
other standard department has at least one (unit-tested).
`WeightedPicker.pick(weights)`: `total = Σ max(w, 0)`; if `total == 0` return none **without drawing**;
else `r = nextInt(total)` and return the first index `i` with `w_i > 0` and
`r < Σ_{j ≤ i, w_j > 0} w_j`. Zero or negative weights are never returned.

## 17. Rarity (display-only)

Baseline JSON (`taste_baseline.json`):
```
{ "schema_version": 1, "baseline_id": "…", "alpha": 4,
  "features": { "<bucket>": { "p_like": 0.42, "n": 5000 }, … },
  "distinctiveness_percentiles": { "swipes_10": {"p50","p75","p90","p95","p99"}, "swipes_20": …,
                                    "swipes_40": …, "swipes_80": … },
  "archetype_shares": { "OFES": 0.07, … } }
```
- Visibility: `< 12` swipes `hidden`; `12…39` `band`; `≥ 40` `exact`.
- Bucket: the `swipes_N` with the smallest `|N − swipe_count|` (ties → smaller N).
- Percentile: linear interpolation of DST through `(0,0), (p50,50), (p75,75), (p90,90), (p95,95),
  (p99,99)`; `DST ≤ 0 → 0`; `DST > p99 → 99`; a zero-width segment yields its upper percentile.
- Band: `[0,50) [50,75) [75,90) [90,95) [95,99) [99,100]` containing the percentile.
- Archetype share = `archetype_shares[id]` ("about X% share your archetype");
  edition number = `clamp(round(share·100), 1, 100)` ("Edition N / 100").
All rarity copy is labelled "estimated".

## 18. Price display (pure string building)

`compact(usd)`: `r = round2(usd)`; unit/suffix chosen **after** rounding: `r ≥ 1e9 → B`,
`≥ 1e6 → M`, `≥ 1e3 → K`, else none; `whole = r / unit`, `tenth = (r % unit)·10 / unit`;
text `"$" + whole + (tenth ≠ 0 ? "." + tenth : "") + suffix` — `$450M`, `$2.8M`, `$57K`, `$850`, `$1B`.
Markers: prefix `~` for reported private sales, else `≈` when approximate; suffix `+` for lower
bounds (`~$250M+`). For a record: reported = `type == private_sale`; approximate =
`approximate || currency != "USD" || basis == adjusted`.

## 19. JSON encodings shared with Android

- Enums are snake_case strings: `GameMode` `pick_price | higher_lower | category | bid | swipe | daily`;
  `Difficulty` `easy | medium | hard`; `PricierSide` `top | bottom`; `BidTier` as in §12.
- `Round`: `{"kind": "<round kind>", "payload": {…}}` with payloads
  `pick_price {artwork, price_id, options[4], correct_index, difficulty}`,
  `higher_lower {top, bottom, top_milli, bottom_milli, pricier_side, relaxation, difficulty}`,
  `category {artwork, options[4], correct_index, accepted[], difficulty}`,
  `bid {artwork, price_id, actual_milli, actual_usd}`, `swipe {artwork}`.
- `Answer`: `{"kind": "pick_price", "index": n}`, `{"kind": "higher_lower", "side": "top"}`,
  `{"kind": "category", "index": n}`, `{"kind": "bid", "position": p}`, `{"kind": "swipe", "liked": b}`.
- `RoundOutcome`: `{is_correct?, points, bid_tier?, error_milli?, category_match?, liked?}`.
- Dictionaries keyed by an enum (e.g. `stats` by `GameMode`) are JSON objects keyed by the raw value.
- `DayKey` encodes as the string `yyyy-MM-dd`.
- Optional fields are **omitted** when absent (not written as `null`).

## 20. Fixture contract (`spec/fixtures/*.json`)

Every file: `{"description": "…", "cases": [{"name": "…", "input": {…}, "expected": {…}}]}`.
64-bit unsigned values (seeds, PRNG outputs, states, hashes) are **decimal strings**. Absent keys mean
null. Doubles are compared within the `tolerance` / `factor_tolerance` given in the case.
`*_state_after` is the RNG state after the operation and must match exactly. Error cases give
`expected.error` as one of `price_out_of_band, no_valid_price_options, pool_exhausted,
no_quiz_category, not_enough_distractors, invalid_anchor`.

| file | input → expected |
|---|---|
| `prng.json` | `{seed, count, bound?}` → `{values[], state_after}` (`next()` or `nextInt(bound)`) |
| `shuffle.json` | `{seed, n}` shuffle `[0..n)` → `{permutation, state_after}` |
| `fnv.json` | `{text}` → `{hash, hash_hex}` |
| `daykey.json` | `{year, month, day}` → `{valid, day_number?, iso?}` |
| `streak.json` | `{streak, last_day?, today}` → `{streak, last_day?}` |
| `daily.json` | `{day, dataset_version, rules_version}` → `{seed_string, seed, rounds[]}` |
| `distractors.json` | `{truth_usd, difficulty, seed}` → `{options?, correct_index?, used_fallback?, error?, state_after}` |
| `bid_score.json` | `{position, actual_milli}` → `{guess_milli, error_milli, tier, points, direction, factor, factor_tolerance}` |
| `pairs.json` | `{difficulty, year_window?, used[], anchor?, seed}` → `{round?, error?, state_after}` |
| `category.json` | `{artwork_id, difficulty, seed}` → `{round?, error?, state_after}` |
| `taste.json` | `{swipes[{artwork_id, liked}], undo_last}` → `{profile, distinctiveness, axes, archetype_id, top_buckets, tolerance}` |
| `rarity.json` | `{distinctiveness, swipe_count, archetype_id}` → `{visibility, swipe_bucket?, percentile, band, archetype_share?, edition_number?, tolerance}` |
| `price_format.json` | `{usd, approximate, reported, lower_bound}` → `{rounded, compact, text}` |
| `weighted_pick.json` | `{weights[], seed, count}` → `{picks[]?, state_after}` (`picks` absent when the total is 0) |
| `prior.json` | `{answers, mode, recipe?, seed}` → `{prior, seeded_profile, rounds[]}` (`make(mode:recipe:pool:seed:prior:)`; first batch for higher_lower) |

`daily`, `pairs`, `category`, `taste`, `rarity` and `prior` run against `mini_dataset.json`:
`{schema_version, dataset_id, description, artworks[30], taxonomy[14], departments[5], taste_baseline}`
(every category except the inactive sculpture carries `department_id`; rococo has `min_quiz_items` 3
with 2 works, so it is active but not quiz-eligible) — a frozen,
synthetic dataset (real public-domain titles, approximate prices, fake image files) in the same field
names as the shipping files. Its `dataset_id` (`mini-2026.10`) is the daily `datasetVersion`.

Regenerate with `make fixtures` (`swift run --package-path Packages/ArtCore FixtureGen spec/fixtures`)
and review the diff. Generation is idempotent. Fixtures change only when a rule changes; a rule
change that alters daily output must bump `dailyRulesVersion`.

## 21. Porting to Kotlin

- SplitMix64 state and outputs: `ULong`. `ushr` for `>>>`; `*`, `+` on `ULong` wrap.
  `nextInt`: `val b = bound.toULong(); val t = (0UL - b) % b` (ULong `%` is unsigned).
  `bound` itself fits in `Long` (≤ 2^63 − 1); return `(r % b).toLong()` (or `.toInt()` when the bound
  is an `Int`).
- FNV-1a: `ULong`, bytes from `text.encodeToByteArray()`, each byte `toUByte().toULong()`
  (do **not** sign-extend).
- Parse fixture decimal strings with `toULong()`; never route 64-bit values through `Double` or a
  JSON number type.
- Prices and products: `Long` (`v·num` reaches ~4·10^11). Day numbers: `Int` or `Long`.
- Weighted-pick totals: `Long` (sum of weights; artwork weights ≤ 9 each, fixtures include ~10^12 totals).
- Sets in `OnboardingAnswers` serialise as arrays; order is irrelevant on read.
- Integer division/remainder truncate toward zero exactly like Swift; Hinnant's formulas rely on that.
- String ordering for sorts: compare `encodeToByteArray()` lexicographically as **unsigned** bytes.
- Never use `kotlin.random`, `Collection.shuffled()`, `Random.nextInt` or `Math` in selection or
  scoring. `kotlin.math.ln/exp/sqrt/pow` are fine for display-only values (taste, rarity, factor);
  their fixtures carry tolerances (1e-9 absolute for taste, ±0.5 for rarity percentile).
- Dictionary iteration order differs between platforms: the taste model sums over buckets sorted
  by key (§16.3) — keep that so results agree to the last bits where possible.
- Round-trip every fixture type with kotlinx.serialization using the snake_case names in §19/§20,
  `explicitNulls = false`, `ignoreUnknownKeys = true` for dataset files.

## 22. Constants

| constant | value |
|---|---|
| SplitMix64 gamma / mix | `0x9E3779B97F4A7C15` / `0xBF58476D1CE4E5B9`, `0x94D049BB133111EB`; shifts 30, 27, 31 |
| FNV offset / prime | `0xCBF29CE484222325` / `0x100000001B3` |
| price band | 500 … 2,000,000,000; forbidden distractors 1,000,000 and 1,000,000,000 |
| adjacent option ratio | `a·18 ≤ b·10` |
| price attempts | 8 |
| pair gaps | easy 1000, medium 477, hard 301; candidate cap 2000; era window 60 |
| category era | adjacent ≤ 60, far > 150 |
| bid | `2000 + 10p`, p ∈ 0…700; tiers 97 / 301 / 699 / 1000 → 100 / 70 / 40 / 15 / 0 |
| pick bonus | +25 from the 3rd consecutive correct (not in daily) |
| endless batch | 10 |
| taste | α from baseline (4), lift clamp ln 3, tercile cut 33/66 |
| rarity | hidden < 12, band < 40; buckets 10/20/40/80 |
| daily rules version | 2 |
| prior weights | preferred 3, default 1; artwork weight = sum (3…9); seed pseudo-counts S = L = 2 |
