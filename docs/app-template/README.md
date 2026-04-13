# App Template Docs Bundle

This folder packages Quixote's app-development setup into a reusable reference for new Apple app projects.

Files:

- `shared-setup-spec.md`: technical spec for the common project structure, tools, and workflows
- `macos-setup-spec.md`: macOS-specific build and release details
- `ios-setup-spec.md`: iOS-specific build and release details
- `sample-files/macos/`: starter files for a macOS app
- `sample-files/ios/`: starter files for an iOS app

Recommended copy order:

1. Read `shared-setup-spec.md`.
2. Choose either the macOS or iOS spec based on the target app.
3. Copy the matching sample files into a new repo.
4. Replace placeholder values like `APP_NAME`, `APP_SLUG`, `BUNDLE_ID`, `TEAM_ID`, and GitHub/App Store metadata.
5. Run `make setup` and `make generate`.
6. Open the generated Xcode project and confirm signing, capabilities, and platform-specific settings.

Shared assumptions across both templates:

- XcodeGen-managed project
- `.xcodeproj` is generated from `project.yml`
- `Makefile` is the primary local workflow entrypoint
- `scripts/release.sh` owns shipping
- versioning is tracked in `project.yml`

Platform split:

- macOS template: Sparkle, DMG distribution, GitHub Releases, GitHub Pages appcast/site
- iOS template: archive/export flow for App Store or TestFlight submission, no Sparkle or DMG packaging
