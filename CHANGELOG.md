# Changelog

## [Unreleased]

## [1.1.0] - 2026-05-08

### Changed
- README and updated site
- README and site updates
- Implement pinned prompts
- Add pinned prompts design plan
- Add Quixote test coverage
- Handle Uline-style CSV imports
- Add pre-commit test hook

## [1.0.6] - 2026-05-07

### Changed
- Add multi-provider support and output detail polish

## [1.0.5] - 2026-05-07

### Changed
- Upgrade Pages workflow actions to Node 24 versions
- Polish app controls and site metadata

## [1.0.4] - 2026-05-01

### Changed
- Preserve cached run timing in stats
- Raise default concurrency and rate limit bounds
- Add throughput sparkline and match latency width
- copy

## [1.0.3] - 2026-04-30

### Changed
- Add changelog and release verification to make release
- Add GPT-4.1 and GPT-5 variants to model selection
- Hide window title text
- Store raw provider responses with output details
- design system
- Add rerun actions to run menu
- Share settings state and reset unsaved API key drafts
- Rotate Sparkle signing key

## [1.0.2] - 2026-04-21

### Changed
- Store API keys in local macOS Keychain only, with reads limited to explicit user actions.
- Simplified the Settings API key field around a native secure input, masked preview, and OpenAI test action.

## [1.0.1] - 2026-04-21

### Fixed
- Restored cached result hydration on app launch so previous completed runs appear without starting another run.
- Improved stats drawer spacing, sizing, table alignment, and metric header help text.
- Fixed custom control hit targets for the run menu, stats navigation, prompt tabs, and variable pills.
- Kept removed variable pills in sync with prompt preview output.
- Updated About panel copyright metadata.

## [1.0.0] - 2026-04-20

### Added
- Initial release
- AO-10: Cosine similarity — bag-of-words similarity between the expanded prompt and each LLM response is computed, displayed as "Similarity" in the stats panel, and exported as a CSV column.
- AO-11: Extrapolated projections — the stats panel shows projected cost and token usage at 1K / 1M / 10M rows, configurable and toggleable in Settings → Stats.
- AO-8: Response caching — identical requests (same prompt, row data, model, parameters) are served from cache, skipping API calls. Cache persists across app launches and can be cleared from Settings → Data.
- AO-9: Change detection — file content is hashed on open; if the file changes on disk, an alert prompts the user to re-run on the updated data.
