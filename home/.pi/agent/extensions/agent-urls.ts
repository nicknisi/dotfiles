import type { ExtensionAPI, ExtensionCommandContext } from "@mariozechner/pi-coding-agent";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

const AGENT_DIR = process.env.PI_CODING_AGENT_DIR?.startsWith("~/")
	? path.join(os.homedir(), process.env.PI_CODING_AGENT_DIR.slice(2))
	: (process.env.PI_CODING_AGENT_DIR || path.join(os.homedir(), ".pi", "agent"));

const MAX_SCAN_FILES = 2500;
const DEFAULT_LIMIT = 20;
const DEFAULT_MAX_LINES = 500;

type RunSource = "session" | "async" | "artifact" | "chain";

interface ChildRef {
	index?: number;
	agent?: string;
	sessionFile?: string;
	outputFile?: string;
	logFile?: string;
	inputFile?: string;
	metadataFile?: string;
	jsonlFile?: string;
	status?: string;
	task?: string;
	updatedAt: number;
}

interface RunRef {
	runId: string;
	source: RunSource;
	mode?: string;
	state?: string;
	cwd?: string;
	asyncDir?: string;
	chainDir?: string;
	statusFile?: string;
	eventsFile?: string;
	updatedAt: number;
	children: ChildRef[];
}

function exists(file: string | undefined): file is string {
	return Boolean(file) && fs.existsSync(file!);
}

function statMtime(file: string | undefined): number {
	if (!file) return 0;
	try { return fs.statSync(file).mtimeMs; } catch { return 0; }
}

function safeJson(file: string): any | undefined {
	try { return JSON.parse(fs.readFileSync(file, "utf-8")); } catch { return undefined; }
}

function walkFiles(root: string, opts: { maxDepth?: number; maxFiles?: number; match?: (file: string) => boolean } = {}): string[] {
	const out: string[] = [];
	const maxDepth = opts.maxDepth ?? 8;
	const maxFiles = opts.maxFiles ?? MAX_SCAN_FILES;
	function walk(dir: string, depth: number) {
		if (out.length >= maxFiles || depth > maxDepth) return;
		let entries: fs.Dirent[];
		try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
		entries.sort((a, b) => statMtime(path.join(dir, b.name)) - statMtime(path.join(dir, a.name)));
		for (const entry of entries) {
			if (out.length >= maxFiles) return;
			const full = path.join(dir, entry.name);
			if (entry.isDirectory()) {
				if (entry.name === "node_modules" || entry.name === ".git") continue;
				walk(full, depth + 1);
			} else if (!opts.match || opts.match(full)) {
				out.push(full);
			}
		}
	}
	walk(root, 0);
	return out;
}

function upsertRun(map: Map<string, RunRef>, run: RunRef): RunRef {
	const existing = map.get(run.runId);
	if (!existing) {
		map.set(run.runId, run);
		return run;
	}
	existing.source = existing.source === "async" ? existing.source : run.source;
	existing.mode ??= run.mode;
	existing.state ??= run.state;
	existing.cwd ??= run.cwd;
	existing.asyncDir ??= run.asyncDir;
	existing.chainDir ??= run.chainDir;
	existing.statusFile ??= run.statusFile;
	existing.eventsFile ??= run.eventsFile;
	existing.updatedAt = Math.max(existing.updatedAt, run.updatedAt);
	existing.children.push(...run.children);
	return existing;
}

function textFromBlocks(blocks: any): string {
	if (!Array.isArray(blocks)) return "";
	return blocks.map((block) => {
		if (!block || typeof block !== "object") return "";
		if (block.type === "text") return block.text || "";
		if (block.type === "toolCall") return `[tool call: ${block.name}] ${JSON.stringify(block.arguments ?? {})}`;
		if (block.type === "thinking") return "";
		return block.text || block.content || "";
	}).filter(Boolean).join("\n");
}

