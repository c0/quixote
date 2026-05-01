# Quixote Design System

A design system for **Quixote** — a fast, keyboard-driven macOS desktop tool for enriching structured data files (CSV / TSV / JSON / Excel) with LLMs. Users open a file, write prompt templates that interpolate column values, fan each row across one-or-more models, watch results stream into an inline table, and export the enriched file.

The product has two surfaces:

1. **Quixote app** — the SwiftUI macOS application. A three-pane desktop workspace (sidebar → prompt editor → results table). This is where 95% of the visual language lives: dense dark chrome, monospace data grids, a single vivid-blue action color.
2. **Quixote site** — a tiny Astro marketing site at `c0.github.io/quixote`. One hero page: logo, title, tagline, Download-for-macOS CTA. Visually different from the app — floating pill buttons over an animated dithered background — but reading from the same dark palette.

## Sources

All references are preserved in `assets/` and `preview/` for reuse.

- **Codebase** (read-only mount): `quixote-swift/`
  - SwiftUI views: `quixote-swift/Quixote/Views/` — `QuixoteTheme.swift` is the authoritative color/spacing source
  - Functional spec: `quixote-swift/SPEC.md`
  - Marketing site: `quixote-swift/site/src/`
- **Design reference doc**: `uploads/design/quixote-design-reference.md`
- **Token reference CSS** (shadcn-flavored, informational only — the app itself uses the Swift theme): `uploads/design/quixote-theme-reference.css`
- **Reference screenshots**: `assets/ref-main.png`, `assets/ref-tabs.png`, `assets/ref-actions.png`
- **App icon (dithered portrait of Don Quixote)**: `assets/icon-dither.png`, `assets/icon.png`, plus `assets/icon-{32,64,128,256,512}.png`

## Index

| File / folder | What's in it |
|---|---|
| `colors_and_type.css` | CSS custom properties for colors, radii, spacing, type roles (section-label, table-header, button, etc.) |
| `assets/` | Logos, icons at all sizes, dither background image, reference screenshots |
| `preview/` | Small HTML cards used by the Design System review tab (one concept per card) |
| `ui_kits/app/` | Quixote desktop app UI kit — JSX components + `index.html` click-thru |
| `ui_kits/site/` | Marketing site UI kit — JSX components + `index.html` |
| `SKILL.md` | Agent Skills front-matter for cross-compatibility with Claude Code |

---

## Content Fundamentals

Quixote's voice is **quiet, technical, literal**. It is a tool for engineers who run LLMs at scale. No marketing fluff, no emoji, no exclamation points.

**Tone & casing**
- Sentence case for body copy and descriptions. Uppercase is reserved for two jobs: section labels (`MODEL`, `VARIABLES`, `SYSTEM MESSAGE`, `PROMPT`) and button labels (`RUN`, `DOWNLOAD`, `PAUSE`, `CANCEL`, `RESUME`, `RETRY FAILED`).
- Column names in the table stay in the file's own casing (snake_case from the CSV: `cost_per_item`, `included_unit`) but are displayed uppercase in the table header.
- Brand name is always `Quixote`, never `quixote` or `QUIXOTE`.

**Point of view**
- Third-person/neutral for system messages: "No dataset loaded", "Access could not be restored", "File unavailable", "12 rows · 24 columns".
- Second-person imperative for empty states and CTAs: "Open a file from the sidebar to preview its contents", "Add a prompt to start building prompt variants for this file", "Describe desired model behavior (tone, tool usage, response style)".
- First-person never appears. Never "I'll run this for you" — always "RUN".

**Vibe**
- Terse. Labels are 1–2 words. Long strings are for help text only.
- Technical/literal naming. Not "AI Magic Wand" — `MODEL` / `PROMPT` / `VARIABLES`.
- Numbers are citizens: `12 ROWS · 24 COLUMNS`, `Temp 1.00`, `Max Tokens Auto`, `SIM 0.847`. Numbers use the middle-dot `·` as a separator, not pipes or slashes.
- Placeholder examples demonstrate real usage, e.g. system message prompt `"Describe desired model behavior (tone, tool usage, response style)"` and prompt template `"Summarized in 3 bullet points:\n{{body_html}}"`.
- **No emoji.** Icons are SF Symbols glyphs, monochrome, thin-stroke. Unicode separators (`·`, `—`) are fine.
- Errors are factual, one-line: "Access lost", "Missing", "Unreadable". No "Oops!", no exclamation points.

**Site copy** (the one marketing surface, `site/src/pages/index.astro`) is equally terse:
- Title: `Data Quixote`
- Tagline: `Run multiple LLM prompts on any set of data. Iterate and refine.`
- Meta line: `1.0.0 · macOS Sonoma or later · Free`
- Footer: `© 2026 · Open source under MIT`

---

## Visual Foundations

**Mode** — Dark, always. Light tokens exist in the shadcn reference CSS but the shipped app is dark-only (`.preferredColorScheme(.dark)` in `MainWindow.swift`).

