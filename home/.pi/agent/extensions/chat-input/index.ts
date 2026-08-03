/**
 * Chat Input Extension
 *
 * Replaces pi's input editor with a configurable boxed input. All native
 * editor features — cursor movement, history, autocomplete, paste — work
 * normally inside the box.
 *
 * Evolved from the earlier `box-editor.ts`: the rendering is now
 * config-driven (~/.pi/agent/configs/chat-input.json) and supports a
 * prefix glyph, boxed/unboxed modes, configurable padding, menu gap,
 * and rounded vs square corners. The rounded ╭╮│╰╯ corners remain the
 * default to preserve the original look.
 *
 * Layout (boxed):
 *   ╭──────────────────────────╮
 *   │ ❯ <content>               │
 *   │   <content continued>     │
 *   ╰──────────────────────────╯
 *   <autocomplete menu>
 *
 * The prefix (default ❯) is shown only on the first body line; subsequent
 * lines get a space so content aligns. Autocomplete lines render below the
 * box, indented by `extraMenuIndent`.
 */

import { CustomEditor, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { TUI, EditorTheme } from "@earendil-works/pi-tui";
import type { KeybindingsManager } from "@earendil-works/pi-coding-agent";
import { visibleWidth } from "@earendil-works/pi-tui";
import { CONFIG } from "./config.js";
import { applyColor, plainText } from "./utils.js";

// Corner glyphs per style.
const CORNERS = {
  rounded: { tl: "╭", tr: "╮", bl: "╰", br: "╯", side: "│" },
  square: { tl: "┌", tr: "┐", bl: "└", br: "┘", side: "│" },
} as const;

// ─── Border / scroll detection on pi's stock render output ────────────────

/** Solid border: every visible char is ─. */
function isSolidBorder(line: string): boolean {
  return plainText(line).replace(/─/g, "").length === 0;
}

/** Extract the `↑ N more` / `↓ N more` scroll indicator, or null. */
function getScrollText(line: string): string | null {
  const plain = plainText(line);
  if (!plain.startsWith("─")) return null;
  const m = plain.match(/((?:↑|↓)\s*\d+\s*more)/);
  return m ? m[1] : null;
}

function isBorderLike(line: string): boolean {
  return isSolidBorder(line) || getScrollText(line) !== null;
}

// ─── Component ────────────────────────────────────────────────────────────

class ChatInput extends CustomEditor {
  private border: (s: string) => string;
  private accent: (s: string) => string;
  private corners = CORNERS[CONFIG.CORNERS];

  constructor(
    tui: TUI,
    theme: EditorTheme,
    keybindings: KeybindingsManager,
    borderFn: (s: string) => string,
    accentFn: (s: string) => string,
  ) {
    super(tui, theme, keybindings, { paddingX: 0 });
    this.border = borderFn;
    this.accent = accentFn;
  }

  render(width: number): string[] {
    const padMultiplier = CONFIG.BOXED_VIEW ? 3 : 1;
    if (width < 5 + CONFIG.BOX_PAD_X * padMultiplier) return super.render(width);

    const contentWidth = CONFIG.BOXED_VIEW
      ? width - 3 - CONFIG.BOX_PAD_X * 3
      : width - 2 * CONFIG.BOX_PAD_X - 1;
    const stock = super.render(contentWidth);
    if (stock.length < 2) return super.render(width);

    return CONFIG.BOXED_VIEW
      ? this.renderBoxed(stock, contentWidth, width)
      : this.renderUnboxed(stock, contentWidth, width);
  }

  private renderBoxed(stock: string[], contentWidth: number, width: number): string[] {
    const c = this.corners;
    const innerWidth = width - 2;

    const firstIdx = stock.findIndex(isBorderLike);
    let lastIdx = -1;
    for (let i = stock.length - 1; i >= 0; i--) {
      if (isBorderLike(stock[i]!)) { lastIdx = i; break; }
    }

    const buildTop = (scroll: string | null): string =>
      scroll
        ? this.border(c.tl) + this.border(`── ${scroll} `) + this.border("─".repeat(Math.max(0, innerWidth - visibleWidth(`── ${scroll} `)))) + this.border(c.tr)
        : this.border(c.tl) + this.border("─".repeat(innerWidth)) + this.border(c.tr);
    const buildBottom = (scroll: string | null): string =>
      scroll
        ? this.border(c.bl) + this.border(`── ${scroll} `) + this.border("─".repeat(Math.max(0, innerWidth - visibleWidth(`── ${scroll} `)))) + this.border(c.br)
        : this.border(c.bl) + this.border("─".repeat(innerWidth)) + this.border(c.br);

    const topScroll = firstIdx !== -1 ? getScrollText(stock[firstIdx]!) : null;
    const bottomScroll = lastIdx !== -1 && lastIdx !== firstIdx ? getScrollText(stock[lastIdx]!) : null;
    const top = buildTop(topScroll);
    const bottom = buildBottom(bottomScroll);

    const pad = " ".repeat(CONFIG.BOX_PAD_X);

    // Body lines (between first and last border).
    const body: string[] = [];
    let isFirst = true;
    for (let i = 0; i < stock.length; i++) {
      if (i === firstIdx || i === lastIdx) continue;
      if (lastIdx !== -1 && i > lastIdx) continue;
      const vw = visibleWidth(stock[i]!);
      const fill = vw < contentWidth ? " ".repeat(contentWidth - vw) : "";
      const prefixStr = isFirst ? this.accent(CONFIG.PREFIX) : " ";
      body.push(this.border(c.side) + pad + prefixStr + pad + stock[i]! + fill + pad + this.border(c.side));
      isFirst = false;
    }

    // Menu lines (after last border).
    const menu: string[] = [];
    if (lastIdx !== -1) {
      for (let i = lastIdx + 1; i < stock.length; i++) {
        const vw = visibleWidth(stock[i]!);
        const indent = " ".repeat(CONFIG.EXTRA_MENU_INDENT);
        const fill = vw + CONFIG.EXTRA_MENU_INDENT < width ? " ".repeat(width - vw - CONFIG.EXTRA_MENU_INDENT) : "";
        menu.push(indent + stock[i]! + fill);
      }
    }

    const gap = Array.from({ length: CONFIG.MENU_GAP }, () => "");
    return [top, ...body, bottom, ...gap, ...menu];
  }

  private renderUnboxed(stock: string[], contentWidth: number, width: number): string[] {
    const firstIdx = stock.findIndex(isBorderLike);
    let lastIdx = -1;
    for (let i = stock.length - 1; i >= 0; i--) {
      if (isBorderLike(stock[i]!)) { lastIdx = i; break; }
    }

    const buildTop = (scroll: string | null): string =>
      scroll
        ? this.border(`── ${scroll} `) + this.border("─".repeat(Math.max(0, width - visibleWidth(`── ${scroll} `))))
        : this.border("─".repeat(width));
    const buildBottom = buildTop; // identical for unboxed

    const topScroll = firstIdx !== -1 ? getScrollText(stock[firstIdx]!) : null;
    const bottomScroll = lastIdx !== -1 && lastIdx !== firstIdx ? getScrollText(stock[lastIdx]!) : null;
    const top = buildTop(topScroll);
    const bottom = buildBottom(bottomScroll);

    const pad = " ".repeat(CONFIG.BOX_PAD_X);

    const body: string[] = [];
    let isFirst = true;
    for (let i = 0; i < stock.length; i++) {
      if (i === firstIdx || i === lastIdx) continue;
      if (lastIdx !== -1 && i > lastIdx) continue;
      const vw = visibleWidth(stock[i]!);
      const fill = vw < contentWidth ? " ".repeat(contentWidth - vw) : "";
      const prefixStr = isFirst ? this.accent(CONFIG.PREFIX) : " ";
      body.push(pad + prefixStr + pad + stock[i]! + fill);
      isFirst = false;
    }

    const menu: string[] = [];
    if (lastIdx !== -1) {
      for (let i = lastIdx + 1; i < stock.length; i++) {
        const vw = visibleWidth(stock[i]!);
        const indent = " ".repeat(CONFIG.EXTRA_MENU_INDENT);
        const fill = vw + CONFIG.EXTRA_MENU_INDENT < width ? " ".repeat(width - vw - CONFIG.EXTRA_MENU_INDENT) : "";
        menu.push(indent + stock[i]! + fill);
      }
    }

    const gap = Array.from({ length: CONFIG.MENU_GAP }, () => "");
    return [top, ...body, bottom, ...gap, ...menu];
  }
}

// ─── Extension entry ──────────────────────────────────────────────────────

export default function chatInput(pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx: ExtensionContext) => {
    if (ctx.mode !== "tui") return;
    ctx.ui.setEditorComponent((tui, theme, kb) => {
      const borderFn = (s: string) => applyColor(ctx.ui.theme, CONFIG.BORDER_COLOR, s);
      const accentFn = (s: string) => applyColor(ctx.ui.theme, CONFIG.PREFIX_COLOR, s);
      return new ChatInput(tui, theme, kb, borderFn, accentFn);
    });
  });

  pi.on("session_shutdown", (_event, ctx: ExtensionContext) => {
    if (ctx.mode === "tui") ctx.ui.setEditorComponent(undefined);
  });
}
