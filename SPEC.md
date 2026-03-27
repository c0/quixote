# Quixote — Functional Specification

> A fast, keyboard-driven macOS desktop tool for enriching CSV data with LLMs.

---

## Table of Contents

1. [Product Overview](#1-product-overview)
2. [File Management](#2-file-management)
3. [Data Preview](#3-data-preview)
4. [Prompt Authoring](#4-prompt-authoring)
5. [Model Selection](#5-model-selection)
6. [Processing & Queue](#6-processing--queue)
7. [Results & Output](#7-results--output)
8. [Statistics](#8-statistics)
9. [Export](#9-export)
10. [Settings](#10-settings)

---

## 1. Product Overview

Quixote lets users take a CSV file and send each row to one or more LLMs using a prompt template, then see the results inline and export them. The core loop is:

1. Open a CSV file.
2. Write a prompt that references column values.
3. Select one or more models.
4. Run — the app processes every row in the background.
5. Export the enriched CSV.

The app is designed for bulk, iterative prompt exploration: running the same data through different prompts or models, inspecting results, adjusting, and re-running.

---

## 2. File Management

### 2.1 Opening Files

- Users open CSV files via the native file picker (`Cmd+O` or `File > Open File...`).
- Files can also be opened by dragging and dropping one or more `.csv` files onto the app window.
- Multiple files can be open simultaneously; each file is independently tracked.
- Re-opening a file that is already loaded is handled gracefully — no duplicates.

### 2.2 File List

- All open files are listed in a sidebar.
- Clicking a file in the list switches to that file's data and prompt.
- The file list is **persistent** — it is restored when the app is relaunched.

### 2.3 Removing Files

- A file can be removed from the list.
- Removing a file clears all associated data (records, results, prompts, history) from the app.
- The original file on disk is not affected.
- If the file being removed is currently selected, the view is cleared.

### 2.4 Change Detection

- The app tracks the content of each CSV file.
- If a file's content changes on disk (detected on reload), the app detects this and invalidates any cached results for that file, prompting a clean re-run.

---

## 3. Data Preview

### 3.1 Table View

- The selected CSV file is displayed as a table with the original columns.
- Each row in the table represents one CSV record.
- Large files are loaded in pages to keep the UI responsive (up to 1,000 rows displayed at a time; all rows are processed during runs).

### 3.2 Row Status

- Each row has a visual status indicator: `pending`, `in-progress`, `completed`, or `failed`.
- Completed rows show the LLM response text inline in the table.
- When multiple models are selected, each model's response is displayed in its own column.

---

## 4. Prompt Authoring

### 4.1 Prompt Template

- Each file has one active prompt (the "default prompt").
- The prompt is plain text authored by the user — these are the LLM instructions.
- Prompts support **column interpolation**: `{{column_name}}` is replaced with that column's value for each row before sending.

### 4.2 Row Context

- Beyond placeholder interpolation, each row's full data is automatically appended to the prompt as a structured data block, so the LLM sees all column values even if they aren't explicitly referenced in the prompt.

### 4.3 Prompt Persistence

- The prompt is saved automatically when edited.
- It is restored when the file is re-selected or the app is relaunched.
- Changing the prompt does not automatically re-run completed rows — the user must explicitly start a new run.

### 4.4 LLM Parameters

The user can configure the following parameters per prompt:

| Parameter | Description |
|---|---|
| Temperature | Controls response randomness (default: 1.0) |
| Max tokens | Maximum output length |
| Top-P | Nucleus sampling |
| Frequency penalty | Penalizes repetition of tokens |
| Presence penalty | Penalizes introducing new topics |

---

## 5. Model Selection

### 5.1 Available Models

- The app fetches the list of available GPT models from the OpenAI API using the user's API key.
- Models are grouped by family (GPT-4, GPT-3.5, etc.) and sorted newest-first.
- The list is refreshed when the API key changes.

### 5.2 Multi-Model Selection

- The user can select **one or more models** simultaneously.
- When multiple models are selected, every row is sent to **each selected model independently**.
- This enables direct model comparison on the same data with the same prompt.
- The model selection is persisted across sessions.

---

## 6. Processing & Queue

### 6.1 Starting a Run

Three processing modes are available:

| Mode | Description |
|---|---|
| **Process all rows** | Sends every row in the file to the selected model(s) |
| **Process N rows** | Sends the first N rows only (useful for sampling/testing) |
| **Process single row** | Sends one specific row (used for retrying a failed row) |

Starting a new run clears any previous results and begins fresh.

### 6.2 Queue Architecture

- Requests are processed via an **internal async queue** — not all rows are sent at once.
- The queue enforces **concurrency limits** (max simultaneous in-flight requests) and **rate limits** (max requests per second) to stay within API limits.
- Default: 2 concurrent requests, 5 requests per second.
- All queue parameters are configurable in Settings.

### 6.3 Asynchronous Processing

- Processing runs entirely **in the background** — the UI remains fully interactive during a run.
- As rows complete, the table updates in real-time without requiring any user action.
- Progress is tracked and displayed continuously.

### 6.4 Pause & Resume

- A run can be **paused** at any time. Requests already in-flight complete; new requests wait.
- A paused run can be **resumed** to continue where it left off.
- The Start button toggles between Start / Pause / Resume depending on queue state.

### 6.5 Cancel

- A run can be **canceled**. Queued requests are removed; in-flight requests are discarded when they complete.
- Cancellation is scoped to the current file — other files' queues are unaffected.

### 6.6 Retry

- Failed rows can be **retried individually** or **all at once**.
- Each row automatically retries up to 3 times before being permanently marked as failed.
- After max retries, the row remains failed and can be manually retried later.

### 6.7 Queue Persistence

- The queue state is **persisted to disk** — if the app quits or crashes during processing, the queue state survives.
- On restart, the user can see which rows completed and which did not, and resume or retry as needed.

### 6.8 Multi-Model Parallelism

- When N models are selected, each row spawns N independent requests.
- All N × rows requests are enqueued together and processed concurrently subject to queue limits.
- Results arrive and are stored per model independently.

---

## 7. Results & Output

### 7.1 Inline Results

- Completed rows display the LLM response text directly in the table.
- Each model's response appears in its own column (e.g., "Output (gpt-4o)", "Output (gpt-4o-mini)").
- Failed rows display the error message.

### 7.2 Result Metadata

Each completed result stores:
- Response text
- Token usage (input, output, total)
- Cost in USD
- Response duration in milliseconds
- Model used
- Cosine similarity score (see §8.3)

### 7.3 Response Caching

- Results are **cached** so identical requests (same prompt + same row data) are never sent twice.
- If the user re-runs after changing the prompt or the file, new requests are made; unchanged rows may still hit the cache.
- The cache can be cleared from Settings.

---

## 8. Statistics

### 8.1 Per-Model Stats Panel

The app computes live statistics per selected model based on completed rows:

| Stat | Description |
|---|---|
| **Total cost** | Cumulative USD cost for all completed rows |
| **Median response time** | Median API call duration in seconds |
| **Total tokens** | Cumulative token count across all completed rows |
| **Median cosine similarity** | Median similarity between input and output (see §8.3) |

### 8.2 Extrapolated Projections

- Stats can be **extrapolated** to project costs and token usage at scale.
- The user selects a target scale: **1K**, **1M**, or **10M** rows.
- Extrapolation formula: `(stat per row) × target scale`.
- Extrapolation can be toggled on/off.
- The scale setting is persisted.

### 8.3 Cosine Similarity

- After each response, the app computes the **cosine similarity** between the full input sent to the LLM and the response text received.
- Score range: 0 (no shared vocabulary) to 1 (identical vocabulary distribution).
- Provides a quick signal for whether responses mirror the input language or diverge significantly — useful for detecting boilerplate, repetitive, or off-topic outputs.
- The median cosine similarity across all completed rows is shown in the stats panel.

---

## 9. Export

### 9.1 Save Results

- Users can export the enriched CSV via `File > Save Results` (`Cmd+S`).
- A native save dialog appears with a suggested filename (`{original_name}_with_responses.csv`) in the same directory as the source file.

### 9.2 Export Format

The exported CSV contains:
- All original columns from the source file (unchanged, in original order).
- For each model that was run, four appended columns:
  - `Output (model-id)` — LLM response text
  - `Duration (ms) (model-id)` — response time
  - `Tokens (model-id)` — total token count
  - `Cosine Similarity (model-id)` — similarity score (3 decimal places)

### 9.3 Partial Results

- Rows that did not complete (pending, failed) are included in the export with empty values for the output columns.
- Row order matches the original CSV exactly.

---

## 10. Settings

Settings are accessible via `Cmd+,` or `Quixote > Preferences`. They open in a separate window.

### 10.1 API Keys

- **OpenAI API Key**: required for all LLM processing. Stored securely in the macOS Keychain — never saved in plain text.
- **Gemini API Key**: stored (for future use).
- After setting an API key, the app validates it by fetching the available models list.

### 10.2 Processing Settings

| Setting | Default | Description |
|---|---|---|
| Concurrency | 2 | Max simultaneous in-flight API requests |
| Rate limit (RPS) | 5 | Max API requests per second |
| Max retries | 3 | Retry attempts before permanently failing a row |
| Request timeout | — | Per-request timeout in seconds |

### 10.3 Stats Display

| Setting | Default | Description |
|---|---|---|
| Show extrapolated stats | On | Toggle cost/token projections |
| Extrapolation scale | 1K | Target scale for projections (1K / 1M / 10M) |

### 10.4 Data Management

- **Clear cache**: removes all stored responses, forcing a full re-run next time.
- **Data directory**: shows where app data (results, settings) is stored.
