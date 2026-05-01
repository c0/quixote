# Quixote App UI Kit

A high-fidelity web recreation of the Quixote macOS desktop app. Mirrors `quixote-swift/Quixote/Views/*.swift` pixel-for-pixel using the tokens in `QuixoteTheme.swift`.

## Files

| File | What |
|---|---|
| `index.html` | Clickable three-pane mock. Open this to see everything assembled. |
| `Primitives.jsx` | `QX` token object, `QxIcon` (inlined Lucide glyphs), `QxSectionLabel`, `QxPrimaryButton`, `QxSecondaryButton`, `QxChip`, `QxCard`, dividers. |
| `Sidebar.jsx` | `QxSidebar` + `QxSidebarRow` — left file-list pane (220px fixed). |
| `PromptEditor.jsx` | `QxPromptEditor` (center pane, 440px): tab strip, `MODEL`, `VARIABLES`, `SYSTEM MESSAGE`, `PROMPT`. Includes `QxModelCard`, `QxTextArea`, `QxSegmented`. |
| `ResultsPane.jsx` | `QxResultsPane` — right pane with dataset header, `RUN` + `DOWNLOAD` actions, and `QxDataTable` sticky grid. |

## What's mocked vs real

These components are **visually accurate but functionally thin**:

- Tabs: add / close work; no editing of tab names.
- Models: no real API-models popover; card is display-only (the gear icon is decorative here).
- Variables: chips show columns; no interpolation logic.
- System message / Prompt: editable `<textarea>`s; no preview rendering / no column token popover.
- RUN button: shows the split-button with caret, but no real queue / processing.
- DOWNLOAD: fires an alert.
- Table: receives rows as props; no pagination, sorting, or streaming results.

The implementations are intentionally simple — lift them as styling + markup references, not production logic.

## Extending

- All color / spacing / font tokens come from `QX` in `Primitives.jsx`. Change there, propagate everywhere.
- New icons → add to `QX_ICONS` map (Lucide SVG paths, stroke-width 2).
- New section → use `<QxSectionLabel>` above + 10px gap above the control; 18px gap between sections.

## Known gaps (flagged for user iteration)

- StatsPanel is **not** recreated — it's a secondary surface and wasn't needed for the core triple-pane story. Ask if you want it.
- Settings window is not recreated.
- Model picker popover is not recreated (just the trigger).
