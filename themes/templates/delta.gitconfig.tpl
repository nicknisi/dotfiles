# {{ name }} — Delta palette, rendered by bin/theme.
[delta]
    {{ mode }} = true
    line-numbers-minus-style = "{{ red }}"
    line-numbers-zero-style = "{{ muted }}"
    line-numbers-plus-style = "{{ green }}"
    minus-style = "syntax {{ mix background red 18% }}"
    minus-emph-style = "syntax {{ mix background red 34% }}"
    plus-style = "syntax {{ mix background green 18% }}"
    plus-emph-style = "syntax {{ mix background green 34% }}"
    file-style = "bold {{ accent }}"
    hunk-header-style = "syntax"
    hunk-header-decoration-style = "{{ muted }} box"
