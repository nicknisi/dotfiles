---
name: add-theme
description: Add a new named theme pack to the dotfiles theme system (bin/theme-set). Use when the user pastes an omarchy/omacosy-style theme repo URL, says "add this theme", "new theme pack", or wants another entry for theme-set/theme-next to cycle.
---

# Add a theme pack

One command themes everything: `bin/theme-set <name>` swaps
`~/.config/theme/current` -> `themes/<name>/` and nudges consumers.
A pack is FULLY self-contained in `themes/<name>/` — deleting the
directory deletes the theme (theme-set regenerates starship palettes
from whatever packs remain). ALL files below are required — every
past pack forgot one (starship was missed for shadesofjade).

Work directly in the repo (subagent worktrees don't see uncommitted
theme files and have flipped the user's live theme by running
theme-set from the wrong tree — do NOT run theme-set for validation
until told, and never from a worktree).

## 1. Source the palette

Two entry points:

- **Upstream repo** (the common case): fetch it (fetch_content clones
  to /tmp/pi-github-repos/), take `colors.toml` and `backgrounds/`.
- **Just a wallpaper, no repo**: run `bin/theme-from-image <name>
  <image>` first. It extracts colors.toml + backgrounds/ from the
  image; continue below with what it wrote. Eyeball the palette
  first — the hue mapping is heuristic, hand-tune colors.toml if a
  slot looks wrong.

The repo's `colors.toml` (accent, background,
foreground, color0-15) drives everything. If it ships a `neovim.lua`
using `bjarneo/aether.nvim`, that file holds the extended palette
(bg variants, muted, bright_*) needed for nvim + pi + claude JSONs.

## 2. themes/<name>/ files

Copy from the closest existing pack (tokyo-night = dark+light
reference, shadesofjade = dark-only reference):

- `colors.toml` — copied verbatim from upstream
- `backgrounds/` — all images (theme-set <name> [N] picks one).
  Rename each to `<index>-<description>.<ext>` (1-first keeps the
  upstream default first): read every image and describe its content,
  e.g. `1-jade-dragon-statue.jpg`, `2-monk-moon-umbrella.jpg`.
  The fzf wallpaper picker previews the filename, so numbered-only
  names (BG1, 1.jpg) are a miss.
- `theme.conf` — PI_DARK, PI_LIGHT, CLAUDE_DARK, CLAUDE_LIGHT, TAGLINE
  (one-line whimsy, printed on switch). Dark-only: PI_LIGHT= and
  CLAUDE_LIGHT= empty.
- `ghostty.conf` — check `ghostty +list-themes | grep -i <name>`:
  built-in exists -> `theme = dark:X,light:Y` line; no built-in ->
  inline keys (background, foreground, cursor-color,
  selection-background/foreground, `palette = N=#hex` for 0-15).
  Always append the dock icon block: macos-icon = custom-style,
  ghost-color = accent, screen-color = background.
- `nvim-dark` — one line: the colorscheme name. `nvim-light` too if
  the theme has a light variant. If upstream uses aether.nvim, the
  name is `aether` AND you must write `nvim-aether.json` (the full
  colors table from upstream neovim.lua) — aether is shared by several
  packs, the palette lives in the pack, not the plugin spec. Other
  colorschemes need their plugin present in
  config/nvim/lua/nisi/plugins/colorscheme.lua (lazy); add if missing.
- `tmux-dark.sh` — `tmux set -g @thm_*` setters, exact style of
  themes/tokyo-night/tmux-dark.sh (thm_blue <- accent). tmux-light.sh
  only if a light variant exists.
- `sketchybar.sh` — FULL var set from themes/tokyo-night/sketchybar.sh
  (FG, GLOW_* = accent at ff/d9/40/24/14 alphas, BAR_COLOR 0xcc+bg,
  hues with _BORDER 0xe6 / _FILL 0x1f, CALM_GREEN 0x8c+green,
  INK 0xff+bg, TRANSPARENT). Accent = colors.toml accent.
- `borders.sh` — ACTIVE_COLOR=0xff<accent>, INACTIVE_COLOR=0xff<color8>
- `btop.theme` — `theme[key]="#hex"` rows, mechanical from
  colors.toml (copy themes/void/btop.theme's shape): main_bg/bg,
  main_fg+title/fg, hi_fg+selected_fg/accent, selected_bg+meter_bg/
  color0, boxes+div_line+inactive_fg+graph_text/color8, every
  meter+graph trio start=colorN, mid=color3, end=color1
- `wezterm.lua` — `return { foreground, background, cursor_bg,
  cursor_border, cursor_fg, selection_bg, selection_fg, ansi =
  {color0-7}, brights = {color8-15} }` — straight from colors.toml
  (copy themes/sakura/wezterm.lua's shape). theme-set copies it to
  ~/.config/wezterm/theme-current.lua, which wezterm.lua watches.
- `slack.txt` — 8 comma-separated hexes: columnBG, menuBGHover,
  activeItem (accent), activeItemText (bg), hoverItem, text (fg),
  presence (green), mentionBadge (red)

## 3. In-pack consumer JSONs

Named by variant, installed by theme-set into the live dirs under the
name theme.conf points at (PI_DARK=tokyonight-night <- pi-dark.json):

- `pi-dark.json` (and `pi-light.json` if a light variant exists) —
  copy shape of themes/tokyo-night/pi-dark.json (vars block + every
  colors key). `colors.border` MUST differ from `colors.accent`
  (border=fgDark, accent=the loud color): the composer extension's
  focus indicator flips border->accent on pane focus; equal values
  silently kill it.
- `claude-dark.json` (and `claude-light.json` likewise) — copy shape
  of themes/tokyo-night/claude-dark.json, every override key, colors
  as rgb(r,g,b); base dark
- `starship.palette` — 7 lines: accent, red, green, yellow, magenta,
  cyan, muted (hex values). theme-set rebuilds the [palettes.*]
  section of config/starship.toml from these — never edit that
  section by hand.

Do NOT add JSONs to home/.pi/agent/themes or home/.claude/themes for
packs — those dirs are for standalone (non-pack) themes only.

## 4. Validate (no theme-set run)

`bash -n` every .sh; `jq empty` every .json; `starship explain
>/dev/null`. For ghostty: `ghostty +validate-config
--config-file=themes/<name>/ghostty.conf`.

## 5. Hand verification to the user or ask before switching

`./bin/theme-set <name> [N]`, then confirm: `tmux show-option -gqv
@thm_blue` == accent; `sketchybar --query bar | jq -r .border_color`
== 0x3d<accent>; wallpaper takes ~5s (async, out-of-order applies
possible on rapid switches); `jq -r .theme` on both settings.json.
Ghostty needs restart for dock icon; pi/claude apply next launch.

## 6. Commit on the active theme branch and push.

## Removing a theme

`git rm -r themes/<name>/` + `rm ~/.pi/agent/themes/<pi-name>.json
~/.claude/themes/<claude-name>.json`, then run theme-set once (any
theme) — starship.toml self-heals without it.
