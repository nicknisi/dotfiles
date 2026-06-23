// Keep Pi types local so this extension can typecheck and run even when the
// globally-installed Pi package is not resolvable from this extension folder.
type ExtensionAPI = any;
type ExtensionContext = any;
type ExtensionCommandContext = any;

import { Type } from "typebox";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import { SSEClientTransport } from "@modelcontextprotocol/sdk/client/sse.js";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { homedir } from "node:os";

/**
 * Pi MCP bridge.
 *
 * Stolen shamelessly from OMP's good ideas, but kept Pi-native:
 * - mcp.json discovery
 * - mcp__<server>_<tool> tool names
 * - stdio + streamable HTTP + SSE transports
 * - /mcp management command
 * - resource/prompt helper tools
 * - on-demand activation for huge MCP catalogs
 */

type DiscoveryMode = "auto" | "all" | "mcp-only" | "off";
type TransportKind = "stdio" | "http" | "sse" | "streamable-http";

type ServerConfig = {
	type?: TransportKind;
	command?: string;
	args?: string[] | string;
	env?: Record<string, string>;
	cwd?: string;
	url?: string;
	headers?: Record<string, string>;
	timeoutMs?: number;
	disabled?: boolean;
	oauth?: unknown;
	auth?: unknown;
};

type McpConfigFile = {
	$schema?: string;
	discoveryMode?: DiscoveryMode;
	disabledServers?: string[];
	/** Explicit opt-in imports. Paths may use ~, ${VAR}, or be relative to the config file. */
	importConfigs?: string[];
	mcpServers?: Record<string, ServerConfig>;
	servers?: Record<string, ServerConfig>;
};

type DiscoveredServer = {
	name: string;
	config: ServerConfig;
	source: string;
	priority: number;
	disabled: boolean;
};

type ServerRuntime = {
	name: string;
	config: ServerConfig;
	source: string;
	client: Client;
	transport: StdioClientTransport | StreamableHTTPClientTransport | SSEClientTransport;
	tools: McpToolRuntime[];
	stderr: string[];
	status: "connected" | "failed" | "closed";
	error?: string;
};

type McpToolRuntime = {
	serverName: string;
	mcpName: string;
	piName: string;
	description?: string;
	inputSchema: Record<string, unknown>;
	annotations?: Record<string, unknown>;
};

type BridgeState = {
	loaded: boolean;
	loading?: Promise<void>;
	discoveryMode: DiscoveryMode;
	servers: Map<string, ServerRuntime>;
	serverConfigs: Map<string, DiscoveredServer>;
	tools: Map<string, McpToolRuntime>;
	registeredToolNames: Set<string>;
	inactiveMcpToolNames: Set<string>;
	errors: Map<string, string>;
	disabledServers: Set<string>;
	sources: string[];
};

const USER_CONFIG_PATH = join(homedir(), ".pi", "agent", "mcp.json");
const SCHEMA_URL = "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json";
const CLIENT_INFO = { name: "pi-mcp-bridge", version: "0.1.0" };
const TOOL_ACTIVATION_THRESHOLD = 40;

const JSON_VALUE = Type.Any({ description: "JSON value" });
const SERVER_ARG = Type.Optional(Type.String({ description: "MCP server name. Omit to include all servers." }));

function makeInitialState(): BridgeState {
	return {
		loaded: false,
		discoveryMode: "auto",
		servers: new Map(),
		serverConfigs: new Map(),
		tools: new Map(),
		registeredToolNames: new Set(),
		inactiveMcpToolNames: new Set(),
		errors: new Map(),
		disabledServers: new Set(),
		sources: [],
	};
}

const state = makeInitialState();

