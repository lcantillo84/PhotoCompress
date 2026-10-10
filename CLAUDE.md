# Photo Compress

Single-purpose iOS utility (SwiftUI). The user has a photo too big for an upload limit
(email, Discord cap, a web form that rejects >2MB). They tell the app the size they need;
the app hits it.

Design comes from competitor review mining. Each decision exists because reviewers of the
top-ranked apps complained about its absence:

- **Target file size is the primary input.** Leader offers a 5% quality slider, so users guess and retry. We take bytes directly.
- **EXIF preserved by default.** Competitors silently strip it; reviewers (e.g. insurance claims) were blocked by that.
- **No batch limit, ever.** Leader caps free tier at 3 photos.
- **Crash-safe batching.** Leader stalls at 0% and crashes mid-batch. Users must always know which photos were processed.
- **One-time purchase, no subscription, no ads.** Reviewers are angry about weekly subscriptions.

## Non-negotiable constraints

1. **No backend.** No network calls, accounts, analytics, crash reporters, or third-party SDKs. Everything on device. This keeps "Data Not Collected" truthful on the App Store, which is a selling point.
2. **Bilingual from the first string.** Every user-facing string goes through a String Catalog, English + Spanish (natural Latin American Spanish, not literal translation). Never hardcode a display string; never retrofit.
3. **Never overwrite or delete originals.** Always save as a new asset. The app writes; Photos handles deletion.
4. **SwiftUI with `@Observable`.** No Combine, no architecture framework, no DI container.

## Market (researched Oct 2026)

Target-size compression is no longer unique: Size Limit, Tinyfy and Limitfit launched Jul-Aug 2026.
Our edge is unlimited batches, crash-safe resume, metadata kept by default, and a result screen
that says where the photos went. Leave out: ads, rating prompts, video, cropping, print/DPI sizing.

## Layout

- `PhotoCompress/App` entry point + root view, `Localizable.xcstrings`
- `PhotoCompress/Features` UI: `BatchModel` drives Home -> Compose -> Progress -> Results
- `Core/BatchJournal.swift` per-photo journal for resume; `Core/PhotoSaver.swift` add-only save (not in the SwiftPM target)
- `PhotoCompress/Core` engine; no UIKit imports, so it is testable from the CLI
- `PhotoCompress/PrivacyInfo.xcprivacy` privacy manifest; keep in sync with any new required-reason API use
- `Tests/PhotoCompressCoreTests` engine + journal tests; run `swift test`. `Tests/Fixtures` holds real photos and is git-ignored
- `project.yml` is the source of the Xcode project; run `xcodegen generate` after adding files
- Debug builds accept `-demo compose|running|results|unfinished` for screenshots

## Engine rules (`Core/CompressionEngine.swift`)

- Binary search on JPEG quality (floor 0.1) into in-memory `Data`; below the floor, downscale 10% via Core Image and search again. Never write intermediates to disk.
- Never route through `UIImage`: it drops metadata. Use ImageIO (`CGImageSource` -> `CGImageDestinationCreateWithData`) and pass the source properties back in via `MetadataPolicy`.
- Per-image work in `autoreleasepool`; hold one decoded image at a time so batching stays memory-safe.

## Privacy manifest

UserDefaults is a required-reason API: declared with `CA92.1` (app's own data). `NSPrivacyTracking` is false with empty domains; collected data types empty. Adding a tracking domain or SDK would break the "Data Not Collected" claim.
