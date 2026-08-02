/**
 * Box Editor Extension
 *
 * Wraps pi's input editor in a rounded box (╭╮│╰╯) by post-processing
 * the Editor's rendered output. The default editor only draws horizontal
 * borders above and below the input; this adds vertical sides and rounded
 * corners so the input box reads as a contained frame.
 *
 * How it works:
 *   - BoxEditor extends CustomEditor and overrides render(width).
 *   - super.render(width) produces: [topBorder, ...contentLines, bottomBorder,
 *     ...autocompleteLines]. The top/bottom borders are full-width ─ lines
 *     (or a scroll indicator like "─── ↑ N more ───"); content lines are
 *     padded with leftPadding/rightPadding spaces (editorPaddingX=1 makes
 *     those single spaces); autocomplete lines render below the box.
 *   - We detect the top border (line 0) and bottom border (last line that
 *     starts with ─), boxify those with ╭╮ / ╰╯, and wrap each content line's
 *     sides with │. Autocomplete lines are left untouched — they belong to
 *     the dropdown below the box, not the box itself.
 *   - sliceByColumn handles ANSI preservation (cursor highlight, colors)
 *     while we swap the first and last visible columns.
 *
 * Everything else (keybindings, handlers, autocomplete provider, paddingX,
 * borderColor) is wired up by pi when setEditorComponent creates the editor.
 */

import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { CustomEditor } from "@earendil-works/pi-coding-agent";
import { sliceByColumn, visibleWidth } from "@earendil-works/pi-tui";
import { sanitizeTerminalLabel } from "./tui-utils.ts";

// Strip ANSI so we can inspect a rendered line's visible characters.
// Border lines are SGR-colored only, so the tui-utils sanitizer is more than
// enough here.
function visibleText(line: string): string {
  return sanitizeTerminalLabel(line);
}

/** True for the editor's horizontal border lines (plain ─ or scroll indicator). */
function isBorderLine(line: string): boolean {
  const s = visibleText(line);
  return s.startsWith("─") && (s.endsWith("─") || s.includes("more"));
}

/**
 * Replace the first and last visible columns of `line` with `left`/`right`,
 * preserving all interior ANSI (cursor highlight, etc.). The result is exactly
 * `width` visible columns. Uses sliceByColumn to drop columns 0 and width-1
 * and keep everything in between, then pads the inner to width-2.
 */
function boxify(
  line: string,
  width: number,
  left: string,
  right: string,
  border: (s: string) => string,
): string {
  if (width < 3) return line;
  const inner = sliceByColumn(line, 1, width - 2);
  const innerW = visibleWidth(inner);
  const padded = inner + " ".repeat(Math.max(0, width - 2 - innerW));
  return border(left) + padded + border(right);
}

class BoxEditor extends CustomEditor {
  render(width: number): string[] {
    const lines = super.render(width);
    if (width < 3 || lines.length === 0) return lines;

    const border = this.borderColor;
    if (!border) return lines;

    // Top border is always line 0. Find the bottom border by scanning from the
    // end: autocomplete lines (if any) follow it and don't start with ─.
    let bottomIndex = -1;
    for (let i = lines.length - 1; i >= 1; i -= 1) {
      if (isBorderLine(lines[i]!)) {
        bottomIndex = i;
        break;
      }
    }
    if (bottomIndex === -1) bottomIndex = lines.length - 1;

    lines[0] = boxify(lines[0]!, width, "╭", "╮", border);
    lines[bottomIndex] = boxify(lines[bottomIndex]!, width, "╰", "╯", border);
    for (let i = 1; i < bottomIndex; i += 1) {
      lines[i] = boxify(lines[i]!, width, "│", "│", border);
    }
    return lines;
  }
}

export default function boxEditor(pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx: ExtensionContext) => {
    if (ctx.mode !== "tui") return;
    ctx.ui.setEditorComponent(
      (tui, theme, keybindings) => new BoxEditor(tui, theme, keybindings, {}),
    );
  });

  pi.on("session_shutdown", (_event, ctx: ExtensionContext) => {
    if (ctx.mode === "tui") ctx.ui.setEditorComponent(undefined);
  });
}
