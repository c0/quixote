# Stats Panel Drawer

## Summary

This document specifies a replacement for the current summary-card treatment at the bottom of the table area. The new stats panel is a bottom rail that stays visible whenever there is run or result data, shows a compact overview row by default, and expands into a taller drawer when the user clicks a section.

The panel always summarizes the full active dataset/run. It does not re-scope its headline metrics based on the selected prompt.

The visual system and layout direction in this spec are derived from `docs/plans/stats-drawer-mock.html` and `docs/plans/StatsPanel.jsx`. Those mocks are authoritative for density, spacing, typography, chrome, and overall composition, but they are not authoritative for content, sample values, or section grouping. Implement the Quixote product structure defined here, using the mock only as layout and styling direction.

## Visual System

### Typography

- Section titles and major drawer headers use `Inter Tight`.
- Micro-labels, summary metric labels, numeric values, table headers, and tabular data use `JetBrains Mono`.
- Small labels are uppercase with wide tracking, approximately `0.14em` to `0.20em`.
- Numeric values should use tabular figures wherever possible.
- Summary values are visually denser and larger than their labels.

### Color And Chrome

- Use the existing Quixote dark palette direction:
  - layered charcoal surfaces
  - subtle 1px dividers
  - muted secondary and tertiary label text
  - bright primary text
  - one strong blue accent
  - green for healthy/running/completed
  - red for failures
  - orange for paused or warning states
- The collapsed rail uses the raised-panel tone.
- The expanded drawer body uses the panel tone.
- Inner detail surfaces use card-like containers with thin borders and small corner radii.
- Do not introduce a second visual theme for the drawer. It should feel like a denser extension of the existing table/results area.

### Spacing And Sizing

- Collapsed rail height is `44px`.
- Summary modules use `14px` horizontal padding.
- Summary modules are separated by vertical dividers.
- Expanded drawer padding is approximately `14px 14px 16px`.
- Detail cards use small radii around `6px`.
- Action controls use tighter radii around `4px`.
- Subsection headers sit above cards with about `8px` bottom spacing.

## Layout And Interaction

- The stats panel sits directly under the table as a bottom rail.
- The rail is visible whenever there is run or result data for the active dataset.
- The collapsed state shows one horizontal row of summary sections:
  - Progress
  - Throughput
  - Latency
  - Tokens
  - Cost
  - Similarity
  - Errors
- Each summary section is clickable.
- Only one section can be expanded at a time.
- Clicking a collapsed section expands the drawer and reveals a full-width detail region below the summary row.
- Clicking the already-expanded section collapses the drawer back to the compact height.
- Clicking a different section while expanded keeps the drawer open and swaps the detail content in place.
- The drawer height increases only when a section is expanded.
- The summary row remains visible while the drawer is expanded.

## Summary Row Design

- Each summary section is visually structured as:
  - a tiny label row
  - a larger value row
- Labels are mono, uppercase, muted, and compact.
- Values are mono, brighter, slightly larger than labels, and visually dense.
- Summary modules are divider-separated rather than individual pill cards.
- Progress includes an inline thin bar, not a large stacked progress block.
- Latency includes an inline sparkline to the right of the metric values.
- The leading progress area may include a status dot derived from run state:
  - green for running or done
  - orange for paused
  - red for failed-heavy or error state
  - muted neutral for idle

### Progress

- Display `completed / total`.
- Display a percentage progress bar based on completed rows divided by total rows.
- Show the percentage with one decimal place.

### Throughput

- Label should read `Throughput`.
- Display `x.x rows/s`.
- Throughput is dataset-wide and based on completed rows over elapsed processing time.
- If elapsed time is zero or no rows are completed, display `-`.

### Latency

- Label should read `Latency P50 / P90`.
- Display `P50 / P90 ms`.
- Include a compact sparkline rendered from recent per-result latency samples in completion order for the active dataset.
- If there are no completed latency samples, display `-` for both values and render an empty sparkline state.

### Tokens

- Label should read `Tokens In/Out`.
- Display `input / output`.
- Summary-row token values are abbreviated using K and M suffixes, for example `1.0M / 2.1K`.

### Cost

- Label should read `Cost`.
- Display the dataset-wide running total cost in dollars.
- Summary-row cost values may be abbreviated using K and M suffixes, for example `$1.2K`.

### Similarity

- Label should read `Similarity`.
- Display a compact median similarity summary using cosine and ROUGE.
- Use `cosine` terminology everywhere.
- Never use `cosign`.

### Errors

- Label should read `Failed` or `Errors`, whichever best fits the final summary-row width.
- Display the total failed-result count for the active dataset.

## Expanded Drawer Design

- The expanded area is a full-width drawer below the summary row.
- Use a raised dark drawer with card-based detail panels.
- Use a grid/card composition inspired by the mock, but adapt it to the final Quixote sections.
- Do not copy the mock’s `Per model / Usage / Errors` content layout literally.
- Reuse only its:
  - density
  - spacing
  - card treatment
  - border style
  - alignment
  - section-header style

### Expanded Layout Modes

- Use a table-first layout for:
  - Progress
  - Throughput
  - Latency
  - Similarity
- Use a split-card layout where appropriate for:
  - Tokens
  - Cost
  - Errors
- Tokens and Cost may include supporting mini-bars or headline stat cards above or beside the required table, as long as:
  - the required table remains present
  - the table values remain full-width and unabbreviated

### Card And Table Style

- Expanded tables use a raised header strip.
- Table headers are mono, uppercase, compact, and muted.
- Numeric columns are right-aligned.
- Label columns are left-aligned.
- Alternating row backgrounds may be used subtly to improve scanability.
- Empty states use centered muted mono text inside the card body.
- Error rows use a small colored status dot at the left edge.
- The retry button uses:
  - transparent background
  - thin border
  - tight radius
  - uppercase label
  - restrained weight

