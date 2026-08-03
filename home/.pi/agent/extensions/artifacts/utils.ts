/** Pure helpers: slugify, artifact file I/O, browser open. */

import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { join, normalize, sep } from "node:path";
import { spawn } from "node:child_process";

import { ARTIFACT_DIR } from "./config.js";

/** Absolute path to the artifacts dir for the current project. */
export function artifactDir(): string {
  return join(process.cwd(), ARTIFACT_DIR);
}

/** Ensure the artifacts dir exists, return its absolute path. */
export function ensureArtifactDir(): string {
  const dir = artifactDir();
  mkdirSync(dir, { recursive: true });
  return dir;
}

/** Kebab-case slug from a title. Lowercase, alnum + hyphens, trimmed. */
export function slugify(title: string): string {
  return title
    .toLowerCase()
    .trim()
    .replace(/['"`]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80) || "artifact";
}

/** Reject path traversal; a slug must be a bare filename (no separators, no dots-prefix). */
export function isSafeSlug(slug: string): boolean {
  if (!slug) return false;
  if (slug.includes("/") || slug.includes("\\") || slug.includes("..")) return false;
  if (!/^[a-z0-9-]+$/i.test(slug)) return false;
  return true;
}

/** Absolute path to a single artifact file. */
export function artifactPath(slug: string): string {
  return join(artifactDir(), `${slug}.html`);
}

/** Write artifact HTML to <slug>.html, creating the dir lazily. */
export function writeArtifact(slug: string, html: string): string {
  ensureArtifactDir();
  const path = artifactPath(slug);
  writeFileSync(path, html, "utf-8");
  return path;
}

/** Read an artifact file, or null if missing. */
export function readArtifact(slug: string): string | null {
  const path = artifactPath(slug);
  if (!existsSync(path)) return null;
  return readFileSync(path, "utf-8");
}

/** Does the artifact file exist? */
export function artifactExists(slug: string): boolean {
  return existsSync(artifactPath(slug));
}

export interface ArtifactEntry {
  slug: string;
  title: string;
  kind: "markdown" | "html";
  mtime: number;
  absPath: string;
}

/** List artifacts newest-first: slug + title (from <title>) + kind + mtime. */
export function listArtifacts(): ArtifactEntry[] {
  const dir = artifactDir();
  if (!existsSync(dir)) return [];
  const entries: ArtifactEntry[] = [];
  for (const file of readdirSync(dir)) {
    if (!file.endsWith(".html")) continue;
    const absPath = join(dir, file);
    const content = readFileSync(absPath, "utf-8");
    const slug = file.replace(/\.html$/, "");
    const titleMatch = content.match(/<title>(.*?)<\/title>/s);
    const kindMatch = content.match(/<meta name="artifact-kind" content="(.*?)"/);
    const kindRaw = kindMatch?.[1];
    // Meta present → trust it. Absent (pre-fix full-doc html or external file) →
    // infer from the shell marker: buildShell always emits <style data-base>, so
    // its presence means a rendered markdown/fragment artifact; absence means a
    // full-doc html or a foreign file → call it html.
    const kind: "markdown" | "html" = kindRaw === "html" || kindRaw === "markdown"
      ? kindRaw
      : content.includes("<style data-base") ? "markdown" : "html";
    entries.push({
      slug,
      title: titleMatch ? titleMatch[1].trim() : slug,
      kind,
      mtime: extractMtime(content) ?? statSync(absPath).mtimeMs,
      absPath,
    });
  }
  return entries.sort((a, b) => b.mtime - a.mtime);
}

/** Parse the generated-at timestamp embedded by the shell template. */
function extractMtime(html: string): number | null {
  const m = html.match(/<meta name="artifact-generated" content="(\d+)"/);
  return m ? parseInt(m[1], 10) : null;
}

/** Normalize a request path and confirm it resolves inside the artifacts dir. Returns null if unsafe. */
export function safeArtifactPath(reqPath: string): string | null {
  const dir = artifactDir();
  const target = normalize(join(dir, reqPath));
  if (!target.startsWith(dir + sep) && target !== dir) return null;
  return target;
}

/**
 * Open a URL in the default browser.
 * On darwin: `open`; on win32: `rundll32 url.dll,FileProtocolHandler` (avoids `start` which
 * is a cmd.exe built-in and cannot be spawned directly); on linux: `xdg-open`.
 */
export function openInBrowser(url: string): void {
  const [cmd, args] = process.platform === "darwin"
    ? ["open", [url]]
    : process.platform === "win32"
      ? ["rundll32", ["url.dll,FileProtocolHandler", url]]
      : ["xdg-open", [url]];
  spawn(cmd, args, { detached: true, stdio: "ignore" })
    .on("error", (err) => console.warn(`openInBrowser: ${cmd} failed: ${err.message}`))
    .unref();
}
