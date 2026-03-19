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
 *   Summarize this pull request...
 *
 * Handles two invocation paths:
 *   1. /skill:name — intercepted at input, expanded with commands executed
 *   2. Agent reads SKILL.md via read tool — output patched in tool_result
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { exec as execCb } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

/** Matches !`command` — the ! prefix distinguishes from normal backtick code */
const CMD_RE = /!`([^`]+)`/g;
const HAS_CMD = /!`[^`]+`/;

function runCommand(command: string, cwd: string): Promise<string> {
	return new Promise((resolve) => {
		execCb(
			command,
			{ cwd, timeout: 30_000, maxBuffer: 1024 * 512, encoding: "utf-8" },
			(err, stdout, stderr) => {
				if (err && !stdout && !stderr) {
					resolve(`[!\`${command}\` failed: ${err.message}]`);
				} else {
					resolve((stdout || stderr || "").trim());
				}
			},
		);
	});
}

async function expandCommands(text: string, cwd: string): Promise<string> {
	const matches = [...text.matchAll(CMD_RE)];
	if (matches.length === 0) return text;

	// Run all commands in parallel
	const outputs = await Promise.all(matches.map((m) => runCommand(m[1], cwd)));

	// Replace in reverse to preserve indices
	let result = text;
	for (let i = matches.length - 1; i >= 0; i--) {
		const start = matches[i].index!;
		const end = start + matches[i][0].length;
		result = result.slice(0, start) + outputs[i] + result.slice(end);
	}
	return result;
}

export default function (pi: ExtensionAPI) {
	// ── Path 1: /skill:name invocations ───────────────────────────────────
	pi.on("input", async (event, ctx) => {
		const match = event.text.match(/^\/skill:(\S+)(?:\s+([\s\S]*))?$/);
		if (!match) return { action: "continue" as const };

		const [, skillName, args] = match;

		// Find the skill's SKILL.md path
		const skill = pi.getCommands().find((c) => c.source === "skill" && c.name === `skill:${skillName}`);
		if (!skill?.path) return { action: "continue" as const };

		// Read and check for dynamic commands
		let content: string;
		try {
			content = readFileSync(skill.path, "utf-8");
		} catch {
			return { action: "continue" as const };
		}

		if (!HAS_CMD.test(content)) return { action: "continue" as const };

		// Execute commands and expand
		const skillDir = dirname(skill.path);
		ctx.ui.notify(`Expanding dynamic commands in ${skillName}…`, "info");
		const expanded = await expandCommands(content, skillDir);

		// Build the prompt — replicate pi's skill expansion (content + User: args)
		const text = args?.trim() ? `${expanded}\n\nUser: ${args.trim()}` : expanded;
		return { action: "transform" as const, text };
	});

	// ── Path 2: Agent reads a SKILL.md via the read tool ──────────────────
	pi.on("tool_result", async (event, ctx) => {
		if (event.toolName !== "read") return;

		const input = event.input as { path?: string } | undefined;
		if (!input?.path?.endsWith("SKILL.md")) return;

		// Check if any text block contains dynamic commands
		const hasAny = event.content.some(
			(block) => block.type === "text" && HAS_CMD.test((block as { text: string }).text),
		);
		if (!hasAny) return;

		const skillDir = dirname(resolve(ctx.cwd, input.path));

		const newContent = await Promise.all(
			event.content.map(async (block) => {
				if (block.type !== "text") return block;
				const text = (block as { text: string }).text;
				if (!HAS_CMD.test(text)) return block;
				return { ...block, text: await expandCommands(text, skillDir) };
			}),
		);

		return { content: newContent };
	});
}
