# macOS App Setup Spec

## Purpose

This document describes the macOS-specific version of the template. It is based directly on Quixote's current setup.

## macOS-Specific Stack

- `platform: macOS` in `project.yml`
- Developer ID signing for release builds
- Sparkle for self-updates
- DMG packaging for distribution
- notarization and stapling
- GitHub Releases for binary hosting
- GitHub Pages for the landing page and `appcast.xml`

## macOS Build Configuration

Typical settings in `project.yml`:

- deployment target such as `macOS: "14.0"`
- `type: application`
- hardened runtime enabled
- manual signing in Release
- Sparkle package dependency

macOS-only plist settings often include:

- `SUFeedURL`
- `SUPublicEDKey`
- custom URL scheme for deep links

macOS entitlements may include:

- app sandbox
- network client
- user-selected file access
- app-scoped bookmarks
- Sparkle Mach lookup exceptions

## macOS Local Workflow

The macOS template uses:

- `make dev` to build Debug and open the generated `.app`
- `make build` to run a Release build
- `make release VERSION=x.y.z` to perform a full signed release

## macOS Release Flow

The expected release path is:

```text
xcodebuild archive
-> export signed app
-> package DMG
-> notarize
-> staple
-> upload DMG to GitHub Release
-> generate appcast.xml
-> deploy site/appcast on GitHub Pages
```

Required release inputs usually include:

- `APPLE_TEAM_ID`
- `APPLE_ID`
- `SIGNING_IDENTITY_NAME`
- `APPLE_APP_SPECIFIC_PASSWORD`

Required tools usually include:

- `xcodegen`
- `gh`
- `xcpretty`
- `xcrun`
- `hdiutil`
- `osascript`

## Sparkle Notes

Sparkle is appropriate for direct-distribution macOS apps. It is not relevant to iOS apps.

A new macOS app needs:

1. Sparkle package dependency in `project.yml`
2. public EdDSA key in `SUPublicEDKey`
3. hosted `appcast.xml`
4. release artifacts signed consistently with the appcast entries

## What To Copy

Copy these macOS starter files:

- `sample-files/macos/project.yml`
- `sample-files/macos/Makefile`
- `sample-files/macos/ExportOptions.plist`
- `sample-files/macos/.env.example`
- `sample-files/macos/scripts/release.sh`
- `sample-files/macos/CHANGELOG.md`
- `sample-files/macos/site/`
- `sample-files/macos/.github/workflows/deploy-site.yml.sample`

## Best Fit

Use the macOS template when you want:

- direct distribution outside the Mac App Store
- a downloadable DMG
- in-app update checks through Sparkle
- a simple marketing/download site tied to releases
