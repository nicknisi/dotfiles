#!/usr/bin/env bash
# `theme _rows` for the island pickers (PLAN M7, launcher-pickers 7.5): every
# theme row carries mode, bg, fg and the palette the live preview recolours
# the shell with, as valid JSON, for every pack in themes/. The palette must
# agree with bin/theme-color (the resolver `theme <name>` uses) on every key
# it carries, so a previewed card looks like the theme once applied.
#
# Runs on Linux and macOS: bash 3.2, BSD tools, python3 for the JSON checks.
# Never touches the live desktop or the thumbnail cache: bin/theme runs from a
# temp copy with thumbs_background stubbed, under a temp HOME.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# install DIR THEMES: bin/theme and bin/theme-color under DIR/bin, themes/ ->
# THEMES (bin/theme finds its packs at <its dir>/../themes).
install() {
  mkdir -p "$1/bin"
  cp "$ROOT/bin/theme-color" "$1/bin/"
  awk '
    /^case "\$\{1:-\}" in$/ { print "thumbs_background() { :; }" }
    { print }
  ' "$ROOT/bin/theme" >"$1/bin/theme"
  chmod +x "$1/bin/theme"
  ln -s "$2" "$1/themes"
}

export HOME="$TMP/home"
STATE="$HOME/.local/state/theme/current"
mkdir -p "$STATE"
printf 'hackerman\n' >"$STATE/theme.name"

# ---- the real packs ----
install "$TMP/real" "$ROOT/themes"
"$TMP/real/bin/theme" _rows themes >"$TMP/rows.json"
"$TMP/real/bin/theme" _rows backgrounds >"$TMP/backgrounds.json"

# ---- edge cases the real packs do not have ----
F="$TMP/fake-themes"
mkdir -p "$F/forced" "$F/slots" "$F/bright" "$F/quoted"
# theme.conf's THEME_MODE wins over colors.toml's mode (as `theme <name>` passes --mode)
printf 'mode = "dark"\nbackground = "#101010"\nforeground = "#F0F0F0"\naccent = "#3366FF"\nred = "#cc3333"\n' >"$F/forced/colors.toml"
printf 'THEME_MODE=light\nTAGLINE="forced light"\n' >"$F/forced/theme.conf"
# slots only, no accent: accent from color4, foreground from color15, color7 as dark_foreground
cat >"$F/slots/colors.toml" <<'EOF'
# a comment = "#000000"
color0 = "#1d1f21"
color1 = "#cc6666"
color2 = "#b5bd68"
color3 = "#f0c674"
color4 = "#81a2be"
color5 = "#b294bb"
color6 = "#8abeb7"
color7 = "#c5c8c6"
color8 = "#666666"
color13 = "#c397d8"
color15 = "#eaeaea"
EOF
# no mode at all: a bright background reads light; alpha hex is cut to six digits
printf 'background = "#FAFAFAff"\nforeground = "#222222"\naccent = "#0055aa"\n' >"$F/bright/colors.toml"
# single quotes, short spellings, spaces around the key, a trailing comment
printf "  bg='#202020' # dark\n  fg = '#dddddd'\naccent='#ffaa00'\ndarker_bg = '#101010'\ndark_fg = '#888888'\npurple = '#aa77cc'\n" >"$F/quoted/colors.toml"
install "$TMP/fake" "$F"
"$TMP/fake/bin/theme" _rows themes >"$TMP/fake.json"

# ---- POSIX awk: the same rows from gawk --posix, where gawk exists (Linux) ----
posix=skipped
if command -v gawk >/dev/null 2>&1; then
  mkdir -p "$TMP/posix-bin"
  printf '#!/bin/sh\nexec gawk --posix "$@"\n' >"$TMP/posix-bin/awk"
  chmod +x "$TMP/posix-bin/awk"
  PATH="$TMP/posix-bin:$PATH" "$TMP/real/bin/theme" _rows themes >"$TMP/rows-posix.json"
  PATH="$TMP/posix-bin:$PATH" "$TMP/fake/bin/theme" _rows themes >"$TMP/fake-posix.json"
  cmp -s "$TMP/rows.json" "$TMP/rows-posix.json"
  cmp -s "$TMP/fake.json" "$TMP/fake-posix.json"
  posix=same
fi

python3 - "$TMP" "$ROOT" "$F" <<'PY'
import json, os, re, subprocess, sys

tmp, root, fake = sys.argv[1:4]
HEX = re.compile(r"^#[0-9a-f]{6}$")
PALETTE = ["background", "foreground", "accent", "red", "green", "yellow", "blue", "magenta", "cyan",
           "muted", "dark_foreground", "bright_magenta", "darker_background", "mode"]
failures = []

def fail(msg):
    failures.append(msg)

def theme_mode(packdir):
    conf = os.path.join(packdir, "theme.conf")
    if not os.path.exists(conf):
        return ""
    m = re.search(r"^\s*THEME_MODE=[\"']?(dark|light)[\"']?\s*$", open(conf).read(), re.M)
    return m.group(1) if m else ""

def resolved(packdir, name):
    args = [os.path.join(root, "bin", "theme-color"), "-f", os.path.join(packdir, "colors.toml"), "--name", name]
    mode = theme_mode(packdir)
    if mode:
        args += ["--mode", mode]
    return json.loads(subprocess.check_output(args + ["--json"], text=True))

