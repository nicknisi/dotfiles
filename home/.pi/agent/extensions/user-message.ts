/**
 * User Message Extension
 *
 * Styles user messages in the chat history (not the input box) with a
 * theme-colored left border. Pi has no theme token or extension API for
 * this, so this wraps UserMessageComponent.prototype.render.
 *
 * Modes (MODE constant below):
 *  - "inline": recolors the first padding cell of the message box to the
 *    border color. Adds no columns, so tmux/terminal text selection copies
 *    exactly what stock pi would copy. Bar sits at the screen edge.
 *  - "gutter": prepends a background-colored space bar with a left margin.
 *    Off the edge, copies as whitespace (but indents the copied text).
 *  - "glyph": prepends a border character (visible in copies).
 *
 * The color is read fresh on every render, so live theme changes
 * (e.g. auto-theme switching) are picked up immediately.
 */

import { UserMessageComponent, type ExtensionAPI, type Theme } from "@earendil-works/pi-coding-agent";

/** "inline" | "gutter" | "glyph" — see header comment */
const MODE = "gutter";

/** Theme color token for the border: "accent", "borderAccent", "borderMuted", "muted", ... */
const BORDER_COLOR = "accent";

/** Border glyph (glyph mode only). Single-cell — multi-cell combos render with gaps. */
const BORDER = "▐";

/** Blank columns before the border (gutter/glyph modes only) */
const LEFT_MARGIN = 1;

/** Gap between the border and the message box (gutter/glyph modes only).
 *  Empty works well: the box's own padding cell provides the visual gap. */
const GAP = "";

/**
 * The border color as a background ANSI open sequence (the token's foreground
 * sequence with 38 → 48). Returns null if the token has no real color.
 */
function borderBgOpen(theme: Theme): string | null {
  const fgOpen = theme.fg(BORDER_COLOR as never, "").replace("\x1b[39m", "");
  const bgOpen = fgOpen.replace("\x1b[38;", "\x1b[48;");
  return bgOpen === fgOpen ? null : bgOpen;
}

/**
 * Inline mode: recolor the first visible cell (the message box's left padding
 * space) to the border color, restoring the previous background after it.
 * The line's visible width is unchanged.
 */
function recolorFirstCell(line: string, bgOpen: string): string {
  const i = line.indexOf(" ");
  if (i === -1) return line;
  const head = line.slice(0, i);
  // Effective background at that cell: the last bg SGR before it
  const bgs = [...head.matchAll(/\x1b\[(48;[0-9;]*|49)m/g)];
  const restore = bgs.length > 0 ? `\x1b[${bgs[bgs.length - 1][1]}m` : "\x1b[49m";
  return head + bgOpen + " " + restore + line.slice(i + 1);
}

let getTheme: (() => Theme) | undefined;
let patched = false;

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    getTheme = () => ctx.ui.theme;
    if (patched) return;
    patched = true;

    const prefixWidth = MODE === "inline" ? 0 : LEFT_MARGIN + BORDER.length + GAP.length;
    const margin = " ".repeat(LEFT_MARGIN);
    const originalRender = UserMessageComponent.prototype.render;

    UserMessageComponent.prototype.render = function (this: UserMessageComponent, width: number): string[] {
      try {
        const theme = getTheme?.();
        if (!theme || width <= prefixWidth + 4) {
          return originalRender.call(this, width);
        }
        const lines = originalRender.call(this, width - prefixWidth);

        if (MODE === "inline") {
          const bgOpen = borderBgOpen(theme);
          if (!bgOpen) return lines;
          return lines.map((line) => recolorFirstCell(line, bgOpen));
        }

        const cell =
          MODE === "gutter"
            ? (borderBgOpen(theme) ? `${borderBgOpen(theme)} \x1b[49m` : theme.fg(BORDER_COLOR as never, BORDER))
            : theme.fg(BORDER_COLOR as never, BORDER);
        const bar = margin + theme.bg("userMessageBg", cell + GAP);
        return lines.map((line) => bar + line);
      } catch {
        // Never break chat rendering (e.g. after a pi update changes internals)
        return originalRender.call(this, width);
      }
    };
  });
}
