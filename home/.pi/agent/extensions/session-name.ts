/**
 * session-name — name sessions so they're easy to search and resume
 *
 * Built-in `/name` sets a display name manually, but you have to remember to
 * do it. This extension removes that burden by deriving a concise name
 * automatically after the first exchange, and adds a couple of conveniences
 * for searching and resuming by name.
 *
 * Commands:
 *   /sn [name]        Set the session name; show the current name if no arg.
 *                     "/sn clear" clears it.
 *   /sessions [query] Name-focused session picker for the current project.
 *                     Pass "--all" to search across every project. Selecting a
 *                     session resumes (switches to) it.
 *
 * Terminal title:
 *   Reflects the session summary in the terminal/window title (like Claude
 *   Code), updating whenever the name changes. Works through pi's terminal
 *   layer, so it reaches Ghostty, tmux panes, etc.
 *
 * Auto-naming:
 *   After the first real exchange in an unnamed session, a name is derived
 *   automatically. Heuristic by default (free, instant); LLM-generated titles
 *   are opt-in. Already-named sessions (set via /sn, /name, or --name) are
 *   never overwritten.
 *
 *   Configure via ~/.pi/agent/extensions/session-name.json:
 *     {
 *       "autoName": "heuristic" | "llm" | "off",
 *       "heuristicMaxLength": 60,
 *       "llmMaxWords": 6,
 *       "llmModel": "anthropic/claude-haiku-4-5",  // cheap model for titles;
 *                                                  // null = use session model
 *       "notifyOnAutoName": true,
 *       "setTitle": true,
 *       "titleFormat": "{summary} — {dir}"
 *     }
 */

import type { Message } from "@earendil-works/pi-ai";
import { getModelProvider } from "../lib/llm.ts";
import {
  SessionManager,
  type ExtensionAPI,
  type ExtensionContext,
  type SessionEntry,
  type SessionInfo,
} from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join } from "node:path";

// ── Config ────────────────────────────────────────────────────────────────

interface SessionNameConfig {
  /** Auto-naming mode after the first exchange. */
  autoName: "off" | "heuristic" | "llm";
  /** Max characters for derived names (heuristic and LLM). */
  heuristicMaxLength: number;
  /** Max words for LLM-generated titles. */
  llmMaxWords: number;
  /** Model for LLM titles as "provider/model-id". null = the session model. */
  llmModel: string | null;
  /** Notify when a session is auto-named. */
  notifyOnAutoName: boolean;
  /** Set the terminal/window title to reflect the session summary. */
  setTitle: boolean;
  /** Title template using {summary} and {dir} placeholders. */
  titleFormat: string;
}

const DEFAULT_CONFIG: SessionNameConfig = {
  autoName: "heuristic",
  heuristicMaxLength: 60,
  llmMaxWords: 6,
  llmModel: null,
  notifyOnAutoName: true,
  setTitle: true,
  titleFormat: "{summary} — {dir}",
};

function loadConfig(): SessionNameConfig {
  try {
    const path = join(homedir(), ".pi", "agent", "extensions", "session-name.json");
    const raw = readFileSync(path, "utf8");
    const parsed = JSON.parse(raw) as Partial<SessionNameConfig>;
    return { ...DEFAULT_CONFIG, ...parsed };
  } catch {
    return { ...DEFAULT_CONFIG };
  }
}

const config = loadConfig();

// ── Helpers ───────────────────────────────────────────────────────────────

function truncate(text: string, max: number): string {
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

/** Extract plain text from a message's content (string or content blocks). */
function contentToText(content: unknown): string {
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .filter(
        (c): c is { type: "text"; text: string } =>
          typeof c === "object" && c !== null && (c as { type?: string }).type === "text",
      )
      .map((c) => c.text)
      .join(" ");
  }
  return "";
}

