/**
 * Dynamic Skills Extension
 *
 * Adds Claude Code-style !`command` support to pi skills. When a SKILL.md
 * contains !`command` placeholders, the shell commands are executed at
 * invocation time and the output is inlined before the model sees it.
 *
 * Example SKILL.md:
 *   ---
 *   name: pr-summary
 *   description: Summarize changes in a pull request
 *   ---
 *   - PR diff: !`gh pr diff`
 *   - Changed files: !`gh pr diff --name-only`
 *
 *   ```!
 *   gh pr view --json title,body
 *   ```
 *
 *   Summarize this pull request...
 *
 * Handles two invocation paths:
 *   1. /skill:name — intercepted at input, expanded with commands executed
 *   2. Agent reads SKILL.md via read tool — output patched in tool_result
 *
 * Security boundary: commands are only executed for SKILL.md files that pi has
 * actually registered as skills, i.e. files discovered under a configured skill
 * path. Reading an arbitrary SKILL.md — say, from a freshly cloned untrusted
 * repo — never executes anything, because that file is not a registered skill.
 * Without this guard, `read`ing a hostile SKILL.md is remote code execution.
 */

import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import { exec as execCb } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

/**
 * Matches both dynamic-command forms, mirroring Claude Code:
 *   - a fenced block opened with ```! for multi-line commands
 *   - inline !`command`, recognized only when ! starts a line or follows
 *     whitespace, so `KEY=!`cmd`` stays literal text and does not execute
 *
 * Group 1 is a fenced body, group 2 an inline command; exactly one is set.
 */
const CMD_RE = /^```!\r?\n([\s\S]*?)\r?\n```[ \t]*$|(?<=^|\s)!`([^`]+)`/gm;
const HAS_CMD = /^```!\r?\n|(?<=^|\s)!`[^`]+`/m;

function runCommand(command: string, cwd: string): Promise<string> {
  return new Promise((resolve) => {
    execCb(command, { cwd, timeout: 30_000, maxBuffer: 1024 * 512, encoding: 'utf-8' }, (err, stdout, stderr) => {
      if (err && !stdout && !stderr) {
        // Fenced blocks are multi-line; label with the first line only.
        const [first, ...rest] = command.split('\n');
        const label = rest.length > 0 ? `${first}…` : first;
        resolve(`[!\`${label}\` failed: ${err.message}]`);
      } else {
        resolve((stdout || stderr || '').trim());
      }
    });
  });
}

async function expandCommands(text: string, cwd: string): Promise<string> {
  const matches = [...text.matchAll(CMD_RE)];
  if (matches.length === 0) return text;

  // Run all commands in parallel. Matches come from the original text and are
  // replaced by index, so command output is never re-scanned for placeholders.
  const outputs = await Promise.all(matches.map((m) => runCommand(m[1] ?? m[2], cwd)));

  // Replace in reverse to preserve indices
  let result = text;
  for (let i = matches.length - 1; i >= 0; i--) {
    const start = matches[i].index!;
    const end = start + matches[i][0].length;
    result = result.slice(0, start) + outputs[i] + result.slice(end);
  }
  return result;
}

/**
 * Resolved SKILL.md path -> skill base dir, for every skill pi registered in
 * this session. This is the allowlist for command expansion: a SKILL.md that
 * pi did not load as a skill is just an untrusted file on disk.
 */
function registeredSkillPaths(pi: ExtensionAPI): Map<string, string> {
  const paths = new Map<string, string>();
  for (const cmd of pi.getCommands()) {
    if (cmd.source !== 'skill') continue;
    const path = cmd.sourceInfo?.path;
    if (!path) continue;
    paths.set(resolve(path), cmd.sourceInfo.baseDir ?? dirname(path));
  }
  return paths;
}

export default function (pi: ExtensionAPI) {
  // ── Path 1: /skill:name invocations ───────────────────────────────────
  pi.on('input', async (event, ctx) => {
    const match = event.text.match(/^\/skill:(\S+)(?:\s+([\s\S]*))?$/);
    if (!match) return { action: 'continue' as const };

    const [, skillName, args] = match;

    // Find the skill's SKILL.md path
    const skill = pi.getCommands().find((c) => c.source === 'skill' && c.name === `skill:${skillName}`);
    const skillPath = skill?.sourceInfo.path;
    if (!skillPath) return { action: 'continue' as const };

    // Read and check for dynamic commands
    let content: string;
    try {
      content = readFileSync(skillPath, 'utf-8');
    } catch {
      return { action: 'continue' as const };
    }

    if (!HAS_CMD.test(content)) return { action: 'continue' as const };

    // Execute commands and expand
    const skillDir = skill!.sourceInfo.baseDir ?? dirname(skillPath);
    ctx.ui.notify(`Expanding dynamic commands in ${skillName}…`, 'info');
    const expanded = await expandCommands(content, skillDir);

    // Build the prompt — replicate pi's skill expansion (content + User: args)
    const text = args?.trim() ? `${expanded}\n\nUser: ${args.trim()}` : expanded;
    return { action: 'transform' as const, text };
  });

  // ── Path 2: Agent reads a SKILL.md via the read tool ──────────────────
  pi.on('tool_result', async (event, ctx) => {
    if (event.toolName !== 'read') return;

    const input = event.input as { path?: string } | undefined;
    if (!input?.path?.endsWith('SKILL.md')) return;

    // Check if any text block contains dynamic commands
    const hasAny = event.content.some(
      (block) => block.type === 'text' && HAS_CMD.test((block as { text: string }).text),
    );
    if (!hasAny) return;

    // Only expand for SKILL.md files pi registered as skills. Reading some
    // other SKILL.md must never execute the commands embedded in it.
    const skillDir = registeredSkillPaths(pi).get(resolve(ctx.cwd, input.path));
    if (!skillDir) {
      ctx.ui.notify(`Skipped !\`cmd\` expansion in unregistered ${input.path}`, 'warning');
      return;
    }

    const newContent = await Promise.all(
      event.content.map(async (block) => {
        if (block.type !== 'text') return block;
        const text = (block as { text: string }).text;
        if (!HAS_CMD.test(text)) return block;
        return { ...block, text: await expandCommands(text, skillDir) };
      }),
    );

    return { content: newContent };
  });
}