function stripJsonComments(input: string): string {
	// Good enough for JSONC-ish MCP configs without pulling in another parser.
	return input
		.replace(/\/\*[\s\S]*?\*\//g, "")
		.replace(/(^|[^:])\/\/.*$/gm, "$1");
}

function readJsonFile(path: string): McpConfigFile | undefined {
	if (!existsSync(path)) return undefined;
	try {
		return JSON.parse(stripJsonComments(readFileSync(path, "utf8")));
	} catch (error) {
		state.errors.set(path, `Failed to parse ${path}: ${error instanceof Error ? error.message : String(error)}`);
		return undefined;
	}
}

function ensureUserConfig(): McpConfigFile {
	const existing = readJsonFile(USER_CONFIG_PATH);
	if (existing) return existing;
	mkdirSync(dirname(USER_CONFIG_PATH), { recursive: true });
	const initial: McpConfigFile = {
		$schema: SCHEMA_URL,
		discoveryMode: "auto",
		disabledServers: [],
		mcpServers: {},
	};
	writeFileSync(USER_CONFIG_PATH, `${JSON.stringify(initial, null, 2)}\n`);
	return initial;
}

function writeUserConfig(config: McpConfigFile) {
	mkdirSync(dirname(USER_CONFIG_PATH), { recursive: true });
	config.$schema ??= SCHEMA_URL;
	config.discoveryMode ??= "auto";
	config.disabledServers ??= [];
	config.mcpServers ??= {};
	writeFileSync(USER_CONFIG_PATH, `${JSON.stringify(config, null, 2)}\n`);
}

function findGitRoot(start: string): string | undefined {
	let dir = resolve(start);
	while (true) {
		if (existsSync(join(dir, ".git"))) return dir;
		const parent = dirname(dir);
		if (parent === dir || dir === homedir()) return undefined;
		dir = parent;
	}
}

function unique<T>(values: T[]): T[] {
	return [...new Set(values)];
}

function candidateConfigFiles(): Array<{ path: string; priority: number }> {
	const cwd = process.cwd();
	const gitRoot = findGitRoot(cwd);
	const roots = unique([cwd, gitRoot].filter(Boolean) as string[]);
	const projectFiles = roots.flatMap((root) => [
		// Lowest priority standalone/editor configs.
		{ path: join(root, "mcp.json"), priority: 10 },
		{ path: join(root, ".mcp.json"), priority: 10 },
		{ path: join(root, ".claude", "mcp.json"), priority: 20 },
		{ path: join(root, ".cursor", "mcp.json"), priority: 20 },
		{ path: join(root, ".vscode", "mcp.json"), priority: 20 },
		{ path: join(root, ".gemini", "mcp.json"), priority: 20 },
		{ path: join(root, ".gemini", "settings.json"), priority: 20 },
		{ path: join(root, ".windsurf", "mcp.json"), priority: 20 },
		{ path: join(root, ".windsurf", "mcp_config.json"), priority: 20 },
		{ path: join(root, "opencode.json"), priority: 20 },
		// Project-managed Pi config shadows everything else.
		{ path: join(root, ".pi", "mcp.json"), priority: 100 },
	]);

	return [
		...projectFiles,
		// Deliberately do not auto-import global editor configs like ~/.cursor/mcp.json.
		// That is too surprising for a Pi extension; copy wanted servers into ~/.pi/agent/mcp.json instead.
		{ path: USER_CONFIG_PATH, priority: 50 },
	];
}

function normalizeServers(config: McpConfigFile): Record<string, ServerConfig> {
	return config.mcpServers ?? config.servers ?? {};
}

function resolveConfigImport(specifier: string, fromFile: string): string {
	const expanded = expandString(specifier);
	return expanded.startsWith("/") ? expanded : resolve(dirname(fromFile), expanded);
}

function discoverFromConfigFile(
	path: string,
	priority: number,
	discovered: DiscoveredServer[],
	seen: Set<string>,
	isImport = false,
) {
	const resolvedPath = resolveConfigImport(path, process.cwd());
	if (seen.has(resolvedPath)) return;
	seen.add(resolvedPath);

	const config = readJsonFile(resolvedPath);
	if (!config) return;
	state.sources.push(isImport ? `${resolvedPath} (imported)` : resolvedPath);
	if (!isImport && config.discoveryMode) state.discoveryMode = config.discoveryMode;
	for (const name of config.disabledServers ?? []) state.disabledServers.add(name);

	// Imports are loaded just below the importing file's priority, so the importer
	// can explicitly override anything it pulls in.
	for (const imported of config.importConfigs ?? []) {
		discoverFromConfigFile(resolveConfigImport(imported, resolvedPath), priority - 0.5, discovered, seen, true);
	}

	for (const [name, serverConfig] of Object.entries(normalizeServers(config))) {
		discovered.push({
			name,
			config: serverConfig,
			source: resolvedPath,
			priority,
			disabled: Boolean(serverConfig.disabled),
		});
	}
}

function discoverConfigs() {
	state.serverConfigs.clear();
	state.disabledServers.clear();
	state.sources = [];
	state.discoveryMode = "auto";

	const discovered: DiscoveredServer[] = [];
	const seen = new Set<string>();
	for (const candidate of candidateConfigFiles()) {
		discoverFromConfigFile(candidate.path, candidate.priority, discovered, seen);
	}

	for (const server of discovered.sort((a, b) => a.priority - b.priority)) {
		state.serverConfigs.set(server.name, server);
	}
}

function expandString(value: string): string {
	const withHome = value.startsWith("~/") ? join(homedir(), value.slice(2)) : value;
	return withHome.replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)(?::-([^}]*))?\}/g, (_match, name: string, fallback: string | undefined) => {
		return process.env[name] ?? fallback ?? "";
	});
}

