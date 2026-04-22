# Changelog

## [Unreleased]

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
