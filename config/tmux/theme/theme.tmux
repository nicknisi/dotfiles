#!/usr/bin/env bash
# Tmux theme — follows the active desktop theme.
#
# Source priority:
#   1. Linux: ~/.local/state/theme/current/colors.toml — rewritten by
#      bin/theme (this repo owns the state path now, not Omarchy).
#   2. macOS: ~/.config/theme/current/tmux-{dark,light}.sh — hand-tuned
#      scripts shipped in bin/theme packs.
#   3. Checked-in fallback: colors/{dark,light}.sh.
#
# Live reload: bin/theme re-sources tmux.conf on macOS. On Omarchy install the
# hook shipped next to this file (it re-sources tmux.conf on theme changes):
#   omarchy hook install theme-set <dotfiles>/config/tmux/theme/omarchy-hook.sh

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# #(...) and run-shell inherit the tmux *server's* PATH, which goes stale across
# repo moves — so helpers are addressed through the ~/.config/tmux symlink.
BIN="$HOME/.config/tmux/../../bin"

# read `key = "value"` from a colors.toml
toml_get() {
  sed -n 's/^'"$2"'[[:space:]]*=[[:space:]]*"\(.*\)".*$/\1/p' "$1" 2>/dev/null | head -n1
}

# print $1 unless empty, else $2
or_default() {
  if [[ -n "$1" ]]; then printf '%s' "$1"; else printf '%s' "$2"; fi
}

set_thm() { tmux set-option -gq "@thm_$1" "$2"; }

