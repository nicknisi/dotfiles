/**
 * User Message Extension
 *
 * Styles user messages in the chat history (not the input box) with a
 * theme-colored left border. Pi has no theme token or extension API for
 * this, so this wraps UserMessageComponent.prototype.render.
 *
 * Modes (MODE constant below):
 *  - "top": draws a thin accent rule along the top edge of the message box
 *    via an overline (SGR 53) colored with SGR 58 on the box's top padding
 *    line. Adds no columns and copies as pure spaces. Requires overline
 *    support (Ghostty; in tmux needs the overline terminal-features flag).
 *  - "inline": recolors the first padding cell of the message box to the
 *    border color. Adds no columns, so tmux/terminal text selection copies
 *    exactly what stock pi would copy. Bar sits at the screen edge.
 *  - "gutter": prepends a background-colored space bar with a left margin.
 *    Off the edge, copies as whitespace (but indents the copied text).
 *  - "glyph": prepends a border character (visible in copies).
 *
 * In glyph mode, ROUNDED adds arc caps to the first/last line of each
 * message (rounded bar ends). "╮"/"╯" curl the tips outward; "╭"/"╰"
 * curl them inward toward the text. The arcs are thin-line glyphs, so with
 * a "▐" bar there's a slight weight mismatch; use "│" for a uniform line.
 *
 * The color is read fresh on every render, so live theme changes
 * (e.g. auto-theme switching) are picked up immediately.
 */

import { UserMessageComponent, type ExtensionAPI, type Theme } from "@earendil-works/pi-coding-agent";

/** "top" | "inline" | "gutter" | "glyph" — see header comment */
const MODE = "top";

/** Theme color token for the border: "accent", "borderAccent", "borderMuted", "muted", ... */
const BORDER_COLOR = "accent";

/** Border glyph (glyph mode only). Single-cell — multi-cell combos render with gaps. */
const BORDER = "▐";

/** Rounded end caps (glyph mode). Set false for square ends. */
const ROUNDED = true;
const BORDER_TOP = "╮";
const BORDER_BOTTOM = "╯";

/** Blank columns before the border (gutter/glyph modes only) */
const LEFT_MARGIN = 1;

/** Gap between the border and the message box (gutter/glyph modes only).
 *  "" works well for gutter mode (box padding provides the gap); " " for glyph. */
const GAP = " ";

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

    const prefixWidth = MODE === "inline" || MODE === "top" ? 0 : LEFT_MARGIN + BORDER.length + GAP.length;
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

        if (MODE === "top") {
          const bgOpen = borderBgOpen(theme);
          const lineOpen = bgOpen?.replace("\x1b[48;", "\x1b[58;"); // overline color shares the underline color channel
          if (!bgOpen || !lineOpen || lines.length === 0) return lines;
          // Rebuild the top padding line: same box bg and spaces, plus a
          // colored overline so it renders as a thin rule at the box's top edge.
          const boxBgOpen = theme.bg("userMessageBg", "").replace("\x1b[49m", "");
          const osc = lines[0].match(/^\x1b\]133;A\x07/)?.[0] ?? "";
          const spaceCount = lines[0].replace(/\x1b\[[0-9;]*m/g, "").replace(/\x1b\][^\x07]*\x07/g, "").length;
          const rule = `${osc}${boxBgOpen}\x1b[53m${lineOpen}${" ".repeat(spaceCount)}\x1b[55m\x1b[59m\x1b[49m`;
          return [rule, ...lines.slice(1)];
        }

        const cell =
          MODE === "gutter"
            ? (borderBgOpen(theme) ? `${borderBgOpen(theme)} \x1b[49m` : theme.fg(BORDER_COLOR as never, BORDER))
            : theme.fg(BORDER_COLOR as never, BORDER);
        const bar = margin + theme.bg("userMessageBg", cell + GAP);
        if (MODE === "glyph" && ROUNDED && lines.length > 1) {
          const cap = (glyph: string) =>
            margin + theme.bg("userMessageBg", theme.fg(BORDER_COLOR as never, glyph) + GAP);
          return lines.map((line, i) =>
            i === 0 ? cap(BORDER_TOP) + line
            : i === lines.length - 1 ? cap(BORDER_BOTTOM) + line
            : bar + line);
        }
        return lines.map((line) => bar + line);
      } catch {
        // Never break chat rendering (e.g. after a pi update changes internals)
        return originalRender.call(this, width);
      }
    };
  });
}
