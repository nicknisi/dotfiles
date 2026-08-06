/**
 * Pi Statusline Extension
 *
 * Custom footer showing model, cost, context usage, git branch, and lines changed.
 * Also writes tmux status files (working/waiting/idle) for tmux integration.
 *
 * Tmux status integration:
 *   - Writes state to ~/.cache/pi-status/<session>.status
 *   - States: working, done, idle
 *
 * Custom footer showing:
 *   - Model name with icon
 *   - Session cost
 *   - Lines added/removed
 *   - Context window usage bar
 *   - Git branch
 */

import type { AssistantMessage } from '@earendil-works/pi-ai';
import type { ExtensionAPI, Theme } from '@earendil-works/pi-coding-agent';
import { columns } from '../lib/tui-utils.ts';
import { hyperlink, visibleWidth } from '@earendil-works/pi-tui';
import { writeFileSync, readFileSync, mkdirSync, existsSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { execSync, execFile, spawn } from 'node:child_process';
import { promisify } from 'node:util';

const execFileP = promisify(execFile);

// ── Tmux status integration ─────────────────────────────────────────────────

const STATUS_DIR = join(process.env.HOME || '', '.cache', 'pi-status');

function getTmuxSession(): string | undefined {
  if (!process.env.TMUX) return undefined;
  try {
    return execSync("tmux display-message -p '#{session_name}'", {
      encoding: 'utf-8',
      timeout: 2000,
    }).trim();
  } catch {
    // Fallback: parse TMUX env var
    const socketPath = process.env.TMUX?.split(',')[0];
    if (socketPath) {
      const parts = socketPath.split('/');
      return parts[parts.length - 1];
    }
    return undefined;
  }
}

function removeStatus() {
  const paneId = process.env.TMUX_PANE;
  if (!paneId) return;
  const paneNum = paneId.replace('%', '');
  try {
    const file = join(STATUS_DIR, `${paneNum}.status`);
    if (existsSync(file)) {
      const { unlinkSync } = require('node:fs');
      unlinkSync(file);
    }
  } catch {
    // Silently fail
  }
}

function writeStatus(status: 'working' | 'done' | 'completed' | 'idle', tool?: string) {
  const paneId = process.env.TMUX_PANE;
  if (!paneId) return;
  const session = getTmuxSession();
  if (!session) return;
  const paneNum = paneId.replace('%', '');
  try {
    if (!existsSync(STATUS_DIR)) mkdirSync(STATUS_DIR, { recursive: true });
    writeFileSync(
      join(STATUS_DIR, `${paneNum}.status`),
      JSON.stringify({
        state: status,
        pane: paneId,
        session,
        tool: tool ?? '',
        ts: Math.floor(Date.now() / 1000),
      }),
    );
  } catch {
    // Silently fail - don't break the agent
  }
}

// ── Usage limits (Anthropic OAuth API) ────────────────────────────────────────

const USAGE_CACHE_TTL = 120; // seconds
const USAGE_CACHE_DIR = join(process.env.TMPDIR || '/tmp', 'pi-statusline-cache');

interface UsageWindow {
  utilization: number;
  resets_at: string;
}

interface UsageData {
  five_hour: UsageWindow;
  seven_day: UsageWindow;
}

async function getOAuthToken(): Promise<string | undefined> {
  // Try pi's auth.json first (cheap sync file read)
  const piAuth = join(process.env.HOME || '', '.pi', 'agent', 'auth.json');
  try {
    const data = JSON.parse(readFileSync(piAuth, 'utf-8'));
    if (data?.anthropic?.access) return data.anthropic.access;
  } catch {}

  // Fallback: Claude Code keychain (macOS), async so it never blocks the TUI
  try {
    const { stdout } = await execFileP('security', ['find-generic-password', '-s', 'Claude Code-credentials', '-w'], {
      timeout: 2000,
    });
    const parsed = JSON.parse(stdout.trim());
    if (parsed?.claudeAiOauth?.accessToken) return parsed.claudeAiOauth.accessToken;
  } catch {}

  return undefined;
}

function readUsageCache(allowStale = false): UsageData | undefined {
  const cacheFile = join(USAGE_CACHE_DIR, 'usage.json');
  try {
    if (!existsSync(cacheFile)) return undefined;
    const stat = statSync(cacheFile);
    const age = (Date.now() - stat.mtimeMs) / 1000;
    if (!allowStale && age >= USAGE_CACHE_TTL) return undefined;
    return JSON.parse(readFileSync(cacheFile, 'utf-8'));
  } catch {
    return undefined;
  }
}

let usageRefreshInFlight = false;
let onUsageUpdated: (() => void) | undefined;

/** Fire-and-forget async refresh of the usage cache. Never blocks the TUI. */
function refreshUsage(): void {
  if (usageRefreshInFlight) return;
  usageRefreshInFlight = true;
  void (async () => {
    try {
      const token = await getOAuthToken();
      if (!token) return;
      const { stdout } = await execFileP(
        'curl',
        [
          '-s',
          '--max-time',
          '3',
          '-H',
          `Authorization: Bearer ${token}`,
          '-H',
          'anthropic-beta: oauth-2025-04-20',
          'https://api.anthropic.com/api/oauth/usage',
        ],
        { timeout: 5000 },
      );
      const data = JSON.parse(stdout);
      if (data?.five_hour?.utilization === undefined) return;
      if (!existsSync(USAGE_CACHE_DIR)) mkdirSync(USAGE_CACHE_DIR, { recursive: true });
      writeFileSync(join(USAGE_CACHE_DIR, 'usage.json'), stdout);
      onUsageUpdated?.();
    } catch {
      // non-fatal: usage segment just renders stale/absent data
    } finally {
      usageRefreshInFlight = false;
    }
  })();
}

/**
 * Usage data for the footer. Reads only the on-disk cache; when it's stale or
 * missing, kicks an async refresh and renders stale data (or nothing) in the
 * meantime. Never performs network or keychain I/O on the render path.
 */
function getUsageData(): UsageData | undefined {
  const fresh = readUsageCache();
  if (fresh) return fresh;
  refreshUsage();
  return readUsageCache(true);
}

function formatTimeUntil(resetsAt: string): string {
  try {
    const resetEpoch = new Date(resetsAt).getTime();
    const now = Date.now();
    if (now >= resetEpoch) return 'now';

    const secs = Math.floor((resetEpoch - now) / 1000);
    const mins = Math.floor(secs / 60);
    const hours = Math.floor(mins / 60);
    const days = Math.floor(hours / 24);

    if (days > 0) return `${days}d${hours % 24}h`;
    if (hours > 0) return `${hours}h${mins % 60}m`;
    return `${mins}m`;
  } catch {
    return '?';
  }
}

// ── Helper: build a progress bar ─────────────────────────────────────────────

function buildBar(percent: number, width: number, theme: Pick<Theme, 'fg'>): string {
  const filled = Math.round((percent * width) / 100);
  const empty = width - filled;
  const color = percent > 50 ? 'success' : percent > 20 ? 'warning' : 'error';
  let bar = '';
  for (let i = 0; i < filled; i++) bar += '━';
  for (let i = 0; i < empty; i++) bar += '╌';
  return theme.fg(color, bar);
}

// ── Helper: format token count ───────────────────────────────────────────────

function formatTokens(n: number): string {
  if (n >= 1000) return `${Math.round(n / 1000)}K`;
  return `${n}`;
}

// ── PR lookup (async, cached by branch — never blocks render) ───────────────

interface PrInfo {
  number: number;
  url: string;
}

const PR_CACHE_TTL = 60; // seconds — branch→PR mapping is stable, refresh occasionally
const prCache = new Map<string, { info: PrInfo | null; expires: number }>();
let prRefreshInFlight: string | undefined;
let onPrUpdated: (() => void) | undefined;

/** Pure cache read — safe to call on the render path. */
function getPrCached(branch: string): PrInfo | null {
  const cached = prCache.get(branch);
  return cached && cached.expires > Date.now() ? cached.info : null;
}

/**
 * Fire-and-forget `gh pr view` for a branch. Updates the cache and asks the
 * footer to re-render on completion. The branch comes from footerData, so no
 * subprocess is spawned here unless the cache is actually stale.
 */
function refreshPr(branch: string): void {
  const cached = prCache.get(branch);
  if (cached && cached.expires > Date.now()) return;
  if (prRefreshInFlight === branch) return;
  prRefreshInFlight = branch;
  execFile(
    'gh',
    ['pr', 'view', '--json', 'number,url', '--jq', '"\\(.number)\\t\\(.url)"'],
    { timeout: 8000 },
    (err, stdout) => {
      prRefreshInFlight = undefined;
      let info: PrInfo | null = null;
      if (!err) {
        const [num, url] = stdout.trim().split('\t');
        if (num && url) info = { number: parseInt(num, 10), url };
      }
      // Cache misses too, so a non-PR branch doesn't refetch every render window
      prCache.set(branch, { info, expires: Date.now() + PR_CACHE_TTL * 1000 });
      onPrUpdated?.();
    },
  );
}

// ── Thinking level (re-render hook) ─────────────────────────────────────────

let onThinkingUpdated: (() => void) | undefined;

// ── Extension ────────────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  pi.on('thinking_level_select', async () => {
    onThinkingUpdated?.();
  });

  // ── Tmux status hooks ──────────────────────────────────────────────────

  pi.on('session_start', async () => {
    writeStatus('idle');
  });

  pi.on('agent_start', async () => {
    writeStatus('working');
  });

  pi.on('tool_execution_start', async (event) => {
    writeStatus('working', (event as any).toolName);
  });

  pi.on('agent_end', async () => {
    writeStatus('done');
    const session = getTmuxSession();
    const paneId = process.env.TMUX_PANE;
    if (session && paneId) {
      spawn('claude-notify', ['waiting', session, paneId], {
        detached: true,
        stdio: 'ignore',
      }).unref();
    }
  });

  pi.on('session_shutdown', async () => {
    removeStatus();
  });

  pi.on('session_start', async (event) => {
    if (event.reason === 'new') {
      writeStatus('idle');
    }
  });

  // ── Turn tracking ──────────────────────────────────────────────────────

  pi.on('turn_start', async () => {
    // Keep the status-file timestamp fresh during long tool-less
    // generations: fleet decays "working" to idle after 180s stale,
    // and pi has no scrape/title fallback signal there.
    writeStatus('working');
  });

  // ── Custom footer ──────────────────────────────────────────────────────

  pi.on('session_start', async (_event, ctx) => {
    ctx.ui.setFooter((tui, theme, footerData) => {
      const unsub = footerData.onBranchChange(() => tui.requestRender());
      onPrUpdated = () => tui.requestRender();
      onUsageUpdated = () => tui.requestRender();
      onThinkingUpdated = () => tui.requestRender();

      // Cost/lines totals need an O(session) walk of every entry — cache them
      // and recompute only when the branch grows or every 5s, not per render.
      let lastEntryCount = -1;
      let lastTotalsAt = 0;
      let totals = { cost: 0, added: 0, removed: 0 };

      return {
        dispose: () => {
          unsub();
          onPrUpdated = undefined;
          onUsageUpdated = undefined;
          onThinkingUpdated = undefined;
        },
        invalidate() {},
        render(width: number): string[] {
          const SEP = theme.fg('dim', ' │ ');

          // ── Model ────────────────────────────────────────────
          const modelId = ctx.model?.id || 'no-model';
          const modelName = ctx.model?.name || modelId;
          // Short display name: strip provider prefix, parenthetical
          const shortModel = modelName.replace(/ \(.*\)/, '');

          // Model icon based on name (nerd font icons)
          // \U000f06a9 = 󰚩 robot, \U000f01e5 = 󰇥 diamond, \U000f075a = 󰝚 music-note, \U000f0735 = 󰜵 snowflake
          let modelIcon: string;
          const lower = shortModel.toLowerCase();
          if (lower.includes('opus')) modelIcon = theme.fg('accent', '\u{F01E5}');
          else if (lower.includes('sonnet')) modelIcon = theme.fg('accent', '\u{F075A}');
          else if (lower.includes('haiku')) modelIcon = theme.fg('success', '\u{F0735}');
          else modelIcon = theme.fg('dim', '\u{F06A9}');

          // Thinking level — only meaningful on reasoning models (pi clamps
          // everything else to "off"). Read live so /model, keybindings, and
          // pi.setThinkingLevel() all reflect immediately.
          const thinkingLevel = ctx.model?.reasoning ? pi.getThinkingLevel() : undefined;

          // ── Cost & tokens ────────────────────────────────────
          const branchEntries = ctx.sessionManager.getBranch();
          const now = Date.now();
          if (branchEntries.length !== lastEntryCount || now - lastTotalsAt > 5000) {
            lastEntryCount = branchEntries.length;
            lastTotalsAt = now;
            totals = { cost: 0, added: 0, removed: 0 };
            for (const entry of branchEntries) {
              if (entry.type !== 'message') continue;
              if (entry.message.role === 'assistant') {
                const m = entry.message as AssistantMessage;
                totals.cost += m.usage.cost.total;
              }
              if (entry.message.role === 'toolResult') {
                const details = entry.message.details;
                if (details && typeof details === 'object') {
                  // Edit tool details have linesAdded/linesRemoved
                  if ('linesAdded' in details) totals.added += (details as any).linesAdded || 0;
                  if ('linesRemoved' in details) totals.removed += (details as any).linesRemoved || 0;
                }
              }
            }
          }
          const totalCost = totals.cost;
          const linesAdded = totals.added;
          const linesRemoved = totals.removed;

          // ── Context usage ────────────────────────────────────
          const usage = ctx.getContextUsage();
          const usedPercent = usage?.percent ?? 0;
          const remaining = Math.max(0, Math.round(100 - usedPercent));
          const tokensUsed = usage?.tokens ?? 0;

          // ── Build segments ───────────────────────────────────────
          const segments: string[] = [];

          // Nerd font icons for each section
          // \uf155 =  dollar, \uf440 =  lines, \U000f09d1 = 󰧑 context, \ue725 =  branch
          const ICON_COST = theme.fg('success', '\u{F155}');
          const ICON_LINES = theme.fg('accent', '\u{F440}');
          const ICON_CONTEXT = theme.fg('accent', '\u{F09D1}');
          const ICON_BRANCH = theme.fg('success', '\u{E725}');

          // Model (+ thinking level)
          const modelSeg = `${modelIcon} ${theme.fg('accent', shortModel)}`;
          segments.push(thinkingLevel ? `${modelSeg} ${theme.fg('dim', thinkingLevel)}` : modelSeg);

          // Cost (only if non-zero)
          if (totalCost > 0.001) {
            segments.push(`${ICON_COST} ${theme.fg('dim', `$${totalCost.toFixed(2)}`)}`);
          }

          // Lines changed (only if non-zero)
          if (linesAdded > 0 || linesRemoved > 0) {
            const lines = `${theme.fg('success', `+${linesAdded}`)}/${theme.fg('error', `-${linesRemoved}`)}`;
            segments.push(`${ICON_LINES} ${lines}`);
          }

          // Usage limits (5h / 7d windows) — only for Anthropic models
          // \U000f0241 = 󰉁 gauge
          const ICON_USAGE = theme.fg('warning', '\u{F0241}');
          const isAnthropic = ctx.model?.provider === 'anthropic';
          const usageData = isAnthropic ? getUsageData() : undefined;
          if (usageData) {
            const fiveRemaining = Math.max(0, Math.round(100 - usageData.five_hour.utilization));
            const sevenRemaining = Math.max(0, Math.round(100 - usageData.seven_day.utilization));
            const fiveUntil = formatTimeUntil(usageData.five_hour.resets_at);
            const sevenUntil = formatTimeUntil(usageData.seven_day.resets_at);

            const fiveBar = buildBar(fiveRemaining, 5, theme);
            const sevenBar = buildBar(sevenRemaining, 5, theme);

            const fiveStr = `${theme.fg('dim', '5h')} ${fiveBar} ${fiveRemaining}% ${theme.fg('dim', `↻${fiveUntil}`)}`;
            const sevenStr = `${theme.fg('dim', '7d')} ${sevenBar} ${sevenRemaining}% ${theme.fg('dim', `↻${sevenUntil}`)}`;
            segments.push(`${ICON_USAGE} ${fiveStr} ${theme.fg('dim', '╱')} ${sevenStr}`);
          }

          // Context bar — stretch to fill whatever width remains on the line.
          // Build a placeholder context segment, measure all segments + the right
          // side, then give the bar the leftover columns (clamped 5..40).
          const tokenStr = tokensUsed > 0 ? theme.fg('dim', ` (${formatTokens(tokensUsed)})`) : '';
          const ctxLabel = `${ICON_CONTEXT} `;
          const ctxTail = ` ${remaining}% ctx${tokenStr}`;
          const branch = footerData.getGitBranch();
          if (branch) refreshPr(branch); // async; no-op while the cache is fresh
          const pr = branch ? getPrCached(branch) : null;
          const branchStr = branch ? `${ICON_BRANCH} ${branch}` : '';
          const prStr = pr ? ` ${hyperlink(theme.fg('accent', `#${pr.number}`), pr.url)}` : '';
          const right = branch ? theme.fg('dim', branchStr) + prStr : '';
          const PAD = ' ';
          const innerWidth = width - 2; // minus the two PAD gutters
          const sepWidth = visibleWidth(SEP);
          const otherWidth =
            segments.reduce((sum, s) => sum + visibleWidth(s), 0) +
            sepWidth * segments.length + // separators between segments
            sepWidth + // separator before context segment
            visibleWidth(ctxLabel) +
            visibleWidth(ctxTail) +
            visibleWidth(right) +
            1; // min 1 gap between left and right
          const barWidth = Math.max(5, Math.min(40, innerWidth - otherWidth));
          const contextBar = buildBar(remaining, barWidth, theme);
          segments.push(`${ctxLabel}${contextBar}${ctxTail}`);

          const left = segments.join(SEP);
          return [`${PAD}${columns(left, right, width - 2)}${PAD}`];
        },
      };
    });
  });
}