function sessionInfo(file: string): { cwd?: string; task?: string; lastAssistant?: string; updatedAt: number } {
	let cwd: string | undefined;
	let task: string | undefined;
	let lastAssistant: string | undefined;
	let updatedAt = statMtime(file);
	try {
		const lines = fs.readFileSync(file, "utf-8").split("\n").filter(Boolean);
		for (const line of lines) {
			let entry: any;
			try { entry = JSON.parse(line); } catch { continue; }
			if (entry.timestamp) {
				const t = Date.parse(entry.timestamp);
				if (Number.isFinite(t)) updatedAt = Math.max(updatedAt, t);
			}
			if (entry.type === "session" && entry.cwd) cwd = entry.cwd;
			if (entry.type === "message" && entry.message?.role === "user" && !task) task = textFromBlocks(entry.message.content).replace(/^Task:\s*/i, "").trim();
			if (entry.type === "message" && entry.message?.role === "assistant") {
				const text = textFromBlocks(entry.message.content).trim();
				if (text) lastAssistant = text;
			}
		}
	} catch {}
	return { cwd, task, lastAssistant, updatedAt };
}

function discoverSessionRuns(map: Map<string, RunRef>) {
	const sessionsRoot = path.join(AGENT_DIR, "sessions");
	if (!fs.existsSync(sessionsRoot)) return;
	const files = walkFiles(sessionsRoot, {
		maxDepth: 7,
		match: (file) => file.endsWith(".jsonl") && /\/[0-9a-f]{8}\/run-\d+\//.test(file),
	});
	for (const file of files) {
		const normalized = file.split(path.sep).join("/");
		const match = normalized.match(/\/([0-9a-f]{8})\/run-(\d+)\/[^/]+\.jsonl$/);
		if (!match) continue;
		const [, runId, indexText] = match;
		const info = sessionInfo(file);
		upsertRun(map, {
			runId,
			source: "session",
			cwd: info.cwd,
			updatedAt: info.updatedAt,
			children: [{ index: Number(indexText), sessionFile: file, task: info.task, updatedAt: info.updatedAt }],
		});
	}
}

function discoverAsyncRuns(map: Map<string, RunRef>) {
	const asyncRoot = path.join(os.tmpdir(), `pi-subagents-uid-${typeof process.getuid === "function" ? process.getuid() : "user"}`, "async-subagent-runs");
	if (!fs.existsSync(asyncRoot)) return;
	let dirs: string[] = [];
	try { dirs = fs.readdirSync(asyncRoot).map((name) => path.join(asyncRoot, name)); } catch { return; }
	for (const dir of dirs) {
		const statusFile = path.join(dir, "status.json");
		if (!fs.existsSync(statusFile)) continue;
		const status = safeJson(statusFile);
		const runId = status?.runId || path.basename(dir);
		const children: ChildRef[] = [];
		if (Array.isArray(status?.steps)) {
			status.steps.forEach((step: any, index: number) => {
				children.push({
					index,
					agent: step.agent,
					sessionFile: step.sessionFile,
					status: step.status,
					updatedAt: step.endedAt || step.lastActivityAt || status.lastUpdate || statMtime(statusFile),
				});
			});
		} else {
			children.push({
				index: 0,
				agent: status?.agent,
				sessionFile: status?.sessionFile,
				outputFile: status?.outputFile,
				status: status?.state,
				updatedAt: status?.endedAt || status?.lastActivityAt || status?.lastUpdate || statMtime(statusFile),
			});
		}
		for (const child of children) {
			const log = path.join(dir, `output-${child.index ?? 0}.log`);
			if (fs.existsSync(log)) child.logFile = log;
			if (child.sessionFile && !child.task) child.task = sessionInfo(child.sessionFile).task;
		}
		upsertRun(map, {
			runId,
			source: "async",
			mode: status?.mode,
			state: status?.state,
			cwd: status?.cwd,
			asyncDir: dir,
			statusFile,
			eventsFile: exists(path.join(dir, "events.jsonl")) ? path.join(dir, "events.jsonl") : undefined,
			updatedAt: status?.endedAt || status?.lastUpdate || statMtime(statusFile),
			children,
		});
	}
}

