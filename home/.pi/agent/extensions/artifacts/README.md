# artifacts

Give the agent a way to produce visual output — PR review reports, diagrams, comparison tables, rendered diffs — as **HTML artifacts** served from a lazy localhost server and opened in the browser, instead of dumping walls of text into the terminal.

https://github.com/user-attachments/assets/b84e0ebd-84db-45ec-ba77-52aede167b4e

## The `artifact` tool

One tool, action-based:

| Param     | Type / values                            | Notes                                               |
| --------- | ---------------------------------------- | --------------------------------------------------- |
| `action`  | `create` \| `update` \| `open` \| `list` | `update` on a missing slug creates it               |
| `title`   | string                                   | required for create/update/open; slug derived       |
| `kind`    | `markdown` \| `html`                     | required for create/update                          |
| `content` | string                                   | inline content                                      |
| `path`    | string                                   | alternative to `content`: read file (kind required) |
| `open`    | boolean, default `true` on create        | auto-open after write                               |

`create`/`update` return the slug + localhost URL + absolute path. `update` on an already-open artifact **refreshes the browser tab in place** via SSE live reload — iterating on a report reuses one file and one tab. `open` starts the server and opens the artifact. `list` lists existing artifacts **without starting the server** (URLs included only if the server is already running).

### `markdown` (default, workhorse)

Rendered to styled HTML at write time. Fenced code blocks are detected and handled per type — no extra schema surface, the model just writes the markdown it was already going to write:

- ` ```diff ` fences → rendered **server-side** via [`diff2html`](https://github.com/rtfpessoa/diff2html) (Node API). This is the PR-review path: one markdown artifact = findings prose + severity table + per-file diff fences. Offline-safe.
- Ordinary code fences (` ```ts `, ` ```py `, …) → syntax-highlighted **server-side** via [`highlight.js`](https://highlightjs.org/). Highlighted spans are baked into the HTML — zero client JS. Unknown languages fall back to plain escaped code (no unreliable auto-detect on short snippets).
- ` ```mermaid ` fences → rendered **client-side** via the mermaid.js CDN script. This is the **only** client-side JS in a markdown artifact; everything else is rendered at write time and viewable offline. Mermaid artifacts need network on first view.
- GFM tables and task lists via [`marked`](https://marked.js.org/).

### `html` (escape hatch)

For what markdown can't express: custom layout, Chart.js visualizations, interactive widgets. Body fragment injected into the styled shell as-is; full documents (`<!DOCTYPE`/`<html>` detected) bypass the shell, so the extension splices in the same metadata metas the shell writes (`artifact-kind`/`generated`/`project`, skipping any the doc already declares) plus the SSE reload listener — both passive, change no rendering. This keeps full-doc html consistent on the index page (date + kind badge) and lets `update` live-reload them like any other artifact. Otherwise the document is unchanged.

Kind is never auto-detected from content — markdown legitimately opens with inline HTML, and a misdetection produces a confusing artifact. The two-value enum costs one token and removes all ambiguity.

## Storage

Project-local, mirroring plan-mode's `.pi/plans` convention:

```
<project>/.pi/artifacts/<slug>.html
```

- `slug` is derived from the title (kebab-case); `update` with the same slug overwrites the file, so iterating on a report reuses one file (and one browser tab, thanks to live reload).
- Directory created lazily on first write.
- `.pi/artifacts/` is generated output — **gitignore it** in projects (`echo ".pi/artifacts/" >> .gitignore`). The extension does not enforce this.
- No `delete` action: the directory grows across sessions but it's gitignored generated output the user can clear manually. Slug collisions are intentional overwrites — slug = identity is what makes `update` + one-tab live reload work.

## Server (lazy, localhost-only)

- Started on first `open` (not at extension load), bound strictly to `127.0.0.1`, random free port remembered for the process lifetime. Per-project (per-process), matching the cwd-relative storage model.
- **SSE live reload**: the server and the `artifact` tool run in the same process, so `update` pushes an SSE event **directly** to connected clients (no `fs.watch`). The shell includes a snippet that subscribes to `/events` and reloads on an event matching its own slug.
- **Index page** at `/`: artifact list, newest first, kind badge + timestamp. Titles recovered by parsing `<title>` from each file (no sidecar manifest). Reach it with the `/artifacts` command (below) or by opening the localhost URL printed by any tool call.

## `/artifacts` command

User-facing front door to the index page: starts the lazy server (if not running) and opens `/` in the browser. No args, no subcommands — the index page is the listing and the picker (clickable, newest-first). The `artifact` tool's `list`/`open` actions remain for the model; the command is for when you want to browse directly without asking it.

- No auth: localhost-bound, serving files the agent just wrote locally. Paths are normalized and prefix-checked — nothing outside the artifacts dir is served.

## Styling: bespoke document stylesheet

No CSS framework. `styles.ts` owns the entire design system (~300 lines): system fonts, fixed 15px base (no viewport scaling), GitHub-README density, hairline borders, one accent color. Light and dark schemes are defined as token sets and follow the OS via `prefers-color-scheme` by default. diff2html's base CSS (read from the installed package, so it can't drift from its JS) is compacted to code-block scale and recolored through the same tokens; the highlight.js theme is mapped onto scheme tokens too — prose, diffs, and code read as one design in both schemes.

`kind: "html"` fragments inherit the stylesheet and its CSS variables (`--bg`, `--fg`, `--muted`, `--border`, `--code-bg`, `--accent`), so LLM-authored pages stay on-design without carrying their own CSS.

### User config (optional)

Copy [`artifacts.example.json`](artifacts.example.json) to `~/.pi/agent/configs/artifacts.json`. Config is read once at extension load (pi extensions load at session start) — restart pi to apply changes.

| Key           | Default   | Meaning                                              |
| ------------- | --------- | ---------------------------------------------------- |
| `theme`       | `auto`    | `auto` follows the OS; `light`/`dark` pin one scheme |
| `accent`      | `#d67858` | Accent on the dark scheme                            |
| `accentLight` | `#b95730` | Accent on the light scheme (darker for contrast)     |
| `maxWidth`    | `860`     | Content column width in px                           |

## TUI card

Tool results render as a one-line card in the transcript: status icon, title, kind, and the localhost URL (clickable in terminals with link support).

## The "when" layer (prompt, not code)

The extension makes artifacts _possible_; instructions decide _when_:

1. **`pr-review` skill** — companion to the `gh` skill. Instructs the agent to gather the PR diff via `gh`, review it, then emit **one markdown artifact** through the `artifact` tool — verdict up top, findings ranked by severity, per-file ` ```diff ` fences — and open it.
2. **`APPEND_SYSTEM.md`** — one general-case line covering the long tail (reports, diagrams, tables longer than a screen).

Tuning _when_ artifacts appear never touches extension code.

## Dependencies

Three runtime deps — `marked`, `diff2html`, `highlight.js` — each the de-facto standard in its lane, plus one CDN script for mermaid fences only. All rendering happens at write time; everything is viewable offline except mermaid artifacts. Deps are lockfile-tracked and auditable (declared in the extension's own `package.json`, not checked-in min.js blobs). diff2html's stylesheet is read from the installed package at load time; all other CSS is authored in `styles.ts`.
