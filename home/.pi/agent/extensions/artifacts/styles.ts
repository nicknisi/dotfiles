/** Bespoke document stylesheet: design tokens, light/dark schemes, prose, chrome, diff + code theming. */

import { readFileSync } from "node:fs";
import { createRequire } from "node:module";

import { CONFIG } from "./config.js";

const require = createRequire(import.meta.url);

/** diff2html base stylesheet, read from the installed package (stays in sync with its JS). */
const D2H_BASE_CSS = readFileSync(require.resolve("diff2html/bundles/css/diff2html.min.css"), "utf-8");

// ─── Design tokens ─────────────────────────────────────────────────────────────
// One scheme = one flat token set. The accent is user-configurable; everything
// else is a quiet neutral so generated pages read as documents, not dashboards.

interface Scheme {
  bg: string;
  fg: string;
  muted: string;
  border: string;
  codeBg: string;
  accent: string;
  addBg: string;
  addWordBg: string;
  addFg: string;
  delBg: string;
  delWordBg: string;
  delFg: string;
  // syntax highlighting
  hlComment: string;
  hlKeyword: string;
  hlString: string;
  hlNumber: string;
  hlTitle: string;
  hlType: string;
  hlAttr: string;
}

const LIGHT: Scheme = {
  bg: "#ffffff",
  fg: "#1c1c1a",
  muted: "#6b6862",
  border: "#e7e5e0",
  codeBg: "#f7f6f4",
  accent: CONFIG.accentLight,
  addBg: "#e9f7ee",
  addWordBg: "#c8ecd3",
  addFg: "#1a7f37",
  delBg: "#feeff1",
  delWordBg: "#f8d2d7",
  delFg: "#c93c4c",
  hlComment: "#6e7781",
  hlKeyword: "#cf222e",
  hlString: "#0a3069",
  hlNumber: "#0550ae",
  hlTitle: "#8250df",
  hlType: "#953800",
  hlAttr: "#0550ae",
};

const DARK: Scheme = {
  bg: "#171614",
  fg: "#e6e3de",
  muted: "#94918a",
  border: "#2e2d29",
  codeBg: "#201f1c",
  accent: CONFIG.accent,
  addBg: "#1d2a20",
  addWordBg: "#2b4232",
  addFg: "#85c793",
  delBg: "#2e1c1e",
  delWordBg: "#4a292c",
  delFg: "#e28a91",
  hlComment: "#8b949e",
  hlKeyword: "#ff7b72",
  hlString: "#a5d6ff",
  hlNumber: "#79c0ff",
  hlTitle: "#d2a8ff",
  hlType: "#ffa657",
  hlAttr: "#79c0ff",
};

/** Emit a scheme as CSS custom properties (including diff2html's own variables). */
function tokens(s: Scheme): string {
  return `
  --bg: ${s.bg};
  --fg: ${s.fg};
  --muted: ${s.muted};
  --border: ${s.border};
  --code-bg: ${s.codeBg};
  --accent: ${s.accent};
  --add-bg: ${s.addBg};
  --add-word-bg: ${s.addWordBg};
  --add-fg: ${s.addFg};
  --del-bg: ${s.delBg};
  --del-word-bg: ${s.delWordBg};
  --del-fg: ${s.delFg};
  --hl-comment: ${s.hlComment};
  --hl-keyword: ${s.hlKeyword};
  --hl-string: ${s.hlString};
  --hl-number: ${s.hlNumber};
  --hl-title: ${s.hlTitle};
  --hl-type: ${s.hlType};
  --hl-attr: ${s.hlAttr};`;
}

/** Scheme block honoring the configured theme mode (auto = follow the OS). */
function schemeCss(): string {
  if (CONFIG.theme === "light") {
    return `:root { color-scheme: light;${tokens(LIGHT)}\n}`;
  }
  if (CONFIG.theme === "dark") {
    return `:root { color-scheme: dark;${tokens(DARK)}\n}`;
  }
  return `:root { color-scheme: light dark;${tokens(LIGHT)}\n}
@media (prefers-color-scheme: dark) { :root {${tokens(DARK)}\n} }`;
}

// ─── Typography + prose ────────────────────────────────────────────────────────
// System fonts, fixed 15px base (no viewport scaling), GitHub-README density.

export const FONT_SANS =
  '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';
export const FONT_MONO =
  'ui-monospace, "SF Mono", "JetBrains Mono", "Cascadia Code", Menlo, Consolas, "Liberation Mono", monospace';

