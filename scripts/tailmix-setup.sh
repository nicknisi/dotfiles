#!/usr/bin/env bash
# Rebuild my tailmix profiles and policy on a fresh machine.
# Safe to re-run: existing profiles are kept, settings are re-applied.
# Keys and node identity are not stored here; each profile logs in fresh.
set -euo pipefail

[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"

profile() { # profile <name> <accept-all routes+dns: true|false> <shields-up: true|false>
  local name=$1 accept=$2 shields=$3
  tailmix profiles show "$name" >/dev/null 2>&1 || tailmix profiles add "$name"
  tailmix profiles enable "$name" >/dev/null

  if ! tailmix profiles show "$name" --json | grep -q '"backendState": "Running"'; then
    echo "Logging in profile '$name'..."
    tailmix ts -p "$name" up
  fi

  tailmix routes set --profile "$name" --accept-all="$accept" >/dev/null
  tailmix dns routes set --profile "$name" --accept-all="$accept" >/dev/null
  tailmix ts -p "$name" set --shields-up="$shields"
}

profile default false false
profile work true true

tailmix exit-node clear >/dev/null
tailmix dns search clear >/dev/null
tailmix update enable >/dev/null

tailmix status
