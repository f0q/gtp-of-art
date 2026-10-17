# Roadmap

Where GTP of Art is going, in order. Dates are when a stage was finished or is planned; the detailed
build log lives with the owner and is summarised here.

## Done

| When | Stage | What shipped |
|---|---|---|
| 11 Oct 2026 | Plan | Investigation of price sources, rights, audience and business model; architecture, design direction and data plan agreed before any code. |
| 11 Oct 2026 | Rules and fixtures | `spec/game-logic.md` and shared fixtures; the pure-logic package passes them (integer-only, seeded, portable to Kotlin). |
| 12 Oct 2026 | Design system and app | Tokens, typography (Fraunces), components; all six modes playable; onboarding questionnaire that shapes what you see. |
| 13 Oct 2026 | Dataset v1 | 417 public-domain works, 300 with verified sale prices, seven departments, museum open-access and Commons images with credits. |
| 16 Oct 2026 | Release readiness | Accessibility pass (Dynamic Type to AX5, VoiceOver, Reduce Motion), privacy manifest, App Store metadata, trademark review. |
| 17 Oct 2026 | Website and TestFlight | gtp-art.aijam.pro live (privacy, support, journal); builds 1 to 3 on TestFlight; first device pass fixed a crash and five layout issues. |

## Now (October 2026)

- Device testing of build 1.0 (3) on real iPhones.
- App Store submission: screenshots, metadata and review notes are prepared; age rating 13+ (classical nudes), no data collected, free, no ads.
- Small fixes queued from testing: one source image to recrop, spacing on the Which is pricier screen, long alt texts, contrast of dimmed quiz chips.

## Next (after launch)

- **Contemporary pack.** Today every work is public domain, so "modern" ends around 1930. A contemporary pack of living artists' work at asking prices, licensed through marketplace affiliate feeds with a buy link, is the first post-launch feature. It arrives as a downloadable pack, so the base app stays small.
- **Daily challenge calendar.** Hand-picked sets for special days on top of the seeded daily.
- **More works in the thin categories.** Old Master drawings, Pre-Raphaelites, Fauvism, early abstraction and the School of Paris each have the minimum eight works; the aim is twenty.
- **Population data for taste rarity.** "Rarer than X% of players" is estimated from a synthetic baseline today; once there are enough players, an anonymous aggregate replaces it (opt-in, no accounts).

## Later

- **Artists' uploads.** A subscription that lets artists put their own work in front of the crowd and see how it is valued: moderation, reporting and takedown flow are required before this can ship (App Store guideline 1.2).
- **Android.** The rules, dataset and fixtures are platform-neutral by design; the Android app is a Compose port of the UI layer.
- **Toolchain.** Release builds move to Xcode 27 through Xcode Cloud before April 2027, when Apple requires the iOS 27 SDK.

## Principles that do not change

- Public-domain or properly licensed images only; every image credited; every price a sourced, dated fact labelled approximate.
- No real money anywhere in the game. "Bid" is vocabulary, not a transaction.
- Offline first, no accounts, no tracking.
