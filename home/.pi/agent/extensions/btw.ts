/**
 * /btw extension — side-channel chat in a floating window
 *
 * Usage: /btw <question>
 *
 * Opens a side-chat window backed by a one-off LLM thread (streamSimple) that
 * sees the current branch context + your questions. Answers stream live into
 * the window and follow-ups can be typed right there — the main agent's
 * context is never touched, no matter how deep the thread goes.
 *
 * From the window (when idle):
 *   enter    send a follow-up
 *   esc      close (streaming: cancel the in-flight answer)
 *   ctrl+p   promote — close and hand the thread to the main agent
 *   ctrl+f   fork — write branch + thread to a new session file and open it:
 *            tmux split (direction from pane width, PI_BTW_SPLIT=h|v to force)
 *            → new Ghostty window (macOS) → clipboard + printed command
 *
 * On close the thread persists with pi.appendEntry() as a custom ENTRY: it
 * renders in the transcript but never participates in the agent's LLM
 * context and never triggers a turn.
 *
 * Why not pi.sendMessage()? Custom MESSAGES participate in LLM context and,
 * when sent while the agent is streaming, are delivered as steer messages —
 * which continues the agent loop with an extra LLM call. Our own context
 * filter then strips the btw message, leaving the conversation ending with an
 * assistant message, which models that reject assistant prefill 400 on.
 */

import { execFile } from 'node:child_process';
import { randomBytes, randomUUID } from 'node:crypto';
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';
import type { AssistantMessage, Message, ThinkingLevel } from '@earendil-works/pi-ai';
import { getModelProvider } from '../lib/llm.ts';
import type { ExtensionAPI, SessionEntry, Theme } from '@earendil-works/pi-coding-agent';
import { convertToLlm, CURRENT_SESSION_VERSION, getMarkdownTheme } from '@earendil-works/pi-coding-agent';
import {
  Box,
  type Component,
  Editor,
  type EditorTheme,
  type Focusable,
  Key,
  Markdown,
  matchesKey,
  Text,
  truncateToWidth,
  type TUI,
  visibleWidth,
  wrapTextWithAnsi,
} from '@earendil-works/pi-tui';

const CUSTOM_TYPE = 'btw-answer';

interface Turn {
  question: string;
  answer: string;
}

interface BtwEntryData {
  model: string;
  turns?: Turn[];
  /** Legacy single-Q&A entries */
  question?: string;
  answer?: string;
}

type BtwAction = 'close' | 'promote' | 'fork';
type BtwResult = { turns: Turn[]; action: BtwAction } | null;

const SYSTEM_PROMPT = `You are a helpful side-channel assistant. The user is in the middle of a coding session and has a quick question (possibly with follow-ups). Answer concisely based on the conversation context provided. Do not suggest tool calls or actions — just answer directly.`;

const SPINNER_FRAMES = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

function extractText(content: AssistantMessage['content']): string {
  return content
    .filter((c): c is { type: 'text'; text: string } => c.type === 'text')
    .map((c) => c.text)
    .join('\n');
}

function firstLine(text: string, max = 120): string {
  const line = text.split('\n')[0] ?? '';
  return line.length > max ? line.slice(0, max - 3) + '...' : line;
}

function normalizeTurns(data: BtwEntryData | undefined): Turn[] {
  if (data?.turns?.length) return data.turns;
  if (data?.question) return [{ question: data.question, answer: data.answer ?? '' }];
  return [];
}

/** Transcript card shared by the entry renderer and the legacy message renderer. */
function buildCard(turns: Turn[], model: string, expanded: boolean, theme: Theme): Box {
  const count = turns.length > 1 ? theme.fg('dim', ` · ${turns.length} turns`) : '';
  const header = `${theme.fg('accent', theme.bold('btw'))} ${theme.fg('dim', `(${model})`)}${count}`;

  const lines: string[] = [header];
  if (expanded) {
    for (const t of turns) {
      lines.push(`${theme.fg('warning', 'Q:')} ${t.question}`);
      lines.push(`${theme.fg('success', 'A:')} ${t.answer}`);
    }
  } else {
    const last = turns[turns.length - 1];
    if (last) {
      lines.push(`${theme.fg('warning', 'Q:')} ${last.question}`);
      lines.push(`${theme.fg('success', 'A:')} ${firstLine(last.answer)}`);
    }
  }

  const box = new Box(1, 1, (t) => theme.bg('customMessageBg', t));
  box.addChild(new Text(lines.join('\n'), 0, 0));
  return box;
}