function discoverArtifactRuns(map: Map<string, RunRef>) {
	const files = walkFiles(path.join(AGENT_DIR, "sessions"), {
		maxDepth: 5,
		match: (file) => /subagent-artifacts\/.+_(input|output|meta)\.md$|subagent-artifacts\/.+\.jsonl$|subagent-artifacts\/.+_meta\.json$/.test(file.split(path.sep).join("/")),
	});
	const byBase = new Map<string, Partial<ChildRef> & { runId: string; updatedAt: number }>();
	for (const file of files) {
		const name = path.basename(file);
		let base = name.replace(/_(input|output)\.md$/, "").replace(/_meta\.json$/, "").replace(/\.jsonl$/, "");
		const m = base.match(/^([0-9a-f]{8})_(.+?)(?:_(\d+))?$/);
		if (!m) continue;
		const key = base;
		const child = byBase.get(key) ?? { runId: m[1], agent: m[2], index: m[3] ? Number(m[3]) : undefined, updatedAt: 0 };
		if (name.endsWith("_input.md")) child.inputFile = file;
		else if (name.endsWith("_output.md")) child.outputFile = file;
		else if (name.endsWith("_meta.json")) child.metadataFile = file;
		else if (name.endsWith(".jsonl")) child.jsonlFile = file;
		child.updatedAt = Math.max(child.updatedAt ?? 0, statMtime(file));
		byBase.set(key, child);
	}
	for (const child of byBase.values()) {
		upsertRun(map, { runId: child.runId, source: "artifact", updatedAt: child.updatedAt, children: [child as ChildRef] });
	}
}

function discoverChainRuns(map: Map<string, RunRef>) {
	const chainRoot = path.join(os.tmpdir(), `pi-subagents-uid-${typeof process.getuid === "function" ? process.getuid() : "user"}`, "chain-runs");
	if (!fs.existsSync(chainRoot)) return;
	let dirs: string[] = [];
	try { dirs = fs.readdirSync(chainRoot).map((name) => path.join(chainRoot, name)); } catch { return; }
	for (const dir of dirs) {
		let stat: fs.Stats;
		try { stat = fs.statSync(dir); } catch { continue; }
		if (!stat.isDirectory()) continue;
		const runId = path.basename(dir);
		const mdFiles = walkFiles(dir, { maxDepth: 4, maxFiles: 200, match: (file) => file.endsWith(".md") || file.endsWith(".json") });
		upsertRun(map, {
			runId,
			source: "chain",
			chainDir: dir,
			updatedAt: Math.max(stat.mtimeMs, ...mdFiles.map(statMtime)),
			children: mdFiles.map((file, index) => ({ index, outputFile: file, updatedAt: statMtime(file) })),
		});
	}
}

function discoverRuns(): RunRef[] {
	const map = new Map<string, RunRef>();
	discoverAsyncRuns(map);
	discoverSessionRuns(map);
	discoverArtifactRuns(map);
	discoverChainRuns(map);
	for (const run of map.values()) {
		const byKey = new Map<string, ChildRef>();
		for (const child of run.children) {
			const key = `${child.index ?? ""}:${child.agent ?? ""}:${child.sessionFile ?? child.outputFile ?? child.logFile ?? child.jsonlFile ?? ""}`;
			const existing = byKey.get(key);
			if (!existing) byKey.set(key, child);
			else Object.assign(existing, Object.fromEntries(Object.entries(child).filter(([, value]) => value !== undefined)));
		}
		run.children = [...byKey.values()].sort((a, b) => (a.index ?? 9999) - (b.index ?? 9999));
		run.updatedAt = Math.max(run.updatedAt, ...run.children.map((c) => c.updatedAt || 0));
	}
	return [...map.values()].sort((a, b) => b.updatedAt - a.updatedAt);
}

function short(text: string | undefined, max = 90): string {
	if (!text) return "";
	const oneLine = text.replace(/\s+/g, " ").trim();
	return oneLine.length <= max ? oneLine : `${oneLine.slice(0, max - 1)}…`;
}

function formatDate(ms: number): string {
	return ms ? new Date(ms).toISOString().replace(/\.\d{3}Z$/, "Z") : "unknown";
}

