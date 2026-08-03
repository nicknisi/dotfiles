/** Artifacts extension — registers the `artifact` tool (create/update/open/list) and a TUI result card. */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { readFileSync, statSync } from "node:fs";
import { join } from "node:path";

import { artifactUrl, isRunning, notifyReload, runningPort, stopServer } from "./server.js";
import { slugify, isSafeSlug, writeArtifact, artifactExists, listArtifacts, openInBrowser, artifactPath } from "./utils.js";
import { renderMarkdownDocument, renderHtmlDocument } from "./templates.js";

interface ArtifactDetails {
  action: string;
  slug: string;
  title: string;
  kind: "markdown" | "html";
  url?: string;
  absPath: string;
}

function errResult(message: string, details: Partial<ArtifactDetails> = {}) {
  return {
    content: [{ type: "text" as const, text: `Error: ${message}` }],
    isError: true,
    details: { ...details } as Record<string, unknown>,
  };
}

/** Resolve content from inline `content` or `path` (file read, with a size cap). */
function resolveContent(params: { content?: string; path?: string }): { content: string } | { error: string } {
  if (params.content != null) return { content: params.content };
  if (params.path) {
    const abs = join(process.cwd(), params.path);
    try {
      const size = statSync(abs).size;
      const MAX = 2 * 1024 * 1024; // 2 MB — a stray path at a big log becomes a sad browser tab
      if (size > MAX) {
        return { error: `file is ${Math.round(size / 1024 / 1024)} MB — exceeds the 2 MB limit. Excerpt the relevant portion into \`content\` instead of reading the whole file via \`path\`.` };
      }
      return { content: readFileSync(abs, "utf-8") };
    } catch {
      return { error: `could not read file at "${params.path}".` };
    }
  }
  return { error: "provide `content` or `path` for create/update." };
}