const PROSE_CSS = `
* { box-sizing: border-box; }
html { font-size: 15px; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--fg);
  font-family: ${FONT_SANS};
  line-height: 1.65;
  -webkit-font-smoothing: antialiased;
  text-rendering: optimizeLegibility;
}
article { max-width: ${CONFIG.maxWidth}px; margin: 0 auto; padding: 2.75rem 1.5rem 4rem; }
h1, h2, h3, h4 { line-height: 1.3; letter-spacing: -0.01em; color: var(--fg); }
h1 { font-size: 1.45rem; font-weight: 650; margin: 0 0 1rem; }
h2 { font-size: 1.15rem; font-weight: 650; margin: 2.2em 0 .7em; padding-bottom: .35em; border-bottom: 1px solid var(--border); }
h3 { font-size: 1rem; font-weight: 600; margin: 1.8em 0 .5em; }
h4 { font-size: .9rem; font-weight: 600; margin: 1.5em 0 .4em; }
p { margin: .8em 0; }
a { color: var(--accent); text-decoration: underline; text-decoration-color: color-mix(in srgb, var(--accent) 35%, transparent); text-underline-offset: 2px; }
a:hover { text-decoration-color: var(--accent); }
strong { font-weight: 600; }
ul, ol { margin: .8em 0; padding-left: 1.5em; }
li { margin: .3em 0; }
li > ul, li > ol { margin: .2em 0; }
hr { border: none; border-top: 1px solid var(--border); margin: 2.5em 0; }
img, svg, video { max-width: 100%; }
::selection { background: color-mix(in srgb, var(--accent) 25%, transparent); }

blockquote {
  margin: 1.2em 0;
  padding: .1em 1.1em;
  border-left: 3px solid color-mix(in srgb, var(--accent) 55%, transparent);
  color: var(--muted);
}
blockquote > :first-child { margin-top: .4em; }
blockquote > :last-child { margin-bottom: .4em; }

table { border-collapse: collapse; width: 100%; margin: 1.2em 0; font-size: .9rem; }
th {
  text-align: left; font-weight: 600; font-size: .74rem;
  text-transform: uppercase; letter-spacing: .06em; color: var(--muted);
  padding: .5em .75em; border-bottom: 1px solid var(--border);
}
td { padding: .55em .75em; border-bottom: 1px solid var(--border); vertical-align: top; }
tr:last-child td { border-bottom: none; }

code, kbd, samp { font-family: ${FONT_MONO}; }
code { font-size: .85em; background: var(--code-bg); padding: .15em .4em; border-radius: 4px; }
pre {
  background: var(--code-bg);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 1em 1.2em;
  overflow-x: auto;
  font-size: .82rem;
  line-height: 1.55;
  margin: 1.2em 0;
}
pre code { background: transparent; padding: 0; font-size: inherit; }

input[type="checkbox"] { accent-color: var(--accent); margin-right: .4em; }
`;

// ─── Shell chrome (header, badge, footer, mermaid container) ──────────────────

const CHROME_CSS = `
.artifact-header {
  display: flex; align-items: baseline; gap: .75rem; flex-wrap: wrap;
  margin-bottom: 2rem; padding-bottom: 1rem; border-bottom: 1px solid var(--border);
}
.artifact-header h1 { margin: 0; }
.artifact-badge {
  font-family: ${FONT_MONO}; font-size: .66rem; text-transform: uppercase;
  letter-spacing: .08em; color: var(--accent);
  border: 1px solid color-mix(in srgb, var(--accent) 35%, transparent);
  border-radius: 999px; padding: .2em .7em; white-space: nowrap;
}
.artifact-meta { margin-left: auto; color: var(--muted); font-size: .72rem; font-family: ${FONT_MONO}; }
.artifact-footer {
  margin-top: 4rem; padding-top: 1rem; border-top: 1px solid var(--border);
  color: var(--muted); font-size: .72rem; font-family: ${FONT_MONO};
}
.artifact-mermaid { text-align: center; margin: 1.5rem 0; }
`;

/** Base stylesheet: tokens + prose + chrome. Always inlined. */
export const BASE_CSS = `${schemeCss()}\n${PROSE_CSS}\n${CHROME_CSS}`;

// ─── diff2html: base CSS + compaction to match the document ──────────────────
// The base ships early-Bootstrap chrome and inherits page font sizes; this
// tightens it into a quiet, hairline-bordered block at code-block scale.
//
// Ordering matters: the base CSS assigns its own light-mode --d2h-* values on
// :root, so our token remap MUST come after it in the same <style> to win the
// cascade (values resolve per scheme via var()). Layout is left alone — the
// base positions line-number gutters absolutely and clears them with large
// horizontal padding on code lines; overriding that padding clips the code.