## Expanded Sections

All expanded sections render in the full-width detail area below the summary row.

Expanded tables are sorted exactly as the user sees results in the UI:

- prompts left to right
- then models top to bottom within each prompt

Do not re-sort expanded tables by latency, cost, token count, similarity, or error count.

### Progress

Display a table with these columns:

| Column | Notes |
|---|---|
| Prompt Name | Preserve prompt order as shown in the UI, left to right |
| Model Name | Preserve model order as shown in the UI, top to bottom within each prompt |
| Completed Rows | Raw count |
| Failed Rows | Raw count |
| Total Rows | Raw count |
| Percent Complete | One decimal place |

### Throughput

Display a table with these columns:

| Column | Notes |
|---|---|
| Prompt Name | UI order |
| Model Name | UI order |
| Completed Rows | Raw count |
| Elapsed Time | Seconds |
| Current Rows/s | One decimal place |
| Lifetime Average Rows/s | One decimal place |

### Latency

Display a table with these columns:

| Column | Notes |
|---|---|
| Prompt Name | UI order |
| Model Name | UI order |
| Rows | Completed row count |
| P50 ms | One decimal place |
| P90 ms | One decimal place |
| P99 ms | One decimal place |

The collapsed summary sparkline uses recent per-result latency samples in completion order for the active dataset.

### Tokens

Display a table with these columns:

| Column | Notes |
|---|---|
| Prompt Name | UI order |
| Model Name | UI order |
| Rows | Completed row count |
| Input Tokens | Raw full value |
| Output Tokens | Raw full value |
| Running Total | Input + output |
| Est 1K In | Projection |
| Est 1K Out | Projection |
| Est 1K Total | Projection |
| Est 1M In | Projection |
| Est 1M Out | Projection |
| Est 1M Total | Projection |

### Cost

Display a table with these columns:

| Column | Notes |
|---|---|
| Prompt Name | UI order |
| Model Name | UI order |
| Rows | Completed row count |
| Input Cost | Raw full value |
| Output Cost | Raw full value |
| Running Total | Input + output |
| Est 1K In | Projection |
| Est 1K Out | Projection |
| Est 1K Total | Projection |
| Est 1M In | Projection |
| Est 1M Out | Projection |
| Est 1M Total | Projection |

### Similarity

Display a table with these columns:

| Column | Notes |
|---|---|
| Prompt Name | UI order |
| Model Name | UI order |
| Rows | Completed row count |
| Median Cosine | One decimal place |
| Median ROUGE-1 | One decimal place |
| Median ROUGE-2 | One decimal place |
| Median ROUGE-L | One decimal place |

### Errors

Display a table with these columns:

| Column | Notes |
|---|---|
| Error Code | Normalized code such as `rate_limit`, `auth`, `network`, `server`, `unknown` |
| Model Name/Version | Use the exact model identity shown in the run context |
| Count | Raw count |

Also include a `Retry Failed` button wired to the existing retry-failed action.

If there are no failures:

- show `0` in the collapsed summary
- show an empty-state message in the expanded Errors section
- disable the retry button

## Formatting Rules

### Summary Row Formatting

- Summary-row numeric values use one decimal place.
- Summary-row values may use K and M abbreviations.
- Examples:
  - `1.0M`
  - `2.1K`
  - `$1.2K`
  - `4.3 rows/s`

### Expanded Table Formatting

- Expanded-table numeric values are never abbreviated.
- Expanded-table numeric values use comma separators.
- Expanded-table numeric values use one decimal place where relevant.
- Examples:
  - `1,234`
  - `12,345.6`
  - `$1,234.5`
- Empty or null values display `-`.
- Latency values are always shown in milliseconds.
- Currency values always use a `$` prefix.

### Projection Rules

- Estimated 1K and 1M values are derived from completed rows only.
- Formula:
  - `(running total / completed rows) * target scale`
- If completed rows is zero, show `-` for all projected values.

## Required Data Additions

Implementation for this drawer requires stats aggregation beyond the current summary model.

Add support for:

- Dataset-wide throughput
- Per prompt/model P90 latency
- Per prompt/model P99 latency
- Input token totals
- Output token totals
- Input cost totals
- Output cost totals
- Grouped error-code counts
- Recent latency series for the sparkline
- Drawer UI state:
  - collapsed vs expanded
  - expanded section id
  - single-open-section behavior

## Empty And Zero States

- If there are no completed rows:
  - throughput displays `-`
  - latency percentiles display `-`
  - similarity displays `-`
  - projected values display `-`
- If a table cell value is empty or null, display `-`.
- If there are no failures:
  - collapsed Errors shows `0`
  - expanded Errors shows an empty-state message
  - `Retry Failed` is disabled

## Acceptance Criteria

- The spec explicitly describes a `44px` collapsed rail and a taller expanded drawer.
- The spec distinguishes mock-derived styling from final content requirements.
- The collapsed drawer renders all summary sections as divider-separated compact metric cells with inline labels and values.
- The spec preserves these functional constraints:
  - one expanded section at a time
  - dataset-wide summary metrics
  - UI-order sorting
  - full comma-formatted numbers in expanded tables
  - `-` for empty or null values
  - `cosine` terminology
- Expanded sections specify visual treatment for:
  - card borders
  - mono table headers
  - right-aligned numeric columns
  - muted empty states
  - bordered retry action
- The spec makes clear that mock content is non-binding and only layout and design tokens are to be reused.