function expandValue<T>(value: T): T {
	if (typeof value === "string") return expandString(value) as T;
	if (Array.isArray(value)) return value.map((item) => expandValue(item)) as T;
	if (value && typeof value === "object") {
		return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, expandValue(item)])) as T;
	}
	return value;
}

function normalizeArgs(args: string[] | string | undefined): string[] {
	if (!args) return [];
	if (Array.isArray(args)) return args.map(String);
	return args.trim() ? [args] : [];
}

function sanitizePart(input: string): string {
	const sanitized = input
		.trim()
		.toLowerCase()
		.replace(/[^a-z0-9_]+/g, "_")
		.replace(/_+/g, "_")
		.replace(/^_+|_+$/g, "");
	return sanitized || "unnamed";
}

function toolNameFor(serverName: string, mcpToolName: string, used: Set<string>): string {
	const server = sanitizePart(serverName);
	let tool = sanitizePart(mcpToolName);
	if (tool.startsWith(`${server}_`)) tool = tool.slice(server.length + 1);
	let candidate = `mcp__${server}_${tool}`;
	let suffix = 2;
	while (used.has(candidate)) candidate = `mcp__${server}_${tool}_${suffix++}`;
	used.add(candidate);
	return candidate;
}

function headersFrom(config: ServerConfig): Record<string, string> {
	return Object.fromEntries(Object.entries(expandValue(config.headers ?? {})).map(([key, value]) => [key, String(value)]));
}

function appendStderr(runtime: Pick<ServerRuntime, "stderr">, chunk: Buffer | string) {
	const text = String(chunk);
	for (const line of text.split(/\r?\n/).filter(Boolean)) {
		runtime.stderr.push(line);
		if (runtime.stderr.length > 40) runtime.stderr.shift();
	}
}

function createTransport(configInput: ServerConfig, runtime: Pick<ServerRuntime, "stderr">) {
	const config = expandValue(configInput);
	if (config.command) {
		const transport = new StdioClientTransport({
			command: config.command,
			args: normalizeArgs(config.args).map(expandString),
			cwd: config.cwd ? expandString(config.cwd) : undefined,
			env: Object.fromEntries(
				Object.entries({ ...process.env, ...(expandValue(config.env ?? {}) as Record<string, string>) }).filter(
					(entry): entry is [string, string] => typeof entry[1] === "string",
				),
			),
			stderr: "pipe",
		});
		transport.stderr?.on("data", (chunk) => appendStderr(runtime, chunk));
		return transport;
	}

	if (config.url) {
		const url = new URL(expandString(config.url));
		const headers = headersFrom(config);
		const type = config.type ?? (url.pathname.endsWith("/sse") ? "sse" : "http");
		if (type === "sse") {
			return new SSEClientTransport(url, {
				requestInit: { headers },
				eventSourceInit: {
					// eventsource's init accepts a custom fetch; use it to attach headers to the stream request too.
					fetch: (input: unknown, init: Record<string, unknown> = {}) =>
						fetch(input as RequestInfo | URL, {
							...(init as RequestInit),
							headers: { ...((init as RequestInit).headers as Record<string, string> | undefined), ...headers },
						}),
				} as any,
			});
		}
		return new StreamableHTTPClientTransport(url, { requestInit: { headers } });
	}

	throw new Error("MCP server config must include either command or url");
}

async function listAllTools(client: Client, signal?: AbortSignal, timeout = 20_000) {
	const tools: Awaited<ReturnType<Client["listTools"]>>["tools"] = [];
	let cursor: string | undefined;
	do {
		const page = await client.listTools(cursor ? { cursor } : undefined, { signal, timeout });
		tools.push(...page.tools);
		cursor = page.nextCursor;
	} while (cursor);
	return tools;
}

