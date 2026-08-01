/**
 * Claude Agents Bridge — converts CC-format agent definitions to pi format.
 *
 * Claude Code packages ship agent definitions in `agents/*.md` with:
 *   tools: ['Read', 'Glob', 'Grep']   (YAML array, PascalCase)
 *
 * Pi-subagents expects:
 *   tools: read, grep, find           (comma string, lowercase)
 *
 * Pi-subagents also only discovers agents from ~/.pi/agent/agents/ and
 * .pi/agents/, not from package directories.
 *
 * This extension:
 * 1. Finds agent files in installed packages (agents/*.md)
 * 2. Converts CC format to pi format (tool names, tools field, adds model)
 * 3. Writes converted copies to ~/.pi/agent/agents/ with a package prefix
 *
 * The converted files are regenerated each session start, so package
 * updates propagate automatically. The prefix (e.g. "ideation-") prevents
 * collisions with the user's own agents.
 */

import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

/** CC PascalCase tool name → pi lowercase tool name. */
const TOOL_NAME_MAP: Record<string, string> = {
	Read: "read",
	Glob: "find",
	Grep: "grep",
	Bash: "bash",
	Edit: "edit",
	Write: "write",
	LS: "ls",
	NotebookEdit: "edit",
	MultiEdit: "edit",
	WebFetch: "fetch",
	WebSearch: "web_search",
};

/** Convert a CC tool name to pi, or lowercase it if unmapped. */
function convertToolName(ccName: string): string {
	return TOOL_NAME_MAP[ccName] ?? ccName.toLowerCase();
}

/** Parse frontmatter from a markdown file (simple YAML frontmatter). */
function parseFrontmatter(content: string): { frontmatter: Record<string, unknown>; body: string } {
	const match = content.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
	if (!match) {
		return { frontmatter: {}, body: content };
	}

	const yaml = match[1] ?? "";
	const body = match[2] ?? "";

	// Simple YAML parser — handles key: value and key: [array] forms
	const frontmatter: Record<string, unknown> = {};
	for (const line of yaml.split("\n")) {
		const kvMatch = line.match(/^(\w[\w-]*)\s*:\s*(.*)$/);
		if (!kvMatch) continue;
		const [, key, rawValue] = kvMatch;

		// Strip surrounding quotes
		let value: unknown = rawValue.trim().replace(/^['"]|['"]$/g, "");

		// Parse YAML array: ['Read', 'Glob', 'Grep']
		if (typeof value === "string" && value.startsWith("[") && value.endsWith("]")) {
			const inner = value.slice(1, -1);
			value = inner
				.split(",")
				.map((s) => s.trim().replace(/^['"]|['"]$/g, ""))
				.filter(Boolean);
		}

		frontmatter[key] = value;
	}

	return { frontmatter, body };
}

/** Convert a CC-format agent file to pi format. */
function convertAgent(
	content: string,
	packageName: string,
): { name: string; piContent: string } | null {
	const { frontmatter, body } = parseFrontmatter(content);

	const name = frontmatter.name as string | undefined;
	const description = frontmatter.description as string | undefined;
	if (!name || !description) return null;

	// Convert tools: YAML array → comma-separated lowercase string
	let toolsLine = "";
	const rawTools = frontmatter.tools;
	if (Array.isArray(rawTools)) {
		const piTools = rawTools.map((t) => convertToolName(String(t)));
		toolsLine = `tools: ${piTools.join(", ")}`;
	} else if (typeof rawTools === "string") {
		// Already a comma-separated string — just lowercase the tool names
		const piTools = rawTools
			.split(",")
			.map((t) => convertToolName(t.trim()))
			.filter(Boolean);
		toolsLine = `tools: ${piTools.join(", ")}`;
	}

	// Build pi-format frontmatter
	const lines = ["---"];
	lines.push(`name: ${packageName}-${name}`);
	lines.push(`description: ${description}`);
	// Use the session default model if none specified — pi-subagents resolves it
	if (frontmatter.model) {
		lines.push(`model: ${frontmatter.model}`);
	}
	if (frontmatter.thinking) {
		lines.push(`thinking: ${frontmatter.thinking}`);
	}
	if (toolsLine) {
		lines.push(toolsLine);
	}
	lines.push("---");
	lines.push("");

	return {
		name: `${packageName}-${name}`,
		piContent: lines.join("\n") + body,
	};
}

/** Derive the package name from a skill or agent file path. */
function derivePackageName(filePath: string): string | null {
	// Walk up to find a package.json
	let dir = dirname(filePath);
	for (let i = 0; i < 5; i++) {
		const pkgPath = join(dir, "package.json");
		if (existsSync(pkgPath)) {
			try {
				const pkg = JSON.parse(readFileSync(pkgPath, "utf-8"));
				const name = pkg.name;
				if (typeof name === "string") {
					// Use the unscoped part of the package name
					return name.split("/").pop() ?? name;
				}
			} catch {
				// ignore
			}
		}
		dir = dirname(dir);
	}
	return null;
}

/** Find agent files in a package directory. */
function findAgentFiles(pkgDir: string): string[] {
	const agentsDir = join(pkgDir, "agents");
	if (!existsSync(agentsDir)) return [];

	try {
		return readdirSync(agentsDir)
			.filter((f) => f.endsWith(".md"))
			.map((f) => join(agentsDir, f));
	} catch {
		return [];
	}
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, _ctx) => {
		// Discover package roots from loaded skills (same approach as claude-plugin-root)
		const commands = pi.getCommands();
		const skillCommands = commands.filter(
			(cmd: { source?: string }) => cmd.source === "skill",
		);

		const packageRoots = new Set<string>();
		for (const cmd of skillCommands) {
			const skillPath = cmd.sourceInfo?.path;
			if (!skillPath) continue;
			// skill path: <pkg>/skills/<name>/SKILL.md → package root = dirname x3
			const root = dirname(dirname(dirname(skillPath)));
			packageRoots.add(root);
		}

		// Also check npm packages directly
		const npmDir = join(process.env.HOME ?? "", ".pi", "agent", "npm", "node_modules");
		if (existsSync(npmDir)) {
			try {
				for (const entry of readdirSync(npmDir)) {
					const full = join(npmDir, entry);
					if (entry.startsWith("@")) {
						// Scoped package — check subdirectories
						try {
							for (const sub of readdirSync(full)) {
								packageRoots.add(join(full, sub));
							}
						} catch {
							// ignore
						}
					} else {
						packageRoots.add(full);
					}
				}
			} catch {
				// ignore
			}
		}

		// Find and convert all agent files
		const agentsDir = join(process.env.HOME ?? "", ".pi", "agent", "agents");
		mkdirSync(agentsDir, { recursive: true });

		const written: string[] = [];
		for (const pkgRoot of packageRoots) {
			const agentFiles = findAgentFiles(pkgRoot);
			if (agentFiles.length === 0) continue;

			const packageName = derivePackageName(pkgRoot) ?? "pkg";

			for (const agentFile of agentFiles) {
				try {
					const content = readFileSync(agentFile, "utf-8");
					const converted = convertAgent(content, packageName);
					if (!converted) continue;

					const outFile = join(agentsDir, `${converted.name}.md`);
					writeFileSync(outFile, converted.piContent);
					written.push(converted.name);
				} catch {
					// skip unreadable files
				}
			}
		}

		if (written.length > 0) {
			// Log to stderr for debugging (not the UI — this is background work)
			process.stderr.write(
				`[claude-agents-bridge] converted ${written.length} agents: ${written.join(", ")}\n`,
			);
		}
	});
}