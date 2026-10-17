# App Store Connect metadata: GTP of Art

Ready-to-paste metadata for version 1.0 (first App Store submission) and the first external TestFlight
build. Prepared 16 Oct 2026. Facts about the app come from the repo (`Resources/dataset.json`,
`credits.json`, `project.yml`, `App/Support/PrivacyInfo.xcprivacy`); Apple rules are cited inline and
listed under Sources. Items that need an owner decision are marked **DECISION**.

App: iPhone only (`TARGETED_DEVICE_FAMILY = 1`), iOS 18+, English, bundle id `pro.aijam.gtp-art`, free,
no in-app purchases, no ads, no accounts, no networking.

---

## 1. App Information (app level)

| Field | Value | Check |
|---|---|---|
| Name | `GTP of Art` | 10 of 30 characters. Apple: "at least two characters and no more than 30" [1] |
| Subtitle | `Guess the Price of Art` | 22 of 30 characters [1]. Spells out the initialism (see `TRADEMARK.md`) |
| Primary category | **Games** | |
| Games subcategories | **Trivia** (first), **Family** (optional second) | Games allows one or two subcategories [1][4]. Trivia is the store genre used by comparable apps, e.g. The Right Price Is? (Games/Trivia) and QuizzLand (Games/Family/Trivia + Education) [5] |
| Secondary category | **Education** | Apple: "interactive learning experience on a specific skill or subject" [4] |
| Content rights | "Yes, it contains third-party content, and I have the necessary rights" | Images are CC0 museum open access or public-domain PD-Art; prices are facts. Apple requires "all the necessary rights" [1] |
| Age rating | **13+** (see section 4) | **DECISION** |
| Privacy Policy URL | `https://gtp-art.aijam.pro/privacy` | Required for iOS apps [1][8]. Page text in `PRIVACY_POLICY.md`. `gtp-art.aijam.pro` currently resolves to parking IPs, so hosting must go live before submission |
| Made for Kids | No | Choosing it locks the app into Kids Category rules permanently [1] |

## 2. Version information (1.0)

### Promotional text (147 of 170)

```
Old masters, Impressionists, Japanese prints, posters: guess what 300 real artworks sold for. Pick, bid or compare, and play a new daily challenge.
```

Can be changed any time without a new build [2].

### Description (2,375 of 4,000; plain text, no HTML [2])

```
GTP of Art stands for Guess The Price of Art. A Klimt, a Hokusai print, a Toulouse-Lautrec poster: each one sold at auction or privately, and the figure is on public record. How close can you get?

Six ways to play

• Pick the price: four prices, one is real.
• Which is pricier? Two works, one sold for more. Trust your eye.
• Category quiz: Baroque, Fauvism or Ukiyo-e? Name the movement or medium.
• Bid: drag to your own estimate. The closer you land, the more you score.
• Daily challenge: a fresh set every day, the same for everyone. Keep your streak going.
• Swipe: like or pass, and build a taste profile that names your style and estimates how rare it is.

Learn as you play

Every reveal shows the sale year, the venue, and whether the figure includes the buyer's premium. Tap the info button for the full source, an inflation-adjusted estimate, and the image credit. Works you meet are added to your Collection, so you can come back to them.

The collection

417 public-domain artworks from seven departments: Old Masters, 19th Century, Impressionist & Modern, Asian Art, Prints & Multiples, Posters and Photographs. 300 of them carry a documented sale price, from about $1,000 to more than $400 million, sold between 1885 and 2025. Images come from museum open-access programmes (The Met, Art Institute of Chicago, Cleveland Museum of Art, Rijksmuseum) and Wikimedia Commons, each with its licence and attribution in the app.

Honest about the numbers

Prices are approximate public figures for historical sales, gathered from published reports. Most auction prices include the buyer's premium; private-sale prices are as reported. Nothing in the app is an appraisal or investment advice, and a past price says nothing about what a work would fetch today. The app is for fun and learning.

No money, no catches

• Free. No ads, no in-app purchases, no accounts.
• "Bid" is a guessing game: no money, no betting, no prizes.
• Works offline. Everything is bundled; nothing is downloaded.
• No data collected. Your scores and taste profile stay on your iPhone.
• Share a result card with friends from the share sheet if you want to.

Built for everyone

Dynamic Type up to the largest accessibility sizes, VoiceOver labels, a button alternative for every gesture, and respect for Reduce Motion and Reduce Transparency.

Some classical works include artistic nudity.
```

