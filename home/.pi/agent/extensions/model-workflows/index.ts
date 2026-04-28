import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { complete, StringEnum, type Message } from "@mariozechner/pi-ai";
import {
	BorderedLoader,
	convertToLlm,
	getMarkdownTheme,
	serializeConversation,
	type ExtensionAPI,
	type ExtensionCommandContext,
	type SessionEntry,
	withFileMutationQueue,
} from "@mariozechner/pi-coding-agent";
import { Box, Container, Markdown, Spacer, Text, type Component } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";
import { type AgentConfig, type AgentScope, discoverAgents, getAgentByName } from "./agents.js";

const TOOL_NAME = "model_workflow";
const MESSAGE_TYPE = "model-workflow";
const DEFAULT_AGENT_SCOPE: AgentScope = "user";
const MAX_PARALLEL_TASKS = 8;
const MAX_CONCURRENCY = 4;

const HANDOFF_PROMPT = `You are a context transfer assistant. Given a conversation history and the user's goal for a new thread, generate a focused prompt that:

1. Summarizes the relevant context from the conversation
2. Lists any relevant files, commands, or decisions
3. Clearly states the next task for the new thread
4. Is self-contained enough that the new thread can proceed without re-reading the old one

Output only the prompt the user should send in the new thread.

Preferred format:
## Context
- Key decision or finding
- Key decision or finding

## Files / Artifacts
- path/to/file.ts
- path/to/other.ts

## Task
A clear statement of what to do next.`;

const TaskItem = Type.Object({
	agent: Type.String({ description: "Name of the agent to invoke" }),
	task: Type.String({ description: "Task to delegate to the agent" }),
	cwd: Type.Optional(Type.String({ description: "Working directory for the delegated agent" })),
});

const ChainItem = Type.Object({
	agent: Type.String({ description: "Name of the agent to invoke" }),
	task: Type.String({ description: "Task to delegate. Supports {previous} placeholder." }),
	cwd: Type.Optional(Type.String({ description: "Working directory for the delegated agent" })),
	label: Type.Optional(Type.String({ description: "Optional label shown in the UI" })),
});

const WorkflowEnum = StringEnum(["single", "parallel", "chain", "compare", "debate", "implement_with_review"] as const, {
	description: "Workflow to run",
});

const AgentScopeSchema = StringEnum(["user", "project", "both"] as const, {
	description: 'Which agent directories to use. Default: "user".',
	default: DEFAULT_AGENT_SCOPE,
});

const ParamsSchema = Type.Object({
	workflow: Type.Optional(WorkflowEnum),
	task: Type.Optional(Type.String({ description: "Task for canned workflows" })),
	agent: Type.Optional(Type.String({ description: "Agent name for single workflow" })),
	tasks: Type.Optional(Type.Array(TaskItem, { description: "Parallel tasks" })),
	chain: Type.Optional(Type.Array(ChainItem, { description: "Chain steps" })),
	agentScope: Type.Optional(AgentScopeSchema),
	confirmProjectAgents: Type.Optional(Type.Boolean({ default: true })),
	cwd: Type.Optional(Type.String({ description: "Working directory override for single workflow" })),
	proposer: Type.Optional(Type.String({ description: 'Debate proposer agent. Default: "opus".' })),
	critic: Type.Optional(Type.String({ description: 'Debate critic agent. Default: "gpt".' })),
	synthesizer: Type.Optional(Type.String({ description: 'Synthesis agent. Default: "synthesizer".' })),
	implementer: Type.Optional(Type.String({ description: 'Implementation agent. Default: "gpt".' })),
	reviewer: Type.Optional(Type.String({ description: 'Review agent. Default: "reviewer".' })),
});

type WorkflowName = "single" | "parallel" | "chain" | "compare" | "debate" | "implement_with_review";

type ToolParams = {
	workflow?: WorkflowName;
	task?: string;
	agent?: string;
	tasks?: Array<{ agent: string; task: string; cwd?: string }>;
	chain?: Array<{ agent: string; task: string; cwd?: string; label?: string }>;
	agentScope?: AgentScope;
	confirmProjectAgents?: boolean;
	cwd?: string;
	proposer?: string;
	critic?: string;
	synthesizer?: string;
	implementer?: string;
	reviewer?: string;
};

interface UsageStats {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
	contextTokens: number;
	turns: number;
}

interface SingleResult {
	agent: string;
	agentSource: "user" | "project" | "unknown";
	label?: string;
	task: string;
	exitCode: number;
	messages: Message[];
	stderr: string;
	usage: UsageStats;
	model?: string;
	stopReason?: string;
	errorMessage?: string;
}

interface WorkflowDetails {
	workflow: WorkflowName;
	requestedTask?: string;
	agentScope: AgentScope;
	projectAgentsDir: string | null;
	results: SingleResult[];
}

type DisplayItem = { type: "text"; text: string } | { type: "toolCall"; name: string; args: Record<string, unknown> };

type OnUpdateCallback = (details: WorkflowDetails) => void;

function formatTokens(count: number): string {
	if (count < 1000) return count.toString();
	if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1000000) return `${Math.round(count / 1000)}k`;
	return `${(count / 1000000).toFixed(1)}M`;
}

function formatUsageStats(usage: UsageStats, model?: string): string {
	const parts: string[] = [];
	if (usage.turns) parts.push(`${usage.turns} turn${usage.turns === 1 ? "" : "s"}`);
	if (usage.input) parts.push(`↑${formatTokens(usage.input)}`);
	if (usage.output) parts.push(`↓${formatTokens(usage.output)}`);
	if (usage.cacheRead) parts.push(`R${formatTokens(usage.cacheRead)}`);
	if (usage.cacheWrite) parts.push(`W${formatTokens(usage.cacheWrite)}`);
	if (usage.cost) parts.push(`$${usage.cost.toFixed(4)}`);
	if (usage.contextTokens) parts.push(`ctx:${formatTokens(usage.contextTokens)}`);
	if (model) parts.push(model);
	return parts.join(" ");
}

