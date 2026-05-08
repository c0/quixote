# Plan: Pinned Prompts

## Context
Users need reusable, model-agnostic prompt templates that live outside any specific dataset. The design system (`assets/design-system/ui_kits/app/` + `screenshots/`) fully specifies the interaction model. This plan covers every UI component, data model change, and the critical path to ship it.

---

## States documented (from screenshots)

| Screenshot | State |
|---|---|
| 4.44.12 | File view — sidebar with DATA + PROMPTS sections, pinned tab shows filled pin icon in tab strip |
| 4.44.17 | Pin selected — PinnedPromptEditorView in middle, right pane shows centered empty state |
| 4.44.21 | "Run on..." popover open over the editor header |
| 4.44.30 | Tab strip close-up — filled blue pin icon + "FROM:" attribution label |
| 4.45.04/09 | Header of PinnedPromptEditorView — editable name field annotation ("THIS IS EDITABLE") |

---

## Part 1 — UI Components

### Component A: `SidebarView` (modified)

**Changes:**
- Move "+" from main Quixote header into the DATA section header
- Rename section label from implicit "Files" to "DATA"
- Add PROMPTS section below a `QuixoteRowDivider`

**DATA section:**
- Label "DATA" (10pt, 700, tracking 0.22em, uppercase, `quixoteTextMuted`)
- "+" button at right (16pt icon, `quixoteTextSecondary`), calls `workspace.openFilePicker()`
- Rows unchanged (table icon, name, status subtext, selection highlight)

**PROMPTS section:**
- Same header style, label "PROMPTS"
- "+" button: calls `addPin()` + immediately selects the new pin; tooltip "New pinned prompt" unless the `⌘⇧P` app command is added
- Icon per row: `text.alignleft` SF Symbol (13pt, `quixoteTextSecondary`)
- Selection highlight identical to DATA rows
- Empty state: "No pinned prompts. Pin from any prompt tab to save it here." (11pt, `quixoteTextMuted`, 10px horizontal padding)
- Context menu per row: **Duplicate**, **Delete** (destructive)

**Selection logic:**
- File row tap: `sidebarSelection = .data(id)`, `workspace.selectedFileID = id`
- Prompt row tap: `sidebarSelection = .pinnedPrompt(id)`; do **not** clear `workspace.selectedFileID`
- Rationale: `WorkspaceViewModel.selectedFileID` is persisted as the restored dataset selection. A pinned prompt is a content/sidebar selection, not a persisted workspace-file selection.

---

### Component B: `PinnedPromptEditorView` (new)

Middle pane, shown when `sidebarSelection == .pinnedPrompt(id)`.

**Header row** (`minHeight: 44`, `padding: 10px 18px`):
- `Image(systemName: "pin.fill")` — 13pt, `quixoteTextPrimary` (not blue — screenshots show white)
- `TextField` (inline, no border) — 14pt bold, `quixoteTextPrimary`; `onSubmit` + 250ms debounce saves name
- `Button("RUN ON...")` with `▶` icon — `QuixoteSecondaryButtonStyle`
- Duplicate icon button (`doc.on.doc`, 13pt, `quixoteTextSecondary`)
- Delete icon button (`trash`, 13pt, `quixoteTextSecondary`)

`QuixoteRowDivider()`

**Scrollable body** (`padding: 14px 18px`, `gap: 18`):

1. **SYSTEM MESSAGE** section
   - `QuixoteSectionLabel("System Message")`
   - `TextEditor` in `QuixoteCard` (`.quixoteCard` fill, 1px `.quixoteDivider` border, 6pt radius, 12pt padding, `.quixoteTextPrimary`, 14pt monospaced, `minHeight: 120`)
   - Placeholder overlay ("Describe desired model behavior (tone, tool usage, response style)")

2. **PROMPT** section
   - `QuixoteSectionLabel("Prompt")`
   - Same `TextEditor` card, `minHeight: 180`
   - Placeholder: `"Summarize in 3 bullet points:\n{{column_name}}"`

