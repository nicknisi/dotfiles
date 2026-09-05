{
  "name": "system",
  "base": "{{ mode }}",
  "overrides": {
    "text": "rgb({{ foreground_rgb }})",
    "inverseText": "rgb({{ background_rgb }})",
    "inactive": "rgb({{ mix_rgb foreground background 40% }})",
    "inactiveShimmer": "rgb({{ mix_rgb foreground background 25% }})",
    "subtle": "rgb({{ muted_rgb }})",

    "claude": "rgb({{ accent_rgb }})",
    "claudeShimmer": "rgb({{ mix_rgb accent foreground 35% }})",
    "claudeBlue_FOR_SYSTEM_SPINNER": "rgb({{ accent_rgb }})",
    "claudeBlueShimmer_FOR_SYSTEM_SPINNER": "rgb({{ mix_rgb accent foreground 35% }})",

    "permission": "rgb({{ blue_rgb }})",
    "permissionShimmer": "rgb({{ mix_rgb blue foreground 35% }})",
    "suggestion": "rgb({{ cyan_rgb }})",
    "remember": "rgb({{ yellow_rgb }})",
    "skill": "rgb({{ magenta_rgb }})",
    "effortUltra": "rgb({{ magenta_rgb }})",

    "autoAccept": "rgb({{ yellow_rgb }})",
    "autoAcceptShimmer": "rgb({{ mix_rgb yellow foreground 35% }})",
    "merged": "rgb({{ magenta_rgb }})",
    "planMode": "rgb({{ cyan_rgb }})",
    "ide": "rgb({{ bright_cyan_rgb }})",
    "bashBorder": "rgb({{ bright_yellow_rgb }})",

    "promptBorder": "rgb({{ accent_rgb }})",
    "promptBorderShimmer": "rgb({{ mix_rgb accent foreground 35% }})",
    "success": "rgb({{ green_rgb }})",
    "error": "rgb({{ red_rgb }})",
    "warning": "rgb({{ yellow_rgb }})",
    "warningShimmer": "rgb({{ mix_rgb yellow foreground 35% }})",

    "diffAdded": "rgb({{ mix_rgb background green 15% }})",
    "diffRemoved": "rgb({{ mix_rgb background red 15% }})",
    "diffAddedDimmed": "rgb({{ mix_rgb background green 8% }})",
    "diffRemovedDimmed": "rgb({{ mix_rgb background red 8% }})",
    "diffAddedWord": "rgb({{ mix_rgb background green 32% }})",
    "diffRemovedWord": "rgb({{ mix_rgb background red 32% }})",

    "userMessageBackground": "rgb({{ mix_rgb background foreground 6% }})",
    "userMessageBackgroundHover": "rgb({{ mix_rgb background foreground 10% }})",
    "bashMessageBackgroundColor": "rgb({{ mix_rgb background foreground 6% }})",
    "memoryBackgroundColor": "rgb({{ mix_rgb background foreground 6% }})",
    "selectionBg": "rgb({{ selection_background_rgb }})",
    "rate_limit_fill": "rgb({{ accent_rgb }})",
    "rate_limit_empty": "rgb({{ mix_rgb background foreground 20% }})",
    "briefLabelYou": "rgb({{ yellow_rgb }})",
    "briefLabelClaude": "rgb({{ accent_rgb }})"
  }
}
