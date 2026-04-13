# iOS App Setup Spec

## Purpose

This document describes the iOS-specific version of the template. It preserves the same XcodeGen and `make` workflow, but swaps in iOS build targets and an App Store/TestFlight-oriented release flow.

## iOS-Specific Stack

- `platform: iOS` in `project.yml`
- iPhone/iPad deployment target
- iOS signing and provisioning
- archive/export flow for App Store distribution
- TestFlight or App Store Connect delivery
- no Sparkle, no DMG, no appcast

## iOS Build Configuration

Typical settings in `project.yml`:

- deployment target such as `iOS: "17.0"`
- `type: application`
- target device families such as iPhone and iPad
- Release signing tuned for App Store export

iOS-specific plist settings often include:

- `UILaunchScreen`
- `UIApplicationSceneManifest`
- supported interface orientations
- camera/photo/library usage descriptions if needed

iOS entitlements depend heavily on features, but may include:

- push notifications
- associated domains
- keychain sharing
- iCloud capabilities

## iOS Local Workflow

The iOS template uses:

- `make dev` to build for the iOS Simulator
- `make build` for a Release simulator or generic platform build
- `make release VERSION=x.y.z` to archive and export an `.ipa` or App Store archive

In practice, teams often combine this with Fastlane or `xcrun altool` / App Store Connect tooling later, but the template keeps the baseline simple.

## iOS Release Flow

The expected release path is:

```text
xcodebuild archive
-> export archive for app-store or ad-hoc distribution
-> produce .ipa or xcarchive output
-> upload through App Store Connect or hand off for submission
```

Required release inputs usually include:

- `APPLE_TEAM_ID`
- `SIGNING_IDENTITY_NAME`
- optional App Store Connect credentials if upload is automated

Required tools usually include:

- `xcodegen`
- `xcpretty`
- `xcrun`

Optional later additions:

- `gh` if you also want GitHub release notes or repo automation
- Fastlane if you want TestFlight submission automation

## What To Copy

Copy these iOS starter files:

- `sample-files/ios/project.yml`
- `sample-files/ios/Makefile`
- `sample-files/ios/ExportOptions.plist`
- `sample-files/ios/.env.example`
- `sample-files/ios/scripts/release.sh`
- `sample-files/ios/CHANGELOG.md`

## Best Fit

Use the iOS template when you want:

- an iPhone or iPad app
- TestFlight distribution
- App Store submission
- the same generated-project workflow as the macOS template without macOS distribution machinery