const D2H_OVERRIDES_CSS = `
:root {
  --d2h-bg-color: var(--bg);
  --d2h-border-color: var(--border);
  --d2h-dim-color: var(--muted);
  --d2h-line-border-color: var(--border);
  --d2h-file-header-bg-color: var(--code-bg);
  --d2h-file-header-border-color: var(--border);
  --d2h-empty-placeholder-bg-color: var(--code-bg);
  --d2h-empty-placeholder-border-color: var(--border);
  --d2h-selected-color: var(--add-word-bg);
  --d2h-ins-bg-color: var(--add-bg);
  --d2h-ins-border-color: var(--add-bg);
  --d2h-ins-highlight-bg-color: var(--add-word-bg);
  --d2h-ins-label-color: var(--add-fg);
  --d2h-del-bg-color: var(--del-bg);
  --d2h-del-border-color: var(--del-bg);
  --d2h-del-highlight-bg-color: var(--del-word-bg);
  --d2h-del-label-color: var(--del-fg);
  --d2h-change-label-color: var(--accent);
  --d2h-moved-label-color: var(--accent);
  /* "change" rows (paired del/ins) and hunk-info rows have their own vars —
     unmapped they fall back to light-mode cream/green (unreadable in dark). */
  --d2h-change-del-color: var(--del-bg);
  --d2h-change-ins-color: var(--add-bg);
  --d2h-info-bg-color: var(--code-bg);
  --d2h-info-border-color: var(--border);
}
.d2h-file-wrapper { border: 1px solid var(--border); border-radius: 8px; margin: 1.2em 0; }
.d2h-file-header {
  background: var(--code-bg); border-bottom: 1px solid var(--border);
  padding: .5em .9em; height: auto;
  font-family: ${FONT_MONO}; font-size: .74rem; color: var(--muted);
}
.d2h-file-name { color: var(--fg); font-size: .76rem; }
.d2h-tag {
  font-size: .62rem; border-radius: 4px; padding: 0 .45em;
  background: transparent; border-color: var(--border); color: var(--muted);
}
.d2h-diff-table { font-family: ${FONT_MONO}; font-size: .76rem; margin: 0; }
/* Undo the document's prose table styling inside diffs — diff rows are dense:
   no cell padding, no hairlines between rows. */
.d2h-diff-table td, .d2h-diff-table th { padding: 0; border-bottom: none; }
.d2h-code-linenumber, .d2h-code-side-linenumber { color: var(--muted); border: none; cursor: default; }
/* The Node API emits whitespace between the two line-number divs, which breaks
   the base CSS's float layout (numbers stack). Flex ignores whitespace nodes;
   direction:ltr undoes the base's rtl trick, which would reverse flex order. */
.d2h-code-linenumber { display: flex; direction: ltr; }
.d2h-code-linenumber .line-num1, .d2h-code-linenumber .line-num2 { float: none; width: 50%; }
.d2h-info { background: var(--code-bg); color: var(--muted); border-color: var(--border); }
`;

/** diff2html stylesheet (base + document-matched overrides). Inlined only when a diff fence is present. */
export const D2H_CSS = `${D2H_BASE_CSS}\n${D2H_OVERRIDES_CSS}`;

// ─── highlight.js theme, driven by the scheme tokens ──────────────────────────

/** Syntax theme mapped onto the scheme tokens. Inlined only when a highlighted code fence is present. */
export const HLJS_CSS = `
.hljs { color: var(--fg); background: transparent; }
.hljs-comment, .hljs-quote { color: var(--hl-comment); font-style: italic; }
.hljs-keyword, .hljs-selector-tag, .hljs-literal, .hljs-deletion { color: var(--hl-keyword); }
.hljs-string, .hljs-regexp, .hljs-addition { color: var(--hl-string); }
.hljs-number, .hljs-symbol, .hljs-bullet, .hljs-meta, .hljs-link { color: var(--hl-number); }
.hljs-title, .hljs-section, .hljs-function .hljs-title { color: var(--hl-title); }
.hljs-type, .hljs-class .hljs-title, .hljs-built_in { color: var(--hl-type); }
.hljs-variable, .hljs-template-variable, .hljs-attr, .hljs-attribute, .hljs-property { color: var(--hl-attr); }
.hljs-emphasis { font-style: italic; }
.hljs-strong { font-weight: 600; }
`;