function filterRuns(runs: RunRef[], query?: string): RunRef[] {
	const q = query?.toLowerCase().trim();
	if (!q) return runs;
	return runs.filter((run) => [run.runId, run.source, run.mode, run.state, run.cwd, ...run.children.flatMap((c) => [c.agent, c.task, c.sessionFile, c.outputFile])]
		.filter(Boolean).some((value) => String(value).toLowerCase().includes(q)));
}

function formatRunList(runs: RunRef[], query?: string, limit = DEFAULT_LIMIT): string {
	const filtered = filterRuns(runs, query).slice(0, limit);
	if (!filtered.length) return "No subagent runs found.";
	const lines = [`Subagent runs (${filtered.length}${filterRuns(runs, query).length > filtered.length ? ` of ${filterRuns(runs, query).length}` : ""}):`];
	for (const run of filtered) {
		const labels = [run.source, run.mode, run.state].filter(Boolean).join("/");
		lines.push(`- agent://${run.runId} (${labels || "run"}, ${run.children.length} child${run.children.length === 1 ? "" : "ren"}, ${formatDate(run.updatedAt)})`);
		const task = run.children.find((c) => c.task)?.task;
		if (task) lines.push(`  ${short(task)}`);
	}
	lines.push("", "Read with: `/agent read agent://<runId>` or `/agent read history://<runId>`");
	return lines.join("\n");
}

function resolveRun(uriHostOrId: string, runs: RunRef[]): RunRef {
	const matches = runs.filter((run) => run.runId === uriHostOrId || run.runId.startsWith(uriHostOrId));
	if (matches.length === 0) throw new Error(`No subagent run matched '${uriHostOrId}'. Try /agent list.`);
	if (matches.length > 1) throw new Error(`Ambiguous run id '${uriHostOrId}' matched: ${matches.map((r) => r.runId).join(", ")}`);
	return matches[0];
}

function selectChild(run: RunRef, selector?: string): ChildRef[] {
	if (!selector) return run.children;
	const clean = selector.replace(/^run-/, "");
	const n = Number(clean);
	if (Number.isInteger(n)) return run.children.filter((child) => child.index === n);
	return run.children.filter((child) => child.agent === selector || child.agent?.includes(selector));
}

function readTextFile(file: string, maxLines = DEFAULT_MAX_LINES): string {
	const text = fs.readFileSync(file, "utf-8");
	const lines = text.split("\n");
	if (lines.length <= maxLines) return text;
	return `${lines.slice(0, maxLines).join("\n")}\n\n[truncated: ${lines.length - maxLines} more line(s) in ${file}]`;
}

function renderSession(file: string, maxLines = DEFAULT_MAX_LINES): string {
	const lines: string[] = [];
	for (const raw of fs.readFileSync(file, "utf-8").split("\n")) {
		if (!raw.trim()) continue;
		let entry: any;
		try { entry = JSON.parse(raw); } catch { continue; }
		if (entry.type !== "message") continue;
		const msg = entry.message;
		if (!msg) continue;
		if (msg.role === "toolResult") {
			const text = textFromBlocks(msg.content);
			lines.push(`### toolResult: ${msg.toolName || "tool"}\n\n${text}`);
			continue;
		}
		const text = textFromBlocks(msg.content).trim();
		if (!text) continue;
		lines.push(`### ${msg.role}\n\n${text}`);
	}
	const rendered = lines.join("\n\n");
	const renderedLines = rendered.split("\n");
	if (renderedLines.length <= maxLines) return rendered;
	return `${renderedLines.slice(0, maxLines).join("\n")}\n\n[truncated: ${renderedLines.length - maxLines} more rendered line(s) in ${file}]`;
}

