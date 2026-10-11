# tools/ — ArtPrice dataset pipeline

Turns a hand-curated sheet (`curation/works.csv`) into the app's bundled data:
`Resources/dataset.json`, `taxonomy.json`, `credits.json`, `CREDITS.md`, `taste_baseline.json`,
`onboarding.json`, the HEIC images in `Resources/Artworks/`, and a contact sheet at `tools/out/report.html`.

Python 3.13 venv in `tools/.venv` (`make setup`). Only `requests`, `Pillow`, `jsonschema`.

## Run

```bash
make setup                                   # venv + requirements
make dataset                                 # build_dataset.py --csv tools/curation/works.csv --out Resources
make assets                                  # make_assets.py: JPEG masters -> HEIC bundle, patches bytes, re-validates
tools/.venv/bin/python tools/gen_baseline.py # Resources/taste_baseline.json (seeded; rerun after dataset changes)
```

Useful flags for `build_dataset.py`:

| flag | effect |
|---|---|
| `--only <work_key>` | build one row (does not write Resources/) |
| `--limit N` | first N rows (does not write Resources/) |
| `--offline` | never touch the network; a cache miss is an error |
| `--strict` | coverage targets (≥ `min_quiz_items` works per active category, ≥ 10 priced works per decade $10K–$100M) become errors |
| `--reverify` | re-check every price source |

Exit code 0 = no validator errors. Warnings (missing sign-off, coverage, small source images) do not fail.

Everything fetched is cached under `tools/cache/<host>/<sha256(url)>` (gitignored), and per-image
processing under `tools/out/work_cache/`, so a fully cached rerun takes a few seconds. Delete a
cache file to force a refetch. Rate limits: Met ≤ 3 req/s, AIC 1 req/s with `AIC-User-Agent`
(contact from env `AIC_CONTACT`, placeholder `TODO_OWNER_EMAIL`), Wikidata SPARQL 1 req/s; 5xx,
429 and timeouts back off exponentially.

## Stages (Part E9)

1. **load_csv** — `artpipe/csvload.py`
2. **resolve_metadata** — `artpipe/sources.py` (Met, AIC, CMA, Rijksmuseum Linked Art, Commons
   imageinfo at the 1920 px bucket; refuses non-PD/CC0), `artpipe/wikidata.py` (work → creator →
   birth/death, inception cross-check; prices in both P2284 patterns)
3. **download** — largest allowed rendition, sha256 recorded
4. **process_images** — EXIF transpose, ICC → sRGB, LANCZOS to 1600 and 600 px long edge, never
   upscale, JPEG q85 progressive, metadata stripped → `tools/out/images/{id}_lg.jpg|_sm.jpg`
5. **palette_features** — 64×64 HSV: warmth, saturation, brightness; edge density (complexity,
   dataset percentile); median-cut 5-colour palette, dominant hex
6. **derive** — `artpipe/derive.py`: FX (`curation/fx_annual.csv`), CPI-U to 2025
   (`curation/cpi_u_annual.csv`), `usd_nominal`, `usd_adjusted`,
   `log10_usd_*_milli = floor(1000·log10(x) + 0.5)`, era bucket, PD rule
7. **validate** — `artpipe/validate.py`: `spec/dataset.schema.json` + the E9 checklist
8. **emit** — `artpipe/emit.py`

Price verification (`verify_prices.py`, run automatically for new/changed prices): fetches every
`source_url_*` (cached; `https://web.archive.org/web/2024/<url>` works for paywalled or JS pages)
and looks for the amount (e.g. `450,312,500`, `450.3 million`, `$450m`, `183,8 Millionen`) within
700 characters of the artist's or title's name. A `wikidata_price` QID counts when a matching
P2284 statement carries a reference. Results go to `curation/price_checks.json`. **An unverified
price is demoted to `confidence: low, game_eligible: false`** — never invent or hand-wave a price.

## Adding a work

1. Find the image: Met (`collectionapi.metmuseum.org/public/collection/v1.1/search?q=…`, object id
   in the URL `metmuseum.org/art/collection/search/<id>`), AIC (`artic.edu/artworks/<id>`), CMA
   (`clevelandart.org/art/<accession>` → API id), Rijksmuseum (object number e.g. `SK-A-5092`), or
   a Commons file name (`File:` prefix optional). Prefer museum CC0 over Commons. A Commons file
   whose Credit is an auction house is allowed; attribution becomes
   "Photo via Wikimedia Commons (PD-Art); source: <Credit>".
2. Find the price: a primary report (auction house results page, major newspaper) or a Wikidata
   P2284 statement with a reference. Note type (auction_premium / auction_hammer / private_sale…),
   whether the premium is included, and whether the sold object is this object, another impression
   of the same print (`same_edition_other_impression`) or another version (`other_version`, never
   game-eligible).
3. Add a row to `curation/works.csv`:

| column | meaning |
|---|---|
| `work_key` | stable slug, becomes `id` (`artist-short-title`) |
| `kind` | `pd_masterpiece` |
| `title`, `title_alt` | display title, optional original-language title |
| `artist`, `nationality`, `artist_wikidata` | display name; adjective; optional QID (else from the work's P170) |
| `date_display`, `date_start`, `date_end`, `circa` | e.g. `c. 1665–67`, 1665, 1667, y |
| `category_id`, `secondary_categories` | taxonomy ids; secondaries `;`-separated |
| `medium`, `medium_class` | display text; painting / drawing / works_on_paper / print / photograph / ink_painting |
| `holder` | optional current owner |
| `price_amount`, `price_currency` | amount in major units as reported (e.g. `2310000`, `GBP`) |
| `price_type`, `premium_included`, `approximate`, `lower_bound` | enum; y/n flags |
| `price_date`, `price_venue`, `price_lot` | `YYYY-MM-DD`, `YYYY-MM` or `YYYY` |
| `price_scope` | this_object / same_edition_other_impression / other_version |
| `source_url_1..3` | pages that state the price |
| `wikidata_price` | QID whose P2284 statement backs the price (optional) |
| `confidence`, `game_eligible` | high/medium/low; y/n (demoted automatically if unverified) |
| `image_pref` + one of `met_id`, `aic_id`, `cma_id`, `rijks_id`, `commons_file` | image source |
| `wikidata_qid` | the work's QID (cross-checks and artist facts) |
| `subject`, `abstraction`, `mood` | curated taste fields (`abstraction` 0–100) |
| `focus_x`, `focus_y` | crop focus, permille (default 500/450) |
| `alt_text`, `teaser` | written by us — never copy Wikipedia or museum descriptions |
| `pd_override` | reason text to bypass the PD rule (rare; reviewed) |
| `notes` | curator notes (not shipped) |

4. `make dataset`, open `tools/out/report.html`, check the image and numbers, then record approval
   in `curation/signoff.json` as `{"<id>": "<image sha256>"}` (shown on the sheet).
5. `make assets`, then `gen_baseline.py`.

PD rule (Part E2): author died ≤ 1955 and work dated ≤ 1930; Picasso, Pollock, Rothko, Bacon,
Warhol, Basquiat, Hopper, Magritte, Qi Baishi and Kahlo are excluded.

## Taxonomy, departments and onboarding

`artpipe/taxonomy.py` holds the categories (original teaching copy), the five departments of plan
Part I1 and `MIN_QUIZ_V0 = 4`. **`min_quiz_items` is 4 as a v0 setting** for the 91-work dataset
(Part I4); the v1 target is 8 (`MIN_QUIZ_V1_TARGET`) — raise `MIN_QUIZ` when the dataset grows.
Every artwork carries `department_id` derived from its primary category. The validator checks that
the departments cover every active category exactly once.

`artpipe/onboarding.py` holds the curated exemplars for each questionnaire choice. The validator
checks that every id exists, its HEIC files are present, and it really fits the choice (department,
category group, subject or mood). Swap exemplars there if an image is dropped or replaced.

## Reference data

`fetch_reference_data.py` rebuilds `curation/fx_annual.csv` (FRED H.10 monthly → annual mean;
ECB for PLN/CZK; official sterling parities before 1971) and `curation/cpi_u_annual.csv`
(BLS CPI-U via FRED; Minneapolis Fed before 1913). Partial years (e.g. 2026, and 2025 which lacks
the October 2025 CPI release) are flagged and surface as validator warnings on affected prices.

## Outputs

| file | what it is |
|---|---|
| `Resources/dataset.json` | all artworks; priced pool = works with `game_price_id`, unpriced pool = `game_price_id: null` |
| `Resources/taxonomy.json` | `departments` (5, Part I1) + 26 active categories (20 movements, 6 media, each with `department_id`) + inactive sculpture (`department_id: null`) |
| `Resources/onboarding.json` | questionnaire exemplars: 2–3 artwork ids + caption per choice (Part I2; schema `spec/onboarding.schema.json`) |
| `Resources/credits.json`, `CREDITS.md` | image licences/attributions, price sources, data sources, disclaimer |
| `tools/out/report.html` | contact sheet + validator report for curator sign-off (not shipped) |
| `Resources/Artworks/*.heic` | priced: `{id}_full.heic` 1440 px + `{id}_thumb.heic` 480 px; unpriced: `{id}_card.heic` 1080 px + thumb |
| `Resources/taste_baseline.json` | synthetic rarity prior (spec §17) |
| `tools/out/` | JPEG masters and caches (gitignored) |

## Known environment quirk (Homebrew Python 3.13 on this Mac)

`/opt/homebrew/bin/python3.13` loads an older `/usr/lib/libexpat`, so `platform.mac_ver()` returns
an empty string and `pip` crashes inside a fresh venv. The venv at `tools/.venv` carries a local
workaround (`site-packages/_macver_fix.py` + a `.pth` file, and `pip.conf` with
`use-deprecated=legacy-certs`). If you delete and recreate the venv, recreate those files or
install with `uv pip install -r tools/requirements.txt`. A `brew reinstall python@3.13` may also
fix the underlying library mismatch; verify with
`python3.13 -c "import platform; print(platform.mac_ver())"`.

## Contact sheet
`make dataset` writes `tools/out/report.html` (not shipped). Open it, review every image against its
title, and record approvals in `tools/curation/signoff.json` to clear the "not signed off" warnings.
