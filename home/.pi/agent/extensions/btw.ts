/**
 * /btw extension — side-channel questions against the current session context
 *
 * Usage: /btw <question>
 *
 * Fires a one-off LLM call (streamSimple) using the active model and thinking
 * level, with the current branch messages + <question> as context. The answer
 * is persisted as a custom message in the session but excluded from the main
 * agent's context in subsequent turns.
 */

import { streamSimple, type Message, type ThinkingLevel } from "@mariozechner/pi-ai";
import type { ExtensionAPI, SessionEntry } from "@mariozechner/pi-coding-agent";
import { BorderedLoader, convertToLlm } from "@mariozechner/pi-coding-agent";
import { Box, Text } from "@mariozechner/pi-tui";

const CUSTOM_TYPE = "btw-answer";

const SYSTEM_PROMPT = `You are a helpful side-channel assistant. The user is in the middle of a coding session and has a quick question. Answer concisely based on the conversation context provided. Do not suggest tool calls or actions — just answer the question directly.`;

export default function (pi: ExtensionAPI) {
	// ── Filter btw messages out of the main agent's context ────────────────
	pi.on("context", async (event) => {
		const filtered = event.messages.filter(
			(m) => !(m.role === "custom" && (m as any).customType === CUSTOM_TYPE),
		);
		return { messages: filtered };
	});

	// ── Custom renderer for btw answers ───────────────────────────────────
	pi.registerMessageRenderer(CUSTOM_TYPE, (message, { expanded }, theme) => {
		const details = message.details as { question: string; model: string } | undefined;
		const question = details?.question ?? "?";
		const model = details?.model ?? "unknown";

		const header = `${theme.fg("accent", theme.bold("btw"))} ${theme.fg("dim", `(${model})`)}`;
		const q = `${theme.fg("warning", "Q:")} ${question}`;
		const a = `${theme.fg("success", "A:")} ${typeof message.content === "string" ? message.content : ""}`;

		let text = `${header}\n${q}\n${a}`;

		if (!expanded) {
			// Truncate answer to first line in collapsed view
			const firstLine = (typeof message.content === "string" ? message.content : "").split("\n")[0];
			const truncated = firstLine.length > 120 ? firstLine.slice(0, 117) + "..." : firstLine;
			text = `${header}\n${q}\n${theme.fg("success", "A:")} ${truncated}`;
		}

		const box = new Box(1, 1, (t) => theme.bg("customMessageBg", t));
		box.addChild(new Text(text, 0, 0));
		return box;
	});

	// ── /btw command ──────────────────────────────────────────────────────
	pi.registerCommand("btw", {
		description: "Ask a side question using the session context (not sent to main agent)",
		handler: async (args, ctx) => {
			const question = args.trim();
			if (!question) {
				ctx.ui.notify("Usage: /btw <question>", "error");
				return;
			}

			if (!ctx.model) {
				ctx.ui.notify("No model selected", "error");
				return;
			}

			// Gather branch messages and convert to LLM format
			const branch = ctx.sessionManager.getBranch();
			const agentMessages = branch
				.filter((e): e is SessionEntry & { type: "message" } => e.type === "message")
				.map((e) => e.message);
			const llmMessages: Message[] = convertToLlm(agentMessages);

			// Append the user's btw question
			llmMessages.push({
				role: "user",
				content: [{ type: "text", text: question }],
				timestamp: Date.now(),
			});

			// Map thinking level ("off" → undefined, otherwise pass through)
			const thinkingLevel = pi.getThinkingLevel();
			const reasoning: ThinkingLevel | undefined =
				thinkingLevel === "off" ? undefined : (thinkingLevel as ThinkingLevel);

			const apiKey = await ctx.modelRegistry.getApiKey(ctx.model);
			if (!apiKey) {
				ctx.ui.notify(`No API key for ${ctx.model.provider}/${ctx.model.id}`, "error");
				return;
			}

			const modelId = ctx.model.id;

			// Stream the response with a loader UI
			const answer = await ctx.ui.custom<string | null>((tui, theme, _kb, done) => {
				const loader = new BorderedLoader(tui, theme, `btw → ${modelId}...`);
				loader.onAbort = () => done(null);

				(async () => {
					try {
						const stream = streamSimple(
							ctx.model!,
							{ systemPrompt: SYSTEM_PROMPT, messages: llmMessages },
							{ apiKey, reasoning, signal: loader.signal },
						);

						let text = "";
						for await (const event of stream) {
							if (event.type === "text_delta") {
								text += event.delta;
							} else if (event.type === "done") {
								// Extract final text from message
								text = event.message.content
									.filter((c): c is { type: "text"; text: string } => c.type === "text")
									.map((c) => c.text)
									.join("\n");
							} else if (event.type === "error") {
								done(null);
								return;
							}
						}
						done(text || null);
					} catch (err) {
						done(null);
					}
				})();

				return loader;
			});

			if (answer === null) {
				ctx.ui.notify("btw cancelled", "info");
				return;
			}

			// Persist as a custom message — displayed but excluded from agent context
			pi.sendMessage(
				{
					customType: CUSTOM_TYPE,
					content: answer,
					display: true,
					details: { question, model: modelId },
				},
				{ deliverAs: "nextTurn" },
			);
		},
	});
}
