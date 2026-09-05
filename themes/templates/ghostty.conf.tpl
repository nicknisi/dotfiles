# {{ name }} — rendered by bin/theme from themes/templates/ghostty.conf.tpl.
# A pack that ships its own ghostty.conf (e.g. to name a built-in ghostty
# theme with a light variant) wins over this file.
background = {{ background }}
foreground = {{ foreground }}
cursor-color = {{ cursor }}
selection-background = {{ selection_background }}
selection-foreground = {{ selection_foreground }}

palette = 0={{ color0 }}
palette = 1={{ color1 }}
palette = 2={{ color2 }}
palette = 3={{ color3 }}
palette = 4={{ color4 }}
palette = 5={{ color5 }}
palette = 6={{ color6 }}
palette = 7={{ color7 }}
palette = 8={{ color8 }}
palette = 9={{ color9 }}
palette = 10={{ color10 }}
palette = 11={{ color11 }}
palette = 12={{ color12 }}
palette = 13={{ color13 }}
palette = 14={{ color14 }}
palette = 15={{ color15 }}

# dock icon (macOS only; ignored elsewhere): ghost in accent, screen in background
macos-icon = custom-style
macos-icon-ghost-color = {{ accent }}
macos-icon-screen-color = {{ background }}
