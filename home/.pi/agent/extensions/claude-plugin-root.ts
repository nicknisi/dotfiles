/**
 * Claude Plugin Root — exports CLAUDE_PLUGIN_ROOT for CC-origin skills.
 *
 * Claude Code skills reference files via `${CLAUDE_PLUGIN_ROOT}`, a variable
 * that CC sets to the root of the plugin the skill belongs to. Pi doesn't set
 * it, so skills ported from CC (ideation, image-gen, etc.) break when they
 * try to read references or run scripts.
 *
 * This extension:
 * 1. Discovers all loaded skill package roots from pi.getCommands()
 * 2. Sets process.env.CLAUDE_PLUGIN_ROOT (single-package case)
 * 3. Intercepts tool_call for bash/read and rewrites ${CLAUDE_PLUGIN_ROOT}
 *    to the actual path by trying each known root (multi-package case)
 *
 * The rewriting is transparent — the model writes ${CLAUDE_PLUGIN_ROOT}
 * as it always does, and this extension silently resolves it.
 */

import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

/** Package roots derived from loaded skill paths. */
const packageRoots: string[] = [];

/**
 * Derive the package root from a skill file path.
 *
 * Skill paths follow the convention:
 *   <package-root>/skills/<skill-name>/SKILL.md
 *
 * So the package root is two levels up from the skill directory:
 *   SKILL.md → <skill-name>/ → skills/ → <package-root>/
 */
function derivePackageRoot(skillFilePath: string): string {
	const baseDir = dirname(skillFilePath);
	const skillsDir = dirname(baseDir);
	return dirname(skillsDir);
}

/**
 * Rewrite ${CLAUDE_PLUGIN_ROOT} references in a string to actual paths.
 *
 * Tries each known package root to find the one where the referenced file
 * exists, then substitutes. Preserves the path after the root ref.
 *
 * Handles: ${CLAUDE_PLUGIN_ROOT}/path, $CLAUDE_PLUGIN_ROOT/path,
 *          and bare ${CLAUDE_PLUGIN_ROOT} (no path).
 */
function rewriteRootRef(text: string): string {
	if (!text.includes("CLAUDE_PLUGIN_ROOT")) return text;
	if (packageRoots.length === 0) return text;

	return text.replace(
		/\$\{?CLAUDE_PLUGIN_ROOT\}?(?:\s*\/([^\s;|&"'()]+))?/g,
		(fullMatch, relativePath?: string) => {
			// No path after the root ref — return first root
			if (!relativePath) {
				return packageRoots[0] ?? fullMatch;
			}

			// Try each root to find one where the file exists
			for (const root of packageRoots) {
				const candidate = join(root, relativePath);
				if (existsSync(candidate)) {
					return `${root}/${relativePath}`;
				}
			}

			// No match — use first root as fallback
			return `${packageRoots[0]}/${relativePath}`;
		},
	);
}

export default function (pi: ExtensionAPI) {
	// Discover package roots from loaded skills at session start.
	pi.on("session_start", async (_event, _ctx) => {
		packageRoots.length = 0;

		const commands = pi.getCommands();
		const skillCommands = commands.filter(
			(cmd: { source?: string }) => cmd.source === "skill",
		);

		const seen = new Set<string>();
		for (const cmd of skillCommands) {
			const skillPath = cmd.sourceInfo?.path;
			if (!skillPath) continue;

			const root = derivePackageRoot(skillPath);
			if (!seen.has(root)) {
				seen.add(root);
				packageRoots.push(root);
			}
		}

		// Set the env var for the single-package case.
		// Bash commands that use $CLAUDE_PLUGIN_ROOT will get this value.
		// For multi-package, the tool_call interceptor handles it.
		if (packageRoots.length > 0) {
			process.env.CLAUDE_PLUGIN_ROOT = packageRoots[0];
		}
	});

	// Intercept tool calls and rewrite CLAUDE_PLUGIN_ROOT references.
	pi.on("tool_call", async (event, _ctx) => {
		if (packageRoots.length === 0) return;

		// Bash tool: rewrite command string
		if (event.toolName === "bash" && event.input?.command) {
			const original = event.input.command as string;
			const rewritten = rewriteRootRef(original);
			if (rewritten !== original) {
				event.input.command = rewritten;
			}
		}

		// Read tool: rewrite path
		if (event.toolName === "read" && event.input?.path) {
			const original = event.input.path as string;
			const rewritten = rewriteRootRef(original);
			if (rewritten !== original) {
				event.input.path = rewritten;
			}
		}
	});
}