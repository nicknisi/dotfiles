/**
 * orchestrate.ts — Claude Code-style /goal and /loop for pi.
 *
 * /goal <condition>     set a completion condition; pi keeps working across
 *                       turns until a small model confirms the condition is
 *                       met, then clears the goal automatically.
 * /goal                 show status (condition, duration, turns, last reason).
 * /goal clear           remove the active goal (stop|off|reset|none|cancel ok).
 *
 * /loop [interval] <prompt>   re-run a prompt while the session stays open.
 *   /loop 5m check if the deploy finished
 *   /loop check if the deploy finished      (self-paced: next turn after each agent_end)
 *   /loop                                    (uses .pi-loop.md or a default maintenance prompt)
 * /loop                 show status.
 * /loop stop            stop the loop.
 *
 * One goal per session. One loop per session. State persists to
 * <cwd>/.pi-goal/state.json so it survives --resume — but it is stamped with
 * the owning session file and is ONLY re-adopted by that exact session.
 * Other instances in the same cwd ignore it (a cwd-keyed file with no owner
 * check used to leak goals into every concurrent session). Ephemeral
 * sessions keep goal/loop state in memory only. The evaluator reads the
 * transcript tail and calls no tools (cheap, fast — Claude Code semantics).
 */

import * as fs from "node:fs";
import * as path from "node:path";

import {
  createAgentSession,
  createExtensionRuntime,
  SessionManager,
  SettingsManager,
  type ExtensionAPI,
  type ExtensionContext,
  type ResourceLoader,
} from "@earendil-works/pi-coding-agent";

// =================================================================
// State
// =================================================================

interface GoalState {
  condition: string;
  startedAt: number;
  turns: number;
  lastReason?: string;
  lastEvalAt?: number;
}

interface LoopState {
  prompt: string;
  intervalMs: number | null; // null = self-paced (tick on agent_end)
  iterations: number;
  lastTickAt: number;
}

interface SavedState {
  /** Session file that owns this state; null/absent = untrusted (never adopt). */
  owner?: string | null;
  goal: GoalState | null;
  loop: LoopState | null;
}

let api: ExtensionAPI | null = null;
let lastCtx: ExtensionContext | null = null;
let goal: GoalState | null = null;
let loop: LoopState | null = null;
let loopTimer: NodeJS.Timeout | null = null;
let evalInFlight = false;

// Aliases for /goal clear
const CLEAR_ALIASES = new Set(["clear", "stop", "off", "reset", "none", "cancel"]);

// =================================================================
// Persistence
// =================================================================

function stateDir(cwd: string): string {
  return path.join(cwd, ".pi-goal");
}

function statePath(cwd: string): string {
  return path.join(stateDir(cwd), "state.json");
}

function sessionFileOf(ctx: ExtensionContext): string | null {
  try {
    return ctx.sessionManager.getSessionFile() ?? null;
  } catch {
    return null;
  }
}

function persist(ctx: ExtensionContext): void {
  try {
    const owner = sessionFileOf(ctx);
    // Ephemeral session: no durable identity to key on — keep state in
    // memory only rather than writing a file another instance could adopt.
    if (!owner) return;
    fs.mkdirSync(stateDir(ctx.cwd), { recursive: true });
    const data: SavedState = { owner, goal, loop };
    fs.writeFileSync(statePath(ctx.cwd), JSON.stringify(data, null, 2));
  } catch {
    /* persistence is advisory — never block the loop on it */
  }
}

function loadState(ctx: ExtensionContext): void {
  goal = null;
  loop = null;
  try {
    const raw = fs.readFileSync(statePath(ctx.cwd), "utf8");
    const data = JSON.parse(raw) as SavedState;
    const owner = sessionFileOf(ctx);
    // Adopt persisted state only in the session that created it (--resume).
    // Anything else — different session, ephemeral session, or legacy state
    // with no owner stamp — is ignored so goals cannot leak across instances.
    if (!data.owner || !owner || data.owner !== owner) {
      // Prune orphaned state whose owning session no longer exists.
      if (data.owner && !fs.existsSync(data.owner)) clearStateFile(ctx.cwd);
      return;
    }
    goal = data.goal ?? null;
    loop = data.loop ?? null;
  } catch {
    /* no state / unreadable — stay clear */
  }
}

function clearStateFile(cwd: string): void {
  try {
    fs.rmSync(statePath(cwd), { force: true });
  } catch {
    /* advisory */
  }
}