function formatThreadForPromote(turns: Turn[], model: string): string {
  const body = turns.map((t) => `Q: ${t.question}\nA: ${t.answer}`).join('\n\n');
  return `FYI — I had this side conversation with ${model} (via /btw). Factor it into what you're doing where relevant:\n\n${body}`;
}

/** Side-chat window: streaming markdown thread + follow-up editor. */
class BtwWindow implements Component, Focusable {
  onAsk?: (question: string) => void;

  private _focused = false;
  private state: 'streaming' | 'idle' = 'idle';
  private readonly turns: Turn[] = [];
  private currentQuestion = '';
  private currentAnswer = '';
  private lastError = '';
  private abort: AbortController | undefined;
  private frame = 0;
  private timer: ReturnType<typeof setInterval> | undefined;
  private stickBottom = true;
  private scroll = 0;
  private lastMaxScroll = 0;
  private readonly editor: Editor;
  private doneCache?: { width: number; upTo: number; lines: string[] };

  constructor(
    private readonly tui: TUI,
    private readonly theme: Theme,
    private readonly model: string,
    private readonly close: (result: BtwResult) => void,
  ) {
    const editorTheme: EditorTheme = {
      borderColor: (text: string) => theme.fg('borderAccent', text),
      selectList: {
        selectedPrefix: (text: string) => theme.fg('accent', text),
        selectedText: (text: string) => theme.fg('accent', text),
        description: (text: string) => theme.fg('muted', text),
        scrollInfo: (text: string) => theme.fg('dim', text),
        noMatch: (text: string) => theme.fg('warning', text),
      },
    };
    this.editor = new Editor(this.tui, editorTheme);
    this.editor.disableSubmit = true;
    this.editor.onChange = () => this.tui.requestRender();
  }

  get focused(): boolean {
    return this._focused;
  }

  set focused(value: boolean) {
    this._focused = value;
    this.editor.focused = value && this.state === 'idle';
  }

  get signal(): AbortSignal | undefined {
    return this.abort?.signal;
  }

  get completedTurns(): Turn[] {
    return this.turns;
  }

  beginStreaming(question: string): void {
    this.currentQuestion = question;
    this.currentAnswer = '';
    this.lastError = '';
    this.state = 'streaming';
    this.editor.focused = false;
    this.abort = new AbortController();
    this.stickBottom = true;
    if (!this.timer) {
      this.timer = setInterval(() => {
        this.frame = (this.frame + 1) % SPINNER_FRAMES.length;
        this.tui.requestRender();
      }, 100);
    }
    this.tui.requestRender();
  }

  append(delta: string): void {
    this.currentAnswer += delta;
    this.tui.requestRender();
  }

  completeTurn(answer: string): void {
    this.turns.push({ question: this.currentQuestion, answer: answer || this.currentAnswer });
    this.backToIdle('');
  }

  /** Cancelled mid-stream: restore the question into the editor for retry. */
  cancelCurrent(): void {
    this.backToIdle(this.currentQuestion);
  }

  fail(message: string): void {
    this.lastError = message;
    this.backToIdle(this.currentQuestion);
  }

  private backToIdle(editorText: string): void {
    this.currentQuestion = '';
    this.currentAnswer = '';
    this.state = 'idle';
    if (editorText) this.editor.setText(editorText);
    this.editor.focused = this._focused;
    this.stopSpinner();
    this.tui.requestRender();
  }

