#!/usr/bin/env bash
# void — sketchybar palette (0xAARRGGBB), same var set as
# config/sketchybar/colors.sh. Sourced by sketchybarrc when this theme is
# active via ~/.config/theme/current.

export FG=0xffffffff     # default text
export FG_DIM=0xb3ffffff # window title, secondary text
export GREY=0xff6b578f   # comment / muted counts
export ACCENT=0xffbb9af7 # void lavender (borders active_color)

# Glow ramp — accent at four alphas
export GLOW_FULL=0xffbb9af7
export GLOW_EDGE=0xd9bb9af7
export GLOW_RING=0x40bb9af7
export GLOW_FILL=0x24bb9af7
export GLOW_TRACE=0x14bb9af7

# Surfaces
export BAR_COLOR=0xcc05010c
export BAR_BORDER=0x3dbb9af7
export ITEM_BG=0xcc141029
export PILL_BG=0x9e141029
export HAIRLINE=0x1fffffff
export POPUP_BG=0xd905010c
export POPUP_BORDER=0x8cbb9af7

# Semantic hues + border/fill alphas
export RED=0xfff07178
export RED_BORDER=0xe6f07178
export RED_FILL=0x1ff07178
export GREEN=0xffc2b8ff
export GREEN_BORDER=0xe6c2b8ff
export GREEN_FILL=0x1fc2b8ff
export CALM_GREEN=0x8cc2b8ff
export YELLOW=0xffddccff
export YELLOW_BORDER=0xe6ddccff
export YELLOW_FILL=0x1fddccff
export MAGENTA=0xffb49ae6
export MAGENTA_BORDER=0xe6b49ae6
export MAGENTA_FILL=0x1fb49ae6
export ORANGE=0xffff8a95
export ORANGE_BORDER=0xe6ff8a95
export ORANGE_FILL=0x1fff8a95

export INK=0xff05010c
export TRANSPARENT=0x00000000