def own_darker(packdir):
    text = open(os.path.join(packdir, "colors.toml")).read()
    m = re.search(r"^\s*[\"']?darker_(?:background|bg)[\"']?\s*=\s*[\"']?#?([0-9a-fA-F]{6})", text, re.M)
    return "#" + m.group(1).lower() if m else None

def check_rows(path, themes_dir, expect_current):
    rows = json.load(open(path))
    packs = sorted(d for d in os.listdir(themes_dir) if os.path.isfile(os.path.join(themes_dir, d, "colors.toml")))
    if [r.get("name") for r in rows] != packs:
        fail(f"{path}: rows {[r.get('name') for r in rows]} != packs {packs}")
    for r in rows:
        n = r.get("name")
        for key in ("label", "image", "tagline"):
            if not isinstance(r.get(key), str):
                fail(f"{n}: {key} is not a string")
        if not isinstance(r.get("swatches"), list) or not isinstance(r.get("current"), bool):
            fail(f"{n}: swatches or current missing")
        if r.get("mode") not in ("dark", "light"):
            fail(f"{n}: mode {r.get('mode')!r}")
        for key in ("bg", "fg"):
            if not isinstance(r.get(key), str) or not HEX.match(r[key]):
                fail(f"{n}: {key} {r.get(key)!r}")
        p = r.get("palette")
        if not isinstance(p, dict):
            fail(f"{n}: no palette")
            continue
        if p.get("background") != r.get("bg") or p.get("foreground") != r.get("fg") or p.get("mode") != r.get("mode"):
            fail(f"{n}: palette disagrees with bg/fg/mode")
        if not HEX.match(p.get("accent", "")):
            fail(f"{n}: palette accent {p.get('accent')!r}")
        for key, val in p.items():
            if key not in PALETTE:
                fail(f"{n}: unexpected palette key {key}")
            elif key != "mode" and not HEX.match(val):
                fail(f"{n}: palette {key} {val!r}")
        # Against the resolver: every key the palette carries, the mode, and
        # darker_background exactly when the pack sets its own.
        packdir = os.path.join(themes_dir, n)
        want = resolved(packdir, n)
        for key, val in p.items():
            if key == "darker_background":
                continue
            if str(want.get(key)).lower() != val:
                fail(f"{n}: palette {key} {val}, theme-color {want.get(key)}")
        if p.get("darker_background") != own_darker(packdir):
            fail(f"{n}: darker_background {p.get('darker_background')}, pack's own {own_darker(packdir)}")
        # swatches (kept for ThemeMenu and the launcher) lead with the accent when the pack names one
        if len(r["swatches"]) == 7 and r["swatches"][0].lower() != p["accent"]:
            fail(f"{n}: swatches[0] {r['swatches'][0]} is not the palette's accent {p['accent']}")
        if r["current"] != (n == expect_current):
            fail(f"{n}: current {r['current']}")
    return rows

rows = check_rows(os.path.join(tmp, "rows.json"), os.path.join(root, "themes"), "hackerman")
if len(rows) != 37:
    fail(f"expected 37 packs, got {len(rows)}")
fake_rows = {r["name"]: r for r in check_rows(os.path.join(tmp, "fake.json"), fake, "")}
expect = {
    "forced": ("light", "#101010", "#f0f0f0", "#3366ff"),
    "slots": ("dark", "#1d1f21", "#eaeaea", "#81a2be"),
    "bright": ("light", "#fafafa", "#222222", "#0055aa"),
    "quoted": ("dark", "#202020", "#dddddd", "#ffaa00"),
}
for name, (mode, bg, fg, accent) in expect.items():
    r = fake_rows.get(name, {})
    got = (r.get("mode"), r.get("bg"), r.get("fg"), r.get("palette", {}).get("accent"))
    if got != (mode, bg, fg, accent):
        fail(f"fake {name}: {got} != {(mode, bg, fg, accent)}")
if fake_rows.get("slots", {}).get("palette", {}).get("dark_foreground") != "#c5c8c6":
    fail("fake slots: color7 is the dark foreground")
if fake_rows.get("quoted", {}).get("palette", {}).get("magenta") != "#aa77cc":
    fail("fake quoted: purple is the magenta")

walls = json.load(open(os.path.join(tmp, "backgrounds.json")))
bgdir = os.path.join(root, "themes", "hackerman", "backgrounds")
want_walls = sorted(os.path.join(bgdir, f) for f in os.listdir(bgdir)
                    if f.lower().endswith((".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp")))
if sorted(os.path.realpath(w.get("name", "")) for w in walls) != [os.path.realpath(w) for w in want_walls]:
    fail(f"backgrounds rows {[w.get('name') for w in walls]} != {want_walls}")
for w in walls:
    if w.get("tagline") != "hackerman" or w.get("swatches") != [] or not isinstance(w.get("current"), bool):
        fail(f"background row {w}")

if failures:
    print("\n".join(failures[:40]), file=sys.stderr)
    print(f"THEME_ROWS_FAIL ({len(failures)})", file=sys.stderr)
    sys.exit(1)
print(f"{len(rows)} packs, {len(fake_rows)} edge packs, {len(walls)} hackerman wallpapers")
PY
printf 'posix awk: %s\n' "$posix"
printf 'THEME_ROWS_PASS\n'