  private stopSpinner(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = undefined;
    }
  }

  dispose(): void {
    this.stopSpinner();
  }

  invalidate(): void {
    this.doneCache = undefined;
  }

  private dismiss(action: BtwAction): void {
    if (this.turns.length === 0) {
      this.close(null);
      return;
    }
    this.close({ turns: this.turns, action });
  }

  handleInput(data: string): void {
    if (this.state === 'streaming') {
      if (matchesKey(data, Key.escape) || matchesKey(data, Key.ctrl('c'))) {
        this.abort?.abort();
        this.cancelCurrent();
        return;
      }
      if (matchesKey(data, Key.up)) this.scrollBy(-1);
      else if (matchesKey(data, Key.down)) this.scrollBy(1);
      return;
    }

    if (matchesKey(data, Key.escape) || matchesKey(data, Key.ctrl('c'))) {
      this.dismiss('close');
      return;
    }
    if (matchesKey(data, Key.ctrl('p'))) {
      this.dismiss('promote');
      return;
    }
    if (matchesKey(data, Key.ctrl('f'))) {
      this.dismiss('fork');
      return;
    }
    if (matchesKey(data, Key.enter) && !matchesKey(data, Key.shift('enter'))) {
      const question = this.editor.getText().trim();
      if (question) {
        this.editor.setText('');
        this.onAsk?.(question);
      }
      return;
    }
    if (this.editor.getText() === '') {
      if (matchesKey(data, Key.up)) {
        this.scrollBy(-1);
        return;
      }
      if (matchesKey(data, Key.down)) {
        this.scrollBy(1);
        return;
      }
    }
    this.editor.handleInput(data);
    this.tui.requestRender();
  }

  private scrollBy(delta: number): void {
    const base = this.stickBottom ? this.lastMaxScroll : this.scroll;
    this.scroll = Math.max(0, Math.min(this.lastMaxScroll, base + delta));
    this.stickBottom = this.scroll >= this.lastMaxScroll;
    this.tui.requestRender();
  }

  private turnLines(turn: { question: string; answer: string }, width: number): string[] {
    const lines = wrapTextWithAnsi(`${this.theme.fg('warning', 'Q:')} ${turn.question}`, width);
    if (turn.answer) {
      lines.push(...new Markdown(turn.answer, 0, 0, getMarkdownTheme()).render(width));
    }
    return lines;
  }

  private bodyLines(width: number): string[] {
    if (this.doneCache?.width !== width || this.doneCache.upTo !== this.turns.length) {
      const lines: string[] = [];
      for (const turn of this.turns) {
        if (lines.length > 0) lines.push('');
        lines.push(...this.turnLines(turn, width));
      }
      this.doneCache = { width, upTo: this.turns.length, lines };
    }
    const lines = [...this.doneCache.lines];
    if (this.state === 'streaming') {
      if (lines.length > 0) lines.push('');
      lines.push(...this.turnLines({ question: this.currentQuestion, answer: this.currentAnswer }, width));
      if (!this.currentAnswer) lines.push(this.theme.fg('muted', 'thinking…'));
    }
    if (this.lastError) {
      if (lines.length > 0) lines.push('');
      lines.push(...wrapTextWithAnsi(this.theme.fg('error', this.lastError), width));
    }
    return lines;
  }

  render(width: number): string[] {
    const boxWidth = Math.min(Math.max(width, 20), 100);
    const innerWidth = Math.max(1, boxWidth - 2);
    const contentWidth = Math.max(1, innerWidth - 2);
    const border = (s: string) => this.theme.fg('border', s);
    const lines: string[] = [];
    const push = (content = '') => {
      const line = truncateToWidth(content, innerWidth, '…');
      const pad = Math.max(0, innerWidth - visibleWidth(line));
      lines.push(border('│') + line + ' '.repeat(pad) + border('│'));
    };

    lines.push(border(`╭${'─'.repeat(innerWidth)}╮`));
    const spinner = this.state === 'streaming' ? ` ${this.theme.fg('accent', SPINNER_FRAMES[this.frame]!)}` : '';
    push(` ${this.theme.fg('accent', this.theme.bold('btw'))} ${this.theme.fg('dim', `(${this.model})`)}${spinner}`);
    lines.push(border(`├${'─'.repeat(innerWidth)}┤`));

    const rows = this.tui.terminal.rows || 40;
    const maxBody = Math.max(5, Math.min(rows - 14, 30));
    const body = this.bodyLines(contentWidth);
    this.lastMaxScroll = Math.max(0, body.length - maxBody);
    const start = this.stickBottom ? this.lastMaxScroll : Math.min(this.scroll, this.lastMaxScroll);
    for (const l of body.slice(start, start + maxBody)) {
      push(` ${l}`);
    }

    if (this.state === 'idle') {
      lines.push(border(`├${'─'.repeat(innerWidth)}┤`));
      const editorLines = this.editor.render(contentWidth);
      for (let i = 1; i < editorLines.length - 1; i++) {
        push(` ${editorLines[i]}`);
      }
    }

    lines.push(border(`├${'─'.repeat(innerWidth)}┤`));
    const hint =
      this.state === 'streaming'
        ? 'esc cancel'
        : this.turns.length > 0
          ? 'enter send • esc close • ^p promote • ^f fork'
          : 'enter send • esc close';
    push(` ${this.theme.fg('dim', hint)}`);
    lines.push(border(`╰${'─'.repeat(innerWidth)}╯`));
    return lines;
  }
}

