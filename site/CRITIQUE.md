⚠️ DEGRADED: single-context (run as a delegated sub-agent; design review and detector ran sequentially in one context, review written before reading detector output)

# GTP of Art site: design critique

Target: `site/` (live https://gtp-art.aijam.pro/ is byte-identical to local `index.html` and `style.css`, checked with diff).
Screenshots: `/private/tmp/claude-501/-Users-jamsmini-Documents-appDev-artapp/1ef6678d-a63c-4bc5-8cff-ec9bc175f9b7/scratchpad/critique/` (`home-{1440,1024,768,500}-{dark,light}.png`, `detail-1440-gallery-stretched.png`, `detail-1024-light-hero.png`, `detail-500-header.png`, `support-1440-dark.png`, `support-500-light.png`, `journal-1440-dark.png`, `privacy-1440-dark.png`, `ref-pick-reveal-true-ratio.png`).

## 1. "Why are the pictures narrowed?": they are distorted, not just small

**Cause:** every screenshot `<img>` has `width="600" height="1304"`. CSS overrides the width (`.hero img{width:100%;max-width:360px}`, `.shots img{width:100%}`) but never sets `height:auto`. The HTML `height` attribute acts as `height:1304px`, so each image keeps a **fixed 1304 px height** while its width shrinks to the column. With `object-fit: fill` (the default), the picture is squashed horizontally.

Measured in headless Chrome (rendered box, height/width; the file is 2.173):

| Viewport | Hero `home.jpg` | Gallery images |
|---|---|---|
| 1440 | 360×1304, ratio 3.62 (1.67× stretched) | 186×1304, ratio 7.03 (3.2× stretched) |
| 1024 | 360×1304, 3.62 | 182×1304, 7.15 |
| 768 | 310×1304, 4.21 | 231×1304, 5.65 |
| 500 | 280×1304, 4.66 | 221×1304, 5.90 |
| 390 (computed) | 280×1304, 4.66 | 350×1304, 3.73 |

It happens at every width and in both themes. Look at the condensed type and the tall, thin painting in `detail-1440-gallery-stretched.png`, and compare it with `ref-pick-reveal-true-ratio.png`. A side effect is that the hero is 1304 px tall, so the headline floats in a sea of empty space (`detail-1024-light-hero.png`), and the page is about 2× longer than it should be.

There is also a second, separate issue: five phones in one row at desktop are about 186 px wide each. Even when they are not distorted, at that size the app's typography can't be read.

**Fix:**
```css
.hero img, .shots img { height: auto; }   /* the actual bug: one line */
```
Keep the width/height attributes, because they reserve the aspect ratio and prevent layout shift. Then fix the size problem: show 3 shots, not 5, at about 260–300 px each (`grid-template-columns:repeat(3,minmax(0,280px));justify-content:center`). Below 720 px, use a horizontal scroll-snap row (`overflow-x:auto; scroll-snap-type:x mandatory; grid-auto-flow:column; grid-auto-columns:72%`) rather than tall 2-up stacks.

## 2. Facts block (417 / 300 / 7 / $1K–$450M)

**Decision already taken:** remove it entirely. That means the `.facts` markup and the `.fact*` CSS. The provenance paragraph below it can stay in a shortened form.

## Design specificity verdict

The palette, Fraunces and the copy belong to this product. The tone is honest and well written, and the "approx., year, venue" discipline carries through. The structure, though, is the stock landing template: an eyebrow label, a two-column hero with a device, a 3×2 card grid, a "Screens" strip, a stats row, a "Built for everyone" section, and a fat footer. Swap the words and the same layout works for any app. Nothing on the page is composed like the thing it is about: a sale catalogue, a lot, a hammer price.

Detector (`impeccable detect`, 15 findings across 4 HTML files + CSS):
- **hero-eyebrow-chip** ×4 (every page): valid. Tracked caps above every H1 is a template tic.
- **overused-font** (Fraunces) ×7 and **cream-palette** ×4: false positives here, because both are pinned by the Salon Noir brief, and the brief wins.

## Findings

**P0. Distorted screenshots.** See section 1. This is the only thing a visitor will remember. Fix: `height:auto`.

**P1. Header loses its side padding at ≤1040 px.** `header.top{padding:20px 0}` (specificity 0,1,1) overrides `.wrap{padding:0 20px}`. At 1024 and 500 px, the icon touches the left edge and "Privacy" touches the right (`detail-500-header.png`). The header also sits 20 px left of the footer column at every width. Fix: `header.top{padding-block:20px}` instead of the shorthand.

**P1. Too many sections, too much text for "minimal".** The page has 6 sections, 6 cards, 5 shots, 4 facts and 3 long paragraphs, and the legal disclaimer appears twice (collection section and footer). Fix: hero, one compact "how it plays" list, three screenshots, one short provenance line, footer. Move the long provenance and disclaimer text to Journal and Support, where it already exists.

**P1. Mode cards are the generic part.** Six bordered, filled, 20 px-radius boxes with the same weight read as a SaaS feature grid. Fix: drop `.mode` background, border and radius. Set the modes as a two-column catalogue list: a hairline `border-top:1px solid var(--line)` per row, a lot number in muted tabular figures (`01`–`06`), the Fraunces name, and one muted line. No boxes.

**P2. Hero composition.** Once the height is fixed, the 1.1fr/.9fr split with a centred phone is still conventional. The two CTAs fight: the gilt "Coming to the App Store" is a link to a support FAQ, so the most prominent element on the page is a non-action. The eyebrow repeats the lede. Fix: remove the eyebrow. Let the H1 run larger (`clamp(2.8rem,8vw,6rem)`, `letter-spacing:-.02em`) on a ~12-column grid with the phone overlapping the right edge. Make the gilt button an App Store badge on release, and until then an unfilled hairline "Coming soon to the App Store" note. Drop "How it works" (scrolling does that).

**P2. Gilt is overused.** Gilt currently appears on body links, the primary CTA and four facts numbers. The brief says gilt is reserved for value and the primary action. Fix: links become `color:var(--text)` with an underline at 12% cream (`text-decoration-color:var(--line)`), turning gilt on hover. Gilt then appears in one place per screen.

**P2. Typography rhythm.** H2 is `margin-top:1.2em` but `.label+h2` cancels it. Sections use flat 72 px gaps, so every break weighs the same. Body text is 17 px/1.6 with a 36em measure, which is fine. H3 on Support (1.3 rem) sits just 1 step above body and hugs its answer. Fix: one type scale (e.g. 14 / 17 / 22 / 32 / 56 / 88), section spacing of 120–160 px desktop and 80 px mobile, and `h3{margin-bottom:.25em}` with `p+h3{margin-top:2em}`.

**P2. Inner pages misalign.** `main.wrap.prose` is a 40em column centred in the viewport, while header and footer are left-aligned on 1040 px. The text column starts about 160 px right of the logo (`support-1440-dark.png`). Fix: keep `.prose` left-aligned inside the 1040 wrap (`margin-left:0`), or offset it to a fixed grid column so the logo, H1 and footer share one left edge.

**P2. Support contact.** The email is a `<span>` in monospace, not a `mailto:` link. It sits in a filled `.box` card, the only card on the page. Fix: `<a href="mailto:…">` set in Fraunces at about 1.5 rem with a hairline underline, and remove the box.

**P3. Inline styles** (`style="margin-top:18px"`, `margin-top:28px`, `margin-top:48px`, `color:var(--muted)`) break the token rule. Move them to classes.

**P3. Footer.** Nav and two paragraphs run together with no gap. The paragraphs are full width (`footer p{max-width:none}`), so they run 120+ characters per line, and they repeat the disclaimer. Fix: one row with brand and © on the left and links on the right, plus one short muted line of credit at max 60ch.

**P3. Shadows and radii.** `box-shadow:0 24px 64px rgba(0,0,0,.45)` on the hero phone reads as a muddy halo on the light theme (`detail-1024-light-hero.png`). The screenshots already include device corners, yet they get a 22–36 px radius plus a border. Fix: no shadow in light mode (or a 1 px hairline only), and a radius matched to the screenshot's own corners (~11% of width) with no border.

**Colour/contrast:** passes in both themes (muted #B8B0A3 on #0E0D0C ≈ 9:1; #5C554C on #F6F2EA ≈ 6.8:1; white on #7A5C14 ≈ 6.4:1). There is no explicit `[data-theme="light"]` override, only `:not([data-theme="dark"])`. Add it for parity with the app's token pattern.

**Mobile:** the CTAs stack acceptably at 500 px. At 390 px the four nav links plus the logo wrap onto two ragged lines. Fix: at <560 px, hide "How to play" and keep three links, or move nav to the footer only.

## Nielsen scores (Persuade surface; 7 and 10 n/a)

Visibility 3 · Match real world 3 · Control 3 · Consistency 2 (header/footer/prose misalignment) · Error prevention 3 · Recognition 3 · Aesthetic & minimalist 1 (distortion, density) · Error recovery 3 · **21/32**, acceptable with significant issues.

## Top 10 changes, in order

1. `.hero img, .shots img{height:auto}`: fixes the squeezed pictures everywhere.
2. Delete the facts block (decided).
3. Fix the header padding (`padding-block` only) and align header, content and footer on one left edge.
4. Gallery: 3 screenshots at ~280 px on desktop, scroll-snap row on mobile.
5. Replace the six mode cards with a hairline, numbered catalogue list.
6. Hero: remove the eyebrow, enlarge the H1, use one primary action (App Store badge or a quiet "coming soon"), drop "How it works".
7. Restrict gilt to the single primary action and to price figures. Links become cream with a hairline underline.
8. Cut the home page to hero, play, screens, one provenance line and footer. Move long copy to Journal and Support.
9. A real spacing and type scale (larger section gaps, H3 rhythm), with no inline styles.
10. Footer as one quiet row; a `mailto:` link without the box on Support; no hero shadow in light mode.

## Target look

A night-time auction catalogue. The page is a warm near-black sheet with a strict left margin, as if printed. The hero is a single lot: the Fraunces headline set large enough to carry the page alone, and beside it one undistorted phone showing the painting of the day, without a halo. Below, the six modes read like a lot index: numbered, hairline-ruled, no boxes. Then three screens sit at a size where their text is legible, followed by a single line of provenance in small muted type, the way a catalogue credits its photographs. Gilt appears in exactly two kinds of place: a hammer-price figure and the one button that matters. Everything else is cream on black, separated by 12% hairlines and generous silence. The light theme is the same catalogue on paper.

Questions skipped: running as a delegated sub-agent; findings are returned to the caller.
