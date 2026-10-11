# App target (`ArtPrice`)

SwiftUI app shell + feature folders on top of the three local packages
(`ArtCore` rules, `ArtData` storage/dataset, `ArtDesign` tokens and components).
The Xcode project is generated from `/project.yml` (`make project`); never edit `ArtPrice.xcodeproj`.

## Wiring

```
ArtPriceApp ─ AppBoot ─ AppServices(env: AppEnvironment.live())
                          ├─ env: AppEnvironment   (struct of protocol existentials, @Entry var app)
                          ├─ Router                (@Observable: root path, session cover, profile sheet)
                          ├─ SettingsModel         (@Observable over SettingsStoring)
                          ├─ ProfileModel          (@Observable over ProfileStoring; serial write chain)
                          └─ DayModel              (@Observable "today" from DayProviding)
AppRoot ─ RootView ─ NavigationStack(HomeView)
                   ├─ fullScreenCover(item: router.session) → SessionContainer → <Mode>View
                   └─ sheet(router.isProfilePresented)      → ProfileSheet → CreditsView
```

* `AppEnvironment` (Core/AppEnvironment.swift) is the **only** place live implementations are chosen:
  `BundledDataset(bundle: .main)`, `FileProfileStore` in *Application Support/ArtPrice*,
  `UserDefaultsSettingsStore`, `LaunchOptions.dayProvider` (system or fixed day),
  `ImageLoader.shared`, `HapticsPolicy`, `SeedPolicy`. `.preview` uses in-memory stores, a fixed
  day (2026-10-12) and fixed seeds; unit tests and snapshots use it (the test host is the app).
* Haptics: `AppRoot` sets ArtDesign's `\.hapticsEnabled` from `HapticsPolicy.isEnabled(settings)`.
  Appearance: `Settings.appearance == .dark` forces dark, otherwise the system decides.
* Scene phase: background → `ProfileModel.flush()` (drains queued writes, then `store.flush()`);
  active and `.NSCalendarDayChanged` → `DayModel.refresh()`.
* DEBUG builds run `DatasetValidator.validate(bundle: .main)` in a background task at launch
  (skipped with `-uiTesting`) and log a three-line summary under `com.artprice.app / dataset`.

## Launch arguments

| Argument | Effect |
|---|---|
| `-uiTesting` | In-memory profile and settings stores; fixed per-mode session seeds. |
| `-fixedDay yyyy-MM-dd` | Pins "today" (`FixedDayProvider`). |
| `-resetState` | Deletes *Application Support/ArtPrice* and the settings keys before launch. |
| `-startMode <raw>` | DEBUG only: opens a session at launch (`pick_price`, `bid`, `higher_lower`). |
| `-autoAnswer` | DEBUG only: answers the first round after 1.5 s (for reveal screenshots); the daily plays through to its result. |
| `-onboarded` | DEBUG + `-uiTesting`: start with the questionnaire already done. |

UI tests launch with `-uiTesting -fixedDay 2026-10-12 -resetState` (+ `-onboarded` except the onboarding test).

## Onboarding, prior and difficulty

* `OnboardingGate` (on the root stack) presents `OnboardingView` full-screen while
  `profile.hasOnboarded == false`. Five steps from `dataset.onboarding`; step 2 is filtered by the
  era picked in step 1. "Skip" finishes with the answers so far. Completion and "Redo questionnaire"
  go through `ProfileModel.completeOnboarding/resetOnboarding` → `OnboardingService`.
* Every standalone session is dealt from a `SessionContext`: seed (`SeedPolicy`), `prior`
  (`profile.prior`) and difficulty = Settings choice ?? `prior.defaultDifficulty` ?? spec ramp.
  The difficulty override lives in `PreferenceStoring` (UserDefaults key `artprice.app.difficulty`).
* Home outlines `prior.highlightedMode`'s tile in gilt.

## Daily challenge

