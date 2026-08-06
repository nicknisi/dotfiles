/**
 * Chat Input Extension
 *
 * Replaces pi's input editor with a configurable boxed input. All native
 * editor features — cursor movement, history, autocomplete, paste — work
 * normally inside the box. Also implements paste-again-to-expand: when a
 * collapsed `[paste #N ...]` marker is present, pasting the same content
 * again expands it inline so you can see and edit the actual text.
 *
 * Evolved from the earlier `box-editor.ts`: the rendering is now
 * config-driven (~/.pi/agent/configs/chat-input.json) and supports a
 * prefix glyph, boxed/unboxed modes, configurable padding, menu gap,
 * and rounded vs square corners. The rounded ╭╮│╰╯ corners remain the
 * default to preserve the original look. Paste-expand behavior was merged
 * in from the former standalone `paste-expand.ts` so the two features don't
 * fight over `setEditorComponent` (last-call-wins).
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

// ─── Paste-again-to-expand ────────────────────────────────────────────────
// Pi collapses large pastes (>10 lines or >1000 chars) into a `[paste #N ...]`
// marker. Pasting the same content again while the marker is present expands
// it inline. Reaches into pi-tui Editor internals (state, pastes registry)
// that are TS-private but runtime-accessible; may need updating if pi-tui
// changes its paste-marker format or registry bookkeeping.

const PASTE_MARKER_REGEX = /\[paste #(\d+)( (\+\d+ lines|\d+ chars))?\]/g;

/** Replicates pi-tui's paste cleanup so an incoming paste can be compared
 * against already-collapsed paste content. */
