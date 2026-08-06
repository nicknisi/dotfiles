/**
 * LLM Council Tool — Ask multiple models, synthesize with a chairman.
 *
 * Spawns member models in parallel, then a chairman model
 * that synthesizes the answers into a final response.
 * Progress streams inline via renderResult.
 *
 * Rendering follows styled-outputs visual vocabulary:
 * ✓/✗ prefix, └─ branch lines, · indent, expand hints.
 * All labels, colors, and symbols are configurable via
 * ~/.pi/agent/configs/llm-council.json
 */

import { spawn } from 'node:child_process';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import type { ExtensionAPI, Theme } from '@earendil-works/pi-coding-agent';
import { getMarkdownTheme } from '@earendil-works/pi-coding-agent';
import { Markdown, Text } from '@earendil-works/pi-tui';
import { Type } from 'typebox';
import { CONFIG, loadCouncil, type ResolvedCouncil } from './config.js';
import { applyColor, formatElapsed, getExpandToggleKey, getVisibleWidth } from './utils.js';

// ── Derived constants (computed once from CONFIG) ────────────────────────

const SPINNER_FRAMES = [...CONFIG.shared.spinner.prefixChars, ...[...CONFIG.shared.spinner.prefixChars].reverse()];
const INDENT_WIDTH = getVisibleWidth(CONFIG.shared.branch.prefix) + 1;

// ── Styling helpers ──────────────────────────────────────────────────────

function successPrefix(theme: Theme): string {
  return `${applyColor(theme, CONFIG.shared.successPrefix.color, CONFIG.shared.successPrefix.prefix)} `;
}

function errorPrefix(theme: Theme): string {
  return `${applyColor(theme, CONFIG.shared.errorPrefix.color, CONFIG.shared.errorPrefix.prefix)} `;
}

function branchLine(text: string, theme: Theme): string {
  return `${applyColor(theme, CONFIG.shared.branch.color, CONFIG.shared.branch.prefix)} ${text}`;
}

function indentLine(text: string): string {
  return `${' '.repeat(INDENT_WIDTH)}${text}`;
}

function expandHint(theme: Theme): string {
  return applyColor(theme, CONFIG.shared.expandHint.color, ` • ${getExpandToggleKey()} to expand`);
}

function toolHeader(label: string, summary: string, theme: Theme, dot?: string, isError?: boolean): string {
  const d = dot ?? (isError ? errorPrefix(theme) : successPrefix(theme));
  const title = applyColor(theme, CONFIG.shared.toolHeader.titleColor, theme.bold(label));
  return `${d}${title} ${summary}`;
}

function makeText(lastComponent: any, text: string): Text {
  const comp = lastComponent instanceof Text ? lastComponent : new Text('', 0, 0);
  comp.setText(text);
  return comp;
}

function renderMemberTree(
  details: CouncilDetails,
  theme: Theme,
  spinnerFrame: number,
  opts: {
    memberSubLine: (m: MemberResult) => string;
    chairmanSubLine: string;
    chairmanSubLineSuffix?: string;
  },
): string[] {
  const lines: string[] = [];
  for (const m of details.members) {
    const icon =
      m.status === 'done'
        ? applyColor(theme, CONFIG.shared.status.doneColor, CONFIG.shared.successPrefix.prefix)
        : m.status === 'error'
          ? applyColor(theme, CONFIG.shared.status.errorColor, CONFIG.shared.errorPrefix.prefix)
          : m.status === 'working'
            ? applyColor(theme, CONFIG.shared.spinner.color, SPINNER_FRAMES[spinnerFrame % SPINNER_FRAMES.length])
            : applyColor(theme, CONFIG.shared.status.waitingIconColor, CONFIG.shared.status.waitingIcon);
    lines.push(
      indentLine(
        `${icon} ${applyColor(theme, CONFIG.member.display.labelColor, m.label)} ${applyColor(theme, CONFIG.member.display.modelColor, m.displayName ?? m.model)}`,
      ),
    );
    lines.push(indentLine(branchLine(opts.memberSubLine(m), theme)));
    lines.push('');
  }
  if (details.chairman) {
    const cIcon =
      details.chairman.status === 'done'
        ? applyColor(theme, CONFIG.shared.status.doneColor, CONFIG.shared.successPrefix.prefix)
        : details.chairman.status === 'error'
          ? applyColor(theme, CONFIG.shared.status.errorColor, CONFIG.shared.errorPrefix.prefix)
          : details.chairman.status === 'working'
            ? applyColor(theme, CONFIG.shared.spinner.color, SPINNER_FRAMES[spinnerFrame % SPINNER_FRAMES.length])
            : applyColor(theme, CONFIG.shared.status.waitingIconColor, CONFIG.shared.status.waitingIcon);
    lines.push(
      indentLine(
        `${cIcon} ${CONFIG.chairman.display.icon ? CONFIG.chairman.display.icon + ' ' : ''}${applyColor(theme, CONFIG.chairman.display.labelColor, 'Chairman')} ${applyColor(theme, CONFIG.chairman.display.modelColor, details.chairman.displayName ?? details.chairman.model)}`,
      ),
    );
    const suffix = opts.chairmanSubLineSuffix ?? '';
    lines.push(indentLine(branchLine(opts.chairmanSubLine + suffix, theme)));
  }
  return lines;
}

