#!/usr/bin/env bash
# Run in the graphical session. Uses installed Qt6 headers/tools; installs nothing.
# No windows or global settings are changed: each probe reads isolated GTK CSS.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/config/gtk-3.0"
cat >"$TMP/probe.cpp" <<'CPP'
#include <QApplication>
#include <QPalette>
#include <iostream>
int main(int argc, char **argv) {
    QApplication app(argc, argv);
    if (argc != 3) return 2;
    const auto palette = app.palette();
    const auto text = palette.color(QPalette::WindowText).name();
    const auto accent = palette.color(QPalette::Highlight).name();
    if (text != argv[1] || accent != argv[2]) {
        std::cerr << "palette mismatch: text=" << text.toStdString()
                  << " accent=" << accent.toStdString() << '\n';
        return 1;
    }
}
CPP
# pkg-config emits compiler/linker flags as separate words.
# shellcheck disable=SC2046
c++ -fPIC "$TMP/probe.cpp" -o "$TMP/probe" $(pkg-config --cflags --libs Qt6Widgets)
for name in gruvbox white; do
  palette="$ROOT/themes/$name/colors.toml"
  "$ROOT/bin/theme-color" -f "$palette" --name "$name" \
    --stdout "$ROOT/themes/templates/gtk.css.tpl" >"$TMP/config/gtk-3.0/gtk.css"
  gtk_theme=Adwaita
  [[ "$("$ROOT/bin/theme-color" -f "$palette" mode)" == light ]] || gtk_theme=Adwaita-dark
  if ! XDG_CONFIG_HOME="$TMP/config" GTK_THEME="$gtk_theme" QT_QPA_PLATFORMTHEME=gtk3 \
    QT_STYLE_OVERRIDE='' "$TMP/probe" \
    "$("$ROOT/bin/theme-color" -f "$palette" foreground)" \
    "$("$ROOT/bin/theme-color" -f "$palette" accent)" 2>"$TMP/probe.log"; then
    cat "$TMP/probe.log" >&2
    exit 1
  fi
done
printf 'QT_GTK_PALETTE_PASS\n'