function formatToolCall(toolName: string, args: Record<string, unknown>, themeFg: (color: string, text: string) => string): string {
	const shortenPath = (p: string) => {
		const home = os.homedir();
		return p.startsWith(home) ? `~${p.slice(home.length)}` : p;
	};

	switch (toolName) {
		case "bash": {
			const command = ((args.command as string) || "...").trim();
			const preview = command.length > 60 ? `${command.slice(0, 60)}...` : command;
			return themeFg("muted", "$ ") + themeFg("toolOutput", preview);
		}
		case "read": {
			const rawPath = ((args.file_path || args.path || "...") as string).trim();
			const offset = args.offset as number | undefined;
			const limit = args.limit as number | undefined;
			let text = themeFg("accent", shortenPath(rawPath));
			if (offset !== undefined || limit !== undefined) {
				const startLine = offset ?? 1;
				const endLine = limit !== undefined ? startLine + limit - 1 : "";
				text += themeFg("warning", `:${startLine}${endLine ? `-${endLine}` : ""}`);
			}
			return themeFg("muted", "read ") + text;
		}
		case "write":
			return themeFg("muted", "write ") + themeFg("accent", shortenPath((args.path as string) || "..."));
		case "edit":
			return themeFg("muted", "edit ") + themeFg("accent", shortenPath((args.path as string) || "..."));
		case "ls":
			return themeFg("muted", "ls ") + themeFg("accent", shortenPath((args.path as string) || "."));
		case "find":
			return (
				themeFg("muted", "find ") +
				themeFg("accent", String(args.pattern || "*")) +
				themeFg("dim", ` in ${shortenPath((args.path as string) || ".")}`)
			);
		case "grep":
			return (
				themeFg("muted", "grep ") +
				themeFg("accent", `/${String(args.pattern || "")}/`) +
				themeFg("dim", ` in ${shortenPath((args.path as string) || ".")}`)
			);
		default: {
			const argsStr = JSON.stringify(args);
			const preview = argsStr.length > 50 ? `${argsStr.slice(0, 50)}...` : argsStr;
			return themeFg("accent", toolName) + themeFg("dim", ` ${preview}`);
		}
	}
}

function getFinalOutput(messages: Message[]): string {
	for (let i = messages.length - 1; i >= 0; i--) {
		const message = messages[i];
		if (message.role !== "assistant") continue;
		for (const part of message.content) {
			if (part.type === "text") return part.text;
		}
	}
	return "";
}

function getDisplayItems(messages: Message[]): DisplayItem[] {
	const items: DisplayItem[] = [];
	for (const message of messages) {
		if (message.role !== "assistant") continue;
		for (const part of message.content) {
			if (part.type === "text") items.push({ type: "text", text: part.text });
			if (part.type === "toolCall") items.push({ type: "toolCall", name: part.name, args: part.arguments });
		}
	}
	return items;
}

