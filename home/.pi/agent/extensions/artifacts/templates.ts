/** HTML shell + markdown→HTML rendering with server-side diff/code highlighting and client-side mermaid. */

import { Marked } from "marked";
import { parse as diffParse, html as diffHtml } from "diff2html";
import hljs from "highlight.js";

import { CONFIG, MERMAID_CDN } from "./config.js";
import { BASE_CSS, D2H_CSS, HLJS_CSS } from "./styles.js";

export interface RenderFlags {
  hasMermaid: boolean;
  hasDiff: boolean;
  hasCode: boolean;
}

/** Escape HTML special characters. */
function escapeHtml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

/** Escape for attribute context (quotes too). */
function escapeAttr(s: string): string {
  return escapeHtml(s).replace(/"/g, "&quot;");
}

/** Render markdown to an HTML body fragment, handling diff/code/mermaid fences. */
export function renderMarkdown(content: string, flags: RenderFlags): string {
  // Fresh instance per render: the code renderer closes over `flags`, and mutating
  // the global marked singleton would stack an override per call.
  const marked = new Marked({
    gfm: true,
    breaks: false,
    renderer: {
      code({ text, lang }: { text: string; lang?: string }): string {
        const language = (lang ?? "").trim().toLowerCase();

        if (language === "mermaid") {
          flags.hasMermaid = true;
          return `<div class="artifact-mermaid"><pre class="mermaid">${escapeHtml(text)}</pre></div>`;
        }

        if (language === "diff") {
          const rendered = renderDiff(text);
          if (rendered) {
            flags.hasDiff = true;
            return rendered;
          }
          // Malformed diff — fall through to plain code block
        }

        const known = language && hljs.getLanguage(language);
        if (known) {
          flags.hasCode = true;
          try {
            const out = hljs.highlight(text, { language }).value;
            return `<pre><code class="hljs language-${escapeAttr(language)}">${out}</code></pre>`;
          } catch {
            // fall through
          }
        }

        // Plain escaped code block (no unreliable auto-detect on short snippets)
        if (language) flags.hasCode = true;
        return `<pre><code${language ? ` class="language-${escapeAttr(language)}"` : ""}>${escapeHtml(text)}</code></pre>`;
      },
    },
  });

  return marked.parse(content) as string;
}

/** Render a unified-diff string to diff2html HTML (server-side). Returns null if parse yields nothing. */
function renderDiff(diffText: string): string | null {
  try {
    const json = diffParse(diffText, {});
    if (!json || json.length === 0) return null;
    return diffHtml(json, {
      outputFormat: "line-by-line",
      drawFileList: false,
    });
  } catch {
    return null;
  }
}

// ─── Shell ────────────────────────────────────────────────────────────────────

/** SSE snippet: subscribe to /events, reload only on events for this slug. */
function sseSnippet(slug: string): string {
  return `
<script>
(function () {
  var slug = ${JSON.stringify(slug)};
  var es = new EventSource("/events");
  es.addEventListener("reload", function (e) {
    try { if (e.data === slug || e.data === "*") location.reload(); } catch (_) {}
  });
})();
</script>`;
}

/** Mermaid init: render after the library loads. Uses the "base" theme fed with
 * the document's own tokens (read from CSS variables at runtime), so diagrams
 * follow the scheme and the configured accent instead of mermaid's built-ins —
 * "neutral" in particular draws grayscale text that's unreadably pale. */
function mermaidSnippet(): string {
  return `
<script src="${MERMAID_CDN}"></script>
<script>
(function () {
  var mode = ${JSON.stringify(CONFIG.theme)};
  function init() {
    try {
      var dark = mode === "dark" || (mode === "auto" && window.matchMedia("(prefers-color-scheme: dark)").matches);
      var css = getComputedStyle(document.documentElement);
      var t = function (name) { return css.getPropertyValue(name).trim(); };
      mermaid.initialize({
        startOnLoad: false,
        theme: "base",
        themeVariables: {
          darkMode: dark,
          background: t("--bg"),
          mainBkg: t("--code-bg"),
          primaryColor: t("--code-bg"),
          primaryTextColor: t("--fg"),
          primaryBorderColor: t("--border"),
          secondaryColor: t("--code-bg"),
          tertiaryColor: t("--bg"),
          lineColor: t("--muted"),
          textColor: t("--fg"),
          noteBkgColor: t("--code-bg"),
          noteTextColor: t("--fg"),
          noteBorderColor: t("--border"),
          edgeLabelBackground: t("--code-bg"),
          clusterBkg: t("--bg"),
          clusterBorder: t("--border"),
          actorLineColor: t("--muted"),
          signalTextColor: t("--fg"),
          labelTextColor: t("--fg"),
          fontFamily: getComputedStyle(document.body).fontFamily
        }
      });
      mermaid.run({ querySelector: "pre.mermaid" });
    } catch (e) { console.warn("mermaid init failed", e); }
  }
  if (typeof mermaid !== "undefined") init();
  else window.addEventListener("load", init);
})();
</script>`;
}

/** Build the full HTML document shell around a body fragment. */
export function buildShell(opts: {
  title: string;
  slug: string;
  kind: "markdown" | "html";
  bodyHtml: string;
  flags: RenderFlags;
}): string {
  const { title, slug, kind, bodyHtml, flags } = opts;
  const projectPath = process.cwd();
  const generated = Date.now();

  const styles: string[] = [`<style data-base>${BASE_CSS}</style>`];
  if (flags.hasDiff) styles.push(`<style data-d2h>${D2H_CSS}</style>`);
  if (flags.hasCode) styles.push(`<style data-hljs>${HLJS_CSS}</style>`);

  const scripts: string[] = [];
  if (flags.hasMermaid) scripts.push(mermaidSnippet());
  scripts.push(sseSnippet(slug));

  const generatedIso = new Date(generated).toISOString();

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="artifact-kind" content="${kind}">
<meta name="artifact-generated" content="${generated}">
<meta name="artifact-project" content="${escapeAttr(projectPath)}">
<title>${escapeHtml(title)}</title>
${styles.join("\n")}
</head>
<body>
<article>
<header class="artifact-header">
<h1>${escapeHtml(title)}</h1>
<span class="artifact-badge">${kind}</span>
<span class="artifact-meta">${escapeHtml(generatedIso.replace("T", " ").slice(0, 19))}</span>
</header>
${bodyHtml}
<footer class="artifact-footer">source: ${escapeHtml(projectPath)}</footer>
</article>
${scripts.join("\n")}
</body>
</html>`;
}

/** Render a markdown artifact to a full HTML document. */
export function renderMarkdownDocument(title: string, slug: string, content: string): string {
  const flags: RenderFlags = { hasMermaid: false, hasDiff: false, hasCode: false };
  const bodyHtml = renderMarkdown(content, flags);
  return buildShell({ title, slug, kind: "markdown", bodyHtml, flags });
}

/** Render an html artifact: full documents get the shell's metadata metas + SSE reload snippet spliced in; fragments get the full shell. */
export function renderHtmlDocument(title: string, slug: string, content: string): string {
  const trimmed = content.trimStart();
  const isFullDoc = /^<!doctype/i.test(trimmed) || /^<html[\s>]/i.test(trimmed);
  if (isFullDoc) {
    // Full documents bypass the shell, so inject the same metadata metas the shell
    // writes (artifact-kind/generated/project) plus the SSE reload listener. Both
    // are passive — they change no rendering — but they keep full-doc html consistent
    // on the index page (date + kind badge) and let `update` live-reload like any
    // other artifact. Skip any meta the document already declares to avoid dupes.
    const generated = Date.now();
    const projectPath = process.cwd();
    const metas: string[] = [];
    if (!content.includes('name="artifact-kind"')) metas.push(`<meta name="artifact-kind" content="html">`);
    if (!content.includes('name="artifact-generated"')) metas.push(`<meta name="artifact-generated" content="${generated}">`);
    if (!content.includes('name="artifact-project"')) metas.push(`<meta name="artifact-project" content="${escapeAttr(projectPath)}">`);
    const metaBlock = metas.length ? metas.join("\n") + "\n" : "";
    const snippet = sseSnippet(slug);

    let out = content;
    // Metas belong in <head>; splice there when present.
    const headClose = out.search(/<\/head>/i);
    if (headClose !== -1 && metaBlock) {
      out = out.slice(0, headClose) + metaBlock + out.slice(headClose);
    }
    // SSE listener before </body>. If there was no <head>, also drop the metas here —
    // the index parser is regex-based, so location is irrelevant to function.
    const tail = (headClose === -1 ? metaBlock : "") + snippet;
    const bodyClose = out.search(/<\/body>/i);
    out = bodyClose !== -1 ? out.slice(0, bodyClose) + tail + out.slice(bodyClose) : out + tail;
    return out;
  }

  const flags: RenderFlags = { hasMermaid: false, hasDiff: false, hasCode: false };
  return buildShell({ title, slug, kind: "html", bodyHtml: content, flags });
}

/** Build the index page listing all artifacts, newest first. */
export function renderIndexPage(entries: { slug: string; title: string; kind: string; mtime: number }[]): string {
  const projectPath = process.cwd();
  const rows = entries.map((e) => {
    const when = e.mtime ? new Date(e.mtime).toISOString().replace("T", " ").slice(0, 19) : "";
    const href = `/${e.slug}.html`;
    return `<tr><td><a href="${escapeAttr(href)}">${escapeHtml(e.title)}</a></td>` +
      `<td><span class="artifact-badge">${escapeHtml(e.kind)}</span></td>` +
      `<td><code>${escapeHtml(when)}</code></td></tr>`;
  });

  const empty = entries.length === 0
    ? `<p><em>No artifacts yet. Use the <code>artifact</code> tool to create one.</em></p>`
    : `<table><thead><tr><th>Title</th><th>Kind</th><th>Generated</th></tr></thead><tbody>${rows.join("\n")}</tbody></table>`;

  const styles = [`<style data-base>${BASE_CSS}</style>`];

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="artifact-kind" content="html">
<title>Artifacts — ${escapeHtml(projectPath)}</title>
${styles.join("\n")}
</head>
<body>
<article>
<header class="artifact-header">
<h1>Artifacts</h1>
<span class="artifact-badge">index</span>
</header>
${empty}
<footer class="artifact-footer">source: ${escapeHtml(projectPath)}</footer>
</article>
</body>
</html>`;
}