function cleanPastedText(text: string): string {
  // Decode CSI-u Ctrl+<letter> sequences some terminals emit inside bracketed paste
  const decoded = text.replace(/\x1b\[(\d+);5u/g, (match, code) => {
    const cp = Number(code);
    if (cp >= 97 && cp <= 122) return String.fromCharCode(cp - 96);
    if (cp >= 65 && cp <= 90) return String.fromCharCode(cp - 64);
    return match;
  });
  // normalizeText: CRLF/CR -> LF, tabs -> 4 spaces
  const normalized = decoded.replace(/\r\n/g, '\n').replace(/\r/g, '\n').replace(/\t/g, '    ');
  // Strip non-printables except newline
  return normalized
    .split('')
    .filter((c) => c === '\n' || c.charCodeAt(0) >= 32)
    .join('');
}

// pi-tui Editor privates we touch at runtime
interface EditorInternals {
  state: { lines: string[]; cursorLine: number; cursorCol: number };
  pastes: Map<number, string>;
  pasteCounter: number;
  lastAction: unknown;
  pushUndoSnapshot(): void;
  cancelAutocomplete(): void;
  exitHistoryBrowsing(): void;
  setCursorCol(col: number): void;
}

import { CustomEditor, type ExtensionAPI, type ExtensionContext } from '@earendil-works/pi-coding-agent';
import type { TUI, EditorTheme } from '@earendil-works/pi-tui';
import type { KeybindingsManager } from '@earendil-works/pi-coding-agent';
import { visibleWidth } from '@earendil-works/pi-tui';
import { CONFIG } from './config.js';
import { applyColor, plainText } from './utils.js';

// Corner glyphs per style.
const CORNERS = {
  rounded: { tl: '╭', tr: '╮', bl: '╰', br: '╯', side: '│' },
  square: { tl: '┌', tr: '┐', bl: '└', br: '┘', side: '│' },
} as const;

// ─── Border / scroll detection on pi's stock render output ────────────────

/** Solid border: every visible char is ─. */
function isSolidBorder(line: string): boolean {
  return plainText(line).replace(/─/g, '').length === 0;
}

/** Extract the `↑ N more` / `↓ N more` scroll indicator, or null. */
function getScrollText(line: string): string | null {
  const plain = plainText(line);
  if (!plain.startsWith('─')) return null;
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

  // ── Paste-again-to-expand ───────────────────────────────────────────────
  handlePaste(pastedText: string): void {
    const self = this as unknown as EditorInternals;
    if (self.pastes.size > 0) {
      const cleaned = cleanPastedText(pastedText);
      for (const [id, content] of self.pastes) {
        // handlePaste may have prepended a space to path-like pastes
        if (content !== cleaned && content !== ` ${cleaned}`) continue;
        const markerRe = new RegExp(`\\[paste #${id}( (\\+\\d+ lines|\\d+ chars))?\\]`);
        if (!markerRe.test(this.getText())) continue;
        this.expandCollapsedPaste(id, content);
        return;
      }
    }
    super.handlePaste(pastedText);
  }

  /** Replace the collapsed marker for paste `id` with its real content,
   * keeping the paste registry dense (same bookkeeping as marker deletion). */
  private expandCollapsedPaste(id: number, content: string): void {
    const self = this as unknown as EditorInternals;
    self.cancelAutocomplete();
    self.exitHistoryBrowsing();
    self.lastAction = null;
    self.pushUndoSnapshot();

    const markerRe = new RegExp(`\\[paste #${id}( (\\+\\d+ lines|\\d+ chars))?\\]`);

    // Markers are atomic single-line segments; find the line containing it
    let lineIdx = -1;
    let match: RegExpExecArray | null = null;
    for (let i = 0; i < self.state.lines.length; i++) {
      const m = markerRe.exec(self.state.lines[i]!);
      if (m) {
        lineIdx = i;
        match = m;
        break;
      }
    }
    if (lineIdx === -1 || !match) return;

    const line = self.state.lines[lineIdx]!;
    const before = line.slice(0, match.index);
    const after = line.slice(match.index + match[0].length);
    self.state.lines.splice(lineIdx, 1, ...(before + content + after).split('\n'));

    // Remove registry entry, shift higher ids down, renumber their markers
    self.pastes.delete(id);
    self.pasteCounter--;
    const higher = [...self.pastes.keys()].filter((k) => k > id).sort((a, b) => a - b);
    for (const k of higher) {
      self.pastes.set(k - 1, self.pastes.get(k)!);
      self.pastes.delete(k);
    }
    self.state.lines = self.state.lines.map((l) =>
      l.replace(PASTE_MARKER_REGEX, (full, idGroup, suffix) =>
        Number(idGroup) <= id ? full : `[paste #${Number(idGroup) - 1}${suffix ?? ''}]`,
      ),
    );

    // Cursor to end of the expanded content
    const contentLines = content.split('\n');
    self.state.cursorLine = lineIdx + contentLines.length - 1;
    self.setCursorCol(
      contentLines.length === 1 ? before.length + content.length : contentLines[contentLines.length - 1]!.length,
    );

    if (this.onChange) this.onChange(this.getText());
  }

  render(width: number): string[] {
    const padMultiplier = CONFIG.BOXED_VIEW ? 3 : 1;
    if (width < 5 + CONFIG.BOX_PAD_X * padMultiplier) return super.render(width);

    const contentWidth = CONFIG.BOXED_VIEW ? width - 3 - CONFIG.BOX_PAD_X * 3 : width - 2 * CONFIG.BOX_PAD_X - 1;
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
      if (isBorderLike(stock[i]!)) {
        lastIdx = i;
        break;
      }
    }

    const buildTop = (scroll: string | null): string =>
      scroll
        ? this.border(c.tl) +
          this.border(`── ${scroll} `) +
          this.border('─'.repeat(Math.max(0, innerWidth - visibleWidth(`── ${scroll} `)))) +
          this.border(c.tr)
        : this.border(c.tl) + this.border('─'.repeat(innerWidth)) + this.border(c.tr);
    const buildBottom = (scroll: string | null): string =>
      scroll
        ? this.border(c.bl) +
          this.border(`── ${scroll} `) +
          this.border('─'.repeat(Math.max(0, innerWidth - visibleWidth(`── ${scroll} `)))) +
          this.border(c.br)
        : this.border(c.bl) + this.border('─'.repeat(innerWidth)) + this.border(c.br);

    const topScroll = firstIdx !== -1 ? getScrollText(stock[firstIdx]!) : null;
    const bottomScroll = lastIdx !== -1 && lastIdx !== firstIdx ? getScrollText(stock[lastIdx]!) : null;
    const top = buildTop(topScroll);
    const bottom = buildBottom(bottomScroll);

    const pad = ' '.repeat(CONFIG.BOX_PAD_X);

    // Body lines (between first and last border).
    const body: string[] = [];
    let isFirst = true;
    for (let i = 0; i < stock.length; i++) {
      if (i === firstIdx || i === lastIdx) continue;
      if (lastIdx !== -1 && i > lastIdx) continue;
      const vw = visibleWidth(stock[i]!);
      const fill = vw < contentWidth ? ' '.repeat(contentWidth - vw) : '';
      const prefixStr = isFirst ? this.accent(CONFIG.PREFIX) : ' ';
      body.push(this.border(c.side) + pad + prefixStr + pad + stock[i]! + fill + pad + this.border(c.side));
      isFirst = false;
    }

    // Menu lines (after last border).
    const menu: string[] = [];
    if (lastIdx !== -1) {
      for (let i = lastIdx + 1; i < stock.length; i++) {
        const vw = visibleWidth(stock[i]!);
        const indent = ' '.repeat(CONFIG.EXTRA_MENU_INDENT);
        const fill = vw + CONFIG.EXTRA_MENU_INDENT < width ? ' '.repeat(width - vw - CONFIG.EXTRA_MENU_INDENT) : '';
        menu.push(indent + stock[i]! + fill);
      }
    }

    const gap = Array.from({ length: CONFIG.MENU_GAP }, () => '');
    return [top, ...body, bottom, ...gap, ...menu];
  }

  private renderUnboxed(stock: string[], contentWidth: number, width: number): string[] {
    const firstIdx = stock.findIndex(isBorderLike);
    let lastIdx = -1;
    for (let i = stock.length - 1; i >= 0; i--) {
      if (isBorderLike(stock[i]!)) {
        lastIdx = i;
        break;
      }
    }

    const buildTop = (scroll: string | null): string =>
      scroll
        ? this.border(`── ${scroll} `) + this.border('─'.repeat(Math.max(0, width - visibleWidth(`── ${scroll} `))))
        : this.border('─'.repeat(width));
    const buildBottom = buildTop; // identical for unboxed

    const topScroll = firstIdx !== -1 ? getScrollText(stock[firstIdx]!) : null;
    const bottomScroll = lastIdx !== -1 && lastIdx !== firstIdx ? getScrollText(stock[lastIdx]!) : null;
    const top = buildTop(topScroll);
    const bottom = buildBottom(bottomScroll);

    const pad = ' '.repeat(CONFIG.BOX_PAD_X);

    const body: string[] = [];
    let isFirst = true;
    for (let i = 0; i < stock.length; i++) {
      if (i === firstIdx || i === lastIdx) continue;
      if (lastIdx !== -1 && i > lastIdx) continue;
      const vw = visibleWidth(stock[i]!);
      const fill = vw < contentWidth ? ' '.repeat(contentWidth - vw) : '';
      const prefixStr = isFirst ? this.accent(CONFIG.PREFIX) : ' ';
      body.push(pad + prefixStr + pad + stock[i]! + fill);
      isFirst = false;
    }

    const menu: string[] = [];
    if (lastIdx !== -1) {
      for (let i = lastIdx + 1; i < stock.length; i++) {
        const vw = visibleWidth(stock[i]!);
        const indent = ' '.repeat(CONFIG.EXTRA_MENU_INDENT);
        const fill = vw + CONFIG.EXTRA_MENU_INDENT < width ? ' '.repeat(width - vw - CONFIG.EXTRA_MENU_INDENT) : '';
        menu.push(indent + stock[i]! + fill);
      }
    }

    const gap = Array.from({ length: CONFIG.MENU_GAP }, () => '');
    return [top, ...body, bottom, ...gap, ...menu];
  }
}