function renderWorkflowDetails(details: WorkflowDetails, expanded: boolean, theme: any): Component {
	const mdTheme = getMarkdownTheme();
	const results = details.results;
	const aggregateUsage = results.reduce<UsageStats>(
		(total, result) => ({
			input: total.input + result.usage.input,
			output: total.output + result.usage.output,
			cacheRead: total.cacheRead + result.usage.cacheRead,
			cacheWrite: total.cacheWrite + result.usage.cacheWrite,
			cost: total.cost + result.usage.cost,
			contextTokens: Math.max(total.contextTokens, result.usage.contextTokens),
			turns: total.turns + result.usage.turns,
		}),
		{ input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
	);

	const completed = results.filter((result) => result.exitCode !== -1).length;
	const failed = results.filter(
		(result) => result.exitCode > 0 || result.stopReason === "error" || result.stopReason === "aborted",
	).length;
	const running = results.filter((result) => result.exitCode === -1).length;
	const icon = running > 0 ? theme.fg("warning", "⏳") : failed > 0 ? theme.fg("warning", "◐") : theme.fg("success", "✓");
	const header = `${icon} ${theme.fg("toolTitle", theme.bold(details.workflow.replace(/_/g, " ")))}${details.requestedTask ? theme.fg("dim", ` — ${details.requestedTask}`) : ""}`;

	const renderCollapsedPreview = (result: SingleResult): string => {
		const output = getFinalOutput(result.messages).trim();
		if (output) return output.split("\n").slice(0, 3).join("\n");
		const items = getDisplayItems(result.messages);
		if (items.length === 0) return result.exitCode === -1 ? "(running...)" : "(no output)";
		return items
			.slice(-2)
			.map((item) =>
				item.type === "text"
					? item.text.split("\n").slice(0, 2).join("\n")
					: formatToolCall(item.name, item.args, theme.fg.bind(theme)),
			)
			.join("\n");
	};

	if (!expanded) {
		let text = header;
		for (const result of results) {
			const resultIcon =
				result.exitCode === -1
					? theme.fg("warning", "⏳")
					: result.exitCode > 0 || result.stopReason === "error" || result.stopReason === "aborted"
						? theme.fg("error", "✗")
						: theme.fg("success", "✓");
			const label = result.label ?? result.agent;
			text += `\n\n${theme.fg("muted", "─── ")}${theme.fg("accent", label)} ${resultIcon}`;
			text += theme.fg("dim", ` (${result.agent})`);
			text += `\n${theme.fg("toolOutput", renderCollapsedPreview(result))}`;
			const usage = formatUsageStats(result.usage, result.model);
			if (usage) text += `\n${theme.fg("dim", usage)}`;
		}
		if (results.length > 1) {
			text += `\n\n${theme.fg("dim", `Progress: ${completed}/${results.length} complete${running ? `, ${running} running` : ""}`)}`;
		}
		const totalUsage = formatUsageStats(aggregateUsage);
		if (totalUsage) text += `\n${theme.fg("dim", `Total: ${totalUsage}`)}`;
		if (results.length > 0) text += `\n${theme.fg("muted", `(Ctrl+O to expand)`)}`;
		return new Text(text, 0, 0);
	}

	const container = new Container();
	container.addChild(new Text(header, 0, 0));
	if (results.length > 1) {
		container.addChild(new Text(theme.fg("dim", `Progress: ${completed}/${results.length} complete${failed ? `, ${failed} failed` : ""}`), 0, 0));
	}

	for (const result of results) {
		const resultIcon =
			result.exitCode === -1
				? theme.fg("warning", "⏳")
				: result.exitCode > 0 || result.stopReason === "error" || result.stopReason === "aborted"
					? theme.fg("error", "✗")
					: theme.fg("success", "✓");
		const title = result.label ?? result.agent;
		container.addChild(new Spacer(1));
		container.addChild(
			new Text(`${theme.fg("muted", "─── ")}${theme.fg("accent", title)} ${resultIcon}${theme.fg("dim", ` (${result.agent})`)}`, 0, 0),
		);
		container.addChild(new Text(theme.fg("muted", "Task: ") + theme.fg("dim", result.task), 0, 0));
		if (result.errorMessage) {
			container.addChild(new Text(theme.fg("error", `Error: ${result.errorMessage}`), 0, 0));
		}

		const items = getDisplayItems(result.messages);
		const toolCalls = items.filter((item) => item.type === "toolCall") as Array<{ type: "toolCall"; name: string; args: Record<string, unknown> }>;
		if (toolCalls.length > 0) {
			container.addChild(new Spacer(1));
			for (const toolCall of toolCalls) {
				container.addChild(
					new Text(theme.fg("muted", "→ ") + formatToolCall(toolCall.name, toolCall.args, theme.fg.bind(theme)), 0, 0),
				);
			}
		}

		const finalOutput = getFinalOutput(result.messages).trim();
		if (finalOutput) {
			container.addChild(new Spacer(1));
			container.addChild(new Markdown(finalOutput, 0, 0, mdTheme));
		}

		const usage = formatUsageStats(result.usage, result.model);
		if (usage) {
			container.addChild(new Spacer(1));
			container.addChild(new Text(theme.fg("dim", usage), 0, 0));
		}
	}

	const totalUsage = formatUsageStats(aggregateUsage);
	if (totalUsage) {
		container.addChild(new Spacer(1));
		container.addChild(new Text(theme.fg("dim", `Total: ${totalUsage}`), 0, 0));
	}

	return container;
}

function makeDetails(
	workflow: WorkflowName,
	requestedTask: string | undefined,
	agentScope: AgentScope,
	projectAgentsDir: string | null,
	results: SingleResult[],
): WorkflowDetails {
	return { workflow, requestedTask, agentScope, projectAgentsDir, results };
}

async function mapWithConcurrencyLimit<TIn, TOut>(
	items: TIn[],
	concurrency: number,
	fn: (item: TIn, index: number) => Promise<TOut>,
): Promise<TOut[]> {
	if (items.length === 0) return [];
	const limit = Math.max(1, Math.min(concurrency, items.length));
	const results: TOut[] = new Array(items.length);
	let nextIndex = 0;
	const workers = new Array(limit).fill(null).map(async () => {
		while (true) {
			const current = nextIndex++;
			if (current >= items.length) return;
			results[current] = await fn(items[current], current);
		}
	});
	await Promise.all(workers);
	return results;
}

async function writePromptToTempFile(agentName: string, prompt: string): Promise<{ dir: string; filePath: string }> {
	const tmpDir = await fs.promises.mkdtemp(path.join(os.tmpdir(), "pi-model-workflows-"));
	const safeName = agentName.replace(/[^\w.-]+/g, "_");
	const filePath = path.join(tmpDir, `prompt-${safeName}.md`);
	await withFileMutationQueue(filePath, async () => {
		await fs.promises.writeFile(filePath, prompt, { encoding: "utf-8", mode: 0o600 });
	});
	return { dir: tmpDir, filePath };
}

function getPiInvocation(args: string[]): { command: string; args: string[] } {
	const currentScript = process.argv[1];
	if (currentScript && fs.existsSync(currentScript)) {
		return { command: process.execPath, args: [currentScript, ...args] };
	}

	const execName = path.basename(process.execPath).toLowerCase();
	const isGenericRuntime = /^(node|bun)(\.exe)?$/.test(execName);
	if (!isGenericRuntime) {
		return { command: process.execPath, args };
	}

	return { command: "pi", args };
}

async function runSingleAgent(
	defaultCwd: string,
	agents: AgentConfig[],
	agentName: string,
	task: string,
	cwd: string | undefined,
	signal: AbortSignal | undefined,
	onUpdate: ((result: SingleResult) => void) | undefined,
	label?: string,
): Promise<SingleResult> {
	const agent = getAgentByName(agents, agentName);
	if (!agent) {
		const available = agents.map((entry) => `"${entry.name}"`).join(", ") || "none";
		return {
			agent: agentName,
			agentSource: "unknown",
			label,
			task,
			exitCode: 1,
			messages: [],
			stderr: `Unknown agent: "${agentName}". Available agents: ${available}.`,
			usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
			errorMessage: `Unknown agent: ${agentName}`,
		};
	}

	const args: string[] = ["--mode", "json", "-p", "--no-session", "--no-extensions"];
	if (agent.model) args.push("--model", agent.model);
	if (agent.thinking) args.push("--thinking", agent.thinking);
	if (agent.tools && agent.tools.length > 0) args.push("--tools", agent.tools.join(","));

	let tmpPromptDir: string | null = null;
	let tmpPromptPath: string | null = null;
	let wasAborted = false;

	const currentResult: SingleResult = {
		agent: agentName,
		agentSource: agent.source,
		label,
		task,
		exitCode: -1,
		messages: [],
		stderr: "",
		usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
		model: agent.model,
	};

	const emitUpdate = () => {
		onUpdate?.({ ...currentResult, messages: [...currentResult.messages], usage: { ...currentResult.usage } });
	};

	try {
		if (agent.systemPrompt.trim()) {
			const tmp = await writePromptToTempFile(agent.name, agent.systemPrompt);
			tmpPromptDir = tmp.dir;
			tmpPromptPath = tmp.filePath;
			args.push("--append-system-prompt", tmpPromptPath);
		}

		args.push(`Task: ${task}`);

		const exitCode = await new Promise<number>((resolve) => {
			const invocation = getPiInvocation(args);
			const proc = spawn(invocation.command, invocation.args, {
				cwd: cwd ?? defaultCwd,
				shell: false,
				stdio: ["ignore", "pipe", "pipe"],
			});
			let buffer = "";

			const processLine = (line: string) => {
				if (!line.trim()) return;
				let event: any;
				try {
					event = JSON.parse(line);
				} catch {
					return;
				}

				if (event.type === "message_end" && event.message) {
					const message = event.message as Message;
					currentResult.messages.push(message);
					if (message.role === "assistant") {
						currentResult.usage.turns++;
						if (message.usage) {
							currentResult.usage.input += message.usage.input || 0;
							currentResult.usage.output += message.usage.output || 0;
							currentResult.usage.cacheRead += message.usage.cacheRead || 0;
							currentResult.usage.cacheWrite += message.usage.cacheWrite || 0;
							currentResult.usage.cost += message.usage.cost?.total || 0;
							currentResult.usage.contextTokens = message.usage.totalTokens || currentResult.usage.contextTokens;
						}
						if (!currentResult.model && message.model) currentResult.model = message.model;
						if (message.stopReason) currentResult.stopReason = message.stopReason;
						if (message.errorMessage) currentResult.errorMessage = message.errorMessage;
					}
					emitUpdate();
				}

				if (event.type === "tool_result_end" && event.message) {
					currentResult.messages.push(event.message as Message);
					emitUpdate();
				}
			};

			proc.stdout.on("data", (data) => {
				buffer += data.toString();
				const lines = buffer.split("\n");
				buffer = lines.pop() || "";
				for (const line of lines) processLine(line);
			});

			proc.stderr.on("data", (data) => {
				currentResult.stderr += data.toString();
			});

			proc.on("close", (code) => {
				if (buffer.trim()) processLine(buffer);
				resolve(code ?? 0);
			});

			proc.on("error", () => resolve(1));

			if (signal) {
				const killProc = () => {
					wasAborted = true;
					proc.kill("SIGTERM");
					setTimeout(() => {
						if (!proc.killed) proc.kill("SIGKILL");
					}, 5000);
				};
				if (signal.aborted) killProc();
				else signal.addEventListener("abort", killProc, { once: true });
			}
		});

		currentResult.exitCode = exitCode;
		if (wasAborted) {
			currentResult.stopReason = "aborted";
			currentResult.errorMessage = "Delegated agent was aborted";
		}
		return currentResult;
	} finally {
		if (tmpPromptPath) {
			try {
				fs.unlinkSync(tmpPromptPath);
			} catch {}
		}
		if (tmpPromptDir) {
			try {
				fs.rmdirSync(tmpPromptDir);
			} catch {}
		}
	}
}

function isResultError(result: SingleResult): boolean {
	return result.exitCode > 0 || result.stopReason === "error" || result.stopReason === "aborted";
}

async function confirmProjectAgentsIfNeeded(
	ctx: any,
	agents: AgentConfig[],
	discovery: { projectAgentsDir: string | null },
	requestedAgentNames: string[],
	confirmProjectAgents: boolean,
): Promise<boolean> {
	if (!ctx.hasUI || !confirmProjectAgents) return true;
	const projectAgentsRequested = requestedAgentNames
		.map((name) => getAgentByName(agents, name))
		.filter((agent): agent is AgentConfig => agent?.source === "project");
	if (projectAgentsRequested.length === 0) return true;

	const names = projectAgentsRequested.map((agent) => agent.name).join(", ");
	const dir = discovery.projectAgentsDir ?? "(unknown)";
	return ctx.ui.confirm(
		"Run project-local agents?",
		`Agents: ${names}\nSource: ${dir}\n\nProject agents are repo-controlled. Only continue for trusted repositories.`,
	);
}

function buildCompareSynthesisTask(requestedTask: string, opusOutput: string, gptOutput: string): string {
	return `Compare these two model responses to the same request and produce a clear final recommendation.

## Original request
${requestedTask}

## Opus
${opusOutput}

## GPT
${gptOutput}

Respond with:
## Agreement
- ...

## Disagreement
- ...

## Recommendation
- ...

## Next step
- ...`;
}

function buildDebateProposalTask(requestedTask: string): string {
	return `Take a strong position on the best approach for this request.

## Request
${requestedTask}

Respond with:
## Position
## Rationale
## Risks
## Recommendation`;
}

function buildDebateCritiqueTask(requestedTask: string, proposal: string): string {
	return `Critique the following proposal hard. Identify flawed assumptions, missing constraints, risks, blind spots, and a better alternative if you see one.

## Original request
${requestedTask}

## Proposal to critique
${proposal}

Respond with:
## What is right
## What is wrong
## Better alternative
## Recommendation`;
}

function buildDebateRevisionTask(requestedTask: string, proposal: string, critique: string): string {
	return `Revise the original proposal in light of the critique.

## Original request
${requestedTask}

## Original proposal
${proposal}

## Critique
${critique}

Respond with:
## Updated position
## What changed
## What you rejected
## Final recommendation`;
}

function buildDebateSynthesisTask(requestedTask: string, proposal: string, critique: string, revision: string): string {
	return `Synthesize this debate into a final recommendation.

## Original request
${requestedTask}

## Initial proposal
${proposal}

## Critique
${critique}

## Revised proposal
${revision}

Respond with:
## Best answer
## Why this wins
## Remaining risks
## Next step`;
}

function buildImplementationTask(requestedTask: string): string {
	return `Implement this request in the current repository. Make the necessary file changes and summarize what you changed.

## Request
${requestedTask}`;
}

function buildReviewTask(requestedTask: string, implementationSummary: string): string {
	return `Review the current implementation for correctness, maintainability, security, and edge cases.
Use git diff and targeted file reads as needed.

## Original request
${requestedTask}

## Implementation summary
${implementationSummary}`;
}

function buildApplyReviewTask(requestedTask: string, implementationSummary: string, review: string): string {
	return `Apply the review feedback to the current repository.
If you disagree with a point, explain why in the final summary.

## Original request
${requestedTask}

## Current implementation summary
${implementationSummary}

## Review feedback
${review}`;
}

async function executeWorkflow(
	ctx: any,
	agents: AgentConfig[],
	discovery: { projectAgentsDir: string | null },
	params: ToolParams,
	signal: AbortSignal | undefined,
	onUpdate?: OnUpdateCallback,
): Promise<WorkflowDetails> {
	const agentScope = params.agentScope ?? DEFAULT_AGENT_SCOPE;
	const workflow: WorkflowName = params.workflow ?? (params.chain?.length ? "chain" : params.tasks?.length ? "parallel" : "single");
	const results: SingleResult[] = [];
	const emit = () => onUpdate?.(makeDetails(workflow, params.task, agentScope, discovery.projectAgentsDir, [...results]));

	if (workflow === "single") {
		if (!params.agent || !params.task) {
			return makeDetails(workflow, params.task, agentScope, discovery.projectAgentsDir, [
				{
					agent: params.agent ?? "unknown",
					agentSource: "unknown",
					task: params.task ?? "",
					exitCode: 1,
					messages: [],
					stderr: "single workflow requires both agent and task",
					usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
					errorMessage: "single workflow requires both agent and task",
				},
			]);
		}
		const result = await runSingleAgent(ctx.cwd, agents, params.agent, params.task, params.cwd, signal, (partial) => {
			onUpdate?.(makeDetails(workflow, params.task, agentScope, discovery.projectAgentsDir, [partial]));
		});
		results.push(result);
		return makeDetails(workflow, params.task, agentScope, discovery.projectAgentsDir, results);
	}

	if (workflow === "parallel") {
		if (!params.tasks || params.tasks.length === 0) {
			return makeDetails(workflow, params.task, agentScope, discovery.projectAgentsDir, []);
		}
		if (params.tasks.length > MAX_PARALLEL_TASKS) {
			return makeDetails(workflow, params.task, agentScope, discovery.projectAgentsDir, [
				{
					agent: "parallel",
					agentSource: "unknown",
					task: params.task ?? "",
					exitCode: 1,
					messages: [],
					stderr: `Too many parallel tasks (${params.tasks.length}). Max is ${MAX_PARALLEL_TASKS}.`,
					usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
					errorMessage: `Too many parallel tasks (${params.tasks.length}). Max is ${MAX_PARALLEL_TASKS}.`,
				},
			]);
		}

		const allResults: SingleResult[] = params.tasks.map((task) => ({
			agent: task.agent,
			agentSource: "unknown",
			task: task.task,
			exitCode: -1,
			messages: [],
			stderr: "",
			usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
		}));

		const completed = await mapWithConcurrencyLimit(params.tasks, MAX_CONCURRENCY, async (task, index) => {
			const result = await runSingleAgent(ctx.cwd, agents, task.agent, task.task, task.cwd, signal, (partial) => {
				allResults[index] = partial;
				onUpdate?.(makeDetails(workflow, params.task, agentScope, discovery.projectAgentsDir, [...allResults]));
			});
			allResults[index] = result;
			onUpdate?.(makeDetails(workflow, params.task, agentScope, discovery.projectAgentsDir, [...allResults]));
			return result;
		});

		results.push(...completed);
		return makeDetails(workflow, params.task, agentScope, discovery.projectAgentsDir, results);
	}

	if (workflow === "chain") {
		if (!params.chain || params.chain.length === 0) {
			return makeDetails(workflow, params.task, agentScope, discovery.projectAgentsDir, []);
		}
		let previousOutput = "";
		for (const step of params.chain) {
			const task = step.task.replace(/\{previous\}/g, previousOutput);
			const result = await runSingleAgent(ctx.cwd, agents, step.agent, task, step.cwd, signal, (partial) => {
				const partialResults = [...results, { ...partial, label: step.label ?? partial.label }];
				onUpdate?.(makeDetails(workflow, params.task, agentScope, discovery.projectAgentsDir, partialResults));
			}, step.label);
			result.label = step.label ?? result.label;
			results.push(result);
			emit();
			if (isResultError(result)) return makeDetails(workflow, params.task, agentScope, discovery.projectAgentsDir, results);
			previousOutput = getFinalOutput(result.messages);
		}
		return makeDetails(workflow, params.task, agentScope, discovery.projectAgentsDir, results);
	}

	if (workflow === "compare") {
		const task = params.task ?? "";
		const synthesizer = params.synthesizer ?? "synthesizer";
		const parallelTasks = [
			{ agent: "opus", task, label: "Opus" },
			{ agent: "gpt", task, label: "GPT" },
		];
		const parallelResults: SingleResult[] = new Array(parallelTasks.length);
		await mapWithConcurrencyLimit(parallelTasks, 2, async (entry, index) => {
			const result = await runSingleAgent(ctx.cwd, agents, entry.agent, entry.task, undefined, signal, (partial) => {
				parallelResults[index] = { ...partial, label: entry.label };
				onUpdate?.(
					makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, parallelResults.filter(Boolean) as SingleResult[]),
				);
			}, entry.label);
			result.label = entry.label;
			parallelResults[index] = result;
			onUpdate?.(makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, parallelResults.filter(Boolean) as SingleResult[]));
			return result;
		});
		results.push(...parallelResults.filter(Boolean));
		if (results.some(isResultError)) return makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, results);

		const opusOutput = getFinalOutput(results[0]?.messages ?? []);
		const gptOutput = getFinalOutput(results[1]?.messages ?? []);
		const synthesis = await runSingleAgent(
			ctx.cwd,
			agents,
			synthesizer,
			buildCompareSynthesisTask(task, opusOutput, gptOutput),
			undefined,
			signal,
			(partial) => onUpdate?.(makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, [...results, { ...partial, label: "Synthesis" }])),
			"Synthesis",
		);
		synthesis.label = "Synthesis";
		results.push(synthesis);
		return makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, results);
	}

	if (workflow === "debate") {
		const task = params.task ?? "";
		const proposer = params.proposer ?? "opus";
		const critic = params.critic ?? "gpt";
		const synthesizer = params.synthesizer ?? "synthesizer";

		const proposal = await runSingleAgent(ctx.cwd, agents, proposer, buildDebateProposalTask(task), undefined, signal, (partial) => {
			onUpdate?.(makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, [{ ...partial, label: "Proposal" }]));
		}, "Proposal");
		proposal.label = "Proposal";
		results.push(proposal);
		emit();
		if (isResultError(proposal)) return makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, results);

		const critique = await runSingleAgent(
			ctx.cwd,
			agents,
			critic,
			buildDebateCritiqueTask(task, getFinalOutput(proposal.messages)),
			undefined,
			signal,
			(partial) => onUpdate?.(makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, [...results, { ...partial, label: "Critique" }])),
			"Critique",
		);
		critique.label = "Critique";
		results.push(critique);
		emit();
		if (isResultError(critique)) return makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, results);

		const revision = await runSingleAgent(
			ctx.cwd,
			agents,
			proposer,
			buildDebateRevisionTask(task, getFinalOutput(proposal.messages), getFinalOutput(critique.messages)),
			undefined,
			signal,
			(partial) => onUpdate?.(makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, [...results, { ...partial, label: "Revision" }])),
			"Revision",
		);
		revision.label = "Revision";
		results.push(revision);
		emit();
		if (isResultError(revision)) return makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, results);

		const synthesis = await runSingleAgent(
			ctx.cwd,
			agents,
			synthesizer,
			buildDebateSynthesisTask(task, getFinalOutput(proposal.messages), getFinalOutput(critique.messages), getFinalOutput(revision.messages)),
			undefined,
			signal,
			(partial) => onUpdate?.(makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, [...results, { ...partial, label: "Synthesis" }])),
			"Synthesis",
		);
		synthesis.label = "Synthesis";
		results.push(synthesis);
		return makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, results);
	}

	const task = params.task ?? "";
	const implementer = params.implementer ?? "gpt";
	const reviewer = params.reviewer ?? "reviewer";

	const implementation = await runSingleAgent(ctx.cwd, agents, implementer, buildImplementationTask(task), undefined, signal, (partial) => {
		onUpdate?.(makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, [{ ...partial, label: "Implementation" }]));
	}, "Implementation");
	implementation.label = "Implementation";
	results.push(implementation);
	emit();
	if (isResultError(implementation)) return makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, results);

	const review = await runSingleAgent(
		ctx.cwd,
		agents,
		reviewer,
		buildReviewTask(task, getFinalOutput(implementation.messages)),
		undefined,
		signal,
		(partial) => onUpdate?.(makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, [...results, { ...partial, label: "Review" }])),
		"Review",
	);
	review.label = "Review";
	results.push(review);
	emit();
	if (isResultError(review)) return makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, results);

	const applied = await runSingleAgent(
		ctx.cwd,
		agents,
		implementer,
		buildApplyReviewTask(task, getFinalOutput(implementation.messages), getFinalOutput(review.messages)),
		undefined,
		signal,
		(partial) => onUpdate?.(makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, [...results, { ...partial, label: "Apply review" }])),
		"Apply review",
	);
	applied.label = "Apply review";
	results.push(applied);
	return makeDetails(workflow, task, agentScope, discovery.projectAgentsDir, results);
}

