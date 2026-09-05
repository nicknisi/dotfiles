---
name: add-theme
description: Add a new theme pack to the dotfiles theme system (bin/theme). Use when the user pastes a theme repo URL, says "add this theme", "new theme pack", or wants another entry for theme next to cycle.
---

# Add a theme pack

One command themes everything: `bin/theme <name>` renders the pack into
`~/.local/state/theme/current/theme/` and nudges every consumer. A pack is
`themes/<name>/` and needs only:

- `colors.toml` — the contract. Either style:
  semantic (`mode`, `accent`, `background`, `foreground`, `muted`, `red`,
  `bright_red`, `dark_background`, ...) or ANSI (`accent`, `background`,
  `foreground`, `color0`-`color15`). `bin/theme-color -f colors.toml --all`
  shows the full set after aliasing and derivation; anything missing is
  mixed from what is there.
- `backgrounds/` — images. `theme <name> [N]` picks the Nth (sorted by
  name), `theme bg next` cycles. Name them `<index>-<description>.<ext>`;
  the fzf picker previews the filename.
- `theme.conf` — `TAGLINE="one line of whimsy"` (printed on switch, shown
  in the tmux cheat sheet). Optional but every pack has one.
- `icons.theme` — optional, a GTK icon theme name (Yaru-* is common);
  applied on Linux only if that icon set is installed.

Every app file (ghostty, kitty, wezterm, tmux, nvim, btop, starship, pi,
claude, hyprland borders, hyprlock, wofi, sketchybar, borders, slack) is
rendered from `themes/templates/*.tpl`. A pack may ship a file under the
same name to hand-tune one app (`hyprland.lua` for a gradient border,
`btop.theme`, ...); it wins over the template. Do NOT hand-author the rest.

Work directly in the repo (subagent worktrees don't see uncommitted
theme files and have flipped the user's live theme by running theme from
the wrong tree — do NOT run theme for validation until told, and never
from a worktree).

## Sources

- **An existing theme repo** (any `themes/<name>/` laid out as above):
  copy `colors.toml`, `backgrounds/`,
  `icons.theme`. Skip `neovim.lua`, `vscode.json`, `preview*.png`,
  `unlock.png`, `shell*.toml`, `keyboard.rgb`, `chromium.theme`. Keep a
  shipped `btop.theme`; keep a shipped `hyprland.lua` only if it is plain
  `hl.config` (the `o.window(...)` helper style some repos use does not
  exist here). An
  older theme with only `alacritty.toml` and no `colors.toml`: transcribe
  its `[colors.*]` into ANSI-style `colors.toml`.
- **Just a wallpaper**: `bin/theme from-image <name> <image>` writes
  `colors.toml` + `backgrounds/` + an empty `theme.conf`. The hue mapping
  is heuristic — eyeball the swatches it prints and hand-tune slots.

Then write `theme.conf` with a TAGLINE in the house style (see
`themes/*/theme.conf`: short, lower-case, a little wry).

## Validate (no theme run)

```
bin/theme-color -f themes/<name>/colors.toml --all        # no error, sane mode
bin/theme-color -f themes/<name>/colors.toml --name <name> --render /tmp/x themes/templates/*.tpl
jq empty /tmp/x/*.json; bash -n /tmp/x/*.sh
ghostty +validate-config --config-file=/tmp/x/ghostty.conf
```
A rendered file containing `{{` means a template names a key the resolver
does not produce; fix the template, not the pack.

## Hand verification to the user or ask before switching

`theme <name> [N]`, then: `tmux show-option -gqv @thm_pink` == accent;
`cat ~/.local/state/theme/current/mode`; `jq -r .theme ~/.claude/settings.json`
== `custom:<name>`. Linux: `hyprctl getoption general:col.active_border`,
`gsettings get org.gnome.desktop.interface color-scheme`. macOS: sketchybar
border colour, wallpaper after a few seconds. Pi applies on next launch.

## Commit on the active theme branch and push.

## Removing a theme

`git rm -r themes/<name>/`, then `theme <other>`. The rendered
`~/.pi/agent/themes/<name>.json` and `~/.claude/themes/<name>.json` can go
too.
