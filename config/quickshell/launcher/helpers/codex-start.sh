#!/usr/bin/env bash
# Keystroke owns this process. Do not attach to the desktop application's server.
set -euo pipefail
# 0.152.0's generated experimental schema covers our protocol. Upstream
# verified 0.153.2. Reject versions outside these bounds until checked.
actual="$(codex --version 2>/dev/null || true)"
if [[ ! "$actual" =~ ^codex-cli\ 0\.(152\.0|153\.[0-2])$ ]]; then
  echo "Keystroke supports codex-cli 0.152.0 or 0.153.0–0.153.2; found ${actual:-no Codex CLI}." >&2
  exit 65
fi
umask 077
mkdir -p "$HOME/.local/state/keystroke/questions"
exec codex app-server --stdio --enable fast_mode --disable hooks --disable apps --disable plugins
