# {{ name }} — LazyGit palette, rendered by bin/theme.
gui:
  theme:
    activeBorderColor:
      - "{{ accent }}"
      - bold
    inactiveBorderColor:
      - "{{ muted }}"
    searchingActiveBorderColor:
      - "{{ yellow }}"
      - bold
    optionsTextColor:
      - "{{ blue }}"
    selectedLineBgColor:
      - "{{ lighter_background }}"
    cherryPickedCommitBgColor:
      - "{{ selection_background }}"
    cherryPickedCommitFgColor:
      - "{{ accent }}"
    unstagedChangesColor:
      - "{{ red }}"
    defaultFgColor:
      - "{{ foreground }}"
  authorColors:
    "*": "{{ bright_magenta }}"
git:
  diffRenderers:
    - colorArg: always
      command: delta --paging=never
