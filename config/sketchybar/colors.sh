#!/usr/bin/env bash
# Ayu Dark + the Phosphor neon ramp: one hue, four alphas, drawn as 1px
# strokes. Accent matches config/borders/bordersrc so the bar reads as
# part of the same lighting system as the window borders.

export FG=0xffbfbdb6     # default text
export FG_DIM=0xb3bfbdb6 # window title, secondary text
export GREY=0xff5c6773   # borders inactive_color / muted counts
export ACCENT=0xff59c2ff # entity blue (borders active_color)

# Neon ramp — structure is drawn with light, not fill
export GLOW_FULL=0xff59c2ff  # focused text/icons
export GLOW_EDGE=0xd959c2ff  # focused pill border (bright inner stroke)
export GLOW_RING=0x4059c2ff  # focus halo ring, hover borders
export GLOW_FILL=0x2459c2ff  # focused pill fill
export GLOW_TRACE=0x1459c2ff # workspace shelf outline

# Surfaces
export BAR_COLOR=0xcc0d1017  # 80% alpha — lets blur actually frost
export BAR_BORDER=0x3d59c2ff # the bar's own neon hairline
export ITEM_BG=0xcc10161f    # chip fill, visible over glass
export PILL_BG=0x9e131a24    # occupied workspace pill
export HAIRLINE=0x1fbfbdb6   # resting 1px chip border (12% fg)
export POPUP_BG=0xd90d1017
export POPUP_BORDER=0x8c59c2ff

# Semantic hues + their border/fill alphas (0xe6 edge, 0x1f fill)
export RED=0xfff07178
export RED_BORDER=0xe6f07178
export RED_FILL=0x1ff07178
export GREEN=0xffaad94b
export GREEN_BORDER=0xe6aad94b
export GREEN_FILL=0x1faad94b
export CALM_GREEN=0x8caad94b # dim green = fleet healthy, not disabled
export YELLOW=0xffffb454
export YELLOW_BORDER=0xe6ffb454
export YELLOW_FILL=0x1fffb454
export MAGENTA=0xffd2a6ff # ayu purple — fleet 'question' tier
export MAGENTA_BORDER=0xe6d2a6ff
export MAGENTA_FILL=0x1fd2a6ff
export ORANGE=0xffff8f40
export ORANGE_BORDER=0xe6ff8f40
export ORANGE_FILL=0x1fff8f40

export INK=0xff0d1017        # dark text on inverted chips (service badge)
export TRANSPARENT=0x00000000
