import { uuidv7 } from "@earendil-works/pi-ai";
import { complete, getModel } from "@earendil-works/pi-ai/compat";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { DynamicBorder, getMarkdownTheme } from "@earendil-works/pi-coding-agent";
import { Box, Container, Markdown, matchesKey, Text } from "@earendil-works/pi-tui";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

// Auto-recap: after N idle minutes, summarize the conversation and surface it.
// Display mode is configurable: "card" (bordered inline transcript entry)
// or "widget" (one-line bar above editor).

type Mode = "card" | "widget";
type Config = { mode: Mode; idleMinutes: number; model?: { provider: string; id: string } };

const DEFAULT_CONFIG: Config = { mode: "card", idleMinutes: 3 };
const CONFIG_PATH = path.join(os.homedir(), ".pi", "agent", "configs", "recap.json");
const WIDGET_ID = "recap";
const ENTRY_TYPE = "recap";
const TICK_MS = 30_000;
const MIN_BRANCH_LEN = 4; // don't recap tiny conversations

const MODES: Mode[] = ["card", "widget"];

let lastActivity = Date.now();
let firedThisIdle = false;
let lastSummary = "";
let widgetSummary = "";
let timer: ReturnType<typeof setInterval> | null = null;
let requestRender: (() => void) | null = null;

// --- config ---

function isMode(v: unknown): v is Mode {
  return typeof v === "string" && (MODES as string[]).includes(v);
}

function readConfig(): Config {
  try {
    const parsed = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
    return {
      mode: isMode(parsed.mode) ? parsed.mode : DEFAULT_CONFIG.mode,
      idleMinutes: typeof parsed.idleMinutes === "number" ? parsed.idleMinutes : DEFAULT_CONFIG.idleMinutes,
      model: parsed.model && typeof parsed.model === "object" ? parsed.model : undefined,
    };
  } catch {
    return DEFAULT_CONFIG;
  }
}

function writeConfig(c: Config) {
  fs.mkdirSync(path.dirname(CONFIG_PATH), { recursive: true });
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(c, null, 2));
}

// --- conversation extraction (ported from pi's summarize.ts example) ---

type Entry = { type: string; message?: { role?: string; content?: unknown } };
type Block = { type?: string; text?: string; name?: string; arguments?: Record<string, unknown> };

function textParts(content: unknown): string[] {
  if (typeof content === "string") return [content];
  if (!Array.isArray(content)) return [];
  return content
    .filter((p): p is Block => !!p && typeof p === "object")
    .filter((b) => b.type === "text" && typeof b.text === "string")
    .map((b) => b.text as string);
}

function toolLines(content: unknown): string[] {
  if (!Array.isArray(content)) return [];
  return content
    .filter((p): p is Block => !!p && typeof p === "object")
    .filter((b) => b.type === "toolCall" && typeof b.name === "string")
    .map((b) => `Tool ${b.name} called with ${JSON.stringify(b.arguments ?? {})}`);
}

function buildConversation(entries: Entry[]): string {
  const sections: string[] = [];
  for (const e of entries) {
    if (e.type !== "message" || !e.message?.role) continue;
    const role = e.message.role;
    if (role !== "user" && role !== "assistant") continue;
    const lines: string[] = [];
    const tp = textParts(e.message.content);
    const t = tp.join("\n").trim();
    if (t) lines.push(`${role === "user" ? "User" : "Assistant"}: ${t}`);
    if (role === "assistant") lines.push(...toolLines(e.message.content));
    if (lines.length) sections.push(lines.join("\n"));
  }
  return sections.join("\n\n");
}

const MAX_CARD_LINES = 8;

function summaryPrompt(conversation: string): string {
  return [
    "Summarize this conversation so far as a concise recap.",
    "Include goals, key decisions, progress, and open items.",
    "Be terse — at most 6-8 lines. Use short markdown headings.",
    "Skip preamble; lead with the substance.",
    "",
    "<conversation>",
    conversation,
    "</conversation>",
  ].join("\n");
}

