/**
 * nicknisi Header Extension
 *
 * Replaces pi's built-in header with an animated nicknisi sitting at the
 * top-left, Claude Code style, with session info beside him:
 *
 *  - "blink" mode (default): nicknisi-blink.gif — a close-up blink loop
 *  - "waiting" mode: nick-waiting.gif — the Sonic-style waiting animation
 *    (waits 5s, taps its foot, loops)
 *  - "full" mode: the nicknisi ASCII art from the Neovim dashboard
 *    (config/nvim/lua/nisi/assets.lua), with blinking eyes
 *  - "compact" mode: half-block version of the ASCII art (muddier)
 *
 * GIFs are converted to truecolor half-block frames by gen-frames.mjs:
 *   node gen-frames.mjs <gif> <out.ts> <cols> <pxHeight>
 * (square-ish px grid ≈ correct aspect for Monaspace Neon + adjust-cell-height=10%)
 *
 * Session info: pi version + model, cwd + git branch, and a random quote
 * typed out character-by-character. Shown only on fresh sessions; the
 * built-in header is restored when the first prompt is sent — like the
 * vim dashboard disappearing when you get to work.
 *
 * `/nicknisi-header` cycles blink → waiting → full → compact.
 */

import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import {
  VERSION,
  getAgentDir,
  type ExtensionAPI,
  type ExtensionContext,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import * as blinkDataLarge from "./frames-blink-large.ts";
import * as blinkDataSmall from "./frames-blink-small.ts";
import * as blinkData from "./frames-blink.ts";
import * as waitingDataLarge from "./frames-waiting-large.ts";
import * as waitingDataSmall from "./frames-waiting-small.ts";
import * as waitingData from "./frames-waiting.ts";

const ANSI_RESET = "\x1b[0m";
const ANSI_RE = /\u001b\[[0-9;]*m/g; // eslint-disable-line no-control-regex -- intentional: matches ANSI color escapes
const visibleLen = (s: string) => s.replace(ANSI_RE, "").length;

// ---------------------------------------------------------------------------
// GIF frame decoding (palette-indexed half-block cells, per source file)
// ---------------------------------------------------------------------------

interface FrameData {
  COLORS: [number, number, number][];
  CELLS: [number, number][];
  FRAMES: { delay: number; lines: string[][] }[];
}

function makeGifDecoder(data: FrameData) {
  const fgEscapes = new Map<number, string>();
  const bgEscapes = new Map<number, string>();
  const cellStrings = new Map<number, string>();
  const decodedFrames = new Map<number, string[]>();
  let width: number | undefined;

  const fgEscape = (idx: number): string => {
    let esc = fgEscapes.get(idx);
    if (!esc) {
      const [r, g, b] = data.COLORS[idx];
      esc = `\x1b[38;2;${r};${g};${b}m`;
      fgEscapes.set(idx, esc);
    }
    return esc;
  };
  const bgEscape = (idx: number): string => {
    let esc = bgEscapes.get(idx);
    if (!esc) {
      const [r, g, b] = data.COLORS[idx];
      esc = `\x1b[48;2;${r};${g};${b}m`;
      bgEscapes.set(idx, esc);
    }
    return esc;
  };
  const cellString = (idx: number): string => {
    if (idx === 0) return " ";
    let str = cellStrings.get(idx);
    if (!str) {
      const [top, bottom] = data.CELLS[idx];
      if (top && bottom) str = `${fgEscape(top)}${bgEscape(bottom)}▀${ANSI_RESET}`;
      else if (top) str = `${fgEscape(top)}▀${ANSI_RESET}`;
      else str = `${fgEscape(bottom)}▄${ANSI_RESET}`;
      cellStrings.set(idx, str);
    }
    return str;
  };

  return {
    count: data.FRAMES.length,
    delay: (i: number) => data.FRAMES[i].delay,
    frame(index: number): string[] {
      let lines = decodedFrames.get(index);
      if (!lines) {
        lines = data.FRAMES[index].lines.map((tokens) =>
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
    },
    width(): number {
      if (width === undefined) {
        width = 0;
        for (let i = 0; i < data.FRAMES.length; i++) {
          for (const line of this.frame(i)) width = Math.max(width, visibleLen(line));
        }
      }
      return width;
    },
  };
}

type Size = "small" | "medium" | "large";
const SIZES: Size[] = ["small", "medium", "large"];

/** Rows per size: small ≈ 10, medium ≈ 13-14, large ≈ 15-18. */
const GIFS: Record<"blink" | "waiting", Record<Size, ReturnType<typeof makeGifDecoder>>> = {
  blink: {
    small: makeGifDecoder(blinkDataSmall),
    medium: makeGifDecoder(blinkData),
    large: makeGifDecoder(blinkDataLarge),
  },
  waiting: {
    small: makeGifDecoder(waitingDataSmall),
    medium: makeGifDecoder(waitingData),
    large: makeGifDecoder(waitingDataLarge),
  },
};

// Persisted config (~/.pi/agent/nicknisi-header.json)
interface HeaderConfig {
  size?: Size;
}
const CONFIG_PATH = join(getAgentDir(), "nicknisi-header.json");

function loadConfig(): HeaderConfig {
  try {
    return JSON.parse(readFileSync(CONFIG_PATH, "utf8")) as HeaderConfig;
  } catch {
    return {};
  }
}

function saveConfig(config: HeaderConfig): void {
  try {
    writeFileSync(CONFIG_PATH, `${JSON.stringify(config, null, 2)}\n`);
  } catch {
    // non-fatal: size just won't persist across restarts
  }
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

/** Waiting-themed quotes for waiting mode (he's impatiently waiting on you). */
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

/** Blink-mode quotes (he's watching you). */
const BLINK_QUOTES = [
  "blink and you'll miss it",
  "I see everything",
  "did you catch that?",
  "just watching you type",
  "no, YOU'RE staring",
  "always watching. in a fun way.",
  "I blink so I don't miss anything",
  "eyes on the prize. you're the prize.",
];

// ---------------------------------------------------------------------------
// Extension
// ---------------------------------------------------------------------------

type Mode = "blink" | "waiting" | "full" | "compact";
const MODES: Mode[] = ["blink", "waiting", "full", "compact"];

const MARGIN = "  ";
const INFO_GAP = "   ";

function shortenCwd(cwd: string): string {
  const home = homedir();
  return cwd.startsWith(home) ? `~${cwd.slice(home.length)}` : cwd;
}

function gitBranch(cwd: string): string | undefined {
  try {
    const branch = execFileSync("git", ["branch", "--show-current"], {
      cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      timeout: 2000,
    }).trim();
    return branch || undefined;
  } catch {
    return undefined;
  }
}

export default function (pi: ExtensionAPI) {
  let mode: Mode = "blink";
  let size: Size = loadConfig().size ?? "medium";
  let timer: ReturnType<typeof setInterval> | undefined;
  let shown = false;

  const stopAnimation = () => {
    if (timer) {
      clearInterval(timer);
      timer = undefined;
    }
  };

  const showDashboard = (ctx: ExtensionContext) => {
    const gif = mode === "blink" || mode === "waiting" ? GIFS[mode][size] : undefined;
    const pool = mode === "waiting" ? WAITING_QUOTES : mode === "blink" ? BLINK_QUOTES : QUOTES;
    const quote = pool[Math.floor(Math.random() * pool.length)];
    let typed = 0;
    let blink = false;
    let nextBlinkAt = Date.now() + 2000 + Math.random() * 3000;
    let blinkUntil = 0;
    let frameIndex = 0;
    let frameElapsed = 0;
    let lastTick = Date.now();
    let headerComp: { invalidate(): void } | undefined;

    // Session info, resolved once
    const modelName = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "no model";
    const branch = gitBranch(ctx.cwd);
    const location = branch ? `${shortenCwd(ctx.cwd)}  ·  ${branch}` : shortenCwd(ctx.cwd);

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

          if (gif) {
            frameElapsed += dt;
            if (frameElapsed >= gif.delay(frameIndex)) {
              frameElapsed = 0;
              frameIndex = (frameIndex + 1) % gif.count;
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
        render(_width: number): string[] {
          let art: string[];
          let artWidth: number;
          if (gif) {
            art = gif.frame(frameIndex);
            artWidth = gif.width();
          } else if (mode === "compact") {
            art = renderCompact(theme, blink);
            artWidth = ART_WIDTH;
          } else {
            art = renderFull(theme, blink);
            artWidth = ART_WIDTH;
          }

          // Info column, vertically centered against the art
          const cursor = typed < quote.length ? theme.fg("dim", "▌") : "";
          const info = [
            `${theme.bold(theme.fg("accent", "pi"))} ${theme.fg("dim", `v${VERSION} · ${modelName}`)}`,
            theme.fg("muted", location),
            theme.italic(theme.fg("text", quote.slice(0, typed))) + cursor,
          ];
          const infoOffset = Math.max(0, Math.floor((art.length - info.length) / 2));

          const rows = art.map((artLine, i) => {
            const left = MARGIN + artLine + " ".repeat(Math.max(0, artWidth - visibleLen(artLine)));
            const infoIdx = i - infoOffset;
            return infoIdx >= 0 && infoIdx < info.length ? left + INFO_GAP + info[infoIdx] : left;
          });
          return ["", ...rows];
        },
        invalidate() {},
      };
      return headerComp;
    });
  };

  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    // Only show the dashboard on fresh sessions, not resumes
    const hasConversation = ctx.sessionManager
      .getBranch()
      .some((entry) => entry.type === "message");
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

  // Cycle blink → waiting → full → compact (re-renders live if the dashboard is up)
  pi.registerCommand("nicknisi-header", {
    description: "Cycle nicknisi header style (blink → waiting → full → compact)",
    handler: async (_args, ctx) => {
      mode = MODES[(MODES.indexOf(mode) + 1) % MODES.length];
      if (shown && ctx.mode === "tui") {
        stopAnimation();
        showDashboard(ctx);
      }
      ctx.ui.notify(`nicknisi header: ${mode}`, "info");
    },
  });

  // Set or cycle gif size: /nicknisi-header-size [small|medium|large]
  // Persisted to ~/.pi/agent/nicknisi-header.json. ASCII art modes are fixed-size.
  pi.registerCommand("nicknisi-header-size", {
    description: "Set nicknisi header size (small|medium|large, no arg cycles)",
    handler: async (args, ctx) => {
      const requested = args.trim() as Size;
      size = SIZES.includes(requested)
        ? requested
        : SIZES[(SIZES.indexOf(size) + 1) % SIZES.length];
      saveConfig({ ...loadConfig(), size });
      if (shown && ctx.mode === "tui") {
        stopAnimation();
        showDashboard(ctx);
      }
      ctx.ui.notify(`nicknisi header size: ${size} (applies to gif modes)`, "info");
    },
  });
}
