# Test Coverage Backlog

Use Swift Testing (`@Test`, `#expect`) for new tests. Keep tests focused on pure-input/pure-output behavior and view-model logic that can run without AppKit or SwiftUI rendering.

Run with:

```sh
make test
```

## High Priority

- `InterpolationEngine`
  - Empty template and empty table preview behavior.
  - Tokens with repeated whitespace, newlines inside braces, and adjacent tokens.
  - Unknown tokens stay visible in prompt and system-message expansion.
  - Structured row data block ordering follows `columns`.

- `PromptListViewModel`
  - `addPromptFromPin` copies name/system/template and sets `fromPinID/fromPinName/pinnedPromptID/isPinned`.
  - `markCurrentPromptAsPinned` sets only pin identity/display state and does not set `FROM:` attribution.
  - `removePinnedPromptReferences` clears `pinnedPromptID/isPinned` across all files and leaves `fromPinID/fromPinName` snapshots intact.
  - Deleting selected prompts preserves a valid selected prompt.

- `PinnedPromptsViewModel`
  - First load seeds default prompts.
  - Add, update, rename, duplicate, and delete behavior.
  - Empty or whitespace-only names normalize to `"New prompt"`.
  - Persistence round trip using a per-test temp directory.
  - Corrupt or unreadable JSON falls back safely.

- `PinnedPromptCoordinator`
  - `pinCurrentTab` creates a pin from the selected dataset prompt and marks the selected prompt as pinned.
  - `deletePin` removes the pin and cleans dataset prompt references.
  - `apply` creates a dataset prompt from a pending pinned prompt application.

## Medium Priority

- Parsers
  - `CSVParser`: comma, tab, quoted fields, embedded newlines, missing cells, extra cells.
  - `JSONParser`: array-of-objects, nested values, missing keys, mixed types.
  - `ExcelParser`: basic sheet extraction and empty workbook/sheet handling if fixtures can stay small.

- `ResponseCache`
  - Cache key changes when prompt, system message, model, provider profile, base URL, or parameters change.
  - Store/read/remove behavior with a per-test temp directory if storage can be injected.
  - Backward-compatible decode behavior for older cache entries.

- `FileModelConfigsViewModel`
  - Initial model config creation from available models.
  - Invalid/unavailable model selections are repaired.
  - Per-file configs remain isolated.
  - Parameter updates persist to the selected file config.

- `StatsViewModel`
  - Overview counts for completed, failed, cancelled, pending, and in-progress results.
  - Token/cost aggregation.
  - Selected-prompt filtering.
  - Empty input produces stable zero-state stats.

- `ResultsViewModel`
  - Result column generation for prompt/model combinations.
  - Stable ordering.
  - Failed/cancelled result display metadata.

## Lower Priority

- `ExportViewModel`
  - Exported filename generation.
  - Column ordering.
  - Optional metric columns included/excluded correctly.

- `WorkspaceViewModel`
  - Pure restore-state transitions if bookmark/file access can be abstracted.
  - Selection fallback when a selected file is removed.
  - Changed-file acknowledgement state.

- `PromptEditorViewModel`
  - Insert/remove token behavior.
  - Preview refresh when template or visible columns change.
  - System/template updates propagate through `onPromptUpdated`.

## Do Not Unit Test

- SwiftUI view layout/rendering.
- AppKit file picker behavior.
- `NSTextView`/`UITextView` wrappers.
- `WKWebView` preview rendering.
- Menu and command wiring.
- Visual screenshot matching.

Verify those by running the app and using manual `/verify`-style flows.
