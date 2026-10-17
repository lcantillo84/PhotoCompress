# Photo Compress

An iOS app that shrinks photos to an exact file size, for upload limits like a web form that
rejects anything over 2 MB, Discord's 10 MB cap, or a 300 KB visa photo. You tell it the size
you need; it finds the highest quality that fits.

English and Spanish. iOS 17 or later. Not yet on the App Store.

## What it does

- **Target size, not a quality slider.** Pick 100 KB, 300 KB, 500 KB, 1 MB, 2 MB, 10 MB or
  25 MB, or type your own.
- **Keeps photo info.** Capture date, camera and location stay in the copy (can be turned off).
- **No batch limit.** Compress as many photos as you pick, one at a time to keep memory low.
- **Picks up after a crash.** Progress is saved after every photo; reopening the app offers to
  resume where it stopped.
- **Never touches originals.** Results are saved as new photos in a "Photo Compress" album,
  named with "-compressed".
- **Private.** No network calls, accounts, analytics or third-party code. Everything runs on
  the phone.

## How the compression works

Binary search on JPEG quality, encoding to memory and measuring each result, until it lands
just under the target. If even low quality is too big, the image is scaled down 10% and the
search repeats. Photos are read and written with ImageIO, never `UIImage`, so metadata
survives. Details in `PhotoCompress/Core/CompressionEngine.swift`.

## Project layout

| Path | What's there |
|---|---|
| `PhotoCompress/App` | App entry, root view, String Catalogs (English + Spanish) |
| `PhotoCompress/Features` | Screens (Home, Choose size, Progress, Results, Settings) and `BatchModel` |
| `PhotoCompress/Core` | Compression engine, metadata policy, batch journal, saving to Photos |
| `Tests/PhotoCompressCoreTests` | Engine and journal tests |
| `UITests` | End-to-end test that taps through the app in the simulator |
| `project.yml` | Source of the Xcode project (XcodeGen) |
| `CLAUDE.md` | Product rules and constraints for contributors |

## Building

Requirements: a recent Xcode with the iOS 17 SDK or newer, and
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate          # after adding or removing files
open PhotoCompress.xcodeproj
```

To run on your own iPhone, set your team in `project.yml` (`DEVELOPMENT_TEAM`) or in Xcode's
Signing & Capabilities, then pick the phone as the run destination.

## Testing

```sh
swift test                 # engine and journal tests, runs on the Mac
xcodebuild -project PhotoCompress.xcodeproj -scheme PhotoCompress \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test   # UI test
```

Some tests use real photos from `Tests/Fixtures`. That folder is git-ignored because the
photos contain locations and people; tests that need it are skipped when it's empty. Drop in
a few `.heic` or `.jpg` files of your own to run them.

Debug builds accept `-demo compose|running|results|unfinished` as a launch argument to show a
screen with sample data, which is handy for screenshots.

## Status

In development. Still to do before release: app icon, pricing (one-time purchase, no
subscription), App Store listing and screenshots, and a privacy policy page.

Private project. All rights reserved.
