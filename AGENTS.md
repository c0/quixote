# Quixote Agent Notes

## Build

```sh
make generate    # regenerate Quixote.xcodeproj from project.yml
make build       # xcodebuild Release
make test        # xcodebuild test, runs QuixoteTests
make dev         # build Debug and launch app
```

Always edit `project.yml`, never `Quixote.xcodeproj` directly. Run `make generate` after changing `project.yml`.

## Testing

`make test` runs:

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