3. **REQUIRED VARIABLES** section
   - `QuixoteSectionLabel("Required Variables")`
   - Parse `{{token}}` from `systemMessage + " " + template` using shared `InterpolationEngine.tokens(in:)`
   - If vars found: `HStack(wrap)` of `QuixoteChip(text: var)` (no `actionIcon`, non-closable)
   - If none: monospaced 11pt `quixoteTextMuted` text: `"None — prompt is plain text. Add {{column_name}} tokens to interpolate row values."` with `{{column_name}}` in `quixoteTextSecondary`

**"Run on..." popover** (shown as `popover` or `ZStack`-based overlay):
- "APPLY TO DATASET" header label (10pt, 700, tracking 0.22em, uppercase, `quixoteTextMuted`)
- Rows for each `workspace.files.filter(\.isAvailable)`: table icon + name + `arrow.up.right` icon
- Footer (if vars detected): `"Will check for: var1, var2"` in 10pt monospaced `quixoteTextMuted`, separated by divider
- Disable/warn rows where detected vars are not present in the target dataset columns. Runtime expansion leaves unknown tokens in place, so the UI should surface this before applying.
- Empty state: "No datasets open. Open a file from the DATA section first."

**Local state management:**
- `@State var localName`, `localSystem`, `localTemplate` — 250ms debounce → `pinnedPrompts.update(_:)`
- `onChange(of: prompt.id)` resyncs all locals (covers switching between pins)

---

### Component C: `PinnedPromptEmptyPane` (new)

Right pane replacement when a pin is selected. Centered in available space.

- `Image(systemName: "pin.fill")` in a 64×64 rounded rect card (`quixoteCard` fill, 12pt radius) — 24pt icon, `quixoteTextSecondary`
- `Text(pin.name)` — 15pt, 700, `quixoteTextPrimary`
- `Text("Pinned prompts are model-agnostic templates. Use Run on… to apply this prompt to a dataset and pick models there.")` — 13pt, `quixoteTextMuted`, centered, max width ~260pt
- Spacer
- `HStack`: `"NO MODEL"` · `"NO VARIABLES BOUND"` — 10pt, monospaced, 600, tracking 1.4em, uppercase, `quixoteTextMuted`

---

### Component D: `PromptEditorView` tab strip (modified)

Two additions to the right side of the tab strip (before existing `+` button):

**Pin button:**
- `Image(systemName: isPinned ? "pin.fill" : "pin")` — 13pt
- Color: `quixoteBlueMuted` when `isPinned`, `quixoteTextSecondary` when not
- On tap: calls `onPinCurrent?()`
- Tooltip: "Save to PROMPTS" / "Saved to PROMPTS"

**"FROM:" attribution label** (shown below `QuixoteRowDivider`, before MODEL section, only when non-nil):
```
[pin.fill icon 10pt, quixoteTextMuted] FROM: SUMMARIZE  ← uppercase, 10pt, monospaced, tracking 1.4em, quixoteTextMuted
```

---

## Part 2 — Data Model Changes (`Models.swift`)

### New: `PinnedPrompt` struct

```swift
struct PinnedPrompt: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var systemMessage: String
    var template: String
    var createdAt: Date
    var updatedAt: Date

    init(name: String = "New prompt", systemMessage: String = "", template: String = "") {
        id = UUID(); self.name = name; self.systemMessage = systemMessage
        self.template = template; createdAt = Date(); updatedAt = Date()
    }
}
```

### Modified: `Prompt` struct

Add optional fields for the "FROM:" attribution:
```swift
var fromPinName: String? = nil
var fromPinID: UUID? = nil
```
Add `decodeIfPresent` in custom `init(from:)` and a new `CodingKeys` case. Backward-compatible (nil on old data).

Also add:
```swift
var isPinned: Bool = false
var pinnedPromptID: UUID? = nil
```
So the filled pin icon state survives app restart and can remain tied to a specific reusable prompt. Same `decodeIfPresent` treatment.

Do not rely on `isPinned` alone. A boolean cannot handle rename/delete/duplicate semantics or identify which pinned prompt a dataset tab came from. Treat `isPinned` as derived/display state from `pinnedPromptID` where practical.

### Modified: `InterpolationEngine`

Update the shared parser/expander so the pinned prompt UI and runtime agree:

