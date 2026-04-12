# Changelog

## [Unreleased]

### Added
- AO-8: Response caching — identical requests (same prompt, row data, model, parameters) are served from cache, skipping API calls. Cache persists across app launches and can be cleared from Settings → Data.
- AO-9: Change detection — file content is hashed on open; if the file changes on disk, an alert prompts the user to re-run on the updated data.

## [1.0.0] - YYYY-MM-DD

### Added
- Initial release