async function connectServer(server: DiscoveredServer, signal?: AbortSignal): Promise<ServerRuntime> {
	const runtime: ServerRuntime = {
		name: server.name,
		config: server.config,
		source: server.source,
		client: new Client(CLIENT_INFO, { capabilities: {} }),
		transport: undefined as unknown as ServerRuntime["transport"],
		tools: [],
		stderr: [],
		status: "connected",
	};

	runtime.transport = createTransport(server.config, runtime);
	await runtime.client.connect(runtime.transport, { signal, timeout: server.config.timeoutMs ?? 20_000 });

	const tools = await listAllTools(runtime.client, signal, server.config.timeoutMs ?? 20_000);
	const usedNames = new Set([...state.registeredToolNames, ...state.tools.keys()]);
	runtime.tools = tools.map((tool) => ({
		serverName: server.name,
		mcpName: tool.name,
		piName: toolNameFor(server.name, tool.name, usedNames),
		description: tool.description ?? tool.title,
		inputSchema: tool.inputSchema as Record<string, unknown>,
		annotations: tool.annotations as Record<string, unknown> | undefined,
	}));

	return runtime;
}

function formatMcpContent(result: unknown): string {
	if (!result || typeof result !== "object") return JSON.stringify(result, null, 2);
	const value = result as Record<string, unknown>;
	if ("toolResult" in value) return JSON.stringify(value.toolResult, null, 2);

	const parts: string[] = [];
	if (value.isError) parts.push("MCP tool returned an error.");
	if (Array.isArray(value.content)) {
		for (const item of value.content as Array<Record<string, unknown>>) {
			if (item.type === "text") parts.push(String(item.text ?? ""));
			else if (item.type === "image") parts.push(`[image: ${item.mimeType ?? "unknown mime"}, base64 ${String(item.data ?? "").length} chars]`);
			else if (item.type === "audio") parts.push(`[audio: ${item.mimeType ?? "unknown mime"}, base64 ${String(item.data ?? "").length} chars]`);
			else if (item.type === "resource") parts.push(`[resource]\n${JSON.stringify(item.resource, null, 2)}`);
			else if (item.type === "resource_link") parts.push(`[resource link] ${item.name ?? item.uri}: ${item.uri}`);
			else parts.push(JSON.stringify(item, null, 2));
		}
	}
	if (value.structuredContent) {
		parts.push(`Structured content:\n${JSON.stringify(value.structuredContent, null, 2)}`);
	}
	return parts.filter(Boolean).join("\n\n") || JSON.stringify(result, null, 2);
}

function scoreTool(tool: McpToolRuntime, query: string): number {
	const haystack = `${tool.piName} ${tool.serverName} ${tool.mcpName} ${tool.description ?? ""}`.toLowerCase();
	const terms = query.toLowerCase().split(/\s+/).filter(Boolean);
	if (terms.length === 0) return 1;
	let score = 0;
	for (const term of terms) {
		if (tool.piName.toLowerCase().includes(term)) score += 5;
		if (tool.mcpName.toLowerCase().includes(term)) score += 4;
		if (tool.serverName.toLowerCase().includes(term)) score += 2;
		if (haystack.includes(term)) score += 1;
	}
	return score;
}

function applyDiscoveryMode(pi: ExtensionAPI) {
	const mcpToolNames = [...state.tools.keys()];
	const shouldGate =
		state.discoveryMode === "mcp-only" ||
		(state.discoveryMode === "auto" && mcpToolNames.length > TOOL_ACTIVATION_THRESHOLD) ||
		state.discoveryMode === "off";

	state.inactiveMcpToolNames = new Set(shouldGate ? mcpToolNames : []);
	if (!shouldGate) return;

	const active = new Set(pi.getActiveTools());
	for (const name of mcpToolNames) active.delete(name);
	// Keep bridge/discovery tools active.
	for (const name of ["mcp_search_tools", "mcp_list_resources", "mcp_read_resource", "mcp_list_prompts", "mcp_get_prompt"]) {
		active.add(name);
	}
	pi.setActiveTools([...active]);
}

function activateTools(pi: ExtensionAPI, names: string[]) {
	if (state.discoveryMode === "off") return;
	const active = new Set(pi.getActiveTools());
	for (const name of names) {
		if (state.tools.has(name)) {
			active.add(name);
			state.inactiveMcpToolNames.delete(name);
		}
	}
	pi.setActiveTools([...active]);
}

