/** Lazy localhost HTTP server: static artifact serving, index page, SSE live reload. */

import { createServer, type Server, type IncomingMessage, type ServerResponse } from "node:http";
import { readFileSync, existsSync, statSync } from "node:fs";
import { extname } from "node:path";

import { HOST } from "./config.js";
import { listArtifacts, safeArtifactPath } from "./utils.js";
import { renderIndexPage } from "./templates.js";

interface ServerState {
  port: number;
  server: Server;
  clients: Set<ServerResponse>;
}

let state: ServerState | null = null;

/** URL for a given slug (or index). Starts the server if needed. */
export async function artifactUrl(slug?: string): Promise<string> {
  const port = await ensureServer();
  return slug ? `http://${HOST}:${port}/${slug}.html` : `http://${HOST}:${port}/`;
}

/** Push a reload event for a slug to all connected SSE clients. No-op if server isn't running. */
export function notifyReload(slug: string): void {
  if (!state) return;
  const payload = `event: reload\ndata: ${slug}\n\n`;
  for (const res of state.clients) {
    try { res.write(payload); } catch { state.clients.delete(res); }
  }
}

/** Whether the server is currently running (used by `list` to decide whether to include URLs). */
export function isRunning(): boolean {
  return state !== null;
}

/** Current port if the server is running, else null. Does NOT start the server. */
export function runningPort(): number | null {
  return state ? state.port : null;
}

/** Start the server if not already running. Returns the port. */
export async function ensureServer(): Promise<number> {
  if (state) return state.port;

  const clients = new Set<ServerResponse>();
  const server = createServer((req, res) => handle(req, res, clients));

  const port = await new Promise<number>((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, HOST, () => {
      server.removeListener("error", reject);
      const addr = server.address();
      resolve(typeof addr === "object" && addr ? addr.port : 0);
    });
  });

  state = { port, server, clients };
  return port;
}

/** Stop the server (used on session shutdown). */
export function stopServer(): void {
  if (!state) return;
  for (const res of state.clients) { try { res.end(); } catch {} }
  state.clients.clear();
  state.server.close();
  state = null;
}

// ─── Request handler ──────────────────────────────────────────────────────────

const MIME: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".gif": "image/gif",
};

function handle(req: IncomingMessage, res: ServerResponse, clients: Set<ServerResponse>): void {
  const url = (req.url ?? "/").split("?")[0];

  // SSE endpoint
  if (url === "/events") {
    res.writeHead(200, {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    });
    res.write(": connected\n\n");
    clients.add(res);
    req.on("close", () => clients.delete(res));
    return;
  }

  // Index page
  if (url === "/") {
    const entries = listArtifacts();
    const html = renderIndexPage(entries);
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(html);
    return;
  }

  // Static artifact file — normalize + prefix-check to prevent traversal outside artifacts dir
  const safe = safeArtifactPath(decodeURIComponent(url));
  if (!safe || !existsSync(safe) || !statSync(safe).isFile()) {
    res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("404 — artifact not found");
    return;
  }

  const mime = MIME[extname(safe).toLowerCase()] ?? "application/octet-stream";
  res.writeHead(200, { "Content-Type": mime });
  res.end(readFileSync(safe));
}