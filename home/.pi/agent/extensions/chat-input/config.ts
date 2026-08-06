/** Config for chat-input — loaded once at extension load from ~/.pi/agent/configs/chat-input.json. */

import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

export const DEFAULT_CONFIG = {
  /** Full box with side borders, or top/bottom horizontal rules only. */
  BOXED_VIEW: true,
  /** Horizontal padding inside the box (and around the prefix). */
  BOX_PAD_X: 1,
  /** Blank lines between the bottom border and the slash-menu. */
  MENU_GAP: 0,
  /** Extra indent (spaces) for slash-menu lines. */
  EXTRA_MENU_INDENT: 1,
  /** Theme colour token or hex for the box border. */
  BORDER_COLOR: 'border',
  /** Prefix glyph shown on the first body line. */
  PREFIX: '❯',
  /** Theme colour token or hex for the prefix. */
  PREFIX_COLOR: 'accent',
  /** Corner style: "rounded" (╭╮│╰╯) or "square" (┌┐│└┘). */
  CORNERS: 'rounded' as const,
  /** Restyle the border when this pane has terminal focus (needs tmux focus-events). */
  FOCUS_INDICATOR: true,
  /** Theme colour token or hex for the border while the pane is focused. */
  FOCUSED_BORDER_COLOR: 'accent',
};

interface ChatInputUserConfig {
  boxedView?: boolean;
  boxPadX?: number;
  menuGap?: number;
  extraMenuIndent?: number;
  borderColor?: string;
  prefix?: string;
  prefixColor?: string;
  corners?: 'rounded' | 'square';
  focusIndicator?: boolean;
  focusedBorderColor?: string;
}

const CONFIG_PATH = join(homedir(), '.pi', 'agent', 'configs', 'chat-input.json');

function loadUserConfig(): ChatInputUserConfig {
  try {
    return JSON.parse(readFileSync(CONFIG_PATH, 'utf8'));
  } catch {
    return {};
  }
}

const u = loadUserConfig();

export const CONFIG = {
  BOXED_VIEW: u.boxedView ?? DEFAULT_CONFIG.BOXED_VIEW,
  BOX_PAD_X: u.boxPadX ?? DEFAULT_CONFIG.BOX_PAD_X,
  MENU_GAP: u.menuGap ?? DEFAULT_CONFIG.MENU_GAP,
  EXTRA_MENU_INDENT: u.extraMenuIndent ?? DEFAULT_CONFIG.EXTRA_MENU_INDENT,
  BORDER_COLOR: u.borderColor ?? DEFAULT_CONFIG.BORDER_COLOR,
  PREFIX: u.prefix ?? DEFAULT_CONFIG.PREFIX,
  PREFIX_COLOR: u.prefixColor ?? DEFAULT_CONFIG.PREFIX_COLOR,
  CORNERS: (u.corners === 'square' ? 'square' : 'rounded') as 'rounded' | 'square',
  FOCUS_INDICATOR: u.focusIndicator ?? DEFAULT_CONFIG.FOCUS_INDICATOR,
  FOCUSED_BORDER_COLOR: u.focusedBorderColor ?? DEFAULT_CONFIG.FOCUSED_BORDER_COLOR,
};