**Colors** — Five narrow bands and one accent:
- Neutrals: five near-black greys separated by only 2–4% luminance deltas (`--qx-app-bg` → `--qx-panel` → `--qx-panel-raised` → `--qx-card` → `--qx-selection`). Surfaces are distinguished by these micro-deltas plus 1px `rgba(255,255,255,0.08)` dividers — not by shadows.
- Text: three greys (`--qx-fg-1` near-white, `--qx-fg-2` desaturated blue-grey for secondary + icon chrome, `--qx-fg-3` for muted/placeholder/row-index).
- Accent: exactly one saturated blue (`#306BF0`), reserved for the **RUN** button and — as a lighter `--qx-blue-muted` — for interactive/boolean values inside table cells.
- Semantic: green (running model dot, success), red (failed rows, destructive confirm), orange (warning — file access lost).
- Do **not** introduce new accents. If you need a new status color, use the existing semantic four.

**Typography** — Two families:
- **Sans** for UI, buttons, titles. App uses system SF Pro; web substitute is **Inter Tight** (closest geometric proportions and letter-spacing behavior).
- **Mono** for table data, chips, dataset metadata, uppercase table headers, numeric metrics. App uses system SF Mono; web substitute is **JetBrains Mono**.
- Note: fonts are referenced via Google Fonts CDN rather than bundled `.ttf` files. If bundling is required for offline use, the design system will need updated font files — FLAGGED.
- Size scale is tight: 10 / 11 / 12 / 13 / 14 / 15 / 16 / 18px. Anything bigger is marketing-site territory.
- **Uppercase + tracked** is the defining type move. Every section label, button label, table column header, and meta line gets `text-transform: uppercase` with `letter-spacing` ~0.1–0.2em. This single treatment does most of the visual work.

**Spacing** — Tight, control-panel density. The app's canonical scale (`QuixoteSpacing`): `2 / 4 / 6 / 8 / 10 / 12 / 14 / 18px`. `14` for shell padding, `18` for pane inset and section gap. The marketing site is the only place things breathe (`24 / 56 / 80 / 96px`).

**Radii** — `6px` is the house radius; `4px` for the smallest controls (chips, tiny buttons); `2px` for hairline details. The marketing site adds `999px` pill buttons and `10px` cards. No sharp corners anywhere.

**Backgrounds**
- App: flat dark neutrals. No images, no gradients on UI chrome.
- Marketing site: full-viewport **dithered Bayer-ordered canvas animation** (`DitherBackground.astro`) — a slow organic field in six pixel tones from near-black to near-white at 12fps, 2–2.5px "cell" size, with a radial vignette overlay. This dither is the single distinctive marketing motif.
- App icon itself reuses the same dither aesthetic — a halftone-dithered profile of Don Quixote on pure black with a rounded-rect mask.

**Animation** — Minimal. The site uses 160ms ease-out transitions for hover (`transform: translateY(-1px)` on buttons) and `scale(0.98)` on active press. The app is SwiftUI-default — no custom springs, no bounces. The one long-running animation is the dither canvas, and it's background ambience, not interaction feedback.

**Hover states** — Buttons: `opacity 0.85` on press. Secondary buttons on site: border/bg lightens slightly. Table rows alternate with `panel-raised @ 45%` opacity as a zebra (not a hover). Icons in chrome shift from `fg-2` to `fg-1` on hover. No color shifts beyond the built-in opacity steps.

**Press states** — Opacity drop to 0.85, or `scale(0.98)` on site buttons. No color shifts, no ripples.

**Borders** — Universally 1px, low-contrast `rgba(255,255,255,0.08–0.1)`. Cards, inputs, buttons, dividers, the whole grid — everything uses the same divider weight. The app's three panes are separated by `QuixotePaneDivider` — 1px vertical of that same color. There is **no heavier border treatment** anywhere.

**Shadows** — The app uses **none**. Surface hierarchy comes from luminance steps, not drop shadows. The marketing site has exactly two: `0 24px 80px rgba(0,0,0,0.45)` on floating panels and `0 18px 38px rgba(0,0,0,0.4)` on the hero logo. Keep shadow usage *extremely* restricted.

**Transparency / blur** — The app itself is opaque. The marketing site panels use `rgba(10,12,16,0.72)` with the dither visible behind. No explicit `backdrop-filter: blur` in code — panels just layer over the fixed dither canvas with alpha.

**Cards** — `--qx-card` fill + 1px `--qx-divider` border + `--qx-radius-md` (6px). Flat. No shadow, no colored left-border accent, no hover lift in the app. Cards live inside panes that live inside the shell — the nesting itself creates hierarchy.

