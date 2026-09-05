/* {{ name }} — rendered by bin/theme from themes/templates/wofi.css.tpl.
   wofi styles with GTK3 CSS; these #ids are wofi's own. Passed with --style
   from the Hyprland launcher bind and `theme menu`. */

window {
    background-color: {{ background }};
    border: 2px solid {{ accent }};
    border-radius: 8px;
    font-family: "Monaspace Argon", monospace;
    font-size: 14px;
}

#outer-box {
    margin: 10px;
}

#input {
    margin-bottom: 10px;
    padding: 8px 10px;
    border: 1px solid {{ muted }};
    border-radius: 6px;
    background-color: {{ lighter_background }};
    color: {{ foreground }};
}

#input:focus {
    border-color: {{ cyan }};
}

#scroll {
    margin: 0;
}

#inner-box {
    background-color: transparent;
}

#entry {
    padding: 6px 8px;
    border-radius: 6px;
}

/* wofi marks the highlighted row with :selected on the entry, and the text
   inside needs the colour too or it stays muted against the selection. */
#entry:selected {
    background-color: {{ accent }};
}

#entry:selected #text {
    color: {{ background }};
}

#text {
    color: {{ foreground }};
}

#img {
    margin-right: 8px;
}
