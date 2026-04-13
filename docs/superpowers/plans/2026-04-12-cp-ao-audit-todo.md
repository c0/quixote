# CP/AO Audit To-Do

## High Priority

- [ ] Implement real multiple-prompt support for `AO-1`, or mark `AO-1` incomplete in `SPEC.md`.
- [ ] Replace raw workspace URL persistence with security-scoped bookmark storage.
- [ ] Make changed-file handling actually invalidate stale results, or update the alert text and spec to match current behavior.
- [ ] Tighten API key validation so failed validation never persists the key.
- [ ] Stop adding unreadable or invalid files to the workspace silently; surface parse/open errors in the UI.

## Correctness

- [ ] Add inline cosine similarity display if `AO-10` is intended to be complete.
- [ ] Make JSON column ordering deterministic instead of relying on dictionary key iteration.
- [ ] Reconcile `AO-8` cache key behavior with the spec, or update the spec to match the implemented keying scheme.
- [ ] Reconcile `AO-9` live/restore change-detection semantics with the spec.
- [ ] Reconcile `AO-12` parser lifecycle behavior with the spec, especially around file reopening and parser error visibility.

## Error Handling

- [ ] Surface export failures instead of silently ignoring write errors.
- [ ] Stop swallowing queue persistence write/decode failures without feedback or logging.
- [ ] Stop swallowing cache persistence write/decode failures without feedback or logging.
- [ ] Review retry / pause / resume behavior so in-flight work and restored work are handled explicitly rather than implicitly.

## Security / Privacy

- [ ] Minimize or encrypt persisted prompt, queue, and cache payloads stored in Application Support.
- [ ] Avoid surfacing raw server error bodies into result cells and exports.
- [ ] Check and handle Keychain API return statuses explicitly.
- [ ] Review parser hardening for large or malicious CSV/JSON/XLSX inputs.

## Simplification

- [ ] If the product remains single-prompt in practice, simplify prompt persistence and result wiring to match that reality.
- [ ] Simplify result keying and prompt/model coupling where possible.
- [ ] Reduce queue snapshot scope so it stores resumable work identity rather than full payload state where feasible.
- [ ] Consolidate settings flows so validate/save/model-refresh behave as one coherent path.

## Tracking Notes

- Build verification passed during audit: `xcodebuild -project Quixote.xcodeproj -scheme Quixote -configuration Debug -derivedDataPath .build build`
- No automated test target currently covers these behaviors, so fixes should include test coverage where practical.