function getRequestedAgents(params: ToolParams): string[] {
	const requested = new Set<string>();
	if (params.agent) requested.add(params.agent);
	if (params.tasks) for (const task of params.tasks) requested.add(task.agent);
	if (params.chain) for (const step of params.chain) requested.add(step.agent);
	if (params.workflow === "compare") {
		requested.add("opus");
		requested.add("gpt");
		requested.add(params.synthesizer ?? "synthesizer");
	}
	if (params.workflow === "debate") {
		requested.add(params.proposer ?? "opus");
		requested.add(params.critic ?? "gpt");
		requested.add(params.synthesizer ?? "synthesizer");
	}
	if (params.workflow === "implement_with_review") {
		requested.add(params.implementer ?? "gpt");
		requested.add(params.reviewer ?? "reviewer");
	}
	return Array.from(requested);
}

function getFinalWorkflowText(details: WorkflowDetails): string {
	const last = details.results[details.results.length - 1];
	if (!last) return "(no output)";
	return getFinalOutput(last.messages) || last.errorMessage || last.stderr || "(no output)";
}

async function runWorkflowCommand(
	pi: ExtensionAPI,
	ctx: ExtensionCommandContext,
	label: string,
	params: ToolParams,
): Promise<void> {
	await ctx.waitForIdle();
	const agentScope = params.agentScope ?? DEFAULT_AGENT_SCOPE;
	const discovery = discoverAgents(ctx.cwd, agentScope);
	const agents = discovery.agents;
	const requestedAgents = getRequestedAgents(params);
	const confirmed = await confirmProjectAgentsIfNeeded(
		ctx,
		agents,
		discovery,
		requestedAgents,
		params.confirmProjectAgents ?? true,
	);
	if (!confirmed) {
		ctx.ui.notify("Canceled", "info");
		return;
	}

	const execute = async (signal?: AbortSignal) => executeWorkflow(ctx, agents, discovery, params, signal);
	let details: WorkflowDetails | null = null;

	if (ctx.hasUI) {
		details = await ctx.ui.custom<WorkflowDetails | null>((tui, theme, _kb, done) => {
			const loader = new BorderedLoader(tui, theme, label);
			loader.onAbort = () => done(null);
			execute(loader.signal)
				.then(done)
				.catch((error) => {
					const failed = makeDetails(params.workflow ?? "single", params.task, agentScope, discovery.projectAgentsDir, [
						{
							agent: "workflow",
							agentSource: "unknown",
							task: params.task ?? "",
							exitCode: 1,
							messages: [],
							stderr: String(error),
							usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
							errorMessage: error instanceof Error ? error.message : String(error),
						},
					]);
					done(failed);
				});
			return loader;
		});
	} else {
		details = await execute();
	}

	if (!details) {
		ctx.ui.notify("Canceled", "info");
		return;
	}

	pi.sendMessage({
		customType: MESSAGE_TYPE,
		content: getFinalWorkflowText(details),
		display: true,
		details,
	});
}