**Layout rules**
- App: fixed three-pane `HSplitView`. Sidebar 220–240px, prompt editor 400–500px, results pane takes the rest. Minimum window 1240×760.
- Vertical rhythm inside the prompt editor: section label → control, stacked with `--qx-space-8` (18px) between sections and `--qx-space-5` (10px) between a label and its control.
- Site: centered column, `max-width: 720px`, `padding: 96px 24px 56px`.

**Imagery vibe** — Cool, desaturated, monochrome. The dither palette is pure greyscale. The app itself contains no photography. Don Quixote icon = high-contrast black & white halftone. If you need illustrative imagery, match this black-and-white dithered register — not warm, not color-graded, not tinted blue.

**Data display**
- Table rows: alternating background (`panel-raised @ 45%`), 1px `--qx-divider` between cells, mono for values, uppercase mono for headers.
- Boolean values render in `--qx-blue-muted` (`true` / `false` as blue text, not badges).
- Numeric values look mono by default; detected numbers get `design: .monospaced`.
- Row index is right-aligned mono in `--qx-fg-3`.

---

## Iconography

Quixote iconography comes almost entirely from **Apple's SF Symbols** set, rendered natively inside SwiftUI. Because this design system runs on the web, we substitute with **Lucide** from the CDN — Lucide has near-identical thin-stroke geometry and covers every SF Symbol used in the app. **This is a substitution — flagged for review** if pixel-exact match is required.

**Mapping from SF Symbols → Lucide** (what actually appears in the code):

| Usage in app | SF Symbol | Lucide substitute |
|---|---|---|
| Sidebar: add file | `plus` | `plus` |
| Sidebar: CSV file icon | `tablecells` | `table-2` |
| Sidebar: JSON file | `curlybraces` | `braces` |
| Sidebar: Excel file | `tablecells.badge.ellipsis` | `table-properties` |
| Sidebar: unknown file | `doc.text` | `file-text` |
| Sidebar: file missing | `questionmark.folder` | `folder-search` |
| Sidebar: access lost | `exclamationmark.triangle` | `triangle-alert` |
| Sidebar: unreadable | `doc.badge.xmark` | `file-x-2` |
| Tab close | `xmark` | `x` |
| Model card: settings toggle | `slider.horizontal.3` | `sliders-horizontal` |
| Model card: delete | `trash` | `trash-2` |
| Model picker: selected | `checkmark.circle.fill` | `circle-check-big` |
| Model picker: unselected | `circle` | `circle` |
| Menu chevron | `chevron.down` | `chevron-down` |
| Pagination | `chevron.left` / `chevron.right` | `chevron-left` / `chevron-right` |
| Primary RUN button | `play` | `play` |
| Download | `arrow.down.to.line` | `download` |
| Set API key warning | `key.fill` | `key-round` |
| Retry error | `exclamationmark.triangle.fill` | `triangle-alert` (fill via color) |
| Cancelled state | `slash.circle` | `ban` |

**Usage rules**
- All icons are **monochrome**. Color comes from the surrounding foreground role (`--qx-fg-1/2/3`) — icons never bring their own color.
- Sizes: 9–11px inside buttons/chips, 13–14px in rows, 15–17px for action buttons, 24px for the sidebar brand mark.
- Stroke weight: match Lucide's default (`stroke-width: 2`). Don't mix weights.
- Icons always pair with a label in buttons (`[icon] RUN`, `[icon] DOWNLOAD`). Icon-only buttons exist only for micro-actions (tab close, add-plus, delete-trash).

**Emoji / Unicode**
- Emoji: **never**. Not in copy, not in icons, not in empty states.
- Unicode separators (`·`, `—`, `×`, `✓`) are acceptable when they read better than an SVG — e.g. `12 ROWS · 24 COLUMNS`.

**Brand mark**
- Primary: the dithered Don Quixote portrait at `assets/icon-dither.png` (also available as `icon.png` and size-stepped PNGs in `assets/icon-{32..512}.png`).
- In the sidebar, the mark is displayed at 24×24 with a 4px rounded-rect mask plus the wordmark "Quixote" in 15px bold sans.
- On the marketing site, the mark is displayed much larger (up to 280px) with a soft `0 18px 38px rgba(0,0,0,0.4)` drop shadow.

**Illustration**
- The dither canvas (`DitherBackground.astro`) is the one piece of generative brand imagery. It is not static art — it renders in-browser at 12fps. Treat it as the brand's equivalent of a pattern or gradient.

---

## Open items / flags

- **Font substitution** — the app runs on system SF Pro / SF Mono. Web uses Inter Tight + JetBrains Mono via Google Fonts CDN. If pixel-exact fidelity to SF is required, please provide licensed `.ttf` files and we'll bundle them in `fonts/`.
- **Icon substitution** — SF Symbols are substituted with Lucide. The mapping above covers every glyph that appears in the Swift code, but verify visually against any new surfaces that get added.
- **Light mode** — `quixote-theme-reference.css` defines light tokens, but the shipped app is dark-only. We have not produced light-mode variants; ask if needed.
