# Global opencode rules

Applies to every opencode session across all projects. A project's own
`AGENTS.md` layers on top of these and takes precedence. This file lives at
`config/opencode/AGENTS.md` and is symlinked to `~/.config/opencode/AGENTS.md`
by `install.sh link`, so opencode auto-loads it as global rules.

## Web content fetching strategy

`webfetch` does a plain HTTP GET + HTML-to-markdown conversion — it does NOT
execute JavaScript. It returns empty or near-empty content for:
- SPA docs sites (Astro/Docusaurus/Next.js/VuePress) whose first paint is a
  bare `<div id="root">` + JS bundle
- JS-based redirects (`location.href`)
- bot-detection / auth-walled / paywalled pages

Use these fallbacks before giving up on a URL:

1. **Library/framework docs -> use the `context7` MCP** (not `webfetch`). It
   returns pre-extracted docs and bypasses SPA rendering entirely. Prefer it
   for any named library or framework.
2. **Generic pages -> Jina Reader proxy.** Retry as
   `webfetch https://r.jina.ai/<original-url>`. Jina renders server-side and
   returns clean markdown. Free, no API key.
3. **GitHub content -> use `gh` CLI or raw URLs.** Fetch
   `raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>` for source, or
   run `gh api ...` for API data. Do not `webfetch` github.com pages (heavy
   SPA).
4. **Discovery vs retrieval.** Use `websearch` (Exa) to find relevant URLs,
   then `webfetch` to read a specific one. `websearch` is enabled globally via
   `OPENCODE_ENABLE_EXA=1` in `zsh/zshenv.symlink`.

## MCP usage rules

MCP tools are available automatically; these rules set priority so the agent
reaches for the right tool instead of defaulting to a grep/Read crawl.

- **context7**: when the question involves a named library or framework's
  docs/API, use `context7` first rather than `webfetch`-ing the official site.
- **codegraph**: in a project that has a `.codegraph/` index, answer code
  structure / call-path / impact-radius questions with `codegraph_explore`
  instead of grepping file-by-file. If no `.codegraph/` index exists,
  CodeGraph will say so — fall back to built-in `grep`/`read`/`glob`.
