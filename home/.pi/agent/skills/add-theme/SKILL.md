---
name: add-theme
description: Add a new named theme pack to the dotfiles theme system (bin/theme-set). Use when the user pastes an omarchy/omacosy-style theme repo URL, says "add this theme", "new theme pack", or wants another entry for theme-set/theme-next to cycle.
---

# Add a theme pack

One command themes everything: `bin/theme-set <name>` swaps
`~/.config/theme/current` -> `themes/<name>/` and nudges consumers.
A pack is a directory in `themes/` plus three files outside it
(pi/claude theme JSONs, starship palette). ALL steps are required —
every past pack forgot one (starship was missed for shadesofjade).

Work directly in the repo (subagent worktrees don't see uncommitted
theme files and have flipped the user's live theme by running
theme-set from the wrong tree — do NOT run theme-set for validation
until told, and never from a worktree).

## 1. Source the palette

Fetch the upstream theme repo (fetch_content clones it to
/tmp/pi-github-repos/). Take `colors.toml` (accent, background,
foreground, color0-15) and `backgrounds/`. If it ships a `neovim.lua`
using `bjarneo/aether.nvim`, that file holds the extended palette
(bg variants, muted, bright_*) needed for nvim + pi + claude JSONs.

## 2. themes/<name>/ files

Copy from the closest existing pack (tokyo-night = dark+light
reference, shadesofjade = dark-only reference):

- `colors.toml` — copied verbatim from upstream
- `backgrounds/` — all images (theme-set <name> [N] picks one)
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
- `slack.txt` — 8 comma-separated hexes: columnBG, menuBGHover,
  activeItem (accent), activeItemText (bg), hoverItem, text (fg),
  presence (green), mentionBadge (red)

## 3. Outside themes/

- `home/.pi/agent/themes/<name>.json` — copy shape of
  tokyonight-night.json (vars block + every colors key)
- `home/.claude/themes/<name>.json` — copy shape of tokyo-night.json,
  every override key, colors as rgb(r,g,b); base dark. Light variant
  file only if the theme has one (see tokyo-night-day.json)
- `config/starship.toml` — add `[palettes.<name>]` with keys accent,
  red, green, yellow, magenta, cyan, muted. Do not touch others.

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