function ensureSpinner(ctx: any): number {
  if (ctx?.state?.spinnerInterval) return ctx.state.spinnerFrame ?? 0;
  if (!ctx?.state) ctx.state = {};
  ctx.state.spinnerFrame = 0;
  ctx.state.spinnerInterval = setInterval(() => {
    ctx.state.spinnerFrame = (ctx.state.spinnerFrame + 1) % SPINNER_FRAMES.length;
    ctx.invalidate?.();
  }, CONFIG.shared.spinner.interval);
  return 0;
}

function clearSpinner(ctx: any) {
  if (ctx?.state?.spinnerInterval) {
    clearInterval(ctx.state.spinnerInterval);
    ctx.state.spinnerInterval = undefined;
  }
}

function spinnerDot(theme: Theme, frame: number): string {
  return `${applyColor(theme, CONFIG.shared.spinner.color, SPINNER_FRAMES[frame % SPINNER_FRAMES.length])} `;
}

function createExpandedView(details: CouncilDetails, theme: Theme, markdownTheme: any) {
  const memberMds = details.members.map((m) => ({
    m,
    md: m.status === 'done' && m.text ? new Markdown(m.text.trim(), 0, 0, markdownTheme) : null,
  }));
  const chairmanMd = details.chairman?.text ? new Markdown(details.chairman.text.trim(), 0, 0, markdownTheme) : null;

  let cachedWidth: number | undefined;
  let cachedLines: string[] | undefined;

  return {
    render(width: number): string[] {
      if (cachedLines && cachedWidth === width) return cachedLines;
      const cw = Math.max(1, width - INDENT_WIDTH * 2);
      const lines: string[] = [''];

      for (const { m, md } of memberMds) {
        const icon =
          m.status === 'error'
            ? applyColor(theme, CONFIG.shared.status.errorColor, CONFIG.shared.errorPrefix.prefix)
            : applyColor(theme, CONFIG.shared.status.doneColor, CONFIG.shared.successPrefix.prefix);
        lines.push(
          indentLine(
            `${icon} ${applyColor(theme, CONFIG.member.display.labelColor, m.label)} ${applyColor(theme, CONFIG.member.display.modelColor, m.displayName ?? m.model)}`,
          ),
        );
        if (m.status === 'error') {
          lines.push(
            indentLine(
              branchLine(
                `${applyColor(theme, CONFIG.shared.status.errorColor, CONFIG.shared.status.errorLabel)} ${applyColor(theme, CONFIG.shared.status.elapsedColor, formatElapsed(m.startedAt, m.doneAt))}`,
                theme,
              ),
            ),
          );
          if (m.error) lines.push(indentLine(indentLine(applyColor(theme, CONFIG.shared.status.errorColor, m.error))));
        } else {
          lines.push(
            indentLine(
              branchLine(
                `${applyColor(theme, CONFIG.shared.status.doneColor, CONFIG.shared.status.doneLabel)} ${applyColor(theme, CONFIG.shared.status.elapsedColor, formatElapsed(m.startedAt, m.doneAt))}`,
                theme,
              ),
            ),
          );
          if (md) for (const l of md.render(cw)) lines.push(indentLine(indentLine(l)));
        }
        lines.push('');
      }

      if (details.chairman) {
        const cIcon =
          details.chairman.status === 'error'
            ? applyColor(theme, CONFIG.shared.status.errorColor, CONFIG.shared.errorPrefix.prefix)
            : applyColor(theme, CONFIG.shared.status.doneColor, CONFIG.shared.successPrefix.prefix);
        const cStatus =
          details.chairman.status === 'done'
            ? applyColor(theme, CONFIG.shared.status.doneColor, CONFIG.shared.status.doneLabel)
            : applyColor(theme, CONFIG.shared.status.errorColor, CONFIG.shared.status.errorLabel);
        lines.push(
          indentLine(
            `${cIcon} ${CONFIG.chairman.display.icon ? CONFIG.chairman.display.icon + ' ' : ''}${applyColor(theme, CONFIG.chairman.display.labelColor, 'Chairman')} ${applyColor(theme, CONFIG.chairman.display.modelColor, details.chairman.displayName ?? details.chairman.model)}`,
          ),
        );
        lines.push(indentLine(branchLine(cStatus, theme)));
        if (details.chairman.status === 'error' && details.chairman.error) {
          lines.push(
            indentLine(indentLine(applyColor(theme, CONFIG.shared.status.errorColor, details.chairman.error))),
          );
        } else if (chairmanMd) {
          for (const l of chairmanMd.render(cw)) lines.push(indentLine(indentLine(l)));
        }
      }

      cachedWidth = width;
      cachedLines = lines;
      return lines;
    },
    invalidate() {
      cachedWidth = undefined;
      cachedLines = undefined;
      for (const { md } of memberMds) md?.invalidate();
      chairmanMd?.invalidate();
    },
  };
}