// ─── Extension entry ──────────────────────────────────────────────────────

// Terminal focus tracking — delineates the focused tmux pane. We enable
// terminal focus reporting (DECSET 1004) so tmux (with `focus-events on`)
// sends CSI I / CSI O when this pane gains/loses focus, and swap the border
// colour accordingly. pi itself never enables 1004, so we must both enable
// it and clean it up on exit — otherwise the shell inherits a mode that
// spews `[I`/`[O` into the prompt.

const FOCUS_IN = '\x1b[I';
const FOCUS_OUT = '\x1b[O';

let paneFocused = true;
let removeFocusListener: (() => void) | undefined;
let exitHookInstalled = false;

function enableFocusTracking(tui: TUI): void {
  process.stdout.write('\x1b[?1004h');
  if (!exitHookInstalled) {
    exitHookInstalled = true;
    process.on('exit', () => {
      try {
        process.stdout.write('\x1b[?1004l');
      } catch {
        /* stdout gone */
      }
    });
  }
  removeFocusListener?.();
  removeFocusListener = tui.addInputListener((data) => {
    const inIdx = data.lastIndexOf(FOCUS_IN);
    const outIdx = data.lastIndexOf(FOCUS_OUT);
    if (inIdx === -1 && outIdx === -1) return undefined;
    paneFocused = inIdx > outIdx;
    tui.requestRender();
    const stripped = data.replaceAll(FOCUS_IN, '').replaceAll(FOCUS_OUT, '');
    return stripped.length === 0 ? { consume: true } : { data: stripped };
  });
}

function disableFocusTracking(): void {
  try {
    process.stdout.write('\x1b[?1004l');
  } catch {
    /* stdout gone */
  }
  removeFocusListener?.();
  removeFocusListener = undefined;
  paneFocused = true;
}

export default function chatInput(pi: ExtensionAPI) {
  pi.on('session_start', (_event, ctx: ExtensionContext) => {
    if (ctx.mode !== 'tui') return;
    ctx.ui.setEditorComponent((tui, theme, kb) => {
      const baseBorder = (s: string) => applyColor(ctx.ui.theme, CONFIG.BORDER_COLOR, s);
      const focusBorder = (s: string) => applyColor(ctx.ui.theme, CONFIG.FOCUSED_BORDER_COLOR, s);
      const borderFn = CONFIG.FOCUS_INDICATOR
        ? (s: string) => (paneFocused ? focusBorder(s) : baseBorder(s))
        : baseBorder;
      const accentFn = (s: string) => applyColor(ctx.ui.theme, CONFIG.PREFIX_COLOR, s);
      if (CONFIG.FOCUS_INDICATOR) enableFocusTracking(tui);
      return new ChatInput(tui, theme, kb, borderFn, accentFn);
    });
  });

  pi.on('session_shutdown', (_event, ctx: ExtensionContext) => {
    if (ctx.mode !== 'tui') return;
    if (CONFIG.FOCUS_INDICATOR) disableFocusTracking();
    ctx.ui.setEditorComponent(undefined);
  });
}