function registerMcpTool(pi: ExtensionAPI, tool: McpToolRuntime) {
	if (state.registeredToolNames.has(tool.piName)) return;
	state.registeredToolNames.add(tool.piName);
	const readOnly = tool.annotations?.readOnlyHint === true ? " Read-only." : "";
	const destructive = tool.annotations?.destructiveHint === true ? " May perform destructive changes." : "";

	pi.registerTool({
		name: tool.piName,
		label: `MCP ${tool.serverName}/${tool.mcpName}`,
		description: `[MCP:${tool.serverName}] ${tool.description ?? tool.mcpName}.${readOnly}${destructive}`,
		promptSnippet: `Call MCP tool ${tool.serverName}/${tool.mcpName}`,
		parameters: (tool.inputSchema?.type ? tool.inputSchema : { type: "object", properties: {} }) as never,
		async execute(_toolCallId: string, params: Record<string, unknown>, signal: AbortSignal, onUpdate?: (update: unknown) => void) {
			const current = state.tools.get(tool.piName);
			if (!current) throw new Error(`MCP tool is no longer available: ${tool.piName}. Run /mcp reload or /reload.`);
			const server = state.servers.get(current.serverName);
			if (!server || server.status !== "connected") throw new Error(`MCP server is not connected: ${current.serverName}`);
			onUpdate?.({ content: [{ type: "text", text: `Calling MCP ${current.serverName}/${current.mcpName}…` }] });
			const result = await server.client.callTool(
				{ name: current.mcpName, arguments: params as Record<string, unknown> },
				undefined,
				{
					signal,
					timeout: server.config.timeoutMs ?? 60_000,
					onprogress: (progress) => {
						onUpdate?.({ content: [{ type: "text", text: `MCP progress: ${JSON.stringify(progress)}` }] });
					},
				},
			);
			return {
				content: [{ type: "text", text: formatMcpContent(result) }],
				details: { server: current.serverName, tool: current.mcpName, result },
			};
		},
	});
}

async function closeServers() {
	const runtimes = [...state.servers.values()];
	state.servers.clear();
	state.tools.clear();
	for (const runtime of runtimes) {
		runtime.status = "closed";
		try {
			await runtime.transport.close();
		} catch {
			// Best-effort shutdown.
		}
	}
}

async function reloadMcp(pi: ExtensionAPI, ctx?: ExtensionContext | ExtensionCommandContext, signal?: AbortSignal) {
	if (state.loading) return state.loading;
	state.loading = (async () => {
		await closeServers();
		state.loaded = false;
		state.errors.clear();
		discoverConfigs();

		const servers = [...state.serverConfigs.values()].filter(
			(server) => !server.disabled && !state.disabledServers.has(server.name),
		);

		await Promise.all(
			servers.map(async (server) => {
				try {
					const runtime = await connectServer(server, signal);
					state.servers.set(server.name, runtime);
					for (const tool of runtime.tools) {
						state.tools.set(tool.piName, tool);
						registerMcpTool(pi, tool);
					}
				} catch (error) {
					state.errors.set(server.name, error instanceof Error ? error.message : String(error));
				}
			}),
		);

		applyDiscoveryMode(pi);
		state.loaded = true;
		ctx?.ui.setStatus(
			"mcp",
			state.servers.size > 0 || state.errors.size > 0 ? `mcp ${state.servers.size}/${state.serverConfigs.size}` : undefined,
		);
	})();
	try {
		await state.loading;
	} finally {
		state.loading = undefined;
	}
}

async function ensureLoaded(pi: ExtensionAPI, signal?: AbortSignal) {
	if (!state.loaded) await reloadMcp(pi, undefined, signal);
}

function truncateLine(value: string, max = 140): string {
	return value.length <= max ? value : `${value.slice(0, max - 1)}…`;
}

function serverSummary(serverFilter?: string, options: { verbose?: boolean } = {}): string {
	const lines: string[] = [];
	lines.push(`MCP sources: ${state.sources.length ? state.sources.join(", ") : "none"}`);
	lines.push(`Discovery mode: ${state.discoveryMode}`);
	if (state.inactiveMcpToolNames.size) {
		lines.push(`Tool activation: ${state.inactiveMcpToolNames.size} MCP tool(s) gated; use mcp_search_tools to activate matches.`);
	}
	lines.push("");
	if (state.serverConfigs.size === 0) lines.push("No MCP servers configured.");
	for (const [name, server] of state.serverConfigs) {
		if (serverFilter && name !== serverFilter) continue;
		const runtime = state.servers.get(name);
		const disabled = state.disabledServers.has(name) || server.disabled;
		if (disabled) {
			lines.push(`- ${name}: disabled (${server.source})`);
		} else if (runtime) {
			lines.push(`- ${name}: connected, ${runtime.tools.length} tools (${server.source})`);
			for (const tool of runtime.tools.sort((a, b) => a.piName.localeCompare(b.piName))) {
				const gated = state.inactiveMcpToolNames.has(tool.piName) ? " [gated]" : "";
				const description = options.verbose && tool.description ? ` — ${truncateLine(tool.description)}` : "";
				lines.push(`  - ${tool.piName}${gated}${description}`);
			}
		} else {
			lines.push(`- ${name}: failed (${server.source}) ${state.errors.get(name) ?? ""}`);
		}
	}
	const matchingErrors = [...state.errors].filter(([where]) => !serverFilter || where === serverFilter);
	if (matchingErrors.length) {
		lines.push("", "Errors:");
		for (const [where, error] of matchingErrors) lines.push(`- ${where}: ${error}`);
	}
	if (!options.verbose) lines.push("", "Tip: use `/mcp list --verbose` to include descriptions.");
	return lines.join("\n");
}