/** First user message text in the branch (oldest first). */
function firstUserText(branch: SessionEntry[]): string | undefined {
  for (const entry of branch) {
    if (entry.type === "message" && entry.message.role === "user") {
      const text = contentToText(entry.message.content);
      if (text.trim()) return text;
    }
  }
  return undefined;
}

/** First assistant message text in the branch (oldest first). */
function firstAssistantText(branch: SessionEntry[]): string | undefined {
  for (const entry of branch) {
    if (entry.type === "message" && entry.message.role === "assistant") {
      const text = contentToText(entry.message.content);
      if (text.trim()) return text;
    }
  }
  return undefined;
}

/** Derive a name from the first user message: first non-empty line, trimmed. */
function deriveHeuristicName(text: string, maxLen: number): string | null {
  const firstLine = text
    .split(/\n/)
    .map((l) => l.trim())
    .find((l) => l.length > 0);
  let name = (firstLine ?? text).replace(/\s+/g, " ").trim();
  if (!name) return null;
  if (name.length > maxLen) name = `${name.slice(0, maxLen - 1).trimEnd()}…`;
  return name;
}

function relativeTime(date: Date): string {
  const diff = Date.now() - date.getTime();
  const sec = Math.floor(diff / 1000);
  if (sec < 60) return "just now";
  const min = Math.floor(sec / 60);
  if (min < 60) return `${min}m ago`;
  const hr = Math.floor(min / 60);
  if (hr < 24) return `${hr}h ago`;
  const day = Math.floor(hr / 24);
  if (day < 30) return `${day}d ago`;
  const mo = Math.floor(day / 30);
  if (mo < 12) return `${mo}mo ago`;
  return `${Math.floor(mo / 12)}y ago`;
}

function formatSessionLine(s: SessionInfo): string {
  const marker = s.name ? "★" : "·";
  const title = s.name || truncate(s.firstMessage || "(empty)", 60);
  return `${marker} ${title}  — ${s.messageCount} msgs — ${relativeTime(s.modified)} — ${s.id.slice(0, 8)}`;
}

/** Build a terminal title from the session summary and working directory. */
function buildTitle(name: string | undefined, cwd: string, format: string): string {
  const dir = basename(cwd) || cwd;
  if (!name) return `Pi — ${dir}`;
  return format.replace(/\{summary\}/g, name).replace(/\{dir\}/g, dir);
}

// ── Extension ─────────────────────────────────────────────────────────────