export default function (pi: ExtensionAPI) {
  // ── Legacy: old sessions persisted answers as custom MESSAGES ─────────
  // Keep filtering them out of the main agent's context and rendering them.
  // New answers are custom ENTRIES, which never enter context by design.
  pi.on('context', async (event) => {
    const filtered = event.messages.filter((m) => !(m.role === 'custom' && (m as any).customType === CUSTOM_TYPE));
    return { messages: filtered };
  });

  pi.registerMessageRenderer(CUSTOM_TYPE, (message, { expanded }, theme) => {
    const details = message.details as { question?: string; model?: string } | undefined;
    const answer = typeof message.content === 'string' ? message.content : '';
    const turns = [{ question: details?.question ?? '?', answer }];
    return buildCard(turns, details?.model ?? 'unknown', expanded, theme);
  });

  // ── Transcript renderer for persisted btw threads ─────────────────────
  pi.registerEntryRenderer<BtwEntryData>(CUSTOM_TYPE, (entry, { expanded }, theme) => {
    return buildCard(normalizeTurns(entry.data), entry.data?.model ?? 'unknown', expanded, theme);
  });

  // ── /btw command ──────────────────────────────────────────────────────
  pi.registerCommand('btw', {
    description: 'Side-chat window: ask + follow-ups (never touches agent context)',
    handler: async (args, ctx) => {
      const question = args.trim();
      if (!question) {
        ctx.ui.notify('Usage: /btw <question>', 'error');
        return;
      }

      if (!ctx.model) {
        ctx.ui.notify('No model selected', 'error');
        return;
      }

      // Gather branch messages and convert to LLM format
      const branch = ctx.sessionManager.getBranch();
      const agentMessages = branch
        .filter((e): e is SessionEntry & { type: 'message' } => e.type === 'message')
        .map((e) => e.message);
      const llmMessages: Message[] = convertToLlm(agentMessages);

      // If /btw runs mid-turn, trailing tool calls have no results yet and
      // Anthropic rejects tool_use blocks without a matching tool_result.
      // Drop unanswered tool calls (and assistant messages left empty).
      const answered = new Set<string>();
      for (const m of llmMessages) {
        if (m.role === 'toolResult') answered.add(m.toolCallId);
      }
      const sideThread: Message[] = [];
      for (const m of llmMessages) {
        if (m.role !== 'assistant') {
          sideThread.push(m);
          continue;
        }
        const content = m.content.filter((c) => c.type !== 'toolCall' || answered.has(c.id));
        if (content.length > 0) {
          sideThread.push(content.length === m.content.length ? m : { ...m, content });
        }
      }

      // Map thinking level ("off" → undefined, otherwise pass through)
      const thinkingLevel = pi.getThinkingLevel();
      const reasoning: ThinkingLevel | undefined =
        thinkingLevel === 'off' ? undefined : (thinkingLevel as ThinkingLevel);

      const auth = await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model);
      if (!auth.ok) {
        ctx.ui.notify(`No API key for ${ctx.model.provider}/${ctx.model.id}: ${auth.error}`, 'error');
        return;
      }
      const { apiKey, headers } = auth;

      const model = ctx.model;
      const modelId = model.id;

      const makeUser = (text: string): Message => ({
        role: 'user',
        content: [{ type: 'text', text }],
        timestamp: Date.now(),
      });
      const makeAssistant = (text: string): Message => ({
        role: 'assistant',
        content: [{ type: 'text', text }],
        api: model.api,
        provider: model.provider,
        model: modelId,
        usage: {
          input: 0,
          output: 0,
          cacheRead: 0,
          cacheWrite: 0,
          totalTokens: 0,
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
        },
        stopReason: 'stop',
        timestamp: Date.now(),
      });

      // Run the side-chat window
      const result = await ctx.ui.custom<BtwResult>((tui, theme, _kb, done) => {
        const win = new BtwWindow(tui, theme, modelId, done);

        const runQuestion = async (q: string) => {
          win.beginStreaming(q);
          // Capture this run's signal: win.signal changes on retry after cancel.
          const signal = win.signal;
          const requestMessages = [...sideThread, makeUser(q)];
          try {
            const stream = getModelProvider(ctx, model).streamSimple(
              model,
              { systemPrompt: SYSTEM_PROMPT, messages: requestMessages },
              { apiKey, headers, reasoning, signal },
            );

            let final = '';
            for await (const event of stream) {
              if (event.type === 'text_delta') {
                win.append(event.delta);
              } else if (event.type === 'done') {
                final = extractText(event.message.content);
              } else if (event.type === 'error') {
                if (event.reason !== 'aborted' && !signal?.aborted) {
                  win.fail(event.error.errorMessage ?? 'Request failed');
                }
                return;
              }
            }
            if (signal?.aborted) return;
            if (!final) {
              win.fail('Empty response');
              return;
            }
            sideThread.push(makeUser(q), makeAssistant(final));
            win.completeTurn(final);
          } catch (err) {
            if (signal?.aborted) return;
            win.fail(err instanceof Error ? err.message : String(err));
          }
        };

        win.onAsk = (q) => void runQuestion(q);
        void runQuestion(question);
        return win;
      });

      if (!result || result.turns.length === 0) return;

      // Fork BEFORE persisting the card so the snapshot doesn't include it.
      if (result.action === 'fork') {
        try {
          const file = forkSessionWithThread(ctx.sessionManager, result.turns, makeAssistant);
          ctx.ui.notify(await openFork(file, ctx.sessionManager.getCwd()), 'info');
        } catch (err) {
          ctx.ui.notify(`fork failed: ${err instanceof Error ? err.message : String(err)}`, 'error');
        }
      }

      // Persist for scrollback as a custom ENTRY: rendered in the transcript,
      // never part of LLM context, never triggers or steers an agent turn.
      pi.appendEntry<BtwEntryData>(CUSTOM_TYPE, { model: modelId, turns: result.turns });

      if (result.action === 'promote') {
        pi.sendUserMessage(
          formatThreadForPromote(result.turns, modelId),
          ctx.isIdle() ? undefined : { deliverAs: 'steer' },
        );
      }
    },
  });
}