// ── Types ────────────────────────────────────────────────────────────────

interface MemberResult {
  label: string;
  model: string;
  displayName?: string;
  systemPrompt: string;
  status: 'pending' | 'working' | 'done' | 'error';
  text: string;
  error?: string;
  startedAt?: number;
  doneAt?: number;
}

interface CouncilDetails {
  stage: 'members' | 'chairman' | 'complete' | 'error';
  members: MemberResult[];
  chairman?: {
    model: string;
    displayName?: string;
    status: 'pending' | 'working' | 'done' | 'error';
    text: string;
    error?: string;
    startedAt?: number;
    doneAt?: number;
  };
}

interface SubagentResult {
  text: string;
  exitCode: number;
  stderr: string;
  error?: string;
}

interface ExecConfig {
  tools: string[] | null;
  thinking: string | null;
  extensions: string[] | null;
  skills: string[] | null;
  contextFiles: boolean;
}

// ── Subprocess ───────────────────────────────────────────────────────────

function buildExecArgs(exec: ExecConfig): string[] {
  const args: string[] = [];

  // tools: null/[] → --no-tools, [items] → --tools <comma-separated>
  if (!exec.tools || exec.tools.length === 0) {
    args.push('--no-tools');
  } else {
    args.push('--tools', exec.tools.join(','));
  }

  // thinking: null → omit, string → --thinking <level>
  if (exec.thinking) {
    args.push('--thinking', exec.thinking);
  }

  // extensions: null → no flags, [] → --no-extensions, [items] → --no-extensions -e <path>...
  if (exec.extensions === null) {
    // keep defaults, no flags
  } else if (exec.extensions.length === 0) {
    args.push('--no-extensions');
  } else {
    args.push('--no-extensions');
    for (const name of exec.extensions) {
      args.push('-e', path.join(os.homedir(), '.pi', 'agent', 'extensions', name, 'src', 'index.ts'));
    }
  }

  // skills: null → no flags, [] → --no-skills, [items] → --no-skills --skill <path>...
  if (exec.skills === null) {
    // keep defaults, no flags
  } else if (exec.skills.length === 0) {
    args.push('--no-skills');
  } else {
    args.push('--no-skills');
    for (const name of exec.skills) {
      args.push('--skill', path.join(os.homedir(), '.pi', 'agent', 'skills', name, 'SKILL.md'));
    }
  }

  // contextFiles: false → --no-context-files, true → omit flag
  if (exec.contextFiles === false) {
    args.push('--no-context-files');
  }

  return args;
}

