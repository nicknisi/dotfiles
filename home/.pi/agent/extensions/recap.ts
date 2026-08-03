import { uuidv7 } from "@earendil-works/pi-ai";
import { complete, getModel } from "@earendil-works/pi-ai/compat";
import { getMarkdownTheme, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Box, Markdown, Text } from "@earendil-works/pi-tui";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

// Auto-recap: after N idle minutes, inject a dimmed recap card into the transcript.

type Config = { idleMinutes: number; model?: { provider: string; id: string } };

const DEFAULT_CONFIG: Config = { idleMinutes: 3 };
const CONFIG_PATH = path.join(os.homedir(), ".pi", "agent", "configs", "recap.json");
const ENTRY_TYPE = "recap";
const TICK_MS = 30_000;
const MIN_BRANCH_LEN = 4;
const MAX_CARD_LINES = 5;

let lastActivity = Date.now();
let firedThisIdle = false;
let timer: ReturnType<typeof setInterval> | null = null;
let piRef: ExtensionAPI | null = null;

function readConfig(): Config {
  try {
    const parsed = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
    return {
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

async function injectRecap(ctx: import("@earendil-works/pi-coding-agent").ExtensionContext) {
  const summary = await generateSummary(ctx);
  if (!summary) return;
  piRef?.appendEntry(ENTRY_TYPE, { summary, ts: Date.now() });
}

async function maybeFire(ctx: import("@earendil-works/pi-coding-agent").ExtensionContext) {
  if (!ctx.isIdle() || firedThisIdle) return;
  const cfg = readConfig();
  if (Date.now() - lastActivity < cfg.idleMinutes * 60_000) return;
  if (ctx.sessionManager.getBranch().length < MIN_BRANCH_LEN) return;
  firedThisIdle = true;
  await injectRecap(ctx);
}

export default function (pi: ExtensionAPI) {
  piRef = pi;

  pi.on("session_start", async (_e, ctx) => {
    if (ctx.mode !== "tui") return;
    lastActivity = Date.now();
    firedThisIdle = false;

    pi.registerEntryRenderer(ENTRY_TYPE, (entry, _opts, theme) => {
      const data = entry.data as { summary: string; ts: number };
      const dim = (s: string) => theme.fg("dim", s);
      // Hardcoded bg darker than both base bg (#1a1b26) and message bg (#1e1f2b)
      // so it's clearly distinct from user/assistant messages. theme.bg only
      // accepts named tokens, so emit a truecolor escape directly.
      const bg = (s: string) => `\x1b[48;2;19;19;32m${s}\x1b[49m`;
      const box = new Box(1, 0, (s) => bg(dim(s)));
      box.addChild(
        new Text(
          dim(theme.bold("Recap")) + dim(` · ${new Date(data.ts).toLocaleTimeString()}`),
          0,
          0,
        ),
      );
      box.addChild(new Markdown(capLines(data.summary, MAX_CARD_LINES), 0, 0, getMarkdownTheme()));
      return box;
    });

    timer = setInterval(() => {
      void maybeFire(ctx);
    }, TICK_MS);
  });

  pi.on("before_agent_start", async () => {
    lastActivity = Date.now();
    firedThisIdle = false;
  });

  pi.on("agent_settled", async () => {
    lastActivity = Date.now();
  });

  pi.on("session_shutdown", async (_e, ctx) => {
    if (timer) {
      clearInterval(timer);
      timer = null;
    }
    void ctx;
  });

  pi.registerCommand("recap", {
    description: "Inject a conversation recap into the transcript (generates if needed)",
    handler: async (_args, ctx) => {
      ctx.ui.notify("Generating recap...", "info");
      await injectRecap(ctx);
    },
  });

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