/**
 * Write the current branch + the btw thread (as real user/assistant messages)
 * to a NEW session file, leaving the live session untouched. Mirrors what
 * SessionManager.createBranchedSession does, minus the switch-in-place.
 */
function forkSessionWithThread(
  sessionManager: {
    getBranch(): SessionEntry[];
    getCwd(): string;
    getSessionDir(): string;
    getSessionFile(): string | undefined;
  },
  turns: Turn[],
  makeAssistant: (text: string) => Message,
): string {
  const branch = sessionManager.getBranch();
  const usedIds = new Set(branch.map((e) => e.id));
  const genId = (): string => {
    let id: string;
    do {
      id = randomBytes(4).toString('hex');
    } while (usedIds.has(id));
    usedIds.add(id);
    return id;
  };

  // Re-chain the path without label entries (labels may parent other entries).
  const entries: Record<string, unknown>[] = [];
  let parentId: string | null = null;
  for (const entry of branch) {
    if (entry.type === 'label') continue;
    entries.push({ ...entry, parentId });
    parentId = entry.id;
  }

  const now = new Date();
  const iso = now.toISOString();
  const header = {
    type: 'session',
    version: CURRENT_SESSION_VERSION,
    id: randomUUID(),
    timestamp: iso,
    cwd: sessionManager.getCwd(),
    parentSession: sessionManager.getSessionFile(),
  };

  for (const turn of turns) {
    const userId = genId();
    entries.push({
      type: 'message',
      id: userId,
      parentId,
      timestamp: iso,
      message: {
        role: 'user',
        content: [{ type: 'text', text: turn.question }],
        timestamp: now.getTime(),
      },
    });
    parentId = userId;
    const assistantId = genId();
    entries.push({
      type: 'message',
      id: assistantId,
      parentId,
      timestamp: iso,
      message: makeAssistant(turn.answer),
    });
    parentId = assistantId;
  }

  // Name the forked session after the first question.
  entries.push({
    type: 'session_info',
    id: genId(),
    parentId,
    timestamp: iso,
    name: `btw: ${firstLine(turns[0]!.question, 50)}`,
  });

  const file = join(sessionManager.getSessionDir(), `${iso.replace(/[:.]/g, '-')}_${header.id}.jsonl`);
  writeFileSync(file, [header, ...entries].map((e) => JSON.stringify(e)).join('\n') + '\n');
  return file;
}