- `tokens(in:)` trims whitespace inside braces and supports the same syntax the UI advertises, including `{{ column_name }}`
- Token detection can scan both `systemMessage` and `template`
- If system-message interpolation is desired, add a shared helper that expands both fields before API calls. Today only `prompt.template` is expanded; `prompt.systemMessage` is passed to providers unchanged.
- Keep unknown tokens visible in output, but expose a validation helper such as `missingTokens(in:columns:)` for the Run on... popover.

---

## Part 3 — ViewModel Changes

### New: `PinnedPromptsViewModel.swift`

`@MainActor final class PinnedPromptsViewModel: ObservableObject`

```swift
@Published private(set) var prompts: [PinnedPrompt] = []

func addPrompt(name:systemMessage:template:) -> UUID
func update(_: PinnedPrompt)      // touches updatedAt
func rename(id:name:)
func delete(id:)
func duplicate(id:) -> UUID       // appends " copy", returns new id
func prompt(for id: UUID) -> PinnedPrompt?
```

- Persists to `pinned-prompts.json` in Application Support
- On first load (file absent): seeds 4 default starters:
  - **Summarize** — "You are a concise summarizer. No preamble, no apology." / "Summarize the following in 3 bullet points:\n{{text}}"
  - **Classify sentiment** — "Reply with one label and nothing else." / "Classify sentiment as: positive, neutral, negative.\n\n{{text}}"
  - **Extract entities** — "Return JSON only." / "Extract entities as JSON array of {name, type}.\n\n{{text}}"
  - **Translate to English** — "Translate faithfully. Preserve tone. Return only the translation." / "Translate to English:\n\n{{text}}"
- 250ms debounced atomic write (same pattern as `PromptListViewModel`)

### Modified: `PromptListViewModel`

Add two methods:

```swift
// Used by runPinOnDataset in MainWindow
func addPromptFromPin(name: String, systemMessage: String, template: String, fromPinID: UUID, fromPinName: String)

// Used by pinCurrentTab in MainWindow
func markCurrentPromptAsPinned(pinnedPromptID: UUID)
```

### Modified: `MainWindow`

New state:
```swift
@StateObject private var pinnedPrompts = PinnedPromptsViewModel()

private enum SidebarSelection: Equatable {
    case data(UUID)
    case pinnedPrompt(UUID)
}

@State private var sidebarSelection: SidebarSelection? = nil
```

New helper functions:
```swift
private func runPinOnDataset(_ pin: PinnedPrompt, fileID: UUID) {
    sidebarSelection = .data(fileID)
    workspace.selectedFileID = fileID
    promptList.addPromptFromPin(name: pin.name, systemMessage: pin.systemMessage,
                                 template: pin.template, fromPinID: pin.id, fromPinName: pin.name)
}

private func pinCurrentTab() {
    guard let prompt = promptList.selectedPrompt, !prompt.isPinned else { return }
    let pinID = pinnedPrompts.addPrompt(name: prompt.name, systemMessage: prompt.systemMessage,
                                        template: prompt.template)
    promptList.markCurrentPromptAsPinned(pinnedPromptID: pinID)
}
```

`onChange(of: sidebarSelection)`: if `.pinnedPrompt` → cancel processing and clear displayed results/derived view models, but leave `workspace.selectedFileID` untouched so the last dataset can restore on restart.

`onChange(of: workspace.selectedFileID)`: set `sidebarSelection = .data(id)` when the selected file changes through file open/drop/restore, then use the existing `loadSelectedFile()` path. Do not manually call `loadSelectedFile()` immediately after assigning `workspace.selectedFileID`; `MainWindow` already loads in its `onChange`.

Middle pane switch (replaces static `PromptEditorView`):
```swift
if case .pinnedPrompt(let pinnedID) = sidebarSelection,
   let pin = pinnedPrompts.prompt(for: pinnedID) {
    PinnedPromptEditorView(prompt: pin, pinnedPrompts: pinnedPrompts, workspace: workspace,
                           onRunOn: { fid in runPinOnDataset(pin, fileID: fid) })
} else {
    PromptEditorView(..., isPinned: promptList.selectedPrompt?.isPinned ?? false,
                     fromPinName: promptList.selectedPrompt?.fromPinName,
                     onPinCurrent: pinCurrentTab)
}
```

