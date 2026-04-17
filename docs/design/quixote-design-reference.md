# Quixote Design Reference

Saved from user-provided references on 2026-04-14.

## Assets

- Main UI reference: [quixote-ref-main.png](/Users/czero/src/quixote-swift/docs/design/quixote-ref-main.png)
- Tabs crop: [quixote-ref-tabs.png](/Users/czero/src/quixote-swift/docs/design/quixote-ref-tabs.png)
- Actions crop: [quixote-ref-actions.png](/Users/czero/src/quixote-swift/docs/design/quixote-ref-actions.png)
- Token source: [quixote-theme-reference.css](/Users/czero/src/quixote-swift/docs/design/quixote-theme-reference.css)

## Design Summary

The reference is a dense desktop workspace with a dark shell and a three-pane layout:

- Left sidebar for app identity and datasets.
- Center prompt editor with tabs, stacked model boxes, variable chips, system message, and prompt composer.
- Right results table with a sticky header and top-right primary actions.

The UI aims for a quiet, technical, data-tool feel rather than a marketing or consumer look. Contrast is driven by dark neutrals, thin dividers, muted labels, and one strong blue action color.

## Visual Language

- Base mode in the screenshots is dark.
- Surfaces are layered with very small deltas between shell, panel, card, and active states.
- Corners are consistently rounded; controls trend toward pill or rounded-rect shapes.
- Borders are thin and low-contrast, used heavily to define panes and rows.
- Accent color is a saturated blue used almost exclusively for the main `Run` CTA and blue data links/boolean values.
- Success/status color should be used sparingly; avoid redundant status lines inside model boxes.

## Color Cues From The References

Approximate usage based on the screenshots:

- App background: near-black / charcoal.
- Panel background: slightly lifted charcoal.
- Active pills and selected rows: medium-dark gray.
- Body text: off-white / cool light gray.
- Secondary text and chrome icons: desaturated blue-gray.
- Grid lines and borders: low-contrast gray.
- Primary action: vivid blue.
- Positive metadata: green.
- Interactive table values: bright blue.

The raw token set is preserved verbatim in [quixote-theme-reference.css](/Users/czero/src/quixote-swift/docs/design/quixote-theme-reference.css).

## Typography

The reference uses a modern sans-serif system/UI style with these patterns:

- Large product/file titles are bold and compact.
- Section labels are uppercase with generous letter spacing.
- Tab labels are medium-weight; active tabs increase contrast and sit on a filled pill.
- Table headers are uppercase monospace or mono-adjacent in feel, with spaced lettering.
- Table body values use a mono-like look for numbers and booleans.
- Button labels are uppercase, bold, and highly legible.

Practical translation for implementation:

- Use a clean UI sans for interface text.
- Use a monospace face selectively for tabular data, dataset metadata, and headers where alignment matters.
- Keep type mostly in the 12px to 16px range with heavier weight reserved for titles and primary actions.

## Layout Breakdown

### 1. App Shell

- Full-window dark canvas.
- Mac-style traffic-light controls at top left.
- Vertical separators divide sidebar, editor, and table.
- Top toolbar spans editor and results area.

### 2. Sidebar

- Fixed-width column.
- Top row contains app mark, app name, and add action.
- Dataset list below, with each row using icon + label.
- Selected dataset is shown with a filled rounded rectangle.

### 3. Prompt Tabs

- Horizontal tab strip above the editor.
- Inactive tabs are simple text with close affordance.
- Active tab becomes a filled rounded pill.
- A plus button sits beside the tab list for adding prompts.

### 4. Prompt Editor

- Structured as stacked sections with generous vertical spacing.
- `MODEL` section contains one or more stacked model boxes, each with a single model, its own settings, and add/remove affordances.
- `VARIABLES` section uses compact rounded chips in a flowing wrap layout.
- `SYSTEM MESSAGE` and `PROMPT` use large dark text areas with subtle borders.
- Labels are uppercase and widely tracked, which gives the editor a control-panel feel.
- Detailed per-model settings stay hidden until the settings toggle is opened for that box.

### 5. Results Table

- Dominant pane, taking the majority of horizontal space.
- Header shows dataset name with a smaller metadata line beneath it.
- Top-right actions contain secondary `Download` and primary `Run`.
- Data grid uses strong vertical structure and faint horizontal row dividers.
- Boolean values are highlighted in blue; long text outputs are truncated.

## Control Patterns

- Primary button: filled vivid blue rounded rectangle with icon + uppercase label.
- Secondary button: dark outlined rounded rectangle with icon + uppercase label.
- Chips: rounded pills with muted fill and small close affordance.
- Cards/inputs: dark surfaces with subtle inner contrast and 1px border treatment.
- Icons are thin-stroked and understated.

## Implementation Notes

- Preserve the three-pane composition first; it is the defining structural element.
- Keep borders subtle. The design relies on separation through rhythm and linework, not heavy shadows.
- Avoid bright accent overuse. Blue should stay reserved for the highest-priority interaction and specific data states.
- Favor compact spacing and dense information presentation over large empty areas.
- Use truncation for table output and maintain a fixed, grid-like rhythm in the data pane.

## Embedded References

![Main Quixote reference](/Users/czero/src/quixote-swift/docs/design/quixote-ref-main.png)

![Tabs reference](/Users/czero/src/quixote-swift/docs/design/quixote-ref-tabs.png)

![Actions reference](/Users/czero/src/quixote-swift/docs/design/quixote-ref-actions.png)
