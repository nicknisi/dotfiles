-- {{ name }} — rendered by bin/theme from themes/templates/wezterm.lua.tpl
return {
  foreground = "{{ foreground }}",
  background = "{{ background }}",
  cursor_bg = "{{ cursor }}",
  cursor_border = "{{ cursor }}",
  cursor_fg = "{{ background }}",
  selection_bg = "{{ selection_background }}",
  selection_fg = "{{ selection_foreground }}",
  ansi = { "{{ color0 }}", "{{ color1 }}", "{{ color2 }}", "{{ color3 }}", "{{ color4 }}", "{{ color5 }}", "{{ color6 }}", "{{ color7 }}" },
  brights = { "{{ color8 }}", "{{ color9 }}", "{{ color10 }}", "{{ color11 }}", "{{ color12 }}", "{{ color13 }}", "{{ color14 }}", "{{ color15 }}" },
}