function run(cmd: string, args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    execFile(cmd, args, (err) => (err ? reject(err) : resolve()));
  });
}

function copyToClipboard(text: string): Promise<boolean> {
  if (process.platform !== 'darwin') return Promise.resolve(false);
  return new Promise((resolve) => {
    const child = execFile('pbcopy', (err) => resolve(!err));
    child.stdin?.end(text);
  });
}

/**
 * Open the forked session, best surface first:
 *   1. tmux split — direction from pane width (PI_BTW_SPLIT=h|v to force)
 *   2. new Ghostty window (macOS) — via login+interactive zsh so PATH has pi
 *      (GUI apps launched by `open` only get launchd's minimal PATH)
 *   3. clipboard + printed command
 * Returns the notification message.
 */
async function openFork(sessionFile: string, cwd: string): Promise<string> {
  if (process.env.TMUX) {
    const override = process.env.PI_BTW_SPLIT;
    const direction =
      override === 'h' || override === 'v' ? `-${override}` : (process.stdout.columns ?? 0) >= 160 ? '-h' : '-v';
    try {
      await run('tmux', ['split-window', direction, '-c', cwd, 'pi', '--session', sessionFile]);
      return 'btw fork opened in a tmux split';
    } catch {
      // fall through to Ghostty/clipboard
    }
  }

  if (process.platform === 'darwin') {
    try {
      await run('open', [
        '-na',
        'Ghostty',
        '--args',
        `--working-directory=${cwd}`,
        '-e',
        '/bin/zsh',
        '-ilc',
        `exec pi --session '${sessionFile}'`,
      ]);
      return 'btw fork opened in a new Ghostty window';
    } catch {
      // Ghostty not installed — fall through to clipboard
    }
  }

  const cmd = `pi --session ${sessionFile}`;
  const copied = await copyToClipboard(cmd);
  return copied ? `btw fork ready (command copied): ${cmd}` : `btw fork ready: ${cmd}`;
}
