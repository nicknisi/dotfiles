#!/usr/bin/env bash
# Tmux theme plugin - handles dark/light mode automatically

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load color scheme based on macOS appearance
if [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" == "Dark" ]]; then
  source "$CURRENT_DIR/colors/dark.sh"
else
  source "$CURRENT_DIR/colors/light.sh"
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

# Pane borders
tmux set-window-option -g pane-active-border-style "fg=${thm_fg_gutter},bg=${thm_fg_gutter}"
tmux set-window-option -g pane-border-style "fg=${thm_fg_gutter},bg=${thm_fg_gutter}"
tmux set-window-option -g pane-border-lines simple

# Window status
tmux setw -g window-status-activity-style "fg=${thm_fg},none"
tmux setw -g window-status-separator ""
tmux set -g status-style "bg=default,fg=white"

# Icons and separators (Powerline symbols) - define first
tm_separator_left=""
tm_separator_right=""
tm_icon=""
tm_music_icon=""

# Create a formatted section with powerline separators
# Usage: create_section "left|right" "icon" "text" "bg_color" "fg_color" ["no-start"|"no-end"|"no-separators"]
create_section() {
  local direction=$1
  local icon=$2
  local text=$3
  local bg_color=$4
  local fg_color=$5
  local separator_mode=${6:-""}

  if [[ "$direction" == "left" ]]; then
    local result="#[bg=${bg_color},fg=${fg_color},bold] ${icon} ${text} "
    if [[ "$separator_mode" != "no-end" && "$separator_mode" != "no-separators" ]]; then
      result+="#[bg=default]#[fg=${bg_color}]${tm_separator_left}"
    fi
    result+="#[bg=default,fg=default]"
    echo -e "$result"
  else
    local result=""
    if [[ "$separator_mode" != "no-start" && "$separator_mode" != "no-separators" ]]; then
      result+="#[bg=default]#[fg=${bg_color}]${tm_separator_right}"
    fi
    result+="#[bg=${bg_color}]#[fg=${fg_color}] ${icon} #[bold]${text} "
    if [[ "$separator_mode" != "no-end" && "$separator_mode" != "no-separators" ]]; then
      result+="#[bg=default]#[fg=${bg_color}]${tm_separator_left}"
    fi
    result+="#[bg=default,fg=default]"
    echo -e "$result"
  fi
}

# Tunes component
create_tunes_section() {
  local tunes_result="$(current-song)"
  if [[ -n "$tunes_result" ]]; then
    echo -e "$(create_section "right" " " "${tunes_result}" "${thm_blue7}" "${thm_blue6}")"
  fi
}

# Tunes component
# tm_tunes_display="$(create_tunes_section)"
tm_tunes_display="#(song=\$(current-song); if [[ -n \"\$song\" ]]; then echo \"#[bg=default]#[fg=${thm_blue7}]${tm_separator_right}#[bg=${thm_blue7}]#[fg=${thm_blue6}] ${tm_music_icon}  \$song #[bg=default]#[fg=${thm_blue7}]${tm_separator_left}#[bg=default,fg=default]\"; fi)"

# Status line components
session="$(create_section "left" "$tm_icon" "#S" "${thm_purple}" "${thm_bg}" "no-start")"
tm_claude_display="#(s=\$(claude-status #{session_name}); if [ \"\$s\" = \"working\" ]; then echo '#[fg=colour208] ⚡ '; else echo '#[fg=#a6e3a1] ✓ '; fi)"
tm_git_status="$(create_section "right" "" "#(tmux-git-status '#{pane_current_path}')" "${thm_bg}" "${thm_fg}" "no-end")"

# Status left and right - using the exact original syntax
tmux set -g status-left "$session"
# tmux set -g status-right "${tm_claude_display}#{?$tm_tunes,${tm_tunes_display},}${tm_git_status}"
tmux set -g status-right "${tm_claude_display}${tm_tunes_display}${tm_git_status}"

# Window status formats
tmux setw -g window-status-format "#[fg=${thm_black4}] #{?#{window_name},#W,#{b:pane_current_path}} "
tmux setw -g window-status-current-format "#[fg=${thm_magenta},bold] #{?#{window_name},#W,#{b:pane_current_path}} "

# Clock mode
tmux setw -g clock-mode-colour "${thm_blue0}"
