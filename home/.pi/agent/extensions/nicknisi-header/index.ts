/**
 * nicknisi Header Extension
 *
 * Replaces pi's built-in header with an animated nicknisi:
 *
 *  - "gif" mode (default): the nick-waiting.gif Sonic-style waiting
 *    animation, converted to truecolor half-block frames by gen-frames.mjs
 *    (waits 5s, taps its foot, loops — just like the GIF)
 *  - "full" mode: the nicknisi ASCII art from the Neovim dashboard
 *    (config/nvim/lua/nisi/assets.lua), with blinking eyes
 *  - "compact" mode: half-block version of the ASCII art (muddier)
 *
 * All modes get a cowsay-style speech bubble with a random quote typed
 * out character-by-character. Shown only on fresh sessions; the built-in
 * header is restored when the first prompt is sent — like the vim
 * dashboard disappearing when you get to work.
 *
 * `/nicknisi-header` cycles gif → full → compact.
 * Regenerate frames: node gen-frames.mjs <gif> frames-waiting.ts 40 44
 */

import type { ExtensionAPI, ExtensionContext, Theme } from "@mariozechner/pi-coding-agent";
import { CELLS, COLORS, FRAMES } from "./frames-waiting.ts";

// ---------------------------------------------------------------------------
// GIF frame decoding (palette-indexed half-block cells)
// ---------------------------------------------------------------------------

const ANSI_RESET = "\x1b[0m";

const fgEscapes = new Map<number, string>();
const bgEscapes = new Map<number, string>();
function fgEscape(idx: number): string {
	let esc = fgEscapes.get(idx);
	if (!esc) {
		const [r, g, b] = COLORS[idx];
		esc = `\x1b[38;2;${r};${g};${b}m`;
		fgEscapes.set(idx, esc);
	}
	return esc;
}
function bgEscape(idx: number): string {
	let esc = bgEscapes.get(idx);
	if (!esc) {
		const [r, g, b] = COLORS[idx];
		esc = `\x1b[48;2;${r};${g};${b}m`;
		bgEscapes.set(idx, esc);
	}
	return esc;
}

const cellStrings = new Map<number, string>();
function cellString(idx: number): string {
	if (idx === 0) return " ";
	let str = cellStrings.get(idx);
	if (!str) {
		const [top, bottom] = CELLS[idx];
		if (top && bottom) str = `${fgEscape(top)}${bgEscape(bottom)}▀${ANSI_RESET}`;
		else if (top) str = `${fgEscape(top)}▀${ANSI_RESET}`;
		else str = `${fgEscape(bottom)}▄${ANSI_RESET}`;
		cellStrings.set(idx, str);
	}
	return str;
}

const decodedFrames = new Map<number, string[]>();
function gifFrame(index: number): string[] {
	let lines = decodedFrames.get(index);
	if (!lines) {
		lines = FRAMES[index].lines.map((tokens) =>
			tokens
				.map((token) => {
					const star = token.indexOf("*");
					if (star === -1) return cellString(Number(token));
					return cellString(Number(token.slice(0, star))).repeat(Number(token.slice(star + 1)));
				})
				.join(""),
		);
		decodedFrames.set(index, lines);
	}
	return lines;
}

// ---------------------------------------------------------------------------
// ASCII art (from config/nvim/lua/nisi/assets.lua — ascii.nicknisi)
// ---------------------------------------------------------------------------

const ART = [
	"                                              ",
	"               ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓               ",
	"           ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓        ",
	"          ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓       ",
	"       ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓       ",
	"      ▓▓▓▓▓▓▓▓▓▓▒▒░░░░░▓▓▓▓▓▓▓▓▓▓░▒▒▓▓▓       ",
	"     ▓▓▓▓▓▓▓▓▓▓▒░░░░░░░░░░░░░░░░░░░░▒▒▓▓▓     ",
	"     ▓▓▓▓▓▓▒▒░░░░░░░░░░░░░░░░░░░░░░░░░▒▓▓     ",
	"     ▓▓▓▓▓▒░░░░░▓▓▓▓▓▓▓░░░░░░░░░▒▓▓▓▓▓▓▓▓     ",
	"     ▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒▓▓     ",
	"   ░░░▒▓▓▓░░░░░      ▓▓░░░░░░░░       ▓▓▓░░   ",
	" ░░░░░▒▓▓▓░░░░░    ░▓▓▓▒▒░░░░▒▒     ▓▓▓▓▓░░   ",
	" ░░▒▒░▒▓░░░░░░░    ░▓██▒▒░░░░▒▒     ▓▓█▒▒░░   ",
	"   ░░▒▒░░░░░░░░▒     ▒▒░░░░░░░░▒░     ▒░░▒▒   ",
	"     ░░░░░░░░░░░▒▒▒▒▒░░░░░░░░░░░░▒▒▒░░░▒▒     ",
	"        ▒▒░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒░░░░░▒       ",
	"          ▒░░░░░░░░░░░░░░░░░░░░░░░░░▒▒        ",
	"           ▒▒░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒░░░▒▒          ",
	"             ▒▒▒░░░░░░░░░░░░░░░░░▒            ",
	"                ▒▒▒▒▒░░░░░░░░▒▒▒▒             ",
	"           ▓▓▓▓▓▓▓▓▒░▒▒▒▒▒▒▒▒▓▓               ",
	"          ▓▓▓▓▓▓▓▓▓▓▓░░░░░▓▓▓▓▓▓▓             ",
	"      ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓          ",
	"      ▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒          ",
	"      ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░          ",
].map((line) => line.trimEnd());