function capLines(text: string, max: number): string {
  const lines = text.split("\n");
  if (lines.length <= max) return text;
  return lines.slice(0, max).join("\n") + " …";
}

function truncate(text: string, budget: number): string {
  if (text.length <= budget) return text;
  return text.slice(0, Math.max(0, budget - 1)).trimEnd() + "…";
}

// --- LLM summary ---

async function generateSummary(ctx: import("@earendil-works/pi-coding-agent").ExtensionContext): Promise<string> {
  const cfg = readConfig();
  const model = cfg.model ? getModel(cfg.model.provider, cfg.model.id) : ctx.model;
  if (!model) {
    ctx.ui.notify("recap: no model available", "warning");
    return "";
  }
  const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
  if (!auth?.ok || !auth.apiKey) {
    ctx.ui.notify("recap: no API key for model", "warning");
    return "";
  }
  const conversation = buildConversation(ctx.sessionManager.getBranch());
  if (!conversation.trim()) return "";
  const response = await complete(
    model,
    { messages: [{ role: "user", content: [{ type: "text", text: summaryPrompt(conversation) }], timestamp: Date.now() }] },
    { apiKey: auth.apiKey, headers: auth.headers, env: auth.env, reasoningEffort: "low", cacheRetention: "none", sessionId: uuidv7() },
  );
  return response.content
    .filter((c): c is { type: "text"; text: string } => c.type === "text")
    .map((c) => c.text)
    .join("\n");
}

// --- display ---

async function showOverlay(summary: string, ctx: import("@earendil-works/pi-coding-agent").ExtensionContext) {
  if (ctx.mode !== "tui") return;
  await ctx.ui.custom((_tui, theme, _kb, done) => {
    const c = new Container();
    c.addChild(new Text(theme.fg("accent", theme.bold("Conversation Recap")), 1, 0));
    c.addChild(new Markdown(summary, 1, 1, getMarkdownTheme()));
    c.addChild(new Text(theme.fg("dim", "enter / esc to close"), 1, 0));
    return {
      render: (w: number) => c.render(w),
      invalidate: () => c.invalidate(),
      handleInput: (d: string) => {
        if (matchesKey(d, "enter") || matchesKey(d, "escape")) done(undefined);
      },
    };
  });
}

function setWidgetSummary(summary: string) {
  widgetSummary = summary;
  requestRender?.();
}

function clearWidget() {
  widgetSummary = "";
  requestRender?.();
}

// --- auto-trigger ---

async function maybeFire(ctx: import("@earendil-works/pi-coding-agent").ExtensionContext) {
  if (!ctx.isIdle() || firedThisIdle) return;
  const cfg = readConfig();
  if (Date.now() - lastActivity < cfg.idleMinutes * 60_000) return;
  if (ctx.sessionManager.getBranch().length < MIN_BRANCH_LEN) return;
  firedThisIdle = true;
  const summary = await generateSummary(ctx);
  if (!summary) return;
  lastSummary = summary;
  if (cfg.mode === "card") {
    piRef?.appendEntry(ENTRY_TYPE, { summary, ts: Date.now() });
  } else if (cfg.mode === "widget") {
    setWidgetSummary(summary);
  }
}

// Need pi in module scope for appendEntry from timer/commands.
let piRef: ExtensionAPI | null = null;

