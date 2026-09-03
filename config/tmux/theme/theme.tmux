#!/usr/bin/env bash
# Tmux theme — follows the active desktop theme.
#
# Source priority:
#   1. Omarchy (Linux): ~/.local/state/omarchy/current/theme/colors.toml —
#      rewritten by `omarchy theme set`; the palette below is derived from it.
#   2. macOS: ~/.config/theme/current/tmux-{dark,light}.sh — hand-tuned
#      scripts shipped in bin/theme packs.
#   3. Checked-in fallback: colors/{dark,light}.sh.
#
# Live reload: bin/theme re-sources tmux.conf on macOS. On Omarchy install the
# hook shipped next to this file (it re-sources tmux.conf on theme changes):
#   omarchy hook install theme-set <dotfiles>/config/tmux/theme/omarchy-hook.sh

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# read `key = "value"` from a colors.toml
toml_get() {
  sed -n 's/^'"$2"'[[:space:]]*=[[:space:]]*"\(.*\)".*$/\1/p' "$1" 2>/dev/null | head -n1
}

# print $1 unless empty, else $2
or_default() {
  if [[ -n "$1" ]]; then printf '%s' "$1"; else printf '%s' "$2"; fi
}

set_thm() { tmux set-option -gq "@thm_$1" "$2"; }

OMARCHY_COLORS="$HOME/.local/state/omarchy/current/theme/colors.toml"

if [[ -f "$OMARCHY_COLORS" ]]; then
  # ── Omarchy: derive the palette from the active theme ────────────────────
  g() { toml_get "$OMARCHY_COLORS" "$1"; }

  thm_bg=$(g background)
  thm_fg=$(g foreground)
  accent=$(or_default "$(g accent)" "$thm_fg")
  muted=$(or_default "$(g muted)" "$thm_bg")
  dark_bg=$(or_default "$(g dark_background)" "$thm_bg")
  magenta=$(or_default "$(g magenta)" "$accent")
  red=$(or_default "$(g red)" "$thm_fg")
  green=$(or_default "$(g green)" "$thm_fg")

  set_thm bg              "$thm_bg"
  set_thm bg_dark         "$dark_bg"
  set_thm bg_dark1        "$(or_default "$(g darker_background)" "$dark_bg")"
  set_thm bg_highlight    "$(or_default "$(g lighter_background)" "$thm_bg")"
  set_thm fg              "$thm_fg"
  set_thm fg_dark         "$(or_default "$(g dark_foreground)" "$thm_fg")"
  set_thm fg_gutter       "$muted"
  set_thm cyan            "$(or_default "$(g bright_cyan)" "$(or_default "$(g cyan)" "$thm_fg")")"
  set_thm black           "$dark_bg"
  set_thm magenta         "$magenta"
  set_thm magenta2        "$(or_default "$(g bright_magenta)" "$magenta")"
  set_thm pink            "$accent"
  set_thm red             "$red"
  set_thm red1            "$(or_default "$(g bright_red)" "$red")"
  set_thm green           "$green"
  set_thm green1          "$(or_default "$(g bright_green)" "$green")"
  set_thm green2          "$(or_default "$(g bright_green)" "$green")"
  set_thm yellow          "$(or_default "$(g bright_yellow)" "$(or_default "$(g yellow)" "$thm_fg")")"
  set_thm blue            "$(or_default "$(g bright_blue)" "$(or_default "$(g blue)" "$accent")")"
  set_thm blue0           "$dark_bg"
  set_thm blue1           "$(or_default "$(g bright_blue)" "$(or_default "$(g blue)" "$accent")")"
  set_thm blue2           "$(or_default "$(g bright_blue)" "$(or_default "$(g blue)" "$accent")")"
  set_thm blue5           "$(or_default "$(g light_foreground)" "$thm_fg")"
  set_thm blue6           "$(or_default "$(g bright_foreground)" "$thm_fg")"
  set_thm blue7           "$dark_bg"
  set_thm orange          "$(or_default "$(g orange)" "$(or_default "$(g bright_yellow)" "$thm_fg")")"
  set_thm purple          "$accent"
  set_thm black4          "$muted"
  set_thm comment         "$muted"
  set_thm dark3           "$muted"
  set_thm dark5           "$muted"
  set_thm teal            "$(or_default "$(g cyan)" "$thm_fg")"
  set_thm terminal_black  "$dark_bg"
