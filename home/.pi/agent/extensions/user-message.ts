/**
 * User Message Extension
 *
 * Styles user messages in the chat history (not the input box) with a
 * theme-colored left border. Pi has no theme token or extension API for
 * this, so this wraps UserMessageComponent.prototype.render: it renders
 * the original component a few columns narrower and prepends a themed
 * border bar that shares the userMessageBg background, so it reads as
 * one block.
 *
 * The bar color is read fresh on every render, so live theme changes
 * (e.g. auto-theme switching) are picked up immediately.
 *
 * Configure via the constants below.
 */

import { UserMessageComponent, type ExtensionAPI, type Theme } from "@earendil-works/pi-coding-agent";

/**
 * Border glyph. Single-cell only — multi-cell combos like "▐▌" render with
 * a visible gap because terminals add spacing between character cells.
 * Good options: "▎" (thin), "▌"/"▐" (medium), "█" (full block), "│"/"┃" (line)
 */
const BORDER = "▐";

/** Theme color token for the border: "accent", "borderAccent", "borderMuted", "muted", ... */
const BORDER_COLOR = "accent";

/** Blank columns before the border, outside the message background (keeps it off the screen edge) */
const LEFT_MARGIN = 1;

/** Gap between the border glyph and the message box */
const GAP = " ";

let getTheme: (() => Theme) | undefined;
let patched = false;

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    getTheme = () => ctx.ui.theme;
    if (patched) return;
    patched = true;

    const prefixWidth = LEFT_MARGIN + BORDER.length + GAP.length;
    const margin = " ".repeat(LEFT_MARGIN);
    const originalRender = UserMessageComponent.prototype.render;

    UserMessageComponent.prototype.render = function (this: UserMessageComponent, width: number): string[] {
      try {
        const theme = getTheme?.();
        // Fall back to stock rendering before session start or on tiny terminals
        if (!theme || width <= prefixWidth + 4) {
          return originalRender.call(this, width);
        }
        const lines = originalRender.call(this, width - prefixWidth);
        const bar = margin + theme.bg("userMessageBg", theme.fg(BORDER_COLOR, BORDER) + GAP);
        return lines.map((line) => bar + line);
      } catch {
        // Never break chat rendering (e.g. after a pi update changes internals)
        return originalRender.call(this, width);
      }
    };
  });
}
