import type { Theme, ThemeColor } from "@earendil-works/pi-coding-agent";

const ANSI_RE = /\x1b\[[0-9;]*m|\x1b\[0?m/g;

/** Strip ANSI escapes so we can inspect a rendered line's visible characters. */
export function plainText(line: string): string {
  return line.replace(ANSI_RE, "");
}

function isHexColor(color: string): boolean {
  return color.startsWith("#");
}

function hexToAnsi(hex: string): string {
  const h = hex.replace("#", "");
  if (!/^[0-9a-fA-F]{6}$/.test(h)) return "";
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  return `\x1b[38;2;${r};${g};${b}m`;
}

/** Apply a colour by theme token or hex value. Hex takes precedence. */
export function applyColor(theme: Theme, color: string, text: string): string {
  if (isHexColor(color)) {
    const seq = hexToAnsi(color);
    return seq ? `${seq}${text}\x1b[0m` : text;
  }
  try {
    return theme.fg(color as ThemeColor, text);
  } catch {
    return text;
  }
}
