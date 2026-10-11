# AGENTS.md — working agreement for everyone (human or AI) building this app

Plan of record: ~/.claude/plans/velvet-churning-wind.md (approved 11 Oct 2026). Read it before changing scope.

## What this is
An elegant iPhone game (SwiftUI, iOS 18+) where players estimate what artworks cost.
Six modes: pick the price, which is pricier, category quiz, swipe → taste profile, bid/estimate, daily challenge.
Offline-first MVP, bundled public-domain dataset, no accounts, no monetization. Android port later.

## Layout
- `spec/`            platform-neutral contract: game-logic.md, dataset.schema.json, fixtures/*.json
- `Packages/ArtCore` pure logic, stdlib only, NO `import Foundation`; `swift test` runs on macOS
- `Packages/ArtData` Foundation; dataset loading/validation, profile store, day provider, settings
- `Packages/ArtDesign` SwiftUI/UIKit/ImageIO; tokens, typography, glass wrapper, components, share cards
- `App/`             app target, one folder per feature under `App/Features/`
- `Resources/`       dataset.json, taxonomy.json, taste_baseline.json, credits.json, Artworks/*.heic
- `tools/`           Python dataset pipeline (curation CSV → validated JSON + images)
- `Design/`          Tokens.json (W3C DTCG) and fonts; `design-system/<slug>/MASTER.md` from the UI UX Pro Max skill

## Rules
1. Game selection and scoring are integer-only and deterministic (SplitMix64, explicit Fisher–Yates, precomputed `log10_*_milli`). Never use Swift's `shuffled(using:)` or `Int.random(in:using:)`. Every engine has a fixture in `spec/fixtures/`; fixtures change only via `make fixtures` with a reviewed diff.
2. Taste/rarity is display-only and may use Double; fixtures tolerate ±0.5 percentile.
3. ArtCore has no Foundation. Domain types are `Codable, Sendable, Equatable` value types. JSON is snake_case with explicit CodingKeys.
4. UI: tokens only (no raw hex/magic numbers), SF Symbols not emoji, glass only on static floating controls via `artGlass`, never over artwork or in share cards. Every gesture has a button alternative. Respect Reduce Motion / Transparency / Dynamic Type to AX5.
5. Every price shown is "approx." with sale year and source. No real-money language. Images carry licence + attribution.
6. Swift 6 language mode. App + ArtDesign default to MainActor isolation; ArtCore/ArtData are nonisolated.
7. Before claiming done: build + tests green with the commands below; snapshot/UI tests on both iOS 18 and the current iOS simulator when Xcode is present.

## Commands
```bash
make setup                 # brew deps, python venv, skill check
make test-core          # swift test for a package (adds CLT flags when Xcode is absent)
make test-design
make project               # xcodegen generate
make build                 # xcodebuild build (ArtCI-26); DerivedData lives in ~/Library/Developer/ArtPrice (TCC hang under ~/Documents)
make build-18              # same on ArtCI-18 (destination must pin OS=18.6)
make ui-test               # UI smoke plan on both simulators
make shots                 # boot ArtCI-26, install, launch, capture screenshots
make test                  # Unit test plan
make dataset               # tools/build_dataset.py → Resources/
make assets                # JPEG masters → HEIC bundle
make fixtures              # regenerate spec/fixtures (review the diff!)
```