async function buildSessionChain(sessionFile: string | undefined): Promise<string[]> {
	if (!sessionFile) return [];
	const chain: string[] = [sessionFile];
	let current = sessionFile;
	while (true) {
		try {
			const firstLine = fs.readFileSync(current, "utf-8").split("\n")[0];
			const header = JSON.parse(firstLine);
			const parentSession = header?.parentSession as string | undefined;
			if (!parentSession) break;
			chain.push(parentSession);
			current = parentSession;
		} catch {
			break;
		}
	}
	return chain;
}

async function generateHandoffPrompt(target: "opus" | "gpt", goal: string, ctx: ExtensionCommandContext): Promise<string | null> {
	const branch = ctx.sessionManager.getBranch();
	const messages = branch
		.filter((entry): entry is SessionEntry & { type: "message" } => entry.type === "message")
		.map((entry) => entry.message);
	if (messages.length === 0) return null;

	const llmMessages = convertToLlm(messages);
	const conversationText = serializeConversation(llmMessages);
	const targetModel =
		target === "opus"
			? ctx.modelRegistry.find("anthropic", "claude-opus-4-7")
			: ctx.modelRegistry.find("openai-codex", "gpt-5.5");
	const model = targetModel;
	if (!model) throw new Error(`Could not resolve ${target} model`);

	const apiKey = await ctx.modelRegistry.getApiKey(model);
	if (!apiKey) throw new Error(`No API key configured for ${model.provider}/${model.id}`);

	const response = await complete(
		model,
		{
			systemPrompt: `${HANDOFF_PROMPT}\n\nThe target model for the new thread is ${target}. Tailor the task wording accordingly.`,
			messages: [
				{
					role: "user",
					content: [
						{
							type: "text",
							text: `## Conversation History\n\n${conversationText}\n\n## Goal for the new ${target.toUpperCase()} thread\n\n${goal}`,
						},
					],
					timestamp: Date.now(),
				},
			],
		},
		{ apiKey },
	);

	if (response.stopReason === "aborted") return null;
	if (response.stopReason === "error") throw new Error(response.errorMessage || "Handoff generation failed");

	return response.content
		.filter((part): part is { type: "text"; text: string } => part.type === "text")
		.map((part) => part.text)
		.join("\n")
		.trim();
}