function formatRunSummary(run: RunRef): string {
	const lines = [`# agent://${run.runId}`, ""];
	lines.push(`- source: ${run.source}`);
	if (run.mode) lines.push(`- mode: ${run.mode}`);
	if (run.state) lines.push(`- state: ${run.state}`);
	if (run.cwd) lines.push(`- cwd: ${run.cwd}`);
	if (run.asyncDir) lines.push(`- asyncDir: ${run.asyncDir}`);
	if (run.chainDir) lines.push(`- chainDir: ${run.chainDir}`);
	if (run.statusFile) lines.push(`- status: ${run.statusFile}`);
	if (run.eventsFile) lines.push(`- events: ${run.eventsFile}`);
	lines.push(`- updated: ${formatDate(run.updatedAt)}`);
	lines.push("", "## Children");
	for (const child of run.children) {
		lines.push(`- ${child.index !== undefined ? `run-${child.index}` : "child"}${child.agent ? ` (${child.agent})` : ""}${child.status ? ` — ${child.status}` : ""}`);
		if (child.task) lines.push(`  - task: ${short(child.task, 140)}`);
		if (child.sessionFile) lines.push(`  - history: history://${run.runId}${child.index !== undefined ? `/${child.index}` : ""}`);
		if (child.sessionFile) lines.push(`  - sessionFile: ${child.sessionFile}`);
		if (child.outputFile) lines.push(`  - output: ${child.outputFile}`);
		if (child.logFile) lines.push(`  - log: ${child.logFile}`);
		if (child.inputFile) lines.push(`  - input: ${child.inputFile}`);
		if (child.metadataFile) lines.push(`  - metadata: ${child.metadataFile}`);
	}
	return lines.join("\n");
}

function parseAgentUri(uri: string): { scheme: "agent" | "history"; id?: string; selector?: string; leaf?: string } {
	const match = uri.match(/^(agent|history):\/\/(.*)$/);
	if (!match) throw new Error(`Unsupported URI '${uri}'. Use agent://<runId> or history://<runId>.`);
	const scheme = match[1] as "agent" | "history";
	const parts = match[2].split("/").filter(Boolean);
	return { scheme, id: parts[0], selector: parts[1], leaf: parts[2] };
}

function readAgentUri(uri: string, maxLines = DEFAULT_MAX_LINES): string {
	const parsed = parseAgentUri(uri);
	const runs = discoverRuns();
	if (!parsed.id) return formatRunList(runs, undefined, DEFAULT_LIMIT);
	const run = resolveRun(parsed.id, runs);
	if (parsed.scheme === "history") {
		const children = selectChild(run, parsed.selector).filter((child) => exists(child.sessionFile) || exists(child.jsonlFile));
		if (!children.length) throw new Error(`No session history found for ${uri}.`);
		return children.map((child) => {
			const file = child.sessionFile || child.jsonlFile!;
			return `# history://${run.runId}${child.index !== undefined ? `/${child.index}` : ""}\n\nSession: ${file}\n\n${renderSession(file, maxLines)}`;
		}).join("\n\n---\n\n");
	}
	if (!parsed.selector) return formatRunSummary(run);
	const selected = selectChild(run, parsed.selector);
	if (!selected.length) throw new Error(`No child matched '${parsed.selector}' in ${run.runId}.`);
	const leaf = parsed.leaf || "output";
	return selected.map((child) => {
		if (leaf === "summary") return formatRunSummary({ ...run, children: [child] });
		if (leaf === "session" && child.sessionFile) return readTextFile(child.sessionFile, maxLines);
		if (leaf === "history" && child.sessionFile) return renderSession(child.sessionFile, maxLines);
		if (leaf === "input" && child.inputFile) return readTextFile(child.inputFile, maxLines);
		if (leaf === "meta" && child.metadataFile) return readTextFile(child.metadataFile, maxLines);
		if (leaf === "jsonl" && (child.jsonlFile || child.sessionFile)) return readTextFile(child.jsonlFile || child.sessionFile!, maxLines);
		if (leaf === "log" && child.logFile) return readTextFile(child.logFile, maxLines);
		if ((leaf === "output" || leaf === "result") && child.outputFile) return readTextFile(child.outputFile, maxLines);
		if ((leaf === "output" || leaf === "result") && child.logFile) return readTextFile(child.logFile, maxLines);
		if ((leaf === "output" || leaf === "result") && child.sessionFile) {
			const info = sessionInfo(child.sessionFile);
			return info.lastAssistant || renderSession(child.sessionFile, maxLines);
		}
		throw new Error(`No '${leaf}' content for ${uri}.`);
	}).join("\n\n---\n\n");
}