function postCommandResult(pi: ExtensionAPI, ctx: ExtensionCommandContext, text: string) {
	const hasErrors = text.includes("\nErrors:\n");
	ctx.ui.notify(hasErrors ? "MCP result shown; one or more servers reported errors." : "MCP result shown.", hasErrors ? "warning" : "info");
	// No deliverAs: "nextTurn" here — slash command output should render immediately,
	// not wait until the user's next message.
	pi.sendMessage({ customType: "mcp", content: text, display: true, details: { kind: "mcp-command" } });
}

function parseJsonTail(input: string): { head: string[]; json?: unknown; error?: string } {
	const trimmed = input.trim();
	const jsonStart = trimmed.indexOf("{");
	if (jsonStart === -1) return { head: trimmed.split(/\s+/).filter(Boolean) };
	try {
		return {
			head: trimmed.slice(0, jsonStart).trim().split(/\s+/).filter(Boolean),
			json: JSON.parse(trimmed.slice(jsonStart)),
		};
	} catch (error) {
		return { head: trimmed.slice(0, jsonStart).trim().split(/\s+/).filter(Boolean), error: error instanceof Error ? error.message : String(error) };
	}
}

async function handleMcpCommand(pi: ExtensionAPI, args: string, ctx: ExtensionCommandContext) {
	const [subcommand = "list", ...rest] = args.trim().split(/\s+/).filter(Boolean);
	const sub = subcommand.toLowerCase();

	if (["list", "ls", "status", "tools", "describe"].includes(sub)) {
		await ensureLoaded(pi, ctx.signal);
		const verbose = sub === "describe" || rest.includes("--verbose") || rest.includes("-v");
		const serverFilter = rest.find((part) => part !== "--verbose" && part !== "-v");
		postCommandResult(pi, ctx, serverSummary(serverFilter, { verbose }));
		return;
	}

	if (sub === "reload") {
		await reloadMcp(pi, ctx, ctx.signal);
		postCommandResult(pi, ctx, `Reloaded MCP.\n\n${serverSummary()}`);
		return;
	}

	if (sub === "test") {
		await reloadMcp(pi, ctx, ctx.signal);
		const name = rest[0];
		if (!name) {
			postCommandResult(pi, ctx, serverSummary());
			return;
		}
		const runtime = state.servers.get(name);
		const err = state.errors.get(name);
		postCommandResult(pi, ctx, runtime ? `${name}: connected (${runtime.tools.length} tools)` : `${name}: failed ${err ?? "not configured"}`);
		return;
	}

	if (sub === "resources") {
		await ensureLoaded(pi, ctx.signal);
		const serverFilter = rest[0];
		const lines: string[] = [];
		for (const [name, runtime] of state.servers) {
			if (serverFilter && name !== serverFilter) continue;
			try {
				const page = await runtime.client.listResources(undefined, { signal: ctx.signal, timeout: runtime.config.timeoutMs ?? 20_000 });
				lines.push(`## ${name}`);
				for (const resource of page.resources) lines.push(`- ${resource.name}: ${resource.uri}${resource.description ? ` — ${resource.description}` : ""}`);
			} catch (error) {
				lines.push(`## ${name}\n- resources unavailable: ${error instanceof Error ? error.message : String(error)}`);
			}
		}
		postCommandResult(pi, ctx, lines.join("\n") || "No resources.");
		return;
	}

	if (sub === "prompts") {
		await ensureLoaded(pi, ctx.signal);
		const serverFilter = rest[0];
		const lines: string[] = [];
		for (const [name, runtime] of state.servers) {
			if (serverFilter && name !== serverFilter) continue;
			try {
				const page = await runtime.client.listPrompts(undefined, { signal: ctx.signal, timeout: runtime.config.timeoutMs ?? 20_000 });
				lines.push(`## ${name}`);
				for (const prompt of page.prompts) lines.push(`- ${prompt.name}${prompt.description ? ` — ${prompt.description}` : ""}`);
			} catch (error) {
				lines.push(`## ${name}\n- prompts unavailable: ${error instanceof Error ? error.message : String(error)}`);
			}
		}
		postCommandResult(pi, ctx, lines.join("\n") || "No prompts.");
		return;
	}

	if (["disable", "enable", "remove"].includes(sub)) {
		const name = rest[0];
		if (!name) {
			ctx.ui.notify(`Usage: /mcp ${sub} <server>`, "warning");
			return;
		}
		const config = ensureUserConfig();
		config.disabledServers ??= [];
		config.mcpServers ??= {};
		if (sub === "disable" && !config.disabledServers.includes(name)) config.disabledServers.push(name);
		if (sub === "enable") config.disabledServers = config.disabledServers.filter((item) => item !== name);
		if (sub === "remove") delete config.mcpServers[name];
		writeUserConfig(config);
		await reloadMcp(pi, ctx, ctx.signal);
		postCommandResult(pi, ctx, `${sub}d ${name} in ${USER_CONFIG_PATH}.`);
		return;
	}

	if (sub === "add") {
		const parsed = parseJsonTail(rest.join(" "));
		const name = parsed.head[0];
		if (!name || parsed.error || !parsed.json || typeof parsed.json !== "object") {
			ctx.ui.notify('Usage: /mcp add <name> {"command":"npx","args":["-y","pkg"]}', "warning");
			if (parsed.error) ctx.ui.notify(parsed.error, "error");
			return;
		}
		const config = ensureUserConfig();
		config.mcpServers ??= {};
		config.mcpServers[name] = parsed.json as ServerConfig;
		writeUserConfig(config);
		await reloadMcp(pi, ctx, ctx.signal);
		postCommandResult(pi, ctx, `Added ${name} to ${USER_CONFIG_PATH}.`);
		return;
	}

	if (["reauth", "unauth", "smithery-search", "smithery-login", "smithery-logout"].includes(sub)) {
		ctx.ui.notify(`${sub} is not implemented yet in the Pi MCP bridge. Use env/header auth for now.`, "warning");
		return;
	}

	ctx.ui.notify("Usage: /mcp list [server]|list --verbose|describe [server]|reload|test|resources|prompts|add|remove|enable|disable", "warning");
}