function getPiInvocation(args: string[]): { command: string; args: string[] } {
  const currentScript = process.argv[1];
  const isBunVirtualScript = currentScript?.startsWith('/$bunfs/root/');
  if (currentScript && !isBunVirtualScript && fs.existsSync(currentScript)) {
    return { command: process.execPath, args: [currentScript, ...args] };
  }
  const execName = path.basename(process.execPath).toLowerCase();
  const isGenericRuntime = /^(node|bun)(\.exe)?$/.test(execName);
  if (!isGenericRuntime) {
    return { command: process.execPath, args };
  }
  return { command: 'pi', args };
}

async function runSubagent(
  model: string,
  prompt: string,
  systemPrompt: string | undefined,
  cwd: string,
  execConfig: ExecConfig,
  signal?: AbortSignal,
): Promise<SubagentResult> {
  const baseArgs: string[] = ['--mode', 'json', '-p', '--no-session', '--model', model];
  const execArgs = buildExecArgs(execConfig);
  const args: string[] = [...baseArgs, ...execArgs];

  let tmpDir: string | null = null;
  let tmpFile: string | null = null;

  try {
    if (systemPrompt) {
      tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'pi-council-'));
      tmpFile = path.join(tmpDir, 'system-prompt.md');
      fs.writeFileSync(tmpFile, systemPrompt, { mode: 0o600 });
      args.push('--append-system-prompt', tmpFile);
    }

    if (process.env.PI_SUBAGENT_DEPTH) {
      throw new Error('Subagents cannot spawn further subprocesses');
    }

    args.push(prompt);

    const result: SubagentResult = { text: '', exitCode: 0, stderr: '' };

    result.exitCode = await new Promise<number>((resolve) => {
      const invocation = getPiInvocation(args);
      const proc = spawn(invocation.command, invocation.args, {
        cwd,
        shell: false,
        stdio: ['ignore', 'pipe', 'pipe'],
        env: { ...process.env, PI_SUBAGENT_DEPTH: '1' },
      });

      let buffer = '';

      const processLine = (line: string) => {
        if (!line.trim()) return;
        let event: any;
        try {
          event = JSON.parse(line);
        } catch {
          return;
        }
        if (event.type === 'message_end' && event.message) {
          const msg = event.message;
          if (msg.role === 'assistant') {
            for (const part of msg.content) {
              if (part.type === 'text') {
                result.text += part.text;
              }
            }
          }
        }
      };

      proc.stdout.on('data', (data: Buffer) => {
        buffer += data.toString();
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';
        for (const line of lines) processLine(line);
      });

      proc.stderr.on('data', (data: Buffer) => {
        result.stderr += data.toString();
      });

      proc.on('close', (code) => {
        if (buffer.trim()) processLine(buffer);
        resolve(code ?? 0);
      });

      proc.on('error', () => {
        resolve(1);
      });

      if (signal) {
        const killProc = () => {
          proc.kill('SIGTERM');
          setTimeout(() => {
            if (!proc.killed) proc.kill('SIGKILL');
          }, 5000);
        };
        if (signal.aborted) killProc();
        else signal.addEventListener('abort', killProc, { once: true });
      }
    });

    if (result.exitCode !== 0 && !result.text && result.stderr) {
      result.error = result.stderr.split('\n').filter(Boolean).pop() || 'Process failed';
    }

    return result;
  } finally {
    if (tmpFile) {
      try {
        fs.unlinkSync(tmpFile);
      } catch {
        /* ignore */
      }
    }
    if (tmpDir) {
      try {
        fs.rmdirSync(tmpDir);
      } catch {
        /* ignore */
      }
    }
  }
}

// ── Council logic ─────────────────────────────────────────────────────────

