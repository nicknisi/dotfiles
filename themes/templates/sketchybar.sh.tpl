#!/usr/bin/env bash
# {{ name }} — sketchybar palette (0xAARRGGBB), rendered by bin/theme from
# themes/templates/sketchybar.sh.tpl. Same var set as config/sketchybar/colors.sh,
# which sources this when the theme is active.

export FG=0xff{{ foreground_strip }}     # default text
export FG_DIM=0xb3{{ foreground_strip }} # window title, secondary text
export GREY=0xff{{ mix_strip muted foreground 30% }}   # comment / muted counts
export ACCENT=0xff{{ accent_strip }} # borders active_color

# Glow ramp — accent at four alphas
export GLOW_FULL=0xff{{ accent_strip }}
export GLOW_EDGE=0xd9{{ accent_strip }}
export GLOW_RING=0x40{{ accent_strip }}
export GLOW_FILL=0x24{{ accent_strip }}
export GLOW_TRACE=0x14{{ accent_strip }}

# Surfaces
export BAR_COLOR=0xcc{{ background_strip }}
export BAR_BORDER=0x3d{{ accent_strip }}
export ITEM_BG=0xcc{{ lighter_background_strip }}
export PILL_BG=0x9e{{ selection_background_strip }}
export HAIRLINE=0x1f{{ foreground_strip }}
export POPUP_BG=0xd9{{ background_strip }}
export POPUP_BORDER=0x8c{{ accent_strip }}

# Semantic hues + border/fill alphas
export RED=0xff{{ red_strip }}
export RED_BORDER=0xe6{{ red_strip }}
export RED_FILL=0x1f{{ red_strip }}
export GREEN=0xff{{ green_strip }}
export GREEN_BORDER=0xe6{{ green_strip }}
export GREEN_FILL=0x1f{{ green_strip }}
export CALM_GREEN=0x8c{{ green_strip }}
export YELLOW=0xff{{ yellow_strip }}
export YELLOW_BORDER=0xe6{{ yellow_strip }}
export YELLOW_FILL=0x1f{{ yellow_strip }}
export MAGENTA=0xff{{ magenta_strip }}
export MAGENTA_BORDER=0xe6{{ magenta_strip }}
export MAGENTA_FILL=0x1f{{ magenta_strip }}
export ORANGE=0xff{{ orange_strip }}
export ORANGE_BORDER=0xe6{{ orange_strip }}
export ORANGE_FILL=0x1f{{ orange_strip }}

export INK=0xff{{ background_strip }}
export TRANSPARENT=0x00000000
