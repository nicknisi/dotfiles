import type { Theme, ThemeColor } from "@earendil-works/pi-coding-agent";
import { getKeybindings } from "@earendil-works/pi-tui";

export function isHexColor(color: string): boolean {
  return typeof color === "string" && color.startsWith("#");
}

export function applyColor(theme: Theme, color: string, text: string): string {
  if (isHexColor(color)) {
    const h = color.replace("#", "");
    if (!/^[0-9a-fA-F]{6}$/.test(h)) return text;
    const r = parseInt(h.slice(0, 2), 16);
    const g = parseInt(h.slice(2, 4), 16);
    const b = parseInt(h.slice(4, 6), 16);
    return `\x1b[38;2;${r};${g};${b}m${text}\x1b[39m`;
  }
  try {
    return theme.fg(color as ThemeColor, text);
  } catch {
    return text;
  }
}

export function getVisibleWidth(text: string): number {
  return text.replace(/\x1b\[[0-9;]*m/g, "").length;
}

export function formatElapsed(startedAt: number | undefined, endedAt?: number): string {
  if (!startedAt) return "";
  const ms = (endedAt ?? Date.now()) - startedAt;
  return `(${(ms / 1000).toFixed(1)}s)`;
}

export function getExpandToggleKey(): string {
  return getKeybindings().getKeys("app.tools.expand")[0] ?? "ctrl+o";
}