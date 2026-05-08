# Quixote — AI Context

## What this is

A barebones macOS app template with Sparkle self-update, a minimal Astro microsite, and a full release pipeline. Replace the placeholder UI in `ContentView.swift` with your actual app.

## Architecture

Single macOS application target. No widget.

| File | Purpose |
|---|---|
| `project.yml` | XcodeGen spec — source of truth for all Xcode settings |
| `Quixote.xcodeproj` | Generated — never edit by hand |
| `Quixote/QuixoteApp.swift` | App entry point + Sparkle init |
| `Quixote/ContentView.swift` | Main UI (replace with your app) |
| `Quixote/Quixote.entitlements` | Sandbox + network.client (for Sparkle) |
| `ExportOptions.plist` | Developer ID export config (sed-substituted at release) |
| `scripts/release.sh` | Full release pipeline |
| `site/` | Astro marketing site |
| `CHANGELOG.md` | Keep-a-changelog format |

## Build commands

```sh
make setup       # install xcodegen (once)
make generate    # regenerate Quixote.xcodeproj from project.yml
make build       # xcodebuild Release
make test        # xcodebuild test, runs QuixoteTests
make open        # open in Xcode
make dev         # build Debug and launch app
make release VERSION=1.0.1  # full release pipeline
```

## Testing

`make test` runs the unit suite through Xcode:

```sh
xcodebuild test -project Quixote.xcodeproj \
  -scheme Quixote \
  -destination 'platform=macOS' \
  -derivedDataPath .build
```

All tests should be green at any commit.

What to test: anything pure-input/pure-output in Quixote. Good candidates include parsers, interpolation, prompt/list persistence logic, sync logic, statistics/math, and cache-key behavior.

What not to test: SwiftUI views, `NSTextView`/`UITextView` wrappers, `WKWebView` preview rendering, AppKit menu wiring, file picker panels, and other Apple UI framework seams. Verify those by running the app.

Prefer Swift Testing (`@Test`, `#expect`) for new tests. Existing XCTest suites can stay if added later — don't rewrite working tests just to change frameworks. Per-test temp dir pattern:

```swift
let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
defer { try? FileManager.default.removeItem(at: tempDir) }
```

## XcodeGen workflow

**Always edit `project.yml`, never `.xcodeproj` directly.**

After any change to `project.yml`:
```sh
make generate
```

## Sparkle setup (first time)

After your first `make generate`:

1. Find `generate_appcast` in Xcode DerivedData:
   ```sh
   find ~/Library/Developer/Xcode/DerivedData -name generate_appcast 2>/dev/null | head -1
   ```
2. Run it once on an empty directory to get your key pair:
   ```sh
   /path/to/generate_appcast --ed-key-file sparkle_private_key
   ```
3. Copy the public key into `project.yml` → `SUPublicEDKey`
4. Keep the private key file somewhere safe (not in the repo)

## Release

Requires a `.env` file (copy `.env.example`).

```sh
make release VERSION=1.0.1
```

Pipeline: bump versions → archive → export → DMG → notarize/staple → tag → generate_appcast → GitHub Release → deploy site.

## Site

```sh
cd site && npm ci && npm run dev   # localhost:4321
cd site && npm run build           # production build → dist/
```

Deployed automatically to GitHub Pages on push to main via `.github/workflows/deploy-site.yml`.
Update `APP_VERSION` in `site/src/pages/index.astro` when releasing (done automatically by release script).