const ART_WIDTH = Math.max(...ART.map((line) => line.length));

type Shade = "▓" | "▒" | "░" | "█";

const SHADE_COLORS: Record<Shade, Parameters<Theme["fg"]>[0]> = {
	"▓": "accent",
	"▒": "muted",
	"░": "text",
	"█": "dim",
};

/** Pixel lookup; when blinking, eyes (█) become face (░). */
function pixel(x: number, y: number, blink: boolean): Shade | undefined {
	const ch = ART[y]?.[x];
	if (ch === "▓" || ch === "▒" || ch === "░" || ch === "█") {
		return blink && ch === "█" ? "░" : ch;
	}
	return undefined;
}

/** Full-size render: one char per pixel, grouped into same-color runs. */
function renderFull(theme: Theme, blink: boolean): string[] {
	const lines: string[] = [];
	for (let y = 0; y < ART.length; y++) {
		let line = "";
		let runShade: Shade | undefined;
		let run = "";
		const flush = () => {
			if (runShade) line += theme.fg(SHADE_COLORS[runShade], run);
			else line += run;
			run = "";
		};
		for (let x = 0; x < ART_WIDTH; x++) {
			const shade = pixel(x, y, blink);
			if (shade !== runShade) {
				flush();
				runShade = shade;
			}
			run += shade ?? " ";
		}
		flush();
		lines.push(line.trimEnd());
	}
	return lines;
}

/** Convert a theme fg escape (\x1b[38;…) into the matching bg escape (\x1b[48;…). */
function bgAnsi(theme: Theme, color: Parameters<Theme["fg"]>[0]): string {
	return theme.getFgAnsi(color).replace("38;", "48;");
}

/** Compact render: two pixel rows per terminal row via ▀/▄ half-blocks. */
function renderCompact(theme: Theme, blink: boolean): string[] {
	const fg = (s: Shade) => theme.getFgAnsi(SHADE_COLORS[s]);
	const bg = (s: Shade) => bgAnsi(theme, SHADE_COLORS[s]);
	const lines: string[] = [];
	for (let y = 0; y < ART.length; y += 2) {
		let line = "";
		for (let x = 0; x < ART_WIDTH; x++) {
			const top = pixel(x, y, blink);
			const bottom = pixel(x, y + 1, blink);
			if (top && bottom) line += `${fg(top)}${bg(bottom)}▀${ANSI_RESET}`;
			else if (top) line += `${fg(top)}▀${ANSI_RESET}`;
			else if (bottom) line += `${fg(bottom)}▄${ANSI_RESET}`;
			else line += " ";
		}
		lines.push(line.trimEnd());
	}
	return lines;
}

// ---------------------------------------------------------------------------
// Quotes
// ---------------------------------------------------------------------------

const QUOTES = [
	"turning coffee into commits",
	"the code works and nobody knows why",
	"git blame says it was me. rude.",
	"it's not a bug, it's a side quest",
	"ship it, then read the docs",
	"TODO: write better TODOs",
	"my other editor is also vim",
	"have you tried :wq?",
	"there is no place like ~/.",
	"weeks of coding save hours of planning",
	"neovim btw",
	"merge conflicts build character",
	"dotfiles: 10 years in the making",
	"rm -rf doubt && ship",
	"undefined is not a function, it's a vibe",
	"every bug was once a feature",
	"the real bug was inside us all along",
	"turning tokens into something readable",
	"the cloud is just someone else's computer",
	"keep calm and :wq",
];

/** Waiting-themed quotes for gif mode (he's impatiently waiting on you). */
const WAITING_QUOTES = [
	"*taps foot*",
	"any decade now…",
	"still faster than npm install",
	"I'll just wait here then",
	"ahem.",
	"loading prompt…",
	"the cursor blinks, questioning our purpose",
	"take your time. I'll wait. obviously.",
	"this is me, waiting",
	"did the wifi eat your prompt?",
];