Before submitting, confirm the accessibility paragraph matches the shipped build (the accessibility
pass in `CHECKLIST.md` is still open). If any item is not yet true, delete that clause. Apple rejects
inaccurate metadata (guideline 2.3).

### Keywords (97 of 100 bytes)

```
auction,painting,quiz,trivia,masterpiece,museum,expensive,worth,bid,gallery,artist,van gogh,monet
```

Rules applied: limit is 100 bytes, commas with no spaces between keywords, and the name and company
aren't repeated [2]. Words already indexed from the name and subtitle (gtp, guess, price, art) are left
out. Excluded on purpose: "gpt", "chatgpt", "ai" (other companies' marks; guideline 2.3.7 bars
"trademarked terms, popular app names" [3]) and "Christie's"/"Sotheby's" (same rule). Van Gogh (8
works) and Monet (4) are in the dataset, so they describe real content. Swap in "klimt" or "hokusai"
after launch if App Store Connect analytics shows better terms.

### URLs and copyright

| Field | Value | Note |
|---|---|---|
| Support URL (required) | `https://gtp-art.aijam.pro/support` | Must be a full URL that "lead[s] to actual contact information" [2]. Minimum page: a contact email, a short FAQ ("Are prices exact? Where do images come from?") and a link to the privacy policy. support email: info@aijam.pro |
| Marketing URL (optional) | `https://gtp-art.aijam.pro` or leave blank | |
| Copyright (required) | `2026 <owner's legal name>` | Format is year then owner; App Store Connect adds the © itself [2]. **DECISION**: an individual developer account shows the owner's legal name as the seller anyway |
| Version | 1.0 | `project.yml` has 0.1.0; bump `MARKETING_VERSION` to 1.0 for the App Store version (TestFlight can stay 0.x) |

### What's New

Not shown for the first version; required for every later version [2].

## 3. App Review information

- Sign-in required: **No** (no accounts).
- Contact: owner name, phone, email (**DECISION**: which phone/email).
- Notes (paste):

```
GTP of Art ("Guess The Price of Art") is a single-player, offline trivia game. Players estimate what real artworks sold for. No account, no network access, no ads, no in-app purchases, no data collection.

Images: all 417 artworks are public-domain works. 203 images come from museum open-access programmes released as CC0 (The Metropolitan Museum of Art, Art Institute of Chicago, Cleveland Museum of Art, Rijksmuseum); the rest are faithful photographic reproductions of public-domain 2D works from Wikimedia Commons (PD-Art). Every image's licence and attribution is in the app under Profile > Credits and sources, and on each reveal via the info button. No museum logos are used and no endorsement is implied.

Prices: sale prices are facts from published auction results and press reports, cited per work (venue, date, source URL) in the info sheet. They are labelled approximate, with a disclaimer that they are not appraisals or investment advice.

"Bid" mode: the player drags a slider to estimate a price and earns points for accuracy. There is no money, no wagering, no virtual currency and no prizes. "Bid" is auction vocabulary only. No mode involves real or simulated gambling.

Age rating: some classical paintings include artistic nudity (e.g. Modigliani's Nu couché, Cabanel's Birth of Venus), a few Old Master works depict violence (e.g. Rubens's Massacre of the Innocents), and some Belle Epoque posters advertise champagne or cigarette papers. We rated the app accordingly (13+).

Sharing: result cards are shared only through the system share sheet. Saving an image to Photos uses the add-only permission (NSPhotoLibraryAddUsageDescription).

The name: "GTP" is an initialism of "Guess The Price". The app has no AI features and no connection to any AI product.

To try every mode quickly: open the app, finish or skip onboarding, then use the mode cards on Home. The Daily challenge is on the Home card at the top.
```

Check that the last paragraph matches the shipped navigation before pasting.

## 4. Age rating questionnaire

Apple moved to 4+, 9+, 13+, 16+, 18+ in July 2025, and the new questions became mandatory for
submissions after 31 Jan 2026 [9][10]. Definitions and the answer-to-rating mapping below are from
Apple's reference page [6].

**Recommendation: 13+.** The dataset honestly triggers three 13+ descriptors at "Infrequent":

