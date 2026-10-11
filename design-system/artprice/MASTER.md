# ArtPrice design system: MASTER ("Salon Noir")

> **How to use:** read this file before building any screen. If `design-system/artprice/pages/<page>.md`
> exists, its rules override this file for that page. There are no page overrides yet, because the
> generator produced none.
>
> **Sources of truth, in order:** the approved plan (`~/.claude/plans/velvet-churning-wind.md`,
> Parts C and D), then `Design/Tokens.json`, then this file. The UI UX Pro Max generator output is
> merged below. Where it disagreed with Part C, Part C wins; every deviation is listed in
> "Generator reconciliation".

Project: ArtPrice (working title; "Going Once" is the design lead's pick). Category: Museum/Gallery
blended with Dark-Mode entertainment. Platform: native SwiftUI, iPhone, iOS 18+, Liquid Glass on iOS 26+.

---

## 1. Direction

You are alone in a museum after hours. The walls are warm near-black and each artwork is lit as if
under a picture light. **Gilt is used only where value is involved** (prices, scores, streaks, the one
primary CTA). Appearance follows the system. Dark is the primary design, and light ("Day Salon") gets
equal care. From White Cube the system borrows restraint: a strict 8pt grid, one accent and SF-heavy
UI. From Lot & Ledger it borrows auction vocabulary: "Lot 3 of 10", "hammer", "approx.", and a gavel
haptic.

## 2. Tokens (never use raw values in components)

Swift: `import ArtDesign`, then use `Tokens.*`. The generated file is `Packages/ArtDesign/Sources/ArtDesign/Generated/Tokens.swift`.

### Colour (`Tokens.Color.*`)
| Token | Dark | Light | Use |
|---|---|---|---|
| `bgCanvas` | #0E0D0C | #F6F2EA | screen background |
| `bgSurface` | #1A1816 | #FFFFFF | cards, sheets |
| `bgElevated` | #24211E | #EFE9DE | controls; Reduce Transparency fallback |
| `bgMat` | #E9E2D6 | #FFFFFF | 2pt artwork mat (non-text) |
| `textPrimary` | #F4EFE6 | #1A1714 | text |
| `textSecondary` | #B8B0A3 | #5C554C | supporting text, provenance |
| `textOnGilt` | #0E0D0C | #FFFFFF | on gilt |
| `accentGilt` | #C9A55C | #7A5C14 | value only, ≤ ~5% of pixels |
| `feedbackHit` | #7FCB9B | #2B734A | correct (always with icon + word) |
| `feedbackMiss` | #E8846A | #B04429 | miss (always with icon + word) |
| `lineHairline` | #F4EFE6 @12% | #1A1714 @10% | 0.5pt separators, glass fallback stroke |
| `lineShadow` | #000 @45% | #000 @18% | artwork shadow only |

Every text/background pair is at least 4.5:1 in both modes, and this is verified by tests. The lowest
pair is light `feedbackMiss` on `bgElevated` at 4.69. The full table is in `Tokens.json → meta.contrast_pairs`.

### Type (`.artTextStyle(Tokens.Typography.*)` preferred; `ArtFont.*` for plain `Font`)
| Style | Face | Size / weight | Scales with |
|---|---|---|---|
| `displayXL` | Fraunces, opsz 72, SOFT 50 | 40 / 500 | largeTitle |
| `displayL` | Fraunces | 28 / 500 | title |
| `titleArt` | Fraunces Italic | 22 / 400 | title2 |
| `priceHero` | SF Pro, monospaced digits | 48 / 600 | largeTitle |
| `body` | SF Pro | 17 / 400 | body |
| `label` | SF Pro | 15 / 500 | subheadline |
| `provenance` | SF Pro, small caps | 13 / 400 | footnote |

For prices, add `.contentTransition(.numericText(value:))`. Never truncate a price. Never use gradient text.

### Space, radius, size
- Space `Tokens.Space`: xxs 2, xs 4, s 8, m 12, l 16, xl 24, xxl 32, xxxl 48.
- Radius `Tokens.Radius`: control 14, card 20, sheet 28, pill 999. Always use `style: .continuous`. Images have **no** radius.
- Size `Tokens.Size`: minTarget 44, answerButton 56, swipeButton 64, artMaxHeightRatio 0.62, artMinHeightRatio 0.35, matWidth 2, hairline 0.5, share card 360×450 @3.
- Layout `Tokens.Layout`: artworkHeightFraction 0.58, heroArtworkFraction 0.55, pricierFrameFraction 0.42, winnerLift 1.02, disabledTileOpacity 0.6, onboardingEraFraction 0.30, onboardingTileFraction 0.18, tileDetailAspect 1.6, clueZoom 1.6, bracketLabelMaxRows 2.
- Elevation: `Tokens.Elevation.artwork` (y 12, blur 32), applied with `.artShadow(_:)`. **Only artworks cast shadows.**

### Motion (`Tokens.Motion`, `ArtMotion`)
"Slow in, decisive settle, like a gavel." Entrances ease out over 350–500ms. Reveals use the settle
spring 0.45/0.82, and nothing overshoots by more than ~4%. No more than two animated elements per view.
Under Reduce Motion, use `ArtMotion.crossfade` (200ms, opacity only) through `.artAnimation`,
`.artTransition` or `withArtAnimation`.

### Haptics (`.artHaptic(_:trigger:)`, gated by `\.hapticsEnabled`)
| Token | iOS | Android |
|---|---|---|
| `selectCommit` | impact light | CONTEXT_CLICK |
| `resultHit` | success | CONFIRM |
| `resultMiss` | impact soft 0.5 (never `.error`) | VIRTUAL_KEY_RELEASE |
| `streakTick` | increase | CLOCK_TICK |
| `sliderDecade` | impact rigid 0.8 | SEGMENT_TICK |
| `sliderMinor` | selection | SEGMENT_FREQUENT_TICK |
| `swipeThreshold` | selection | GESTURE_THRESHOLD_ACTIVATE |
| `swipeCommit` | impact medium | GESTURE_END |

## 3. Components (`Packages/ArtDesign`)
| Component | Use |
|---|---|
| `artGlass(_:interactive:tint:)` | **Static floating chrome only**: close button, bottom action bar, score capsule. It renders glass on iOS 26+, material + hairline on iOS 18–25, and solid `bgElevated` under Reduce Transparency. Never put it over artwork, on moving cards or in share cards. |
| `artButtonStyle(.prominent / .secondary / .option)` | One `.prominent` (gilt) per screen. `.option` is for **answers** (Pick options and Category chips): solid `bgSurface` + hairline, 56pt, full width, no glass or shadow. After the reveal use `.artOptionState(.correct)` (filled `feedbackHit`, `textOnHit`) and `.artOptionState(.incorrect)` (dimmed 35%), always with an icon and a word. `.secondary` is glass chrome only, never answers. |
| `ArtworkFrame` | Every artwork. It is aspect-fit, never cropped, with a 2pt mat, no radius and the picture-light shadow. A dominant-colour placeholder at the exact aspect ratio prevents layout jumps. |
| `ImageLoader.shared` | ImageIO thumbnail decode (max pixel = points × scale) off the main thread. It has a ~60 MB cost-limited cache and can prefetch the next 3. |
| `CardStack` + `CardStackController` + `CardStackButtons` | Swipe mode. It shows 3 cards and has KEEP/PASS stamps, 64pt ✕/♥ buttons, one-level undo, VoiceOver Like/Pass/Details, and **no prices**. |
| `LogSlider` | Bid mode. Positions run 0…700 ($100–$1B), with decade labels, 2×/5× ticks, detent haptics, fine scrub at 0.25× (labelled "Fine"), −/+ steppers and an adjustable VoiceOver action (±10). |
| `BracketLabelLayout.place(_:trackWidth:)` | Bid reveal tier labels: widest bracket first, labels stagger up to 2 rows, and anything that can't fit is dropped, so labels never overlap. |
| `HammerRevealDriver` + `.revealOption/.revealSettle/.revealProvenance/.revealNext/.revealHaptics` + `RevealPrice` | The shared reveal used in every mode. |
| `ShareCardView` + `ShareCardRenderer` + `ShareCardImage` | 1080×1350 PNG for `ShareLink`. It always includes the wordmark and "Prices approx.". It has no glass or materials. |

## 4. Information architecture
Hub + one `NavigationStack` + full-screen play sessions. **No tab bar.** Home has a full-bleed
"Painting of the Day" over the top 55%, the Daily Challenge card with a gilt "Play today" button, and a
2-column mode grid. Profile is reached from a glass toolbar button. Sessions open as `fullScreenCover`,
with a glass ✕ (44pt) at top-left, interactive dismiss disabled mid-round, a quit confirmation and a
segmented progress bar. Session lengths: Pick, Category and Bid have 10 rounds; Pricier is an endless
streak; Swipe has 20 cards; Daily has 5 rounds.

## 5. Hammer reveal (every mode)
| t | Event |
|---|---|
| 0 | Input locks (synchronously); `selectCommit` |
| 0–150ms | Unchosen options fade to 35%; the chosen one is outlined in gilt |
| 150–600ms | The price rolls from the guess (or "$—") to the truth along a log path (roll easing) |
| 600ms | Settle spring 1.04→1.0; `resultHit` / `resultMiss`; VoiceOver announcement |
| 650–900ms | The provenance line fades in, rising 6pt ("Sold 1990 · Christie's NY · approx. $82.5M incl. premium" + ⓘ) |
| 900ms | Next appears; tapping the image also advances |

Under Reduce Motion, everything happens in one 200ms crossfade, with no roll or scale. Layout: the
artwork zone takes the top 55–62% and the answer zone the bottom 38–45% (thumb zone). Targets are at
least 56pt with 12pt gaps.

## 6. Per-mode notes
The authoritative details are in plan Part C4. In brief:
- **Pick the price**: 4 full-width 56pt options, ascending, with 2 significant figures.
- **Which is pricier**: two frames stacked vertically with a "vs" medallion. The winner lifts 1.02 and gets a gilt border; the chain uses `ArtMotion.chain`.
- **Category quiz**: a 2×2 chip grid, which becomes 1×4 at AX sizes. A teaching line appears at 350ms.
- **Swipe**: `CardStack`. From card 8, show "12 more to reveal your taste".
- **Bid**: `LogSlider`, with a 48pt live bid and a gilt "Place bid". Tier labels use an icon and a word.
- **Daily**: 5 tiles shown as ◆/◇/▢ in SF Symbols (`diamond.fill`, `diamond`, `square`).

## 7. Accessibility and craft checklist (pre-delivery)
- [ ] Text contrast is at least 4.5:1 everywhere, including 48pt numerals. Use tokens only.
- [ ] Hit/miss always shows an icon, a word and a colour, never colour alone.
- [ ] Dynamic Type works up to AX5: grids drop to 1 column, the artwork keeps at least 35% of the height, and prices are never truncated.
- [ ] VoiceOver: alt text comes from the dataset (≤140 characters), reveal announcements are made, swipe has custom actions and the slider is adjustable.
- [ ] Reduce Motion means crossfades of 200ms or less, and nothing else. Reduce Transparency means solid `bgElevated`.
- [ ] Every gesture has a button alternative (WCAG 2.2 dragging movements).
- [ ] Targets are at least 44pt (answers 56) with gaps of at least 8pt. Nothing interactive sits within 16pt of the edges. The swipe stack is inset 20pt so system edge gestures still work.
- [ ] Use SF Symbols at .medium only. No emoji. No glass over artwork. No gradient text. No timers.
- [ ] One primary CTA per screen. Gilt is reserved for value and the primary action.
- [ ] Every price says "approx." and shows its year and source. Rarity is labelled "estimated". There are no won/lost-money metaphors.
- [ ] Performance: 60/120fps on swipe and reveal; images are pre-decoded; the next image is prefetched before the reveal ends.
- [ ] Previews exist in light, dark, AX5 and Reduce Motion (`Previews/`, which needs Xcode).

## 8. Anti-patterns (do not use)
- Dimming a whole card (text included) to show "not chosen". Dim the **image** only; text that stays on screen must keep 4.5:1.
- Fixed bottom CTAs overlapping scrollable answers. Reserve the space, or give the bar a canvas background.
- Glass or blur over artwork, on moving cards or in share cards.
- Cropped artworks, rounded image corners, or shadows on anything other than artwork.
- `.error` haptics or red "error" styling for a wrong guess.
- Emoji icons. Web icon sets (Phosphor or Heroicons) are wrong for this native app.
- Hover-only affordances, gesture-only actions, or infinite decorative animation.
- Tab bars. A floating glass tab bar would cover the answer thumb zone.
- Exact prices without "approx.", or any language about real bidding or money.

---

## Generator reconciliation

Commands run (ui-ux-pro-max skill, python3 stdlib):
```
search.py "art museum gallery price guessing game dark elegant mobile" --design-system --persist -p "ArtPrice" --output-dir <repo>
search.py "haptics sensory feedback gesture" --stack swiftui            (no match; retried as "ontapgesture", "reduced accessibilitylabel")
search.py "glass material accessibility reduce transparency" --stack swiftui   (no match)
search.py "dynamic type custom font" --stack swiftui
search.py "reduced motion animation" --domain ux
search.py "dragging alternative swipe" --domain ux
search.py "haptic feedback" --domain ux ; "touch target" --domain ux
search.py "elegant serif editorial museum" --domain typography
search.py "icon button accessible label" --domain icons
```

**Kept from the generator:** the Museum/Gallery category; minimal, high-contrast, grid-based restraint
(it recommended "Minimalism & Swiss Style"); the 4.5:1 contrast floor; no emoji icons; visible labels for
icon-only buttons (`accessibilityLabel`); reduced-motion support; at most 1–2 animated elements per view;
transitions instead of instant state changes; a spacing scale of 4/8/16/24/32/48; and avoiding clutter.
From the SwiftUI stack results: scalable fonts rather than fixed sizes (hence `@ScaledMetric` /
`relativeTo`), reusable `ViewModifier`s (`artGlass`, `artTextStyle`, `artHaptic`), the
`accessibilityReduceMotion` check, and `accessibilityLabel` on controls. From the UX results: a button
alternative for every drag, haptics only for confirmations and important moments, targets of 44pt on
iOS and 48dp on Android, and gaps of at least 8pt.

**Deviations (Part C wins):**
| Generator said | We use | Why |
|---|---|---|
| Light zinc palette (#18181B primary, #FAFAFA bg, #DC2626 destructive) | Salon Noir warm near-black + gilt, light "Day Salon" | Part C1. Art reads better on warm dark walls, and gilt signals value. A red "destructive" colour would make a miss feel like an error. |
| Poiret One / Didact Gothic (art deco) | Fraunces variable + SF Pro | Part C1. Fraunces has optical sizes and can be variation-pinned with Dynamic Type; SF Pro is native. Art deco would be costume. The typography search (Playfair/Inter, Cormorant) was also rejected for Fraunces (OFL, opsz axis, SOFT). |
| "Scroll-Triggered Storytelling" landing pattern | Hub + NavigationStack + full-screen sessions | This is an app, not a landing page (Part C2). |
| Shadow scale sm–xl on cards/buttons/modals | One shadow, on artworks only | Part C1 "picture light". |
| Radii 8/12/16 | 14 controls / 20 cards / 28 sheets, continuous | Part C6 and iOS idiom. |
| Hover states, cursor-pointer, 375–1440px breakpoints | Pressed states, Dynamic Type to AX5, iPhone portrait | Web-only rules do not apply to native iOS. |
| Phosphor / Heroicons | SF Symbols (.medium) | Native platform icons, which also scale with Dynamic Type. |
| "No online access" anti-pattern | Offline-first by design | MVP is deliberately offline (plan Part B). |

**Deviations from Part C itself (documented in `Tokens.json → meta.deviations`):**
- Light `feedbackHit` changed from #2F7A4F to **#2B734A**. Part C1 claimed ≥4.5:1 for all pairs, but #2F7A4F on light `bgElevated` (#EFE9DE) is only 4.33:1.
- Light `feedbackMiss` changed from #B4462B to **#B04429**. The original was 4.51:1 on `bgElevated`; it was darkened for margin and now measures 4.69.
- Added tokens Part C6 did not list: `color.bg.mat`, `color.line.shadow`, `size.artMinHeightRatio`/`matWidth`/`hairline`/`shareCard*`, `motion.easing.*`, `motion.reveal.*` (the C3 timeline), and the gesture constants from Part D6 and the brief (`swipePredictedEndRatio` 0.8, `swipeRotationDivisor` 20, `swipeUpRatio`, `dragMinimumDistance`, `stackOffset`/`stackScale*`, `edgeInset`, `fineScrubDistance` 60, `sliderPositions` 700, `sliderAccessibilityStep` 10).
- The snap-back spring is 0.35/0.70 (Part C4/C6) rather than D6's `interactiveSpring(0.3, 0.75)`. The stack scales are 0.96/0.92 (C4) rather than D6's 0.95.
- The slider thumb is solid, not glass (D6 said "glass thumb"). It moves, and AGENTS.md rule 4 keeps glass to static chrome.
- The slider spans $100–$1B (positions 0…700, matching ArtCore's `guessMilli`). Screens can pass `bounds:` to show just the dataset's decades (e.g. `200...700` = $10K–$1B, as Part C4 described).
