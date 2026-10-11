# Design tokens: "Salon Noir"

`Design/Tokens.json` is the single source of truth for colour, type, spacing, radius, size,
elevation, motion, haptics and gesture constants. iOS consumes it via a generated Swift file;
the Android (Compose) port will consume the same file. Screen-level rules live in
`design-system/artprice/MASTER.md`.

```
Design/
  Tokens.json        W3C DTCG 2025.10 tokens + `meta` (version, contrast proofs)
  gen_tokens.py      Tokens.json -> Packages/ArtDesign/Sources/ArtDesign/Generated/Tokens.swift
  Fonts/             Fraunces variable TTFs (upright + italic) and OFL.txt (SIL OFL 1.1)
```

## Workflow

```bash
python3 Design/gen_tokens.py                 # regenerate Tokens.swift (commit both files)
python3 Design/gen_tokens.py --update-meta   # recompute meta.contrast_pairs[].ratio after a colour change
python3 Design/gen_tokens.py --check          # fail if any contrast pair is below its minimum

# ArtDesign tests (Command Line Tools need explicit Swift Testing paths; with Xcode, plain `swift test` works)
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
L=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
swift test --package-path Packages/ArtDesign -Xswiftc -F -Xswiftc $F -Xlinker -rpath -Xlinker $F -Xlinker -rpath -Xlinker $L
```

The test suite regenerates `Tokens.swift` into a temp dir and fails if the committed file differs.
It also recomputes every contrast pair with the WCAG formula. So to change a token, edit the JSON,
then run `--update-meta` and the generator, and commit everything.

Fonts are duplicated on purpose: `Design/Fonts` is the source and
`Packages/ArtDesign/Sources/ArtDesign/Resources/Fonts` is the bundled copy (SwiftPM resources must live
inside the package). A test fails if the two copies differ. Fonts were downloaded from
`github.com/google/fonts/tree/main/ofl/fraunces` (renamed from `Fraunces[SOFT,WONK,opsz,wght].ttf`
and `Fraunces-Italic[SOFT,WONK,opsz,wght].ttf`). sha256:
upright `177ff6c0…abbb`, italic `b24448c4…0e01`, OFL `bdf4c228…833b`.

## Format conventions

The file follows the DTCG 2025.10 stable format (`$type`, `$value`, `$description`, `$extensions`,
`{alias}` references). The project-specific conventions are:

| Concern | Convention |
|---|---|
| Colour value | DTCG colour object `{colorSpace: "srgb", components, alpha, hex}`. The generator checks that `hex` and `components` agree. |
| Light/dark | `$value` is the **dark** appearance (the primary design). The **light** ("Day Salon") value lives in `$extensions["app.artprice.modes"].light`. |
| Units | `dimension` uses `px`, read as iOS points and Android dp. `duration` uses `ms`. |
| Typography extras | `$extensions["app.artprice.text"]` holds `relativeTo` (the iOS text style the size scales with), `opsz`/`soft` (Fraunces axes), `italic`, `smallCaps` and `monospacedDigit`. |
| Springs | No `$type`. `$value: {response, dampingFraction}` with `$extensions["app.artprice.type"] = "spring"`. |
| Haptics | No `$type`. `$value: {ios: {kind, weight/flexibility, intensity}, android: "<HapticFeedbackConstants name>"}` with `app.artprice.type = "haptic"`. |
| `meta` | Not a token group: version, deviations and `contrast_pairs` (`fg`, `bg`, `min`, computed `ratio` per mode). Strip it before feeding a DTCG tool. |

## Token semantics

- **color.bg**: `canvas` is the wall behind everything. `surface` is for cards and sheets. `elevated` is for controls and is also the solid fallback when Reduce Transparency is on. `mat` is the 2pt artwork mat (non-text).
- **color.text**: `primary` and `secondary` for text, `onGilt` for anything drawn on gilt.
- **color.accent.gilt**: only where value is involved (prices, scores, streaks, the one primary CTA). Keep it to about 5% of pixels.
- **color.feedback**: `hit` and `miss`. Always pair them with an icon and a word. Miss is never "error red", and its haptic is never `.error`.
- **color.line**: `hairline` (0.5pt separators and the glass-fallback stroke) and `shadow` (the picture-light shadow, artworks only).
- **font.style**: `displayXL` 40 / `displayL` 28 / `titleArt` 22 italic (Fraunces, weight 500/500/400, opsz 72, SOFT 50). `priceHero` is 48 semibold with monospaced digits. `body`, `label` and `provenance` (footnote, small caps) are SF Pro. Every style scales with Dynamic Type through its `relativeTo` style.
- **space**: 2/4/8/12/16/24/32/48. **radius**: control 14, card 20, sheet 28, pill 999 (continuous).
- **size**: minimum target 44, answer button 56, swipe button 64, artwork at most 62% and at least 35% of the height, share card 360×450 @3×.
- **layout**: artwork zone 0.58 of the content height, hero 0.55, pricier frames 0.42 each, winner lift 1.02, disabled tile opacity 0.6, onboarding era 0.30 / tile 0.18, tile detail aspect 1.6, clue zoom 1.6, bracket label rows 2.
- **text.onHit**: text on a filled `feedback.hit` surface (correct option); 10.09 dark / 5.75 light.
- **motion**: durations 100–800ms (plus `step` 350ms for onboarding), easings (entrance, exit, standard, roll), springs (settle 0.45/0.82, snapBack 0.35/0.70, chain 0.40/0.85), stagger 60/120, the Reduce Motion crossfade (200ms), and the hammer-reveal timeline (`motion.reveal.*`, including `teachAt` 350ms for the Category teaching line).
- **haptic**: `select.commit`, `result.hit`, `result.miss`, `streak.tick`, `slider.decade`, `slider.minor`, `swipe.threshold`, `swipe.commit`.
- **gesture**: swipe commit at 35% of width, 800pt/s, or a predicted end past 80% of width. Rotation is x/20, clamped to ±12°. The stack shows 3 cards (offset 8, scales 0.96/0.92). Fine scrub engages 60pt off the track at 0.25×. The slider has 700 positions, and VoiceOver adjusts it in steps of 10.

## How Compose will consume the same file

1. Run a Style Dictionary v4+/v5 build (or a small Kotlin/Gradle task modelled on `gen_tokens.py`).
   Add a preprocessor that drops `meta` and expands `app.artprice.modes` into a `light` and a `dark` platform.
2. Map the token kinds like this:
   - colours become `Color(0xAARRGGBB)` in `LightColors` / `DarkColors`, selected by `isSystemInDarkTheme()`;
   - `dimension` becomes `.dp`;
   - `duration` becomes `Int` milliseconds for `tween`;
   - `cubicBezier` becomes `CubicBezierEasing`;
   - springs become `spring(dampingRatio = dampingFraction, stiffness = (2π / response)² )`, with mass 1;
   - haptics become `view.performHapticFeedback(HapticFeedbackConstants.<android>)`;
   - typography becomes `TextStyle`, with Fraunces loaded via `FontVariation.Settings(weight, opsz, SOFT)`.
     `relativeTo` maps to the Material type-scale slot, and sizes are given in `sp` so they scale with system font size.
3. Use the same semantic names: `ArtTokens.Color.bgCanvas`, `ArtTokens.Space.l`, and so on.