| Question | Answer | Why (works in `dataset.json`) | Rating it implies [6] |
|---|---|---|---|
| Parental controls | No | none | |
| Age assurance | No | none | |
| Unrestricted web access | No | source links open Safari outside the app; no in-app browser | (would be 16+) |
| User-generated content | No | | |
| Social media | No | | |
| Messaging and chat | No | | |
| Advertising | No | | |
| Profanity or crude humor | None | | |
| Horror/fear themes | Infrequent | van Eyck *Crucifixion; Last Judgment* (hell scene), Francken *Death and the Miser*, Böcklin *Island of the Dead*, Dürer *Knight, Death and the Devil* | 9+ |
| Alcohol, tobacco or drug use or references | Infrequent | Mucha *Job* (cigarette-paper poster), Bonnard *France-Champagne*, Toulouse-Lautrec cabaret posters | 13+ |
| Medical or treatment information | None | | |
| Health or wellness topics | No | | |
| Mature or suggestive themes | Infrequent | Apple's definition includes "sensual or suggestive imagery, censored or implied nudity … war" | 9+ |
| Sexual content or nudity | **Infrequent** | Apple: "brief or partial nudity". About 15 of 417 works show nudity: Modigliani *Nu couché*, Cabanel *Birth of Venus*, Boucher *Toilette of Venus*, Cranach *Reclining Water Nymph*, Dürer *Adam and Eve*, Gentileschi *Danaë*, Kirchner *Seated Black-Haired Female Nude*, Corinth, Adler, Stuck *Susanna Bathing*, Merritt *Eve*, Mashkov *Bathers*, Klimt *Water Serpents II*, Gauguin Tahitian scenes | 13+ |
| Graphic sexual content and nudity | **None** | Apple: "Explicit, detailed depictions of sexual activity or nudity … pornographic portrayals". Museum paintings shown for art-historical reasons are not that (guideline 1.1.4 also separates erotic from "aesthetic or emotional" intent [3]). Answering anything but None makes the app **unpublishable** [6] | (Unrated) |
| Cartoon or fantasy violence | None | | |
| Realistic violence | Infrequent | Rubens *Massacre of the Innocents*, Lanfranco *Execution of Saint John the Baptist*, Raphael *Lucretia*, David *Death of Socrates* | 13+ |
| Prolonged graphic or sadistic realistic violence | None | | (Unrated) |
| Guns or other weapons | Infrequent | swords and lances in Old Master scenes, cannonballs in Fenton's Crimean War photograph | 9+ |
| Gambling | No | no real money | |
| Simulated gambling | **None** | Apple: "Betting or wagering without using real money". Bid mode is an estimate scored for accuracy; nothing is staked | (would be 13+; R18+ in Australia) |
| Contests | **None** | Apple: "Events that allow users to compete with one another for rankings, rewards…". The app is single-player with no leaderboards, rankings or rewards. Infrequent would still be 4+; Frequent would make it 13+ [6] | |
| Loot boxes | No | | |

Precedent: other art apps with classical nudes carry the "Infrequent/Mild Sexual Content and Nudity"
descriptor: Google Arts & Culture, DailyArt, Artly, Art Authority and Smartify (all 12+ under the old
scale, which became 13+) [5].

**DECISION (owner):** to get 9+ or 4+ instead, the nude, violent and alcohol/tobacco works (about 30)
would have to be removed or excluded from the bundle. Rating 4+ while showing *Nu couché* conflicts with guideline 2.3.6 ("Answer the age rating questions … honestly" [3]) and risks
rejection and a forced re-rate. Screenshots and the icon must still be
4+-appropriate whatever the rating (guideline 2.3.8 [3]), so **don't use a nude in any screenshot**.

## 5. App Privacy (nutrition label)

- Answer **"No, we do not collect data from this app"**, then Save. No further questions follow [8].
- Why this is correct: Apple defines collecting as "transmitting data off the device" and keeping it
  longer than needed to serve the request; "Data that is processed only on device is not
  'collected'" [7]. The app has no networking, analytics, crash SDK or third-party code (the only
  dependency, swift-snapshot-testing, links into the test target only). Scores, settings and the taste
  profile stay in UserDefaults and Application Support on the device. Sharing goes through the
  system share sheet, where the user picks the destination, and the app receives nothing back.
- The answer is still mandatory even when it is "No" [8], and must cover third-party code too [8].
- The privacy manifest (`PrivacyInfo.xcprivacy`) already matches: tracking false, no collected data
  types, required-reason APIs UserDefaults `CA92.1` and file timestamp `C617.1`.
