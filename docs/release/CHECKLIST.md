# First TestFlight build: release checklist

App: **GTP of Art** · bundle id `pro.aijam.gtp-art` · version 0.1.0 (build 1) · iPhone only, iOS 18+.
Plan of record: Part G milestone 8 in `~/.claude/plans/velvet-churning-wind.md`.
Prepared 16 Oct 2026. Code signing is deliberately left to the owner (below).

## Done (in the repo)

- [x] **Privacy manifest** `App/Support/PrivacyInfo.xcprivacy`, bundled via `project.yml` (Resources phase
      of the `ArtPrice` target). Tracking false, no tracking domains, no collected data types.
      Required-reason APIs declared after a grep audit of `App/` and `Packages/*/Sources`:
      - `NSPrivacyAccessedAPICategoryUserDefaults` → `CA92.1` (ArtData `UserDefaultsSettingsStore`).
      - `NSPrivacyAccessedAPICategoryFileTimestamp` → `C617.1` (ArtData `DatasetValidator` reads bundled
        image sizes with `FileManager.attributesOfItem`; only called in DEBUG, but the code ships).
      - Not used: system boot time (`systemUptime`, `mach_absolute_time`), disk space, active keyboards.
      - `swift-snapshot-testing` is linked only into `ArtPriceTests`, not into the app.
- [x] **App icon**: single 1024×1024 universal icon (`AppIcon.appiconset`, opaque RGB, square corners).
      Installed: candidate 1 (Fraunces italic "G" monogram in gilt). Alternatives in `tools/out/icon/`
      (gitignored); regenerate with `tools/.venv/bin/python tools/make_icon.py`, install another with
      `--only frame --install` or `--only gavel --install`.
- [x] **Launch screen**: `UILaunchScreen.UIColorName = LaunchBackground` (#F6F2EA light / #0E0D0C dark);
      `AccentColor` = gilt (#7A5C14 light / #C9A55C dark).
- [x] **Info.plist** (generated from `project.yml`): display name "GTP of Art", 0.1.0 (1),
      `LSApplicationCategoryType = public.app-category.games`, `UIRequiresFullScreen`, portrait only,
      `TARGETED_DEVICE_FAMILY = 1` (iPhone), `CFBundleLocalizations = [en]`,
      `ITSAppUsesNonExemptEncryption = false`, and `NSPhotoLibraryAddUsageDescription` (needed because
      the PNG share cards offer "Save Image" in the share sheet; without the key that action crashes).
- [x] **Credits** (Profile › Credits and sources): the plan's E10 disclaimer verbatim (from
      `dataset.json`, identical to `credits.json`), 10 data sources, all 417 image credits loaded from
      `credits.json` in a lazy `List`, and a Typeface section (Fraunces, SIL OFL 1.1, with the licence
      text from the bundled `OFL.txt`). No third-party code ships, so no other notices are required.
- [x] User-visible "ArtPrice": none in `App/` or `ArtDesign` UI strings. Remaining uses are internal
      (target/module/executable name, RNG seed salts, UserDefaults keys, Application Support folder).

## Owner: steps in Xcode (Xcode 26.6 on this Mac)

1. `make project`, then open `ArtPrice.xcodeproj`.
2. Xcode › Settings › Accounts › **+** › Apple ID: sign in with the developer account.
3. Select the **ArtPrice** project › target **ArtPrice** › *Signing & Capabilities*:
   tick **Automatically manage signing**, choose your **Team**, confirm the bundle identifier reads
   `pro.aijam.gtp-art`. (Signing set in the Xcode UI is overwritten by the next `make project`; to make
   it stick, add `DEVELOPMENT_TEAM: <TEAMID>` and `CODE_SIGN_STYLE: Automatic` under the ArtPrice target
   settings in `project.yml`.)
4. In a browser, [App Store Connect](https://appstoreconnect.apple.com) › Apps › **+ New App**:
   platform iOS, name "GTP of Art" (or a fallback if taken), primary language English, bundle ID
   `pro.aijam.gtp-art` (register it under Certificates, Identifiers & Profiles first if it is not in
   the list; Xcode's automatic signing usually registers it), SKU e.g. `gtp-art`.
   Categories: primary **Games** (subcategory Trivia or Word/Puzzle), secondary **Education**.
5. Fill App Privacy in App Store Connect: **Data Not Collected**. Age rating questionnaire: no
   objectionable content (some artworks include classical nudes; answer "Infrequent/Mild" for
   "Nudity" if the questionnaire asks, per Apple's guidance on artistic nudity).
6. In Xcode choose destination **Any iOS Device (arm64)**, then **Product › Archive** (scheme ArtPrice,
   Release). Xcode 26.6 / iOS 26 SDK uploads are accepted until April 2027; after that use Xcode 27
   via Xcode Cloud (plan Part G, milestone 0).
7. Organizer › select the archive › **Distribute App** › **App Store Connect** › **Upload**, keep the
   defaults (automatic signing, upload symbols). Encryption export questions are pre-answered by
   `ITSAppUsesNonExemptEncryption = false`.
8. When processing finishes (email), App Store Connect › TestFlight: add yourself to Internal Testing,
   install via the TestFlight app on the iPhone.

## Open items (not done here)

- [ ] **Build and tests not run** by this pass (simulators were in use). Run `make build`, `make build-18`,
      `make test`, `make ui-test` before archiving; the Credits change and new Info.plist keys need a
      green build.
- [ ] **Owner picks the final icon** (candidates in `tools/out/icon/`). Optional: dark and tinted icon
      variants for iOS 18+ appearance modes.
- [ ] Accessibility pass (plan C7) and device design pass.
- [ ] App Store metadata: subtitle, description, keywords, support URL, **privacy policy URL**
      (required even for "Data Not Collected"), screenshots (6.9" and 6.5" iPhone; `make shots` helps).
- [ ] Name/trademark check for "GTP of Art" (plan C8: only a quick web check was done).
- [ ] Dataset: `copy_licence` in `dataset.json` still reads "original (ArtPrice project)" (written by
      `tools/build_dataset.py` line 287). Not shown in the UI today; data owner should rename it on the
      next `make dataset`.
- [ ] Release build runs `DatasetValidator` only under DEBUG; if that code is ever stripped from ArtData
      in release, the `C617.1` entry in the privacy manifest can be dropped.
