# Shared App Development Setup Spec

## Purpose

This document describes the development setup pattern shared across the app templates in this bundle. It is the part you can reuse for either macOS or iOS, before applying platform-specific build and release rules.

## Shared Principles

1. Treat `project.yml` as the source of truth for build settings.
2. Generate the `.xcodeproj`; do not hand-edit it.
3. Use `make` for the most common local tasks.
4. Script release steps so they run the same way every time.
5. Keep versioning, signing inputs, and automation assumptions explicit.

## Shared Repository Layout

```text
.
├── Makefile
├── project.yml
├── scripts/
│   └── release.sh
├── APP_NAME/
│   ├── APP_NAMEApp.swift
│   ├── Info.plist
│   └── APP_NAME.entitlements
├── APP_NAME.xcodeproj/           # generated
├── CHANGELOG.md
└── .env.example
```

Some apps add:

- `site/` for a landing page or hosted metadata
- `.github/workflows/` for CI/CD
- `ExportOptions.plist` when export configuration is needed outside Xcode defaults

## Shared Build System

### XcodeGen

The templates use XcodeGen to define the Xcode project declaratively in `project.yml`.

Benefits:

- source-controlled build settings
- easy cloning into new apps
- reproducible package and target configuration
- fewer hidden settings inside Xcode UI state

Typical `project.yml` responsibilities:

- app name and target names
- platform and deployment target
- bundle identifier
- version numbers
- signing style
- plist values
- entitlements path
- Swift package dependencies

### Generated Project Workflow

The intended workflow is:

```sh
make generate
make open
```

Whenever `project.yml` changes, regenerate the `.xcodeproj`.

## Shared Local Developer Workflow

The standard `Makefile` shape is:

- `make setup`: install required local tools
- `make generate`: regenerate the Xcode project
- `make build`: run `xcodebuild`
- `make open`: open the generated project in Xcode
- `make dev`: build a debug artifact or simulator build
- `make release VERSION=x.y.z`: run the release script

Goals:

- memorable commands
- minimal Xcode CLI knowledge required for daily work
- one place to evolve local conventions across apps

## Shared Derived Output Strategy

The templates keep build output local to the repo:

- `.build/` for ordinary build output
- `build/` for release artifacts

This makes cleanup and artifact inspection easier.

## Shared App Configuration

Both platform templates assume:

- `Info.plist` exists and is referenced by `project.yml`
- entitlements live beside the app target
- the SwiftUI app entry point owns app-level wiring

Recommended rule:

- avoid splitting the same setting across too many files unless the generator requires it

## Shared Release Concepts

Both platforms need:

- version bumping
- signing credentials
- a clean working tree before shipping
- archived output built from a reproducible command

Common release-script responsibilities:

1. Load `.env`.
2. Validate required tools and credentials.
3. Determine version.
4. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
5. Regenerate the project if `project.yml` changed.
6. Archive/export the app.
7. Publish or hand off artifacts.

The artifact and publishing steps diverge by platform, which is covered in the platform-specific specs.

## Shared New-App Bootstrap

1. Copy the matching sample directory into a new repo.
2. Rename placeholders in `project.yml`, target folders, and scripts.
3. Run `make setup`.
4. Run `make generate`.
5. Open the generated project and verify signing/capabilities.
6. Build locally before touching release automation.