async function runCouncil(
  question: string,
  cwd: string,
  council: ResolvedCouncil,
  signal: AbortSignal | undefined,
  onUpdate: (details: CouncilDetails) => void,
): Promise<{ content: { type: 'text'; text: string }[]; details: CouncilDetails }> {
  const memberExecConfig: ExecConfig = {
    tools: council.member.tools,
    thinking: council.member.thinking,
    extensions: council.member.extensions,
    skills: council.member.skills,
    contextFiles: council.member.contextFiles,
  };

  const details: CouncilDetails = {
    stage: 'members',
    members: council.member.council.map((m) => ({
      label: m.label,
      model: m.model,
      displayName: m.displayName,
      systemPrompt: m.systemPrompt,
      status: 'pending' as const,
      text: '',
    })),
    chairman: {
      model: council.chairman.model,
      displayName: council.chairman.displayName,
      status: 'pending',
      text: '',
    },
  };

  const emit = () => onUpdate(details);

  // Phase 1: Run members in parallel
  emit();

  const memberPromises = details.members.map(async (m) => {
    m.status = 'working';
    m.startedAt = Date.now();
    emit();
    const result = await runSubagent(m.model, question, m.systemPrompt, cwd, memberExecConfig, signal);
    if (result.exitCode === 0 && result.text) {
      m.status = 'done';
      m.doneAt = Date.now();
      m.text = result.text;
    } else {
      m.status = 'error';
      m.doneAt = Date.now();
      m.error = result.error || 'Failed';
      m.text = result.text || '';
    }
    emit();
  });

  await Promise.all(memberPromises);

  const successfulMembers = details.members.filter((m) => m.status === 'done' && m.text);
  if (successfulMembers.length === 0) {
    details.stage = 'error';
    emit();
    return {
      content: [{ type: 'text', text: `Council failed: no models returned valid responses.` }],
      details,
    };
  }

  // Phase 2: Run chairman
  details.chairman = {
    model: council.chairman.model,
    displayName: council.chairman.displayName,
    status: 'working',
    text: '',
    startedAt: Date.now(),
  };
  details.stage = 'chairman';
  emit();

  let chairmanPrompt = `Question: ${question}\n\nHere are answers from council members:\n`;
  for (const m of successfulMembers) {
    if (council.chairman.exposePersonas && m.systemPrompt) {
      chairmanPrompt += `\n--- Member ${m.label} (persona: "${m.systemPrompt}") ---\n${m.text}\n`;
    } else {
      chairmanPrompt += `\n--- Member ${m.label} ---\n${m.text}\n`;
    }
  }
  chairmanPrompt += '\n---\nSynthesize a unified answer incorporating the best points from each response.';

  const chairmanExecConfig: ExecConfig = {
    tools: council.chairman.tools,
    thinking: council.chairman.thinking,
    extensions: council.chairman.extensions,
    skills: council.chairman.skills,
    contextFiles: council.chairman.contextFiles,
  };

  const chairmanResult = await runSubagent(
    council.chairman.model,
    chairmanPrompt,
    council.chairman.systemPrompt,
    cwd,
    chairmanExecConfig,
    signal,
  );

  if (chairmanResult.exitCode === 0 && chairmanResult.text) {
    details.chairman.status = 'done';
    details.chairman.doneAt = Date.now();
    details.chairman.text = chairmanResult.text;
  } else {
    details.chairman.status = 'error';
    details.chairman.doneAt = Date.now();
    details.chairman.error = chairmanResult.error || 'Chairman failed';
    details.chairman.text = chairmanResult.text || '';
  }

  details.stage = 'complete';
  emit();

  const finalText = details.chairman.text || details.chairman.error || 'No output from chairman';
  return {
    content: [{ type: 'text', text: finalText }],
    details,
  };
}

// ── Live progress bridge (renderCall workaround for isPartial bug) ────────
let liveDetails: CouncilDetails | null = null;