async function runHandoffCommand(pi: ExtensionAPI, ctx: ExtensionCommandContext, target: "opus" | "gpt", goal: string): Promise<void> {
	await ctx.waitForIdle();
	if (!goal.trim()) {
		ctx.ui.notify(`Usage: /handoff-to-${target} <goal for new thread>`, "error");
		return;
	}
	if (!ctx.hasUI) {
		ctx.ui.notify(`handoff-to-${target} requires interactive mode`, "error");
		return;
	}

	const result = await ctx.ui.custom<string | null>((tui, theme, _kb, done) => {
		const loader = new BorderedLoader(tui, theme, `Generating handoff for ${target}...`);
		loader.onAbort = () => done(null);
		generateHandoffPrompt(target, goal, ctx)
			.then(done)
			.catch((error) => {
				console.error(error);
				done(`__ERROR__:${error instanceof Error ? error.message : String(error)}`);
			});
		return loader;
	});

	if (result === null) {
		ctx.ui.notify("Canceled", "info");
		return;
	}

	if (result.startsWith("__ERROR__:")) {
		ctx.ui.notify(result.replace("__ERROR__:", ""), "error");
		return;
	}

	const sessionChain = await buildSessionChain(ctx.sessionManager.getSessionFile());
	const historySection = sessionChain.length
		? `\n\n## Session History\nPrevious sessions (most recent first):\n${sessionChain.map((file, index) => `${index + 1}. ${file}`).join("\n")}`
		: "";
	const promptWithHistory = `${result}${historySection}`;
	const editedPrompt = await ctx.ui.editor(`Edit handoff for ${target}`, promptWithHistory);
	if (editedPrompt === undefined) {
		ctx.ui.notify("Canceled", "info");
		return;
	}

	const newSessionResult = await ctx.newSession({ parentSession: ctx.sessionManager.getSessionFile() });
	if (newSessionResult.cancelled) {
		ctx.ui.notify("New session canceled", "info");
		return;
	}

	const model =
		target === "opus"
			? ctx.modelRegistry.find("anthropic", "claude-opus-4-7")
			: ctx.modelRegistry.find("openai-codex", "gpt-5.5");
	if (model) {
		const switched = await pi.setModel(model);
		if (!switched) {
			ctx.ui.notify(`Could not switch to ${target}`, "warning");
		}
	}

	ctx.ui.setEditorText(editedPrompt);
	ctx.ui.notify(`Handoff ready for ${target}. Submit when ready.`, "info");
}

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: TOOL_NAME,
		label: "Model Workflow",
		description:
			"Delegate tasks to named model agents (opus, gpt, synthesizer, reviewer) with isolated context. Supports single, parallel, chain, compare, debate, and implement_with_review workflows.",
		promptSnippet: "Delegate work to named model agents with isolated context and compare or debate their answers.",
		promptGuidelines: [
			"Use this tool when the user explicitly wants a second model opinion, a comparison between Opus and GPT, or a debate/synthesis workflow.",
			"Use the canned workflows compare, debate, and implement_with_review when they fit instead of manually recreating them.",
		],
		parameters: ParamsSchema,
		async execute(_toolCallId, params: ToolParams, signal, onUpdate, ctx) {
			const agentScope = params.agentScope ?? DEFAULT_AGENT_SCOPE;
			const discovery = discoverAgents(ctx.cwd, agentScope);
			const agents = discovery.agents;
			const requestedAgents = getRequestedAgents(params);
			const confirmed = await confirmProjectAgentsIfNeeded(
				ctx,
				agents,
				discovery,
				requestedAgents,
				params.confirmProjectAgents ?? true,
			);
			if (!confirmed) {
				return {
					content: [{ type: "text", text: "Canceled." }],
					details: makeDetails(params.workflow ?? "single", params.task, agentScope, discovery.projectAgentsDir, []),
				};
			}

			const details = await executeWorkflow(ctx, agents, discovery, params, signal, (nextDetails) => {
				onUpdate?.({
					content: [{ type: "text", text: getFinalWorkflowText(nextDetails) }],
					details: nextDetails,
				});
			});
			return {
				content: [{ type: "text", text: getFinalWorkflowText(details) }],
				details,
			};
		},
		renderCall(args: ToolParams, theme) {
			const workflow = args.workflow ?? (args.chain?.length ? "chain" : args.tasks?.length ? "parallel" : "single");
			if (workflow === "single") {
				const agent = args.agent ?? "...";
				const preview = args.task ? (args.task.length > 60 ? `${args.task.slice(0, 60)}...` : args.task) : "...";
				return new Text(`${theme.fg("toolTitle", theme.bold(`${TOOL_NAME} `))}${theme.fg("accent", agent)}\n  ${theme.fg("dim", preview)}`, 0, 0);
			}
			if (workflow === "parallel") {
				return new Text(
					`${theme.fg("toolTitle", theme.bold(`${TOOL_NAME} `))}${theme.fg("accent", `parallel (${args.tasks?.length ?? 0})`)}`,
					0,
					0,
				);
			}
			return new Text(
				`${theme.fg("toolTitle", theme.bold(`${TOOL_NAME} `))}${theme.fg("accent", workflow.replace(/_/g, " "))}${args.task ? theme.fg("dim", ` — ${args.task}`) : ""}`,
				0,
				0,
			);
		},
		renderResult(result, { expanded }, theme) {
			const details = result.details as WorkflowDetails | undefined;
			if (!details) return new Text(result.content[0]?.type === "text" ? result.content[0].text : "(no output)", 0, 0);
			return renderWorkflowDetails(details, expanded, theme);
		},
	});

	pi.registerMessageRenderer(MESSAGE_TYPE, (message, { expanded }, theme) => {
		const box = new Box(1, 1, (text) => theme.bg("customMessageBg", text));
		const details = message.details as WorkflowDetails | undefined;
		if (!details) {
			box.addChild(new Text(message.content, 0, 0));
			return box;
		}
		box.addChild(renderWorkflowDetails(details, expanded, theme));
		return box;
	});

	pi.registerCommand("ask-opus", {
		description: "Ask Opus 4.7 in an isolated sub-session",
		handler: async (args, ctx) => {
			if (!args.trim()) {
				ctx.ui.notify("Usage: /ask-opus <task>", "error");
				return;
			}
			await runWorkflowCommand(pi, ctx, "Asking Opus...", { workflow: "single", agent: "opus", task: args.trim() });
		},
	});

	pi.registerCommand("ask-gpt", {
		description: "Ask GPT 5.5 Codex in an isolated sub-session",
		handler: async (args, ctx) => {
			if (!args.trim()) {
				ctx.ui.notify("Usage: /ask-gpt <task>", "error");
				return;
			}
			await runWorkflowCommand(pi, ctx, "Asking GPT...", { workflow: "single", agent: "gpt", task: args.trim() });
		},
	});

	pi.registerCommand("compare-models", {
		description: "Ask Opus and GPT in parallel, then synthesize",
		handler: async (args, ctx) => {
			if (!args.trim()) {
				ctx.ui.notify("Usage: /compare-models <task>", "error");
				return;
			}
			await runWorkflowCommand(pi, ctx, "Comparing models...", { workflow: "compare", task: args.trim() });
		},
	});

	pi.registerCommand("debate-models", {
		description: "Have Opus and GPT debate a question, then synthesize",
		handler: async (args, ctx) => {
			if (!args.trim()) {
				ctx.ui.notify("Usage: /debate-models <task>", "error");
				return;
			}
			await runWorkflowCommand(pi, ctx, "Debating models...", { workflow: "debate", task: args.trim() });
		},
	});

	pi.registerCommand("handoff-to-opus", {
		description: "Create a fresh session and hand off the thread to Opus 4.7",
		handler: async (args, ctx) => runHandoffCommand(pi, ctx, "opus", args.trim()),
	});

	pi.registerCommand("handoff-to-gpt", {
		description: "Create a fresh session and hand off the thread to GPT 5.5 Codex",
		handler: async (args, ctx) => runHandoffCommand(pi, ctx, "gpt", args.trim()),
	});
}