function postCommandResult(pi: ExtensionAPI, ctx: ExtensionCommandContext, text: string) {
	ctx.ui.notify("Agent URL result shown.", "info");
	pi.sendMessage({ customType: "agent-url", content: text, display: true, details: { kind: "agent-url-command" } });
}

export default function agentUrls(pi: ExtensionAPI) {
	pi.registerTool({
		name: "list_agent_runs",
		label: "List Agent Runs",
		description: "List recent pi-subagents runs and their agent:// / history:// URLs.",
		promptSnippet: "List recent subagent runs before reading agent:// or history:// URLs.",
		parameters: {
			type: "object",
			properties: {
				query: { type: "string", description: "Optional substring filter over run id, agent, task, cwd, and paths." },
				limit: { type: "number", description: "Maximum runs to return.", default: DEFAULT_LIMIT },
			},
		},
		async execute(_id: string, params: { query?: string; limit?: number }) {
			const runs = discoverRuns();
			const text = formatRunList(runs, params.query, Math.max(1, Math.min(params.limit ?? DEFAULT_LIMIT, 100)));
			return { content: [{ type: "text", text }], details: { runs: filterRuns(runs, params.query).slice(0, params.limit ?? DEFAULT_LIMIT) } };
		},
	});

	pi.registerTool({
		name: "read_agent_url",
		label: "Read Agent URL",
		description: "Read agent:// and history:// URLs for pi-subagents runs, outputs, and transcripts.",
		promptSnippet: "Read subagent outputs or transcripts via agent://<runId> and history://<runId>.",
		parameters: {
			type: "object",
			required: ["uri"],
			properties: {
				uri: { type: "string", description: "agent://<runId>[/child[/output|history|session|log|input|meta|jsonl]] or history://<runId>[/child]" },
				maxLines: { type: "number", description: "Maximum rendered lines to return.", default: DEFAULT_MAX_LINES },
			},
		},
		async execute(_id: string, params: { uri: string; maxLines?: number }) {
			const maxLines = Math.max(20, Math.min(params.maxLines ?? DEFAULT_MAX_LINES, 5000));
			const text = readAgentUri(params.uri, maxLines);
			return { content: [{ type: "text", text }], details: { uri: params.uri } };
		},
	});

	pi.registerCommand("agent", {
		description: "Inspect pi-subagents URLs: /agent list [query] | /agent read agent://<runId> | /agent read history://<runId>",
		getArgumentCompletions: (prefix: string) => {
			const parts = prefix.trim().split(/\s+/).filter(Boolean);
			if (parts.length <= 1 && !prefix.endsWith(" ")) {
				return ["list", "read"].filter((item) => item.startsWith(parts[0] ?? "")).map((item) => ({ value: item, label: item }));
			}
			return discoverRuns().slice(0, 20).flatMap((run) => [
				{ value: `agent://${run.runId}`, label: `agent://${run.runId}` },
				{ value: `history://${run.runId}`, label: `history://${run.runId}` },
			]);
		},
		handler: async (args, ctx) => {
			const [sub = "list", ...rest] = args.trim().split(/\s+/).filter(Boolean);
			if (["list", "ls"].includes(sub)) {
				postCommandResult(pi, ctx, formatRunList(discoverRuns(), rest.join(" ") || undefined, DEFAULT_LIMIT));
				return;
			}
			if (["read", "show", "cat"].includes(sub)) {
				const uri = rest[0];
				if (!uri) {
					ctx.ui.notify("Usage: /agent read agent://<runId> or /agent read history://<runId>", "warning");
					return;
				}
				try {
					postCommandResult(pi, ctx, readAgentUri(uri, DEFAULT_MAX_LINES));
				} catch (error) {
					ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
				}
				return;
			}
			ctx.ui.notify("Usage: /agent list [query] | /agent read agent://<runId> | /agent read history://<runId>", "warning");
		},
	});
}