// ── Tool registration ────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: 'llm_council',
    label: 'LLM Council',
    description: [
      'Convene an LLM Council — multiple models answer a question independently,',
      'then a chairman synthesizes their answers into a unified response.',
      'Use for questions that benefit from multiple perspectives, cross-checking,',
      'or when accuracy matters. Not for simple factual questions.',
    ].join(' '),
    promptSnippet: 'Ask multiple LLMs for a council opinion',
    promptGuidelines: [
      'Use llm_council for complex questions that benefit from multiple LLM perspectives or cross-checking.',
      'Do NOT use llm_council for simple factual questions or routine tasks.',
    ],
    parameters: Type.Object({
      question: Type.String({ description: 'The question to pose to the council' }),
    }),

    async execute(_toolCallId, params, signal, onUpdate, ctx) {
      const council = loadCouncil(ctx.cwd);
      return runCouncil(params.question, ctx.cwd, council, signal, (details) => {
        liveDetails = details;
        const stageLabels: Record<string, string> = {
          members: CONFIG.shared.status.waitingLabel,
          chairman: CONFIG.shared.status.synthesizingLabel,
          complete: CONFIG.shared.status.doneLabel,
          error: CONFIG.shared.status.errorLabel,
        };
        const doneCount = details.members.filter((m) => m.status === 'done' || m.status === 'error').length;
        const stageText = stageLabels[details.stage] || details.stage;
        let text = `[Council] ${stageText}`;
        if (details.stage === 'members') {
          text += ` ${doneCount}/${details.members.length} done`;
        }
        onUpdate?.({
          content: [{ type: 'text', text }],
          details,
        });
      });
    },

    renderCall(args, theme, ctx) {
      const preview =
        args.question?.length > CONFIG.shared.questionPreview.maxLength
          ? `${args.question.slice(0, CONFIG.shared.questionPreview.maxLength)}...`
          : args.question || '...';
      const summary = applyColor(theme, CONFIG.shared.toolHeader.summaryColor, preview);

      if (!ctx?.isPartial) {
        clearSpinner(ctx);
        liveDetails = null;
        return makeText(ctx?.lastComponent, toolHeader('LLM Council', summary, theme));
      }

      const frame = ensureSpinner(ctx);
      const lines = [toolHeader('LLM Council', summary, theme, spinnerDot(theme, frame)), ''];

      // Live progress from onUpdate
      if (!liveDetails) {
        lines.push(
          indentLine(
            branchLine(applyColor(theme, CONFIG.shared.status.workingColor, CONFIG.shared.status.workingLabel), theme),
          ),
        );
        return makeText(ctx.lastComponent, lines.join('\n'));
      }
      const details = liveDetails;
      lines.push(
        ...renderMemberTree(details, theme, frame, {
          memberSubLine: (m) =>
            m.status === 'done'
              ? `${applyColor(theme, CONFIG.shared.status.doneColor, CONFIG.shared.status.doneLabel)} ${applyColor(theme, CONFIG.shared.status.elapsedColor, formatElapsed(m.startedAt, m.doneAt))}`
              : m.status === 'working'
                ? applyColor(theme, CONFIG.shared.status.workingColor, CONFIG.shared.status.workingLabel)
                : m.status === 'error'
                  ? `${applyColor(theme, CONFIG.shared.status.errorColor, m.error?.slice(0, 60) || CONFIG.shared.status.errorLabel)} ${applyColor(theme, CONFIG.shared.status.elapsedColor, formatElapsed(m.startedAt, m.doneAt))}`
                  : applyColor(theme, CONFIG.shared.status.workingColor, CONFIG.shared.status.workingLabel),
          chairmanSubLine:
            details.stage === 'chairman' && details.chairman?.status === 'working'
              ? applyColor(theme, CONFIG.shared.status.workingColor, CONFIG.shared.status.synthesizingLabel)
              : applyColor(theme, CONFIG.shared.status.workingColor, CONFIG.shared.status.waitingLabel),
        }),
      );
      return makeText(ctx.lastComponent, lines.join('\n'));
    },

    renderResult(result, options, theme, ctx) {
      const details = result.details as CouncilDetails | undefined;
      const expanded = options?.expanded ?? false;

      // No details — plain text fallback
      if (!details) {
        const text = result.content[0];
        return makeText(ctx?.lastComponent, text?.type === 'text' ? text.text : '(no output)');
      }

      const frame = ctx?.state?.spinnerFrame ?? 0;

      // ── Error state ──────────────────────────────────────────────────
      if (details.stage === 'error') {
        const lines = [
          '',
          ...renderMemberTree(details, theme, 0, {
            memberSubLine: (m) =>
              applyColor(
                theme,
                CONFIG.shared.status.errorColor,
                m.error?.slice(0, 60) || CONFIG.shared.status.errorLabel,
              ),
            chairmanSubLine: applyColor(theme, CONFIG.shared.status.workingColor, CONFIG.shared.status.waitingLabel),
          }),
        ];
        return makeText(ctx?.lastComponent, lines.join('\n'));
      }

      // ── Progress: members deliberating ─────────────────────────────────
      if (details.stage === 'members') {
        const lines = renderMemberTree(details, theme, frame, {
          memberSubLine: (m) =>
            m.status === 'done'
              ? `${applyColor(theme, CONFIG.shared.status.doneColor, CONFIG.shared.status.doneLabel)} ${applyColor(theme, CONFIG.shared.status.elapsedColor, formatElapsed(m.startedAt, m.doneAt))}`
              : m.status === 'working'
                ? applyColor(theme, CONFIG.shared.status.workingColor, CONFIG.shared.status.workingLabel)
                : m.status === 'error'
                  ? `${applyColor(theme, CONFIG.shared.status.errorColor, m.error?.slice(0, 60) || CONFIG.shared.status.errorLabel)} ${applyColor(theme, CONFIG.shared.status.elapsedColor, formatElapsed(m.startedAt, m.doneAt))}`
                  : applyColor(theme, CONFIG.shared.status.workingColor, CONFIG.shared.status.workingLabel),
          chairmanSubLine: applyColor(theme, CONFIG.shared.status.workingColor, CONFIG.shared.status.waitingLabel),
        });
        return makeText(ctx?.lastComponent, lines.join('\n'));
      }

      // ── Progress: chairman synthesizing ────────────────────────────────
      if (details.stage === 'chairman') {
        const lines = [
          '',
          ...renderMemberTree(details, theme, frame, {
            memberSubLine: (m) =>
              m.status === 'done'
                ? `${applyColor(theme, CONFIG.shared.status.doneColor, CONFIG.shared.status.doneLabel)} ${applyColor(theme, CONFIG.shared.status.elapsedColor, formatElapsed(m.startedAt, m.doneAt))}`
                : `${applyColor(theme, CONFIG.shared.status.errorColor, m.error?.slice(0, 60) || CONFIG.shared.status.errorLabel)} ${applyColor(theme, CONFIG.shared.status.elapsedColor, formatElapsed(m.startedAt, m.doneAt))}`,
            chairmanSubLine:
              details.chairman?.status === 'working'
                ? applyColor(theme, CONFIG.shared.status.workingColor, CONFIG.shared.status.synthesizingLabel)
                : details.chairman?.status === 'error'
                  ? applyColor(
                      theme,
                      CONFIG.shared.status.errorColor,
                      details.chairman.error?.slice(0, 60) || CONFIG.shared.status.errorLabel,
                    )
                  : details.chairman?.status === 'done'
                    ? applyColor(theme, CONFIG.shared.status.doneColor, CONFIG.shared.status.doneLabel)
                    : applyColor(theme, CONFIG.shared.status.workingColor, CONFIG.shared.status.waitingLabel),
          }),
        ];
        return makeText(ctx?.lastComponent, lines.join('\n'));
      }

      // ── Complete: collapsed ────────────────────────────────────────────
      if (!expanded) {
        const lines = [
          '',
          ...renderMemberTree(details, theme, 0, {
            memberSubLine: (m) =>
              m.status === 'done'
                ? `${applyColor(theme, CONFIG.shared.status.doneColor, CONFIG.shared.status.doneLabel)} ${applyColor(theme, CONFIG.shared.status.elapsedColor, formatElapsed(m.startedAt, m.doneAt))}`
                : `${applyColor(theme, CONFIG.shared.status.errorColor, m.error?.slice(0, 60) || CONFIG.shared.status.errorLabel)} ${applyColor(theme, CONFIG.shared.status.elapsedColor, formatElapsed(m.startedAt, m.doneAt))}`,
            chairmanSubLine:
              details.chairman?.status === 'error'
                ? applyColor(
                    theme,
                    CONFIG.shared.status.errorColor,
                    details.chairman.error?.slice(0, 60) || CONFIG.shared.status.errorLabel,
                  )
                : applyColor(theme, CONFIG.shared.status.doneColor, CONFIG.shared.status.doneLabel),
            chairmanSubLineSuffix: expandHint(theme),
          }),
        ];
        return makeText(ctx?.lastComponent, lines.join('\n'));
      }

      // ── Complete: expanded ────────────────────────────────────────────
      return createExpandedView(details, theme, getMarkdownTheme());
    },
  });
}