function registerBridgeTools(pi: ExtensionAPI) {
	pi.registerTool({
		name: "mcp_search_tools",
		label: "MCP Search Tools",
		description: "Search configured MCP tools and optionally activate matching tools for this Pi session.",
		promptSnippet: "Search and activate MCP tools by capability before using large MCP catalogs",
		promptGuidelines: [
			"Use mcp_search_tools when the user asks for a capability that may exist in an MCP server but no active MCP tool is visible.",
		],
		parameters: Type.Object({
			query: Type.String({ description: "Capability, integration, or tool name to search for" }),
			limit: Type.Optional(Type.Number({ description: "Maximum matches to return and activate", default: 10 })),
			activate: Type.Optional(Type.Boolean({ description: "Activate returned tools in this session", default: true })),
		}),
		async execute(_id: string, params: { query: string; limit?: number; activate?: boolean }, signal: AbortSignal) {
			await ensureLoaded(pi, signal);
			const limit = Math.max(1, Math.min(Number(params.limit ?? 10), 50));
			const matches = [...state.tools.values()]
				.map((tool) => ({ tool, score: scoreTool(tool, params.query) }))
				.filter((item) => item.score > 0)
				.sort((a, b) => b.score - a.score)
				.slice(0, limit);
			if (params.activate !== false) activateTools(pi, matches.map((match) => match.tool.piName));
			const text = matches.length
				? matches.map(({ tool }) => `- ${tool.piName}: ${tool.description ?? tool.mcpName} (server: ${tool.serverName})`).join("\n")
				: "No MCP tools matched.";
			return { content: [{ type: "text", text }], details: { matches: matches.map((match) => match.tool) } };
		},
	});

	pi.registerTool({
		name: "mcp_list_resources",
		label: "MCP List Resources",
		description: "List resources exposed by configured MCP servers.",
		promptSnippet: "List MCP resources by server",
		parameters: Type.Object({ server: SERVER_ARG }),
		async execute(_id: string, params: { server?: string }, signal: AbortSignal) {
			await ensureLoaded(pi, signal);
			const output: Record<string, unknown> = {};
			for (const [name, runtime] of state.servers) {
				if (params.server && params.server !== name) continue;
				try {
					output[name] = (await runtime.client.listResources(undefined, { signal, timeout: runtime.config.timeoutMs ?? 20_000 })).resources;
				} catch (error) {
					output[name] = { error: error instanceof Error ? error.message : String(error) };
				}
			}
			return { content: [{ type: "text", text: JSON.stringify(output, null, 2) }], details: output };
		},
	});

	pi.registerTool({
		name: "mcp_read_resource",
		label: "MCP Read Resource",
		description: "Read a resource URI from an MCP server.",
		promptSnippet: "Read MCP resources by server and URI",
		parameters: Type.Object({
			server: Type.String({ description: "MCP server name" }),
			uri: Type.String({ description: "Resource URI" }),
		}),
		async execute(_id: string, params: { server: string; uri: string }, signal: AbortSignal) {
			await ensureLoaded(pi, signal);
			const runtime = state.servers.get(params.server);
			if (!runtime) throw new Error(`MCP server not connected: ${params.server}`);
			const result = await runtime.client.readResource({ uri: params.uri }, { signal, timeout: runtime.config.timeoutMs ?? 20_000 });
			return { content: [{ type: "text", text: JSON.stringify(result.contents, null, 2) }], details: result };
		},
	});

	pi.registerTool({
		name: "mcp_list_prompts",
		label: "MCP List Prompts",
		description: "List prompts exposed by configured MCP servers.",
		promptSnippet: "List MCP prompts by server",
		parameters: Type.Object({ server: SERVER_ARG }),
		async execute(_id: string, params: { server?: string }, signal: AbortSignal) {
			await ensureLoaded(pi, signal);
			const output: Record<string, unknown> = {};
			for (const [name, runtime] of state.servers) {
				if (params.server && params.server !== name) continue;
				try {
					output[name] = (await runtime.client.listPrompts(undefined, { signal, timeout: runtime.config.timeoutMs ?? 20_000 })).prompts;
				} catch (error) {
					output[name] = { error: error instanceof Error ? error.message : String(error) };
				}
			}
			return { content: [{ type: "text", text: JSON.stringify(output, null, 2) }], details: output };
		},
	});

	pi.registerTool({
		name: "mcp_get_prompt",
		label: "MCP Get Prompt",
		description: "Get/render a prompt exposed by an MCP server.",
		promptSnippet: "Render MCP prompts by server and prompt name",
		parameters: Type.Object({
			server: Type.String({ description: "MCP server name" }),
			name: Type.String({ description: "Prompt name" }),
			arguments: Type.Optional(Type.Record(Type.String(), JSON_VALUE, { description: "Prompt arguments" })),
		}),
		async execute(_id: string, params: { server: string; name: string; arguments?: Record<string, unknown> }, signal: AbortSignal) {
			await ensureLoaded(pi, signal);
			const runtime = state.servers.get(params.server);
			if (!runtime) throw new Error(`MCP server not connected: ${params.server}`);
			const result = await runtime.client.getPrompt(
				{ name: params.name, arguments: params.arguments as Record<string, string> | undefined },
				{ signal, timeout: runtime.config.timeoutMs ?? 20_000 },
			);
			return { content: [{ type: "text", text: JSON.stringify(result.messages, null, 2) }], details: result };
		},
	});
}