Right pane — wrap `DataTableView` in a conditional:
```swift
if case .pinnedPrompt(let pinnedID) = sidebarSelection,
   let pin = pinnedPrompts.prompt(for: pinnedID) {
    PinnedPromptEmptyPane(pin: pin)
        .frame(minWidth: 580, maxWidth: .infinity)
} else {
    DataTableView(...) // unchanged
}
```

---

## Part 4 — Critical Path

Build in this order (each step compiles cleanly before proceeding):

| Step | File(s) | What |
|------|---------|------|
| 1 | `Models.swift` | Add `PinnedPrompt` struct; add `fromPinName`, `fromPinID`, `isPinned`, `pinnedPromptID` to `Prompt` |
| 2 | `InterpolationEngine.swift` | Normalize token detection/validation so UI and runtime agree |
| 3 | `PinnedPromptsViewModel.swift` | New file — CRUD + persistence + default seeding |
| 4 | `PromptListViewModel.swift` | Add `addPromptFromPin` + `markCurrentPromptAsPinned` |
| 5 | `PromptEditorView.swift` | Add pin button to tab strip; add FROM: label; add `isPinned`/`fromPinName`/`onPinCurrent` params |
| 6 | `PinnedPromptEmptyPane.swift` | New file — right pane empty state (no external deps) |
| 7 | `PinnedPromptEditorView.swift` | New file — full editor with Run on... popover |
| 8 | `SidebarView.swift` | Rename DATA section, add PROMPTS section, move + button |
| 9 | `MainWindow.swift` | Wire `SidebarSelection`, pinned prompts state, and conditional panes |
| 10 | `project.yml` / generated Xcode project | Run `make generate` if new Swift files are not picked up automatically, then build |

---

## Open Questions

Resolved from current design/repo:

1. **"+" in main header**: Remove it from the main Quixote header. The design kit puts add buttons in DATA and PROMPTS section headers.

2. **`isPinned` persistence**: Persist it, but pair it with `pinnedPromptID` so the app can identify which reusable prompt owns the filled state.

Still needs a product call:

1. **Delete/rename propagation**: If a pinned prompt is renamed or deleted, should existing dataset tabs with `fromPinID` update their FROM label, keep the historical `fromPinName`, or clear the relationship?

2. **System-message interpolation**: Should `{{column}}` tokens in system messages expand at runtime? The pinned editor detects them, but the current provider path only expands prompt templates unless we update runtime expansion.

3. **Keyboard shortcut**: The UI mentions `⌘⇧P`. Add a real app command/notification for "New Pinned Prompt" or remove the shortcut from tooltips.

---

## Verification

1. `make generate` after adding new Swift files, if needed
2. `make build` — clean compile
3. Launch — sidebar shows DATA + PROMPTS sections with 4 default starters
4. Click a pin → middle pane = PinnedPromptEditorView, right pane = PinnedPromptEmptyPane, last dataset selection is not erased from workspace persistence
5. Edit name/system/prompt → persists across restart
6. Type `{{foo}}` and `{{ foo }}` → one normalized `foo` chip appears in REQUIRED VARIABLES
7. "Run on…" → popover shows open files and warns/blocks when required variables are missing from a target dataset
8. Pick a dataset → app navigates to file through existing `workspace.selectedFileID` onChange path, new tab named after pin, "FROM:" label visible, model card present, system+prompt copied
9. In a dataset tab: pin button → fills blue, pin appears in PROMPTS sidebar, state persists across restart via `pinnedPromptID`
10. Delete pin via context menu → removed from sidebar, editor cleared if selected, existing dataset tabs follow the chosen delete/rename propagation rule
11. Quit while viewing a pinned prompt, reopen → previous dataset selection still restores

---

## GSTACK REVIEW REPORT

| Run | Status | Findings |
|-----|--------|----------|
| — | NO REVIEWS YET — run `/autoplan` | — |
| — | — | — |
| — | — | — |
| — | — | — |
| — | — | — |