`DailyHubCard` shows Play today / done-with-score + Practice. `DailyModel` wraps
`DailyService.today(provider:dataset:profile:)`; each round opens with an intro card and reuses the
mode's answer component (`PickAnswers`, `PricierPair`, `CategoryAnswers`, `BidAnswers`). Completion
calls `ProfileModel.recordDailyCompletion` unless the day was already completed (practice).

## Commands

```bash
make project            # xcodegen generate
make build              # ArtCI-26
make build-18           # ArtCI-18 (iOS 18.6; the OS must be pinned in the destination)
make test               # Unit test plan: model tests + snapshots (snapshots run on iOS 26 only)
make ui-test            # UI test plan on ArtCI-26 and ArtCI-18
make run ARGS="-uiTesting -fixedDay 2026-10-12"
make shots SHOTS=/path  # light PNGs: onboarding, home, pick/bid/pricier/category question+reveal, daily intro+result
make shots-dark SHOTS=/path   # same in dark, into /path-dark (restores light afterwards)
```

DerivedData lives in `~/Library/Developer/ArtPrice/DerivedData` (see the Makefile note): with it
under `~/Documents`, a simulator process blocks on a TCC-protected rpath at launch.

Snapshots: `Tests/ArtPriceTests/__Snapshots__`, recorded on ArtCI-26 with `record: .missing`
(a missing reference is written and that run fails once). To re-record after an intended UI change,
temporarily switch the suite trait to `.snapshots(record: .failed)`, run `make test` once, switch back.

## Folders

```
App/
  ArtPriceApp.swift
  Core/      AppEnvironment, AppServices, AppRoot/RootView, Router, DebugLaunch, Previews
  State/     SettingsModel, ProfileModel, DayModel
  Shared/    SessionStage (fixed art zone + thumb-zone answers), PhaseLayers, SessionBottomBar,
             ArtworkImage (+ prefetch), ArtworkDetail (focus crop), PriceCopy, ProvenanceLine + ⓘ sheet,
             Layout (PendingTokens: values awaiting design tokens)
  Features/
    Home/     HomeView, HomeContent (pure), DailyCard/ModeTile/ModeGrid
    Session/  PlaySession, SessionContainer/SessionScreen, SessionChrome, SessionSummary, ShareCardFactory
    PickPrice/ Bid/ Pricier/ Category/   <Mode>Model (@Observable) + <Mode>View + reusable answer zone
    Daily/      DailyModel, DailyView (intro + rounds), DailyResultView, DailyHubCard
    Onboarding/ OnboardingModel, OnboardingView, OnboardingGate
    Profile/  ProfileSheet, CreditsView, Credits (credits.json + dataset disclaimer)
```

## Adding a mode

1. ArtCore must already generate and score the mode (`GameSession.recipe(for:)`, `Scorer`).
2. Create `Features/<Mode>/<Mode>Model.swift`: an `@Observable final class` with
   `init(context: SessionContext) throws` that wraps `PlaySession(game: context.makeSession(mode))`,
   owns a `HammerRevealDriver`, and on
   each answer calls `profile.recordRound(of:at:)` (and `recordSession` when the session ends).
   Expose `summary() -> SessionSummary`.
3. Create `<Mode>View(model:actions:)`: `SessionTopBar` + `SessionStage { ArtworkZone } answers: { … }`
   with both phases in `PhaseLayers` (fixed geometry); put the answer zone in its own struct so the
   daily can reuse it. Start the reveal with `model.reveal.start(isHit:reduceMotion:announcement:)`;
   the `session.next` button (`.secondary`) sits in `SessionBottomBar` and appears at
   `reveal.phase >= .next`; show `SessionSummaryView` when `play.isOver`. Prefetch `upcomingArtworks`.
4. Add a `case` to `SessionContainer.content` and flip `isAvailable` on its tile in `HomeContent.tiles`.
5. Add model tests (seeded determinism, scoring, persistence via `InMemoryProfileStore`) and a
   UI smoke test with accessibility identifiers.

Rules (AGENTS.md): tokens only, SF Symbols only, no glass over artwork, one primary CTA per screen,
every price approximate with year and source, no real-money language.