- The **privacy policy URL is still mandatory** even with Data Not Collected [1][8]. Guideline 5.1.1(i)
  also requires the policy to be linked "within the app in an easily accessible manner" [3]. **The app
  has no in-app privacy link today** (Profile has Credits only). Add a "Privacy policy" row in Profile
  that opens the hosted URL, or shows the policy text bundled in the app. This is a code change for
  the next build.

## 6. Export compliance

- Answer: the app uses **no encryption** (it makes no network connections and implements no
  cryptography). `ITSAppUsesNonExemptEncryption = false` is already in `project.yml`, so App Store
  Connect skips the per-build encryption questions [11].
- If App Store Connect asks anyway (some developers report this even with the key set [12]): choose
  "None of the algorithms mentioned above" / no non-exempt encryption. No documentation upload is
  needed.

## 7. Screenshots

Apple's current iPhone rules (App Store Connect screenshot specifications, read 16 Oct 2026 [13]):

- **Required:** at least one screenshot for **iPhone with Dynamic Island (medium display)**: 1206 x 2622
  or 1179 x 2556 portrait (iPhone 17/17 Pro/18 Pro, 16/16 Pro, 15/15 Pro, 14 Pro).
- **Required if no large Dynamic Island set is provided:** iPhone with Face ID (large display),
  1284 x 2778 or 1242 x 2688. Providing the **large Dynamic Island** set covers it: 1320 x 2868
  (iPhone 17 Pro Max / 18 Pro Max), 1290 x 2796 or 1260 x 2736 (iPhone Air).
- Smaller sizes are scaled down automatically from the next larger set [13].
- 1 to 10 screenshots per size; .png or .jpeg; **no alpha channel** [13].
- **iPhone Duo** (new foldable): optional today; "Starting in April 2027, screenshots will be required
  for any app using the iOS 27.1 SDK or later" [13]. Not needed for a 1.0 built with Xcode 26.6.

**Plan:** shoot the **6.9-inch set at 1320 x 2868** (iPhone 17 Pro Max simulator) and the **6.3-inch set
at 1206 x 2622** (iPhone 17 Pro simulator), portrait, the same 6 frames in each. `make shots` boots
ArtCI-26; add those two simulators. Flatten to RGB PNG (no alpha) before upload. Use light mode for
the main set (art reads better), and use no nude works in any frame (guideline 2.3.8).

**Captured 17 Oct 2026** with `Tests/Scripts/appstore_shots.sh <dest>` (simulators ArtCI-26-Max = iPhone 17
Pro Max and ArtCI-26 = iPhone 17 Pro, light mode, status bar 9:41, RGB PNG without alpha) into
`~/Desktop/GTP-AppStore-Screenshots-17Oct/`: 01 Pick the price question (Han Gan *Horse*), 02 Which is pricier
(Boonen vs Velázquez, `-seedSalt 2` avoids nudes), 03 Bid reveal "Bullseye" (`-autoBest`), 04 Pick reveal with
provenance, 05 Daily result, 06 Taste reveal, 07 Category quiz reveal (Teniers, Baroque), 08 Home. Plain
screenshots, no caption bands; upload 01–07 in that order (08 optional).

| # | Screen | Caption (short; on a band above the device frame) |
|---|---|---|
| 1 | Pick the price, four options on a famous work (e.g. Klimt *Adele Bloch-Bauer I*) | What did it sell for? |
| 2 | Which is pricier, two stacked works | Two masterpieces. One sold for more. |
| 3 | Bid, slider mid-drag, then the reveal "Bullseye" | Name your price. Get close. |
| 4 | Reveal with the provenance line and the info sheet open (year, venue, "approx.", source) | Every price sourced and dated |
| 5 | Daily challenge result card with streak | A new challenge every day |
| 6 | Taste profile archetype screen | Swipe to find your art taste |

Optional 7th: Category quiz ("Baroque or Rococo? Name the movement"). Captions must not claim prices
are exact, and must not mention AI or GPT.

## 8. Build and SDK requirements

- Today: uploads must be built with **Xcode 26 / iOS 26 SDK or later** (in force since 28 Apr 2026
  [14]). The local **Xcode 26.6** therefore qualifies.