export default function (pi: ExtensionAPI) {
  piRef = pi;

  pi.on("session_start", async (_e, ctx) => {
    if (ctx.mode !== "tui") return;
    lastActivity = Date.now();
    firedThisIdle = false;

    pi.registerEntryRenderer(ENTRY_TYPE, (entry, _opts, theme) => {
      const data = entry.data as { summary: string; ts: number };
      const box = new Box(1, 1, (s) => theme.bg("customMessageBg", s));
      box.addChild(new DynamicBorder((s) => theme.fg("accent", s)));
      box.addChild(
        new Text(
          theme.fg("accent", theme.bold("Recap")) + theme.fg("dim", ` · ${new Date(data.ts).toLocaleTimeString()}`),
          0,
          0,
        ),
      );
      box.addChild(new Markdown(capLines(data.summary, MAX_CARD_LINES), 0, 1, getMarkdownTheme()));
      box.addChild(new DynamicBorder((s) => theme.fg("accent", s)));
      return box;
    });

    ctx.ui.setWidget(WIDGET_ID, (tui, theme) => {
      requestRender = () => tui.requestRender();
      const icon = theme.fg("accent", "\uf021"); // nerd-font sync/refresh glyph
      return {
        render(width: number): string[] {
          if (!widgetSummary) return [];
          const budget = Math.max(0, width - 3); // indent + icon + gap
          return [" " + icon + " " + theme.fg("muted", truncate(widgetSummary, budget))];
        },
        invalidate() {},
      };
    });

    timer = setInterval(() => {
      void maybeFire(ctx);
    }, TICK_MS);
  });

  pi.on("before_agent_start", async (_e, _ctx) => {
    lastActivity = Date.now();
    firedThisIdle = false;
    clearWidget();
  });

  pi.on("agent_settled", async (_e, _ctx) => {
    lastActivity = Date.now();
  });

  pi.on("session_shutdown", async (_e, ctx) => {
    if (timer) {
      clearInterval(timer);
      timer = null;
    }
    if (ctx.mode !== "tui") return;
    ctx.ui.setWidget(WIDGET_ID, undefined);
    clearWidget();
    requestRender = null;
  });

  // Manual trigger: render via the current mode (generates if needed).
  // /recap-full always opens the full overlay.
  pi.registerCommand("recap", {
    description: "Show a recap via the current display mode (generates if needed)",
    handler: async (_args, ctx) => {
      let summary = lastSummary;
      if (!summary) {
        ctx.ui.notify("Generating recap...", "info");
        summary = await generateSummary(ctx);
      }
      if (!summary) {
        ctx.ui.notify("Nothing to recap yet", "warning");
        return;
      }
      lastSummary = summary;
      const cfg = readConfig();
      if (cfg.mode === "card") {
        piRef?.appendEntry(ENTRY_TYPE, { summary, ts: Date.now() });
      } else if (cfg.mode === "widget") {
        setWidgetSummary(summary);
      } else {
        await showOverlay(summary, ctx);
      }
    },
  });

  // Full overlay, regardless of mode.
  pi.registerCommand("recap-full", {
    description: "Show the full recap in a dismissible overlay",
    handler: async (_args, ctx) => {
      let summary = lastSummary;
      if (!summary) {
        ctx.ui.notify("Generating recap...", "info");
        summary = await generateSummary(ctx);
      }
      if (!summary) {
        ctx.ui.notify("Nothing to recap yet", "warning");
        return;
      }
      lastSummary = summary;
      await showOverlay(summary, ctx);
    },
  });

  // View or set the display mode.
  pi.registerCommand("recap-mode", {
    description: "Show or set recap display mode (card | widget)",
    handler: async (args, ctx) => {
      const cfg = readConfig();
      const arg = args.trim();
      if (!arg) {
        ctx.ui.notify(`recap mode: ${cfg.mode} (idle ${cfg.idleMinutes}m)`, "info");
        return;
      }
      if (!isMode(arg)) {
        ctx.ui.notify(`invalid mode. options: ${MODES.join(", ")}`, "warning");
        return;
      }
      const next = { ...cfg, mode: arg };
      writeConfig(next);
      ctx.ui.notify(`recap mode → ${arg}`, "info");
    },
  });

  // Set idle threshold in minutes.
  pi.registerCommand("recap-idle", {
    description: "Set recap idle threshold in minutes",
    handler: async (args, ctx) => {
      const n = Number(args.trim());
      if (!Number.isFinite(n) || n <= 0) {
        ctx.ui.notify("usage: /recap-idle <minutes>", "warning");
        return;
      }
      writeConfig({ ...readConfig(), idleMinutes: n });
      ctx.ui.notify(`recap idle → ${n}m`, "info");
    },
  });
}