/** cowsay-style bubble above the art; quote revealed up to `typed` chars. */
function renderBubble(theme: Theme, quote: string, typed: number): string[] {
	const w = quote.length + 2;
	const shown = quote.slice(0, typed).padEnd(quote.length);
	const border = theme.fg("borderMuted", "─");
	const side = theme.fg("borderMuted", "│");
	return [
		theme.fg("borderMuted", `╭${border.repeat(w)}╮`),
		`${side}${theme.italic(theme.fg("text", ` ${shown} `))}${side}`,
		theme.fg("borderMuted", `╰──╮ ╭${border.repeat(w - 5)}╯`),
		theme.fg("borderMuted", "   ╲╱"),
	];
}

// ---------------------------------------------------------------------------
// Extension
// ---------------------------------------------------------------------------

type Mode = "gif" | "full" | "compact";
const MODES: Mode[] = ["gif", "full", "compact"];

export default function (pi: ExtensionAPI) {
	let mode: Mode = "gif";
	let timer: ReturnType<typeof setInterval> | undefined;
	let shown = false;

	const stopAnimation = () => {
		if (timer) {
			clearInterval(timer);
			timer = undefined;
		}
	};

	const showDashboard = (ctx: ExtensionContext) => {
		const pool = mode === "gif" ? WAITING_QUOTES : QUOTES;
		const quote = pool[Math.floor(Math.random() * pool.length)];
		let typed = 0;
		let blink = false;
		let nextBlinkAt = Date.now() + 2000 + Math.random() * 3000;
		let blinkUntil = 0;
		let frameIndex = 0;
		let frameElapsed = 0;
		let lastTick = Date.now();
		let headerComp: { invalidate(): void } | undefined;

		shown = true;
		ctx.ui.setHeader((tui, theme) => {
			const startAnimation = () => {
				if (timer) return;
				timer = setInterval(() => {
					const now = Date.now();
					const dt = now - lastTick;
					lastTick = now;
					let dirty = false;

					if (typed < quote.length) {
						typed += 1;
						dirty = true;
					}

					if (mode === "gif") {
						frameElapsed += dt;
						const delay = FRAMES[frameIndex].delay;
						if (frameElapsed >= delay) {
							frameElapsed = 0;
							frameIndex = (frameIndex + 1) % FRAMES.length;
							dirty = true;
						}
					} else {
						if (!blink && now >= nextBlinkAt) {
							blink = true;
							blinkUntil = now + 180;
							dirty = true;
						} else if (blink && now >= blinkUntil) {
							blink = false;
							nextBlinkAt = now + 2500 + Math.random() * 3500;
							dirty = true;
						}
					}

					if (dirty && headerComp) {
						headerComp.invalidate();
						tui.requestRender();
					}
				}, 50);
			};
			startAnimation();

			headerComp = {
				render(width: number): string[] {
					let art: string[];
					if (mode === "gif") art = gifFrame(frameIndex);
					else if (mode === "compact") art = renderCompact(theme, blink);
					else art = renderFull(theme, blink);
					const content = ["", ...renderBubble(theme, quote, typed), ...art, ""];
					// Center each line independently (bubble width differs from art width)
					return content.map((line) => {
						const visible = line.replace(/\x1b\[[0-9;]*m/g, "").length;
						return " ".repeat(Math.max(0, Math.floor((width - visible) / 2))) + line;
					});
				},
				invalidate() {},
			};
			return headerComp;
		});
	};

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		// Only show the dashboard on fresh sessions, not resumes
		const hasConversation = ctx.sessionManager.getBranch().some((entry) => entry.type === "message");
		if (hasConversation) return;

		showDashboard(ctx);
	});

	// Dashboard's job is done once you start working — restore built-in header
	pi.on("before_agent_start", (_event, ctx) => {
		if (ctx.mode === "tui" && shown) {
			shown = false;
			stopAnimation();
			ctx.ui.setHeader(undefined);
		}
	});

	pi.on("session_shutdown", () => {
		shown = false;
		stopAnimation();
	});

	// Cycle gif → full → compact (re-renders live if the dashboard is up)
	pi.registerCommand("nicknisi-header", {
		description: "Cycle nicknisi header style (gif → full → compact)",
		handler: async (_args, ctx) => {
			mode = MODES[(MODES.indexOf(mode) + 1) % MODES.length];
			if (shown && ctx.mode === "tui") {
				stopAnimation();
				showDashboard(ctx);
			}
			ctx.ui.notify(`nicknisi header: ${mode}`, "info");
		},
	});
}
