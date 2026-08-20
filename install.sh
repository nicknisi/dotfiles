#!/usr/bin/env bash
#
# Set up a machine from scratch:
#
#   curl -fsSL https://raw.githubusercontent.com/nicknisi/dotfiles/main/install.sh | bash
#
# See what it would do without touching anything:
#
#   curl -fsSL https://raw.githubusercontent.com/nicknisi/dotfiles/main/install.sh | bash -s -- --dry-run
#
# Safe to re-run — every step is idempotent.

set -Eeuo pipefail

DOTFILES="$HOME/Developer/dotfiles"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
  -n | --dry-run) DRY_RUN=true; shift ;;
  -h | --help)
    cat <<'USAGE'
install.sh — set up this machine from scratch

  -n, --dry-run   print each command instead of running it
  -h, --help      this

env: NO_COLOR
USAGE
    exit 0
    ;;
  *) printf 'unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
done

# ── Output ──────────────────────────────────────────────────────

# Plain text for pipes, NO_COLOR, and dumb terminals; the fun is opt-out.
BOLD=$'\033[1m' DIM=$'\033[2m' RESET=$'\033[0m'
BLUE=$'\033[94m' GREEN=$'\033[92m' YELLOW=$'\033[93m' RED=$'\033[91m'
MAGENTA=$'\033[95m' CYAN=$'\033[96m'
FANCY=true
if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]] || [[ "${TERM:-}" == "dumb" ]]; then
  for v in BOLD DIM RESET BLUE GREEN YELLOW RED MAGENTA CYAN; do printf -v "$v" ''; done
  FANCY=false
fi

banner() {
  [[ "$FANCY" == true ]] || { printf 'nicknisi/dotfiles\n'; return; }
  cat <<EOF

   ${MAGENTA}┌────────────────────────────────────┐
   │${RESET}  ${CYAN}◆${RESET}  ${DIM}nicknisi${RESET} ${DIM}/${RESET} ${BOLD}dotfiles${RESET}            ${MAGENTA}│
   │${RESET}  ${DIM}a terminal, carefully over-tuned${RESET}  ${MAGENTA}│
   └────────────────────────────────────┘${RESET}
EOF
}

step() { printf '\n %s%s▸%s  %s%s%s\n' "$BOLD" "$BLUE" "$RESET" "$BOLD" "$1" "$RESET"; }

note() { printf '   %s%s%s\n' "$DIM" "$1" "$RESET"; }
die() { printf '\n %s✗%s %s\n' "$RED" "$RESET" "$1" >&2; exit 1; }

# Every mutating command goes through here so --dry-run has nothing to miss.
run() {
  if [[ "$DRY_RUN" == true ]]; then
    printf '   %s$ %s%s\n' "$DIM" "$*" "$RESET"
    return 0
  fi
  "$@"
}

# ── Setup ───────────────────────────────────────────────────────

banner
[[ "$DRY_RUN" == true ]] &&
  printf '\n %s%s dry run — nothing will be written%s\n' "$YELLOW" "$([[ "$FANCY" == true ]] && echo '☂' || echo '!')" "$RESET"

step "Checking for git"
if command -v git &>/dev/null; then
  note "$(git --version)"
else
  [[ "$(uname)" == "Darwin" ]] || die "install git, then re-run this script"
  note "not found, asking macOS for the Command Line Tools"
  run xcode-select --install
  die "re-run this script once the Command Line Tools finish installing"
fi

step "Cloning the repo"
if [[ -d "$DOTFILES" ]]; then
  note "already at $DOTFILES"
else
  run git clone https://github.com/nicknisi/dotfiles.git "$DOTFILES"
fi

step "Installing mise"
if command -v mise &>/dev/null; then
  note "$(mise --version 2>/dev/null | head -1)"
else
  run sh -c 'curl -fsSL https://mise.run | sh'
fi
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
[[ "$DRY_RUN" == true ]] || command -v mise &>/dev/null || die "mise is still not on PATH"

# Until bootstrap creates ~/.config/mise, point mise at the cloned config.
# Its pre-packages hook installs Homebrew before the brew package manager runs.
step "Bootstrapping the machine"
run env "MISE_GLOBAL_CONFIG_FILE=$DOTFILES/config/mise/config.toml" \
  mise bootstrap --yes

# ── Done ────────────────────────────────────────────────────────

SIGNOFFS=(
  "Go forth and misconfigure something."
  "Your terminal is now insufferable. Congratulations."
  "That's the easy part done."
  "Somewhere, a default setting is crying."
)
printf '\n %s✓%s %s%s%s\n' "$GREEN" "$RESET" "$BOLD" "${SIGNOFFS[RANDOM % ${#SIGNOFFS[@]}]}" "$RESET"

cat <<EOF

 ${DIM}Open a new login shell to pick up the chsh, then configure Git:${RESET}

   ${CYAN}mise run setup-git${RESET}

EOF