// =================================================================
// Helpers
// =================================================================

function freshCtx(): ExtensionContext | null {
  if (!lastCtx) return null;
  try {
    lastCtx.isIdle();
    return lastCtx;
  } catch {
    return null;
  }
}

function rememberCtx(ctx: ExtensionContext): void {
  lastCtx = ctx;
}

function isStaleError(err: unknown): boolean {
  const msg = err instanceof Error ? err.message : String(err);
  return /stale|invalid|session replacement|assertActive/i.test(msg);
}

/** Send a user message to keep the session working. Returns true on success. */
function sendContinuation(text: string): boolean {
  if (!api) return false;
  const ctx = freshCtx();
  if (!ctx) return false;
  try {
    api.sendUserMessage(text, { deliverAs: ctx.isIdle() ? "followUp" : "steer" });
    return true;
  } catch (err) {
    if (isStaleError(err)) return false;
    return false;
  }
}

function notify(ctx: ExtensionContext, msg: string, kind: "info" | "warning" = "info"): void {
  try {
    ctx.ui.notify(msg, kind);
  } catch {
    /* stale ctx — next event refreshes */
  }
}

function fmtDuration(ms: number): string {
  const s = Math.floor(ms / 1000);
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m${s % 60 ? ` ${s % 60}s` : ""}`;
  const h = Math.floor(m / 60);
  return `${h}h ${m % 60}m`;
}

function short(s: string, n = 80): string {
  const one = s.replace(/\s+/g, " ").trim();
  return one.length <= n ? one : one.slice(0, n - 1) + "…";
}

// =================================================================
// Status line
// =================================================================

function refreshStatus(ctx: ExtensionContext): void {
  if (!ctx.hasUI) return;
  try {
    if (goal) {
      const dur = fmtDuration(Date.now() - goal.startedAt);
      ctx.ui.setStatus(
        "pi-goal",
        `◎ goal active · ${dur} · ${goal.turns} turn${goal.turns === 1 ? "" : "s"}`,
      );
    } else if (loop) {
      const pace = loop.intervalMs ? `every ${fmtDuration(loop.intervalMs)}` : "self-paced";
      ctx.ui.setStatus(
        "pi-goal",
        `↻ loop · ${pace} · ${loop.iterations} run${loop.iterations === 1 ? "" : "s"}`,
      );
    } else {
      ctx.ui.setStatus("pi-goal", "");
    }
  } catch {
    /* stale ctx */
  }
}

// =================================================================
// Transcript for the evaluator
// =================================================================

function transcriptTail(ctx: ExtensionContext, maxChars = 20000): string {
  try {
    const manager = ctx.sessionManager as unknown as {
      buildSessionContext?: () => { messages?: unknown[] };
    };
    if (typeof manager.buildSessionContext !== "function") return "(transcript unavailable)";
    const messages = manager.buildSessionContext().messages ?? [];
    const parts: string[] = [];
    let total = 0;
    for (let i = messages.length - 1; i >= 0; i--) {
      const m = messages[i] as any;
      const role = m?.role ?? "?";
      let body = "";
      if (Array.isArray(m?.content)) {
        body = m.content
          .filter((p: any) => p?.type === "text" && typeof p.text === "string")
          .map((p: any) => p.text)
          .join("\n");
      } else if (typeof m?.content === "string") {
        body = m.content;
      }
      if (!body) continue;
      const chunk = `[${role}] ${body}`;
      if (total + chunk.length > maxChars) {
        parts.unshift(`[…earlier turns truncated…]`);
        break;
      }
      parts.unshift(chunk);
      total += chunk.length;
    }
    return parts.join("\n\n") || "(empty transcript)";
  } catch {
    return "(transcript unavailable)";
  }
}

// =================================================================
// Evaluator — a small model reads the transcript, returns YES/NO + reason.
// No tools (Claude Code semantics: judges only from surfaced conversation).
// =================================================================

function evalResourceLoader(): ResourceLoader {
  return {
    getExtensions: () => ({ extensions: [], errors: [], runtime: createExtensionRuntime() }),
    getSkills: () => ({ skills: [], diagnostics: [] }),
    getPrompts: () => ({ prompts: [], diagnostics: [] }),
    getThemes: () => ({ themes: [], diagnostics: [] }),
    getAgentsFiles: () => ({ agentsFiles: [] }),
    getSystemPrompt: () =>
      "You are a goal-completion evaluator. You judge whether a stated goal condition has been met, using ONLY the conversation transcript provided. You do not run commands or read files. Answer with exactly YES or NO on the first line, then a single short sentence explaining your judgement.",
    // The evaluator prompt is synthetic, so there are no backing files to report.
    getSystemPromptSource: () => undefined,
    getAppendSystemPrompt: () => [],
    getAppendSystemPromptSources: () => [],
    extendResources: () => {},
    reload: async () => {},
  };
}

function buildEvalPrompt(condition: string, transcript: string): string {
  return [
    `GOAL CONDITION:`,
    condition,
    ``,
    `RECENT CONVERSATION:`,
    transcript,
    ``,
    `Has the goal condition been met? Answer with exactly YES or NO on the first line, then one short sentence with your reason.`,
  ].join("\n");
}

interface EvalResult {
  met: boolean;
  reason: string;
  error?: string;
}

async function evaluateGoal(ctx: ExtensionContext, condition: string): Promise<EvalResult> {
  const model = (ctx as any).model;
  if (!model) {
    return { met: false, reason: "", error: "no model available on ctx" };
  }
  const transcript = transcriptTail(ctx);
  const prompt = buildEvalPrompt(condition, transcript);
  const output: string[] = [];
  try {
    const { session } = await createAgentSession({
      cwd: ctx.cwd,
      model,
      thinkingLevel: "minimal",
      modelRuntime: (ctx as any).modelRegistry?.runtime,
      resourceLoader: evalResourceLoader(),
      sessionManager: SessionManager.inMemory(ctx.cwd),
      settingsManager: SettingsManager.inMemory({}),
      tools: [],
    });
    let streamError: string | undefined;
    const unsub = session.subscribe((event: any) => {
      if (event.type === "message_end") {
        const message = event.message;
        if (message?.role !== "assistant") return;
        if (message.stopReason === "error" && typeof message.errorMessage === "string") {
          streamError = message.errorMessage.slice(0, 300);
        }
        for (const part of message.content ?? []) {
          if (part?.type === "text" && typeof part.text === "string") output.push(part.text);
        }
      }
      if (event.type === "error" || event.error) {
        const msg = event.error?.message ?? event.message ?? event.errorMessage;
        if (typeof msg === "string") streamError = msg.slice(0, 300);
      }
    });
    try {
      await session.prompt(prompt);
    } finally {
      unsub();
    }
    const text = output.join("\n").trim();
    if (streamError && !text) {
      return { met: false, reason: "", error: streamError };
    }
    const firstLine = text.split("\n").find((l) => l.trim()) ?? "";
    const met = /^\s*yes\b/i.test(firstLine);
    const reason = text.split("\n").slice(1).join(" ").trim() || firstLine;
    return { met, reason: short(reason, 300) };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return { met: false, reason: "", error: msg.slice(0, 300) };
  }
}

// =================================================================
// Goal lifecycle
// =================================================================

function setGoal(ctx: ExtensionContext, condition: string): void {
  const trimmed = condition.trim();
  if (!trimmed) {
    notify(ctx, "Usage: /goal <condition>", "warning");
    return;
  }
  goal = { condition: trimmed, startedAt: Date.now(), turns: 0 };
  persist(ctx);
  refreshStatus(ctx);
  notify(ctx, `Goal set: ${short(trimmed)}`);
  // Setting a goal starts a turn immediately with the condition as directive.
  sendContinuation(trimmed);
}

function clearGoal(ctx: ExtensionContext, silent = false): void {
  if (!goal) {
    if (!silent) notify(ctx, "No goal set");
    return;
  }
  const cond = goal.condition;
  goal = null;
  persist(ctx);
  if (!goal && !loop) clearStateFile(ctx.cwd);
  refreshStatus(ctx);
  if (!silent) notify(ctx, `Goal cleared: ${short(cond)}`);
}

function goalStatus(ctx: ExtensionContext): void {
  if (!goal) {
    notify(ctx, "No goal set");
    return;
  }
  const dur = fmtDuration(Date.now() - goal.startedAt);
  const reason = goal.lastReason ? `\nLast reason: ${goal.lastReason}` : "";
  notify(
    ctx,
    `Goal: ${short(goal.condition, 200)}\nRunning ${dur} · ${goal.turns} turn${goal.turns === 1 ? "" : "s"}${reason}`,
  );
}

// =================================================================
// Loop lifecycle
// =================================================================

function parseInterval(s: string): number | null {
  const m = s.match(/^(\d+)\s*(ms|s|m|h)$/i);
  if (!m) return null;
  const n = parseInt(m[1]!, 10);
  switch (m[2]!.toLowerCase()) {
    case "ms":
      return n;
    case "s":
      return n * 1000;
    case "m":
      return n * 60_000;
    case "h":
      return n * 3_600_000;
  }
  return null;
}

function defaultLoopPrompt(ctx: ExtensionContext): string {
  const loopMd = path.join(ctx.cwd, ".pi-loop.md");
  try {
    if (fs.existsSync(loopMd)) {
      return fs.readFileSync(loopMd, "utf8").trim();
    }
  } catch {
    /* fall through to default */
  }
  return "Run a maintenance check: review the repository state and address anything stale, broken, or left half-finished.";
}

function clearLoopTimer(): void {
  if (loopTimer) {
    clearTimeout(loopTimer);
    loopTimer = null;
  }
}

function loopTick(ctx: ExtensionContext): void {
  if (!loop) return;
  loop.iterations++;
  loop.lastTickAt = Date.now();
  persist(ctx);
  refreshStatus(ctx);
  sendContinuation(loop.prompt);
  // Schedule next tick if timer-driven
  if (loop.intervalMs !== null) {
    clearLoopTimer();
    loopTimer = setTimeout(() => {
      const c = freshCtx();
      if (c && loop) loopTick(c);
    }, loop.intervalMs);
  }
}

function setLoop(ctx: ExtensionContext, args: string): void {
  const trimmed = args.trim();
  if (!trimmed || trimmed.toLowerCase() === "stop" || trimmed.toLowerCase() === "cancel") {
    stopLoop(ctx);
    return;
  }
  // Try to parse a leading interval: "5m <prompt>" or "30s <prompt>"
  const parts = trimmed.split(/\s+(.+)/);
  const intervalMs = parseInterval(parts[0] ?? "");
  let prompt: string;
  let pace: number | null;
  if (intervalMs !== null) {
    pace = intervalMs;
    prompt = (parts[1] ?? "").trim() || defaultLoopPrompt(ctx);
  } else {
    pace = null; // self-paced
    prompt = trimmed || defaultLoopPrompt(ctx);
  }
  clearLoopTimer();
  loop = { prompt, intervalMs: pace, iterations: 0, lastTickAt: Date.now() };
  persist(ctx);
  refreshStatus(ctx);
  const paceLabel = pace ? `every ${fmtDuration(pace)}` : "self-paced";
  notify(ctx, `Loop started (${paceLabel}): ${short(prompt)}`);
  // First tick now
  loopTick(ctx);
}

function stopLoop(ctx: ExtensionContext, silent = false): void {
  if (!loop) {
    if (!silent) notify(ctx, "No loop running");
    return;
  }
  clearLoopTimer();
  const was = loop;
  loop = null;
  persist(ctx);
  if (!goal && !loop) clearStateFile(ctx.cwd);
  refreshStatus(ctx);
  if (!silent)
    notify(
      ctx,
      `Loop stopped (${was.iterations} run${was.iterations === 1 ? "" : "s"}): ${short(was.prompt)}`,
    );
}

function loopStatus(ctx: ExtensionContext): void {
  if (!loop) {
    notify(ctx, "No loop running");
    return;
  }
  const pace = loop.intervalMs ? `every ${fmtDuration(loop.intervalMs)}` : "self-paced";
  notify(
    ctx,
    `Loop (${pace}): ${short(loop.prompt, 200)}\n${loop.iterations} run${loop.iterations === 1 ? "" : "s"}`,
  );
}

// =================================================================
// agent_end: evaluate the goal, continue the loop
// =================================================================

async function onAgentEnd(event: any, ctx: ExtensionContext): Promise<void> {
  if (goal) {
    goal.turns++;
    persist(ctx);
    refreshStatus(ctx);
    if (evalInFlight) return; // don't stack evaluators
    evalInFlight = true;
    try {
      const result = await evaluateGoal(ctx, goal.condition);
      if (!goal) return; // cleared while evaluating
      goal.lastReason = result.reason || (result.met ? "condition met" : "not yet");
      goal.lastEvalAt = Date.now();
      persist(ctx);
      if (result.error) {
        notify(ctx, `Goal evaluator error: ${result.error}. Continuing.`, "warning");
        // Keep working — the evaluator failed, not the goal.
        sendContinuation(`Continue working toward: ${goal.condition}`);
        return;
      }
      if (result.met) {
        const cond = goal.condition;
        goal = null;
        if (!goal && !loop) clearStateFile(ctx.cwd);
        refreshStatus(ctx);
        notify(ctx, `Goal achieved: ${short(cond, 200)}`);
        return;
      }
      // Not met — take the reason as guidance for the next turn.
      sendContinuation(
        `Goal not yet met: ${goal.condition}\nEvaluator: ${result.reason || "condition not satisfied"}\nKeep working.`,
      );
    } finally {
      evalInFlight = false;
    }
    return;
  }
  // Self-paced loop: tick on agent_end (no timer)
  if (loop && loop.intervalMs === null) {
    const c = freshCtx() ?? ctx;
    // Small settle delay — agent_end is a teardown boundary; sending
    // immediately can lose the message (learned from the heavy package).
    setTimeout(() => {
      if (loop && loop.intervalMs === null) loopTick(c);
    }, 1500);
  }
}

// =================================================================
// Commands
// =================================================================

function cmdGoal(args: string, ctx: ExtensionContext): void {
  rememberCtx(ctx);
  const trimmed = args.trim();
  if (!trimmed) {
    goalStatus(ctx);
    return;
  }
  if (CLEAR_ALIASES.has(trimmed.toLowerCase())) {
    clearGoal(ctx);
    return;
  }
  setGoal(ctx, trimmed);
}

function cmdLoop(args: string, ctx: ExtensionContext): void {
  rememberCtx(ctx);
  const trimmed = args.trim();
  if (!trimmed) {
    loopStatus(ctx);
    return;
  }
  setLoop(ctx, trimmed);
}

// =================================================================
// Factory
// =================================================================

export default function (pi: ExtensionAPI): void {
  api = pi;

  pi.registerCommand("goal", {
    description:
      "Set a completion condition and pi keeps working until a model confirms it's met. /goal <condition> | /goal (status) | /goal clear",
    getArgumentCompletions: (prefix: string) =>
      ["clear", "stop"]
        .filter((v) => v.startsWith(prefix))
        .map((v) => ({
          value: v + " ",
          label: v,
          description: v === "clear" ? "remove the active goal" : "alias of clear",
        })),
    handler: async (args: string, ctx: ExtensionContext) => cmdGoal(args, ctx),
  });

  pi.registerCommand("loop", {
    description:
      "Re-run a prompt while the session stays open. /loop [interval] <prompt> | /loop (status) | /loop stop. Omit the interval to self-pace.",
    getArgumentCompletions: (prefix: string) =>
      ["stop", "cancel"]
        .filter((v) => v.startsWith(prefix))
        .map((v) => ({ value: v + " ", label: v, description: "stop the loop" })),
    handler: async (args: string, ctx: ExtensionContext) => cmdLoop(args, ctx),
  });

  // Restore state when a session starts (--resume carries the goal forward).
  pi.on("session_start" as any, (_event: any, ctx: ExtensionContext) => {
    rememberCtx(ctx);
    loadState(ctx);
    // Re-arm a timer-driven loop
    if (loop && loop.intervalMs !== null) {
      clearLoopTimer();
      loopTimer = setTimeout(() => {
        const c = freshCtx();
        if (c && loop) loopTick(c);
      }, loop.intervalMs);
    }
    refreshStatus(ctx);
  });

  pi.on("agent_end", async (event: any, ctx: ExtensionContext) => {
    rememberCtx(ctx);
    await onAgentEnd(event, ctx);
  });

  // Re-arm after compaction (compact ends without an agent_end).
  pi.on("session_compact" as any, (_event: any, ctx: ExtensionContext) => {
    rememberCtx(ctx);
    if (goal) {
      setTimeout(() => {
        if (goal) sendContinuation(`Continue working toward: ${goal.condition}`);
      }, 2000);
    } else if (loop && loop.intervalMs === null) {
      setTimeout(() => {
        if (loop && loop.intervalMs === null) {
          const c = freshCtx();
          if (c) loopTick(c);
        }
      }, 2000);
    }
  });

  // Liveness — refresh the status line as time passes.
  pi.on("turn_start" as any, (_event: any, ctx: ExtensionContext) => {
    rememberCtx(ctx);
    refreshStatus(ctx);
  });
}