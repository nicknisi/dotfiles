#!/usr/bin/env bash
# Spend chip clicks: right = today's spend breakdown in a tmux popup
# (same popup-on-the-terminal-workspace convention as agents_click.sh).
# Left-click does nothing — the chip is information, not navigation.

[ "$BUTTON" = "right" ] || exit 0

# jq program lives in a cache file so the popup's sh -c command stays
# free of nested-quote gymnastics; rewritten each click, it's cheap.
JQ="$HOME/.cache/spend-popup.jq"
cat >"$JQ" <<'EOF'
"today: $\(.summary.totalCostUSD*100|round/100)  ·  \(.summary.sessions) sessions  ·  \(.summary.messages) msgs",
"",
"by tool:",
(.byTool[] | "  \(.label)  $\(.costUSD*100|round/100)"),
"",
"by model:",
(.byModel[:6][] | "  \((.label | split("/") | last))  $\(.costUSD*100|round/100)")
EOF

aerospace workspace D
tmux display-popup -E -w 55% -h 40% \
  "echo 'crunching sessions…'; sessions report --today --stdout 2>/dev/null | jq -rf '$JQ'; echo; read -r"