elif [[ "$(uname -s)" == "Darwin" ]]; then
  # ── macOS: hand-tuned scripts from the active bin/theme pack ─────────────
  if [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" == "Dark" ]]; then
    MODE=dark
  else
    MODE=light
  fi
  THEME_COLORS="$HOME/.config/theme/current/tmux-$MODE.sh"
  [[ -f "$THEME_COLORS" ]] || THEME_COLORS="$CURRENT_DIR/colors/$MODE.sh"
  # shellcheck disable=SC1090
  source "$THEME_COLORS"
else
  # ── Neither: checked-in fallback (assume dark) ───────────────────────────
  # shellcheck disable=SC1091
  source "$CURRENT_DIR/colors/dark.sh"
fi

# Get colors from tmux user options
get_tmux_option() {
  local option=$1
  tmux show-option -gqv "$option"
}

# Retrieve colors
thm_bg=$(get_tmux_option "@thm_bg")
thm_bg_dark=$(get_tmux_option "@thm_bg_dark")
thm_bg_dark1=$(get_tmux_option "@thm_bg_dark1")
thm_bg_highlight=$(get_tmux_option "@thm_bg_highlight")
thm_fg=$(get_tmux_option "@thm_fg")
thm_fg_dark=$(get_tmux_option "@thm_fg_dark")
thm_fg_gutter=$(get_tmux_option "@thm_fg_gutter")
thm_cyan=$(get_tmux_option "@thm_cyan")
thm_black=$(get_tmux_option "@thm_black")
thm_magenta=$(get_tmux_option "@thm_magenta")
thm_magenta2=$(get_tmux_option "@thm_magenta2")
thm_pink=$(get_tmux_option "@thm_pink")
thm_red=$(get_tmux_option "@thm_red")
thm_red1=$(get_tmux_option "@thm_red1")
thm_green=$(get_tmux_option "@thm_green")
thm_green1=$(get_tmux_option "@thm_green1")
thm_green2=$(get_tmux_option "@thm_green2")
thm_yellow=$(get_tmux_option "@thm_yellow")
thm_blue=$(get_tmux_option "@thm_blue")
thm_blue0=$(get_tmux_option "@thm_blue0")
thm_blue1=$(get_tmux_option "@thm_blue1")
thm_blue2=$(get_tmux_option "@thm_blue2")
thm_blue5=$(get_tmux_option "@thm_blue5")
thm_blue6=$(get_tmux_option "@thm_blue6")
thm_blue7=$(get_tmux_option "@thm_blue7")
thm_orange=$(get_tmux_option "@thm_orange")
thm_purple=$(get_tmux_option "@thm_purple")
thm_black4=$(get_tmux_option "@thm_black4")
thm_comment=$(get_tmux_option "@thm_comment")
thm_dark3=$(get_tmux_option "@thm_dark3")
thm_dark5=$(get_tmux_option "@thm_dark5")
thm_teal=$(get_tmux_option "@thm_teal")
thm_terminal_black=$(get_tmux_option "@thm_terminal_black")

# Status bar configuration
tmux set -g status-position top
tmux set -g status-bg "default"
tmux set -g status-justify "left"
tmux set -g status-left-length 100
tmux set -g status-right-length 100

# Messages
tmux set -g message-style "fg=${thm_cyan},bg=${thm_fg_gutter},align=centre"
tmux set -g message-command-style "fg=${thm_cyan},bg=${thm_fg_gutter},align=centre"

# Canonical palette — packs name their knobs differently (catppuccin ships
# pink/mauve/subtext_0, tokyo-night purple/fg_dark/fg_gutter, omarchy
# derives pink from the theme accent), so fall down each chain to a value.
sl_accent=$(or_default "$(get_tmux_option "@thm_pink" "")" \
  "$(or_default "$(get_tmux_option "@thm_mauve" "")" \
  "$(or_default "$thm_purple" "$(or_default "$thm_magenta" "$thm_cyan")")")")
sl_dim=$(or_default "$thm_fg_dark" \
  "$(or_default "$(get_tmux_option "@thm_subtext_0" "")" "$thm_fg")")
sl_muted=$(or_default "$thm_fg_gutter" \
  "$(or_default "$(get_tmux_option "@thm_overlay_0" "")" "$sl_dim")")

# Publish for downstream helpers (bin/tmux-git-status reads these).
set_thm sl_accent "$sl_accent"
set_thm sl_dim    "$sl_dim"
set_thm sl_muted  "$sl_muted"

# Pane borders
tmux set-window-option -g pane-active-border-style "fg=${thm_fg_gutter},bg=${thm_fg_gutter}"
tmux set-window-option -g pane-border-style "fg=${thm_fg_gutter},bg=${thm_fg_gutter}"
tmux set-window-option -g pane-border-lines simple

# Status line — a quiet, glyph-driven bar on a transparent canvas:
#
#   projects ◉ │ ◇ dotfiles  ◆ π statusline  ◇ notes          main ✓
#
# No pills, no powerline: bg=default keeps the terminal's own background as
# the canvas, so emoji and nerd-font icons in session/window names can't
# punch holes in a background that isn't there. Every mark earns its keep:
# fleet's glyph (◉ working, ⚠ waiting, ? asking, ● ready — fleet-colored)
# appears beside the session only when an agent in it wants you; row 2
# (fleet statusline --inject) carries the per-agent detail. ◆ marks the
# current window, ◇ the others, a bell paints a window red.

tmux set -g status-style "bg=default,fg=${thm_fg}"

# The canvas is the canvas — panes never paint over the terminal's own
# background (ghostty runs at 0.85 opacity; an opaque pane bg kills it).
tmux set -g window-style "fg=default,bg=default"
tmux set -g window-active-style "fg=default,bg=default"
tmux setw -g window-status-separator "  "
bell_name="#{?window_bell_flag,#[fg=${thm_red}]#[bold],}"
tmux setw -g window-status-format \
  "#[fg=${sl_dim}]◇ ${bell_name}#{?#{window_name},#{=/32/…:window_name},#{b:pane_current_path}}"
tmux setw -g window-status-current-format \
  "#[fg=${sl_accent},bold]◆ ${bell_name}#[bold,fg=${thm_fg}]#{?#{window_name},#{=/32/…:window_name},#{b:pane_current_path}}#{?window_zoomed_flag,#[fg=${thm_orange}]#[nobold]⊕,}#{?pane_synchronized,#[fg=${thm_red}]#[nobold]⇄,}"

# Left: the italic session name in its own color (hashed from the name
# against the theme palette — every session carries an identity; switching
# sessions changes the bar's mood), then a hairline before the window
# list. fleet's glyph floods the cluster in fleet's colors only when an
# agent in this session wants you. Holding prefix lights a yellow ^A.
# NB: inside #{?...} branches, never put a comma inside a #[style] — tmux
# splits branches on every comma and silently eats what follows.
tmux set -g status-left "#{?client_prefix,#[fg=${thm_yellow}]#[bold]^^A #[nobold],}#($HOME/.config/tmux/../../bin/tmux-session-mood '#{session_name}')#[italics]#S#[noitalics,nobold,fg=${sl_muted}]│ "

# Right: git — branch + status glyphs, self-styled by bin/tmux-git-status
# against this same palette. Called through the ~/.config/tmux symlink
# because #(...) inherits the tmux *server's* PATH, which can go stale
# (run `tmux display -p '#{T;=/100:status-right}'` to see it live).
tmux set -g status-right "#($HOME/.config/tmux/../../bin/tmux-git-status '#{pane_current_path}')"

# Clock mode
tmux setw -g clock-mode-colour "${thm_blue0}"