- Apple: "Starting April 2027 … iOS and iPadOS apps must be built with the iOS & iPadOS 27 SDK or
  later" [15]. Xcode 26.6 uploads are accepted until then; Apple has not published the exact day
  (Apple staff on the forums would not confirm a date [16]). Plan the switch to Xcode 27 (Xcode Cloud,
  since this Mac stays on macOS 26.2) before **1 April 2027** to be safe.
- Using the iOS 27.1 SDK will also make iPhone Duo screenshots mandatory (section 7).

## 9. TestFlight

Beta App Description is required for external testing [17]; Beta App Review information is needed
before sharing with external testers [18]. Internal testers (up to 100 team members) get builds automatically; external testers (up to 10,000) need the first build approved by TestFlight App Review [18].

**Beta App Description**

```
GTP of Art (Guess The Price of Art) is a free iPhone game about what real artworks sold for. Guess prices for 300 public-domain paintings, prints, posters and photographs with documented sales, in six modes: Pick the price, Which is pricier, Category quiz, Bid, the Daily challenge, and Swipe, which builds your art taste profile. Everything runs offline: no account, no ads, no purchases, no data collected. Prices are approximate public figures, shown with the sale year, venue and source.
```

**Feedback email:** info@aijam.pro.

**What to Test (build 0.1.0 (1))**

```
Thanks for testing! Please try:
1. Onboarding, then one round of every mode from Home.
2. The Daily challenge: play it, then come back tomorrow and check the streak.
3. Swipe at least 12 works and open your taste profile.
4. Tap the info button on a reveal: does the price source make sense?
5. Share a result card (Messages, save to Photos).
6. With large text (Settings > Accessibility > Display & Text Size), Reduce Motion and VoiceOver on.
Tell us about: prices that look wrong, images that look cropped or low quality, anything confusing, and any crash (screenshot + what you tapped). Send feedback from the TestFlight app (take a screenshot while the app is open).
```

**Beta App Review notes:** reuse section 3.

## 10. Before you press Submit

- [ ] Privacy policy and support pages live at `gtp-art.aijam.pro` (draft: `PRIVACY_POLICY.md`)
- [ ] In-app privacy policy link added (guideline 5.1.1(i))
- [ ] Age rating questionnaire answered as in section 4
- [ ] App Privacy: "Data Not Collected"
- [ ] 6.9" and 6.3" screenshot sets uploaded, no nudity, no alpha
- [ ] `MARKETING_VERSION` 1.0; accessibility claims in the description verified
- [ ] Trademark memo read (`TRADEMARK.md`); `gtp-art.com` registered; social handles claimed (`gtp_art` where hyphens are not allowed)

## Sources

1. App Store Connect Help, App information: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/
2. App Store Connect Help, Platform version information: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/
3. App Review Guidelines (2.3.6–2.3.8, 1.1.4, 4.1, 5.1.1, 5.2, 5.3): https://developer.apple.com/app-store/review/guidelines/
4. Choosing a category: https://developer.apple.com/app-store/categories/
5. iTunes Search/Lookup API, genres and ratings of comparable apps (read 16 Oct 2026): https://itunes.apple.com/lookup?id=1559178579,1275023828,1050970557,1546647006,355879924,547982045,1102736524&country=us
6. Age ratings values and definitions: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/
7. App privacy details on the App Store: https://developer.apple.com/app-store/app-privacy-details/
8. Manage app privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
9. 9to5Mac, new age rating system (Jul 2025): https://9to5mac.com/2025/07/24/apple-notifies-developers-of-new-app-store-age-rating-system/
10. AppDeveloperMagazine, 31 Jan 2026 questionnaire deadline: https://appdevelopermagazine.com/apple-age-rating-update/
11. Overview of export compliance: https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/ and Complying with encryption export regulations: https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations
12. Apple Developer Forums, export questions despite the key: https://developer.apple.com/forums/thread/802746
13. Screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
14. iOS 26 SDK requirement from 28 Apr 2026: https://appletreats.substack.com/p/apple-clarifies-upcoming-minimum and https://stora.sh/blog/2026-04-28-ios-26-sdk-deadline-day-one
15. Submit your apps (April 2027 minimums): https://developer.apple.com/app-store/submissions/
16. Apple Developer Forums, Xcode 27 cutoff date: https://developer.apple.com/forums/thread/839939
17. Enter test information: https://developer.apple.com/help/app-store-connect/test-a-beta-version/enter-test-information
18. TestFlight: https://developer.apple.com/testflight/