export default function mcpBridge(pi: ExtensionAPI) {
	ensureUserConfig();
	registerBridgeTools(pi);

	pi.on("session_start", async (_event: unknown, ctx: ExtensionContext) => {
		await reloadMcp(pi, ctx, ctx.signal);
		if (state.servers.size || state.errors.size) {
			ctx.ui.notify(`MCP loaded: ${state.servers.size} server(s), ${state.tools.size} tool(s)`, state.errors.size ? "warning" : "info");
		}
	});

	pi.on("session_shutdown", async (_event: unknown, ctx: ExtensionContext) => {
		ctx.ui.setStatus("mcp", undefined);
		await closeServers();
		state.loaded = false;
	});

	pi.registerCommand("mcp", {
		description: "Manage MCP servers: /mcp list [server]|list --verbose|describe [server]|reload|test|resources|prompts|add|remove|enable|disable",
		getArgumentCompletions: (prefix: string) => {
			const parts = prefix.trim().split(/\s+/).filter(Boolean);
			if (parts.length <= 1 && !prefix.endsWith(" ")) {
				return ["list", "tools", "describe", "reload", "test", "resources", "prompts", "add", "remove", "enable", "disable"].
					filter((item) => item.startsWith(parts[0] ?? ""))
					.map((item) => ({ value: item, label: item }));
			}
			const serverPrefix = parts.at(-1) ?? "";
			return [...state.serverConfigs.keys()]
				.filter((name) => name.startsWith(serverPrefix))
				.map((name) => ({ value: name, label: name }));
		},
		handler: async (args: string, ctx: ExtensionCommandContext) => handleMcpCommand(pi, args, ctx),
	});
}