export default function sessionNameExtension(pi: ExtensionAPI): void {
  // Per-session guard so we only auto-name once per session instance.
  let autoNamed = false;
  // Abort in-flight LLM title calls on shutdown / session replacement so a
  // resolved name never lands on the wrong session.
  let titleAbort: AbortController | null = null;
  // A deferred title set from session_start, cancelled on shutdown so it
  // never lands on a torn-down session.
  let pendingTitleTimer: ReturnType<typeof setTimeout> | null = null;

  pi.on("session_start", (_event, ctx) => {
    autoNamed = false;
    if (config.setTitle && ctx.hasUI) {
      // Defer so we run after pi's built-in updateTerminalTitle() on startup,
      // which otherwise sets a "Pi - <name> - <dir>" title right after this event.
      pendingTitleTimer = setTimeout(() => {
        pendingTitleTimer = null;
        try {
          ctx.ui.setTitle(buildTitle(pi.getSessionName(), ctx.cwd, config.titleFormat));
        } catch {
          // Setting the title is best-effort; ignore failures.
        }
      }, 0);
    }
  });

  pi.on("session_info_changed", (event, ctx) => {
    if (!config.setTitle || !ctx.hasUI) return;
    // setSessionName emits to pi's built-in handlers first, then to extensions,
    // so this runs after the built-in updateTerminalTitle() and wins.
    ctx.ui.setTitle(buildTitle(event.name, ctx.cwd, config.titleFormat));
  });

  pi.on("session_shutdown", () => {
    titleAbort?.abort();
    titleAbort = null;
    if (pendingTitleTimer) {
      clearTimeout(pendingTitleTimer);
      pendingTitleTimer = null;
    }
  });

  // ── Auto-naming after the first exchange ──────────────────────────────
  pi.on("agent_settled", async (_event, ctx) => {
    if (autoNamed || config.autoName === "off") return;
    // Respect an existing name (set via /name, /sn, --name, or a prior turn).
    if (pi.getSessionName()) {
      autoNamed = true;
      return;
    }

    const branch = ctx.sessionManager.getBranch();
    const userText = firstUserText(branch);
    if (!userText) return;

    // Claim the slot now so a re-entrant settled event doesn't fire twice.
    autoNamed = true;

    let name: string | null = null;
    try {
      if (config.autoName === "llm") {
        const assistantText = firstAssistantText(branch);
        name = await generateLlmTitle(ctx, userText, assistantText ?? "");
        if (!name) name = deriveHeuristicName(userText, config.heuristicMaxLength);
      } else {
        name = deriveHeuristicName(userText, config.heuristicMaxLength);
      }
    } catch {
      name = null;
    }

    if (!name) return;
    // The name may have been set while the LLM call was in flight.
    if (pi.getSessionName()) return;

    pi.setSessionName(name);
    if (config.notifyOnAutoName && ctx.hasUI) {
      ctx.ui.notify(`Session named: ${name}`, "info");
    }
  });

  async function generateLlmTitle(
    ctx: ExtensionContext,
    userText: string,
    assistantText: string,
  ): Promise<string | null> {
    const model = resolveTitleModel(ctx);
    if (!model) return null;
    const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
    if (!auth.ok || !auth.apiKey) return null;

    const controller = new AbortController();
    titleAbort = controller;

    const systemPrompt = `You generate concise session titles for a coding agent. Given the user's first prompt and the start of the assistant's first reply, reply with ONLY a short title of at most ${config.llmMaxWords} words. No quotes, no trailing punctuation, no explanation.`;
    const body = `User's first prompt:\n${truncate(userText, 1000)}\n\nAssistant's first reply (start):\n${truncate(assistantText, 800)}`;
    const userMessage: Message = {
      role: "user",
      content: [{ type: "text", text: body }],
      timestamp: Date.now(),
    };

    try {
      const response = await getModelProvider(ctx, model)
        .stream(
          model,
          { systemPrompt, messages: [userMessage] },
          { apiKey: auth.apiKey, headers: auth.headers, env: auth.env, signal: controller.signal },
        )
        .result();
      if (response.stopReason === "error" || response.stopReason === "aborted") return null;
      const raw = response.content
        .filter((c): c is { type: "text"; text: string } => c.type === "text")
        .map((c) => c.text)
        .join(" ")
        .trim();
      if (!raw) return null;
      let title = raw
        .split(/\n/)[0]
        .trim()
        .replace(/^["'`]+|["'`]+$/g, "")
        .replace(/[.!?]+$/, "")
        .trim();
      if (!title) return null;
      if (title.length > config.heuristicMaxLength) {
        title = `${title.slice(0, config.heuristicMaxLength - 1).trimEnd()}…`;
      }
      return title;
    } catch {
      return null;
    } finally {
      if (titleAbort === controller) titleAbort = null;
    }
  }

  // Warn once if the configured title model can't be resolved, so a typo
  // doesn't silently burn session-model tokens on every new session.
  let warnedBadModel = false;

  /** Resolve the model for title generation: configured cheap model, else session model. */
  function resolveTitleModel(ctx: ExtensionContext) {
    if (config.llmModel) {
      const slash = config.llmModel.indexOf("/");
      const provider = slash > 0 ? config.llmModel.slice(0, slash) : "";
      const modelId = slash > 0 ? config.llmModel.slice(slash + 1) : "";
      const found = provider && modelId ? ctx.modelRegistry.find(provider, modelId) : undefined;
      if (found) return found;
      if (!warnedBadModel && ctx.hasUI) {
        warnedBadModel = true;
        ctx.ui.notify(
          `session-name: model "${config.llmModel}" not found; using session model`,
          "warning",
        );
      }
    }
    return ctx.model;
  }

  // ── /sn — set / show / clear ─────────────────────────────────────────
  pi.registerCommand("sn", {
    description: "Set or show the session name (usage: /sn [name] | /sn clear)",
    getArgumentCompletions: (prefix: string) => {
      const suggestions = ["clear"];
      const filtered = suggestions.filter((s) => s.startsWith(prefix));
      return filtered.length > 0 ? filtered.map((s) => ({ value: s, label: s })) : null;
    },
    handler: async (args, ctx) => {
      const arg = args.trim();

      if (!arg) {
        const current = pi.getSessionName();
        ctx.ui.notify(
          current ? `Session name: ${current}` : "No session name set (use /sn <name>)",
          "info",
        );
        return;
      }

      if (arg === "clear" || arg === "-c" || arg === "--clear") {
        pi.setSessionName("");
        autoNamed = true; // user intentionally cleared; don't re-auto-name
        ctx.ui.notify("Session name cleared", "info");
        return;
      }

      pi.setSessionName(arg);
      autoNamed = true; // user named manually; don't overwrite later
      ctx.ui.notify(`Session named: ${arg}`, "info");
    },
  });

  // ── /sessions — name-focused picker that resumes ──────────────────────
  pi.registerCommand("sessions", {
    description: "Search sessions by name and resume (usage: /sessions [query] [--all])",
    handler: async (args, ctx) => {
      if (!ctx.hasUI) {
        ctx.ui.notify("/sessions requires interactive mode", "error");
        return;
      }

      const { query, all } = parseSessionsArgs(args);

      ctx.ui.setStatus("session-name", "Loading sessions…");
      let sessions: SessionInfo[];
      try {
        sessions = all ? await SessionManager.listAll() : await SessionManager.list(ctx.cwd);
      } finally {
        ctx.ui.setStatus("session-name", undefined);
      }

      const currentFile = ctx.sessionManager.getSessionFile();
      let list = sessions.filter((s) => s.path !== currentFile);

      if (query) {
        const q = query.toLowerCase();
        list = list.filter(
          (s) =>
            (s.name ?? "").toLowerCase().includes(q) ||
            s.firstMessage.toLowerCase().includes(q) ||
            s.id.toLowerCase().includes(q),
        );
      }

      // Named sessions first, then most recently modified.
      list.sort(
        (a, b) =>
          Number(!!b.name) - Number(!!a.name) || b.modified.getTime() - a.modified.getTime(),
      );

      if (list.length === 0) {
        ctx.ui.notify(
          query ? `No sessions matching "${query}"` : "No other sessions found",
          "info",
        );
        return;
      }

      const lines = list.map(formatSessionLine);
      const choice = await ctx.ui.select(
        all ? "Sessions (all projects)" : "Sessions (this project)",
        lines,
      );
      if (!choice) return;

      const idx = lines.indexOf(choice);
      if (idx < 0) return;
      const target = list[idx];

      const result = await ctx.switchSession(target.path, {
        withSession: async (rctx) => {
          const label = target.name ?? truncate(target.firstMessage, 50);
          rctx.ui.notify(`Resumed: ${label}`, "info");
        },
      });

      if (result?.cancelled) {
        // The original ctx is still valid here only if the switch was cancelled.
        ctx.ui.notify("Switch cancelled", "info");
      }
    },
  });
}

// ── arg parsing for /sessions ─────────────────────────────────────────────

function parseSessionsArgs(args: string): { query: string; all: boolean } {
  const tokens = args.trim().split(/\s+/).filter(Boolean);
  let all = false;
  const queryParts: string[] = [];
  for (const tok of tokens) {
    if (tok === "--all" || tok === "-a") all = true;
    else queryParts.push(tok);
  }
  return { query: queryParts.join(" ").trim(), all };
}