# Clean slate. Packs set different keys (catppuccin pink/mauve, tokyo-night
# purple/comment) and `set -g` only overwrites what the new pack names, so a
# theme switch used to leave the old pack's leftovers for the fallback chains
# below to find. One batched tmux call unsets every @thm_* first.
stale=()
while read -r key _; do stale+=(set-option -gqu "$key" \;); done < <(tmux show-options -g 2>/dev/null | grep '^@thm_')
((${#stale[@]})) && tmux "${stale[@]:0:${#stale[@]}-1}"

OMARCHY_COLORS="$HOME/.local/state/theme/current/colors.toml"

if [[ -f "$OMARCHY_COLORS" ]]; then
  # ── Omarchy: derive the palette from the active theme ────────────────────
  # colors.toml (basecamp/omarchy themes/*/colors.toml) carries accent,
  # foreground, background, cursor, selection_* and color0-15 — nothing named
  # "red" or "muted". Named keys are still read first in case a theme ships
  # them; otherwise the ANSI slots fill in: 1 red 2 green 3 yellow 4 blue
  # 5 magenta 6 cyan, 9-14 their bright variants, 8 bright black, 7 dim fg.
  # Backgrounds keep their original derivation (fg_gutter feeds pane borders).
  g() { toml_get "$OMARCHY_COLORS" "$1"; }
  slot() { or_default "$(g "$1")" "$(g "$2")"; } # named key, else colorN

  thm_bg=$(g background)
  thm_fg=$(g foreground)
  accent=$(or_default "$(g accent)" "$thm_fg")
  muted=$(or_default "$(g muted)" "$thm_bg")
  dark_bg=$(or_default "$(g dark_background)" "$thm_bg")
  bright_black=$(or_default "$(g color8)" "$muted")
  dim_fg=$(or_default "$(slot dark_foreground color7)" "$thm_fg")
  bright_fg=$(or_default "$(slot bright_foreground color15)" "$thm_fg")
  red=$(or_default "$(slot red color1)" "$thm_fg")
  green=$(or_default "$(slot green color2)" "$thm_fg")
  yellow=$(or_default "$(slot yellow color3)" "$thm_fg")
  blue=$(or_default "$(slot blue color4)" "$accent")
  magenta=$(or_default "$(slot magenta color5)" "$accent")
  cyan=$(or_default "$(slot cyan color6)" "$thm_fg")
  bright_red=$(or_default "$(slot bright_red color9)" "$red")
  bright_green=$(or_default "$(slot bright_green color10)" "$green")
  bright_blue=$(or_default "$(slot bright_blue color12)" "$blue")
  bright_magenta=$(or_default "$(slot bright_magenta color13)" "$magenta")
  bright_cyan=$(or_default "$(slot bright_cyan color14)" "$cyan")
  # tokyo-night keeps its orange in slot 11 (bright yellow); other themes
  # repeat yellow there, which is still the right neighbour for a fallback.
  orange=$(or_default "$(g orange)" "$(or_default "$(g color11)" "$yellow")")

  set_thm bg              "$thm_bg"
  set_thm bg_dark         "$dark_bg"
  set_thm bg_dark1        "$(or_default "$(g darker_background)" "$dark_bg")"
  set_thm bg_highlight    "$(or_default "$(g lighter_background)" "$(or_default "$(g color0)" "$thm_bg")")"
  set_thm fg              "$thm_fg"
  set_thm fg_dark         "$dim_fg"
  set_thm fg_gutter       "$muted"
  set_thm cyan            "$bright_cyan"
  set_thm black           "$dark_bg"
  set_thm magenta         "$magenta"
  set_thm magenta2        "$bright_magenta"
  set_thm pink            "$accent"
  set_thm red             "$red"
  set_thm red1            "$bright_red"
  set_thm green           "$green"
  set_thm green1          "$bright_green"
  set_thm green2          "$bright_green"
  set_thm yellow          "$(or_default "$(g bright_yellow)" "$yellow")"
  set_thm blue            "$blue"
  set_thm blue0           "$dark_bg"
  set_thm blue1           "$bright_blue"
  set_thm blue2           "$bright_blue"
  set_thm blue5           "$(or_default "$(g light_foreground)" "$bright_fg")"
  set_thm blue6           "$bright_fg"
  set_thm blue7           "$dark_bg"
  set_thm orange          "$orange"
  set_thm purple          "$accent"
  set_thm black4          "$muted"
  set_thm comment         "$bright_black"
  set_thm dark3           "$bright_black"
  set_thm dark5           "$bright_black"
  set_thm teal            "$cyan"
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

# ── Canonical palette ────────────────────────────────────────────────────────
# Packs name their knobs differently (catppuccin pink/mauve/subtext_0/overlay_0,
# tokyo-night purple/fg_dark/comment; omarchy derives from ANSI slots), so every
# colour the status line uses walks a chain and bottoms out in an ANSI name. A
# fresh server with a pack that lacks a key gets the terminal's own colour, not
# an empty `fg=` — which tmux rejects, and the whole style with it.
OPTS=$(tmux show-options -g 2>/dev/null)
thm() { awk -v k="@thm_$1" '$1 == k { $1 = ""; sub(/^ "?/, ""); sub(/"$/, ""); print; exit }' <<<"$OPTS"; }
pick() { # pick KEY... LITERAL → first non-empty @thm_KEY, else LITERAL
  local v
  while (($# > 1)); do
    v=$(thm "$1")
    [[ -n $v ]] && { printf '%s' "$v"; return; }
    shift
  done
  printf '%s' "$1"
}

c_fg=$(pick fg default)
c_dim=$(pick fg_dark subtext_0 overlay_2 dark5 colour245)
c_muted=$(pick comment overlay_0 surface_2 dark3 fg_gutter brightblack)
c_surface=$(pick bg_highlight surface_0 bg_dark mantle colour236)
c_ink=$(pick bg base crust black) # text on a coloured pill: the theme's own background
c_red=$(pick red maroon red1 red)
c_yellow=$(pick yellow yellow)
c_orange=$(pick orange peach "$c_yellow")
c_green=$(pick green green1 green)
c_cyan=$(pick cyan sky blue1 cyan)
c_teal=$(pick teal green1 "$c_cyan")
c_blue=$(pick blue sapphire blue1 blue)
c_lavender=$(pick lavender blue5 blue2 "$c_blue")
c_magenta=$(pick magenta mauve purple magenta)
c_pink=$(pick pink flamingo magenta2 "$c_magenta")
c_purple=$(pick purple mauve "$c_magenta")
c_accent=$(pick pink mauve purple magenta "$c_cyan")

# Publish for the helpers (bin/tmux-session-mood, bin/tmux-git-status).
publish=()
for k in fg dim muted surface ink red yellow orange green cyan teal blue lavender magenta pink purple accent; do
  v="c_$k"
  publish+=(set-option -gq "@thm_sl_$k" "${!v}" \;)
done
tmux "${publish[@]:0:${#publish[@]}-1}"

# Legacy names for the lines below that keep their original styling — floored
# so a pack that lacks the key can't hand tmux an empty colour.
thm_fg_gutter=$(pick fg_gutter surface_0 overlay_0 "$c_muted")
thm_blue0=$(pick blue0 sapphire "$c_blue")

# Status bar configuration
tmux set -g status-position top
tmux set -g status-justify left
tmux set -g status-left-length 120
tmux set -g status-right-length 200

# Messages and the `:` prompt — the one place the bar paints a background, so
# a `display` stands off the transparent canvas.
tmux set -g message-style "fg=${c_fg},bg=${c_surface},bold,align=centre"
tmux set -g message-command-style "fg=${c_accent},bg=${c_surface},bold,align=centre"

# Pane borders
tmux set-window-option -g pane-active-border-style "fg=${thm_fg_gutter},bg=${thm_fg_gutter}"
tmux set-window-option -g pane-border-style "fg=${thm_fg_gutter},bg=${thm_fg_gutter}"
tmux set-window-option -g pane-border-lines simple

# ── Status line ──────────────────────────────────────────────────────────────
# One row on a transparent canvas.
#
#     ✦ projects    ➊ 󱙺 dotfiles   ➁  sessions ⊕   ➂  skills        󰎇 FM-84 – Arcade Summer    ☰ ⚠ fix login flow 2m    ❖ alto   ✹ coherence
#
# Left is where you are; right is what wants you and where else you could be:
# what's playing, fleet's clickable agent chips, a mode pill, the other
# sessions' pills.
#
# Shape carries meaning — pill or bare text — so nothing reads alike unless it
# is alike:
#
#   session  a rounded pill, and only sessions get one. The left pill wears the
#            session's crest: a sigil and a palette colour hashed from its name
#            (bin/tmux-session-mood), so each session has an identity you learn
#            and switching changes the bar's mood. Hold prefix and it flashes
#            yellow with a bolt. When fleet says an agent in a session wants
#            you, the pill takes fleet's colour and glyph: ⚠ waiting, ? asking,
#            ● ready. The other sessions sit at the right as two-tone mini
#            pills (crest block + name block); click one to switch.
#   windows  bare text. ➊ (filled) is the window you're in, ➀ the rest — the
#            number is the key after prefix, and each slot has its own colour,
#            a small rainbow: ➊ blue, ➋ cyan, ➌ green… The current window's
#            name is bold, nothing more. Hold prefix and every digit turns
#            yellow. Fleet's attention colour beats the slot colour; a bell
#            turns the name red.
#   badges   ⊕ zoomed  ⇄ synchronized  ⚑ marked
#   right    the host when reached over ssh, what's playing (bin/tmux-vitals
#            music, only while it plays), fleet's chips — ☰ toggles the
#            sidebar, one clickable chip per agent that wants you, ✕ clears
#            them (bin/tmux-fleet-chips; running it is also what paints the
#            attention colours above) — then ◈ copy ↑340 as a yellow pill while
#            a pane is in a mode, then the other sessions. Holding prefix swaps
#            it all for a cheat sheet of the non-obvious bindings, signed with
#            the theme's tagline and tonight's moon. ⧉ in the session pill
#            means another client shares it.
#
# NB: inside #{?...} branches never put a comma inside a #[style] or #(...):
# tmux splits branches on every comma it sees outside nested #{...}. That is
# why the formats below write #[fg=x]#[bg=y] as two brackets; script output is
# spliced in after the split and may use commas freely.

tmux set -g status-style "bg=default,fg=${c_fg}"

# The canvas is the canvas — panes never paint over the terminal's own
# background (ghostty runs at 0.85 opacity; an opaque pane bg kills it).
tmux set -g window-style "fg=default,bg=default"
tmux set -g window-active-style "fg=default,bg=default"

# Glyphs. Dingbats (U+27xx) render one cell wide in every font tmux meets; the
# nerd-font marks are spelled as UTF-8 bytes so they survive editors and agents
# that drop private-use characters (and so the comment names them).
FILLED=(➊ ➋ ➌ ➍ ➎ ➏ ➐ ➑ ➒ ➓)
OUTLINE=(➀ ➁ ➂ ➃ ➄ ➅ ➆ ➇ ➈ ➉)
BOLT=$'\xf3\xb1\x90\x8b'  # U+F140B nf-md-lightning_bolt
SSH=$'\xf3\xb0\xa3\x80'   # U+F08C0 nf-md-ssh
CAP_L=$'\xee\x82\xb6'     # U+E0B6  nf-ple-left_half_circle_thick
CAP_R=$'\xee\x82\xb4'     # U+E0B4  nf-ple-right_half_circle_thick

# One colour per window slot, cycling the palette — a small rainbow your eye
# learns ("the green one"). Only the digit is painted; names stay quiet.
slot_styles=()
for c in "$c_blue" "$c_cyan" "$c_green" "$c_yellow" "$c_orange" "$c_red" "$c_magenta" "$c_pink" "$c_teal" "$c_lavender"; do
  slot_styles+=("#[fg=${c}]")
done

# by_index ELSE V1..V10 → nested #{?#{==:#{window_index},i},Vi,…ELSE}: a lookup
# table in tmux's own format language, evaluated per window with no shell.
by_index() {
  local else=$1 out="" close="" i=1 v
  shift
  for v in "$@"; do
    out+="#{?#{==:#{window_index},${i}},${v},"
    close+="}"
    i=$((i + 1))
  done
  printf '%s%s%s' "$out" "$else" "$close"
}
digit_cur=$(by_index '#I' "${FILLED[@]}")
digit_oth=$(by_index '#I' "${OUTLINE[@]}")
slot_fg=$(by_index "#[fg=${c_accent}]" "${slot_styles[@]}")

# Digit colour: prefix hint beats fleet attention beats the slot colour.
digit_style="#{?client_prefix,#[fg=${c_yellow}],#{?#{@fleet_state},#[fg=#{@fleet_state}],${slot_fg}}}"

# Name colour: bell beats fleet attention beats the resting colour. Names are
# capped at 32 cells so app-set titles can't flood the bar.
name='#{?#{window_name},#{=/32/…:window_name},#{b:pane_current_path}}'
name_cur="#{?window_bell_flag,#[fg=${c_red}],#{?#{@fleet_state},#[fg=#{@fleet_state}],#[fg=${c_fg}]}}#[bold]${name}#[nobold]"
name_oth="#{?window_bell_flag,#[fg=${c_red}]#[bold],#{?#{@fleet_state},#[fg=#{@fleet_state}]#[bold],#[fg=${c_dim}]}}${name}#[nobold]"
badges="#{?window_zoomed_flag, #[fg=${c_orange}]⊕,}#{?pane_synchronized, #[fg=${c_red}]⇄,}#{?window_marked_flag, #[fg=${c_accent}]⚑,}"

# Windows are text on the bare canvas; the current one is told by its filled
# digit and bold name, nothing else, so only sessions ever carry a background.
tmux setw -g window-status-separator "  "
tmux setw -g window-status-bell-style default # the formats own the bell look
tmux setw -g window-status-activity-style default
tmux setw -g window-status-format " ${digit_style}${digit_oth} ${name_oth}${badges} "
tmux setw -g window-status-current-format " ${digit_style}#[bold]${digit_cur}#[nobold] ${name_cur}${badges} "

# Fleet's window rollup. With this gate on, `fleet status --statusline` (row 1)
# paints @fleet_state on every window whose agent wants you — yellow ⚠ waiting,
# magenta ? asking, green ● ready — and unsets it when they don't. The formats
# above read the option directly, so fleet never has to replace them, and
# tmux-session-mood reads the same option instead of cold-booting fleet.
tmux set -g @fleet_rollup 1

# Left: the session pill (bin/tmux-session-mood pill), or a yellow bolt pill
# while prefix is held. Padded off the terminal's rounded corner; click it for
# the session tree (tmux.conf binds MouseDown1StatusLeft).
prefix_pill="#[fg=${c_yellow}]#[bg=default]${CAP_L}#[fg=${c_ink}]#[bg=${c_yellow}]#[bold] ${BOLT} #S #[fg=${c_yellow}]#[bg=default]${CAP_R}#[default]"
tmux set -g status-left "  #{?client_prefix,${prefix_pill},#(${BIN}/tmux-session-mood pill '#{session_name}' '#{session_many_attached}')}   "

# Right: ssh host, what's playing, fleet's chips, mode pill, then the other
# sessions' mini pills (clickable, see tmux.conf) — or, while prefix is held,
# the cheat sheet signed with the theme's tagline and the moon.
hint() { printf '#[fg=%s]#[bold]%s#[nobold]#[fg=%s] %s' "$c_yellow" "$1" "$c_dim" "$2"; }
hints="$(hint s sessions)   $(hint g lazygit)   $(hint y fleet)   $(hint n next)   $(hint f sidebar)   $(hint = tile)   $(hint Esc copy)   $(hint T bar)   $(hint r reload)"
theme_note=""
if [[ -f "$HOME/.config/theme/current/theme.conf" ]]; then
  theme_note=$(sed -n 's/^TAGLINE="\(.*\)"/\1/p' "$HOME/.config/theme/current/theme.conf")
elif [[ -L "$HOME/.config/omarchy/current/theme" ]]; then
  theme_note=$(basename "$(readlink "$HOME/.config/omarchy/current/theme")")
fi
# a literal comma inside a #{?} branch must be written #, or it splits the branch
[[ -n $theme_note ]] && hints+="      #[fg=${c_muted}]#[italics]${theme_note//,/#,}#[noitalics]"
hints+="  #(${BIN}/tmux-vitals moon)  " # tonight's moon signs the sheet
mode_pill="#{?pane_in_mode,#[fg=${c_yellow}]#[bg=default]${CAP_L}#[fg=${c_ink}]#[bg=${c_yellow}]#[bold]◈ #{s/-mode//:pane_mode}#{?scroll_position, ↑#{scroll_position},} #[fg=${c_yellow}]#[bg=default]${CAP_R}#[default]  ,}"
others="#(${BIN}/tmux-session-mood others '#{client_session}')"
music="#(${BIN}/tmux-vitals music)"
chips="#(${BIN}/tmux-fleet-chips)  "
ssh=""
[[ -n "${SSH_CONNECTION:-}${SSH_TTY:-}" ]] && ssh="#[fg=${c_dim}]${SSH} #h   "
tmux set -g status-right "#{?client_prefix,${hints},${ssh}${music}${chips}${mode_pill}${others}}"
tmux set -gu @sl_git 2>/dev/null || true
tmux set -gu @sl_row1 2>/dev/null || true

# Clock mode
tmux setw -g clock-mode-colour "${thm_blue0}"