export default function artifacts(pi: ExtensionAPI) {
  pi.on("session_shutdown", () => {
    stopServer();
  });

  // ─── /artifacts command — open the index page (starts the server lazily) ──
  pi.registerCommand("artifacts", {
    description: "Open the artifacts index page in the browser (starts the localhost server if not running)",
    handler: async (_args, ctx) => {
      const url = await artifactUrl(); // no slug → index; ensureServer starts lazily
      openInBrowser(url);
      if (ctx.hasUI) ctx.ui.notify(`Artifacts: ${url}`, "info");
    },
  });

  pi.registerTool({
    name: "artifact",
    label: "Artifact",
    description:
      "Create, update, open, or list HTML artifacts rendered from markdown or raw HTML and served from a lazy localhost server (opened in the browser). Two kinds: `markdown` (rendered to styled HTML — GFM tables, fenced ```diff blocks render as diffs, fenced code blocks get syntax highlighting, fenced ```mermaid blocks render as diagrams) and `html` (escape hatch — body fragment injected into a styled shell, or a full <!DOCTYPE> document passed through unchanged). `create`/`update` write the file and return the slug + localhost URL + absolute path; `update` on a slug whose file is missing creates it. `update` on an already-open artifact refreshes the browser tab in place via live reload. `open` starts the server and opens the artifact. `list` lists existing artifacts (does not start the server). Set `path` to read content from a file instead of passing `content` (kind is still required). html fragments inherit the artifact stylesheet (system fonts, light/dark scheme) and its CSS variables — `--bg`, `--fg`, `--muted`, `--border`, `--code-bg`, `--accent` — so write semantic HTML and use those variables in any scoped <style> instead of hardcoding colors. Storage: <project>/.pi/artifacts/<slug>.html.",
    promptSnippet: "Emit visual output (reports, diagrams, rendered diffs, tables) as a browser HTML artifact instead of terminal text",
    parameters: Type.Object({
      action: Type.Union(
        [Type.Literal("create"), Type.Literal("update"), Type.Literal("open"), Type.Literal("list")],
        { description: "create: write new artifact. update: overwrite existing (or create if missing) + live-reload open tabs. open: start server + open in browser. list: list artifacts (no server start)." },
      ),
      title: Type.Optional(Type.String({ description: "Artifact title; slug is derived from it. Required for create/update/open." })),
      kind: Type.Optional(Type.Union([Type.Literal("markdown"), Type.Literal("html")], { description: "Required for create/update. markdown = rendered to styled HTML (diff/code/mermaid fences handled). html = passthrough." })),
      content: Type.Optional(Type.String({ description: "Inline content (markdown or HTML). Alternative to `path`." })),
      path: Type.Optional(Type.String({ description: "Read content from this file path (relative to cwd) instead of `content`. kind still required. File is rendered into .pi/artifacts/, not served in place." })),
      open: Type.Optional(Type.Boolean({ description: "Auto-open in browser after write. Default: true on create, false on update (use action: open to view an update)." })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const action = params.action;

      // ── list ──────────────────────────────────────────────────────────────
      if (action === "list") {
        const entries = listArtifacts();
        const port = runningPort();
        const lines = entries.map((e) => {
          const when = e.mtime ? new Date(e.mtime).toISOString().replace("T", " ").slice(0, 19) : "";
          const url = port ? `http://127.0.0.1:${port}/${e.slug}.html` : "";
          return `- ${e.title} [${e.kind}] ${when}  ${e.slug}${url ? "  " + url : ""}\n  ${e.absPath}`;
        });
        const text = entries.length === 0
          ? "No artifacts in .pi/artifacts/ yet."
          : `${entries.length} artifact(s):\n\n${lines.join("\n")}`;
        return {
          content: [{ type: "text" as const, text }],
          details: { action, count: entries.length, serverRunning: port !== null } as Record<string, unknown>,
        };
      }

      // ── create / update / open — need title for slug ───────────────────────
      const title = params.title?.trim();
      if (!title) {
        return errResult("`title` is required for create/update/open.");
      }
      const slug = slugify(title);
      if (!isSafeSlug(slug)) {
        return errResult(`derived slug "${slug}" is invalid.`, { slug, title });
      }
      const kind = params.kind;
      const absPath = artifactPath(slug);

      // ── open ───────────────────────────────────────────────────────────────
      if (action === "open") {
        if (!artifactExists(slug)) {
          return errResult(`no artifact with slug "${slug}" — create it first.`, { slug, title });
        }
        const url = await artifactUrl(slug);
        openInBrowser(url);
        const details: ArtifactDetails = { action, slug, title, kind: kind ?? "markdown", url, absPath };
        return {
          content: [{ type: "text" as const, text: `Opened ${title}\n${url}\n${absPath}` }],
          details: details as unknown as Record<string, unknown>,
        };
      }

      // ── create / update — need kind + content ──────────────────────────────
      if (!kind) {
        return errResult("`kind` (markdown or html) is required for create/update.", { slug, title });
      }
      const resolved = resolveContent(params);
      if ("error" in resolved) {
        return errResult(resolved.error, { slug, title, kind });
      }
      const content = resolved.content;

      const html = kind === "html"
        ? renderHtmlDocument(title, slug, content)
        : renderMarkdownDocument(title, slug, content);

      writeArtifact(slug, html);

      // Live-reload already-open tabs (no-op if server not running)
      notifyReload(slug);

      const shouldOpen = params.open ?? (action === "create");
      let url: string | undefined;
      if (shouldOpen) {
        url = await artifactUrl(slug);
        openInBrowser(url);
      } else if (isRunning()) {
        url = await artifactUrl(slug);
      }

      const details: ArtifactDetails = { action, slug, title, kind, url, absPath };
      const verb = action === "create" ? "Created" : "Updated";
      const text = `${verb} ${title} [${kind}]\n${url ?? "(server not running — use action: open to view)"}\n${absPath}`;
      return {
        content: [{ type: "text" as const, text }],
        details: details as unknown as Record<string, unknown>,
      };
    },

  });
}

