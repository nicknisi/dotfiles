#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

luajit "$root/../hypr/tests/style.lua" "$root/../hypr/hyprland.lua" "$root/../../themes/"*/hyprland.lua
# The Copilot key's latch resets when the island's Stop ends dictation (M3 review).
(cd "$root/../.." && luajit config/hypr/tests/copilot.lua)
bash "$root/tests/menu-keys.sh"
# The classic bars (PLAN M4): BarView's layout, material, drags and every
# module (tst_bar_drag, tst_bar_actions), and the anchored panels' place,
# corners and hairlines for every mode, edge and module (tst_anchored_corners).
# The host itself (Hosts/AnchoredView) runs in check.qml below.
bash "$root/tests/bar-drag.sh"
bash "$root/launcher/tests/check.sh"
bash "$root/tests/voxtype-osd.sh"
node "$root/tests/clipboard-model.cjs"
node "$root/tests/window-switcher-model.cjs"
python3 -B "$root/tests/battery-top-up.py"
python3 -B "$root/tests/audio-hotplug.py"
"$root/tests/net.sh"
# Island shell foundation (PLAN M0): tokens, motion, Kit, services.
bash "$root/tests/tokens.sh"
node "$root/tests/token-parity.cjs"
# tst_spring, tst_kit, then the Lucide icon provenance check. That one reads
# lucide-static from $XDG_CACHE_HOME/quickshell-tests (downloaded once);
# QS_TESTS_OFFLINE=1 lets it pass with a SKIP line when neither is available.
bash "$root/tests/kit.sh" ${QS_TESTS_OFFLINE:+--offline-ok}
bash "$root/tests/services.sh"
# Backlight (final audit): sysfs through FileView polling, no process.
bash "$root/tests/backlight.sh"
# Island capsule (PLAN M1): the focus shapes, the state machine, the workspace
# order, and lib/Celestial.js still matching its generator and shapes.luau.
# tst_workspace_strip runs inside kit.sh above.
node "$root/tests/celestial.cjs"
node "$root/tests/island-machine.cjs"
node "$root/tests/workspace-order.cjs"
python3 -B "$root/tools/gen-celestial.py" --check
# The Crew (PLAN M2): the model, the Linux agent scan and the jump helper.
# tst_pixel_sprite runs inside kit.sh above.
node "$root/tests/crew-model.cjs"
python3 -B "$root/../../bin/tests/omniwm-agents.py"
python3 -B "$root/../../bin/tests/crew-jump.py"
# The island's own states (PLAN M3): the calendar grid. The machine's
# priority, queue and return run in island-machine.cjs above, dictation's
# routing in voxtype-osd.sh, and the states themselves, the Context lane and
# the notification timeouts in check.qml below.
node "$root/tests/calendar.cjs"
# The launcher restyle (PLAN M5): clipboard history keeps filling with the old
# picker gone (ClipboardStore against fake wl-paste and cliphist). Match
# ranges, clipboard metadata and the Colors contrast row are qmltests in
# launcher/tests (check.sh above); the island and panel hosts run in check.qml.
bash "$root/tests/clipboard-store.sh"
# The control center, its sheets and the power menu (PLAN M6): Tailscale's
# offline peers, lib/CcData.js and the leaf panels under qmltestrunner
# (tst_cc_layout, tst_sheet_nav, tst_power_keys, tst_cc_live). The Wi-Fi sheet's portal
# row runs in net.sh above, the states themselves in check.qml below.
node "$root/tests/tailscale-model.cjs"
bash "$root/tests/panels.sh"
# The Tailscale service through the sheet (M10: TailscaleMenu, which this
# drove, is gone), on mock tailscale and taildrop executables.
bash "$root/tests/tailscale.sh"
# The theme and wallpaper pickers (PLAN M7): `theme _rows` (mode, bg, fg and
# the preview palette for every pack, agreeing with bin/theme-color), the
# wallpaper paths it keeps working with, and the panels' keys and grid under
# qmltestrunner (tst_picker_nav). The machine's picker states run in
# island-machine.cjs above, the island states and the live preview in
# check.qml below.
bash "$root/../../bin/tests/theme-rows.sh"
bash "$root/../../bin/tests/theme-wallpapers.sh"
bash "$root/tests/pickers.sh"
# Where ThemePicker finds bin/theme (M10, lib/FindBin.js): the checkout it
# runs from, then, for the session's own config only, $DOTFILES/bin and PATH.
node "$root/tests/find-bin.cjs"

# The lock screen and the polkit prompt (PLAN M8): lib/LockMachine.js with a
# fake PamContext, the source rules (one unlock, nothing logged, no capture,
# no paste, allow_session_lock_restore on with the unlock mark for
# shell-lock's watcher, the lock-in motion), tst_auth_card, tst_lock_surface
# and tst_polkit (a fake AuthFlow), the real PamContext against test PAM
# stacks, lock.qml loaded by file path with its IPC checked, and
# bin/shell-lock against fakes (its watcher and two runs at once included).
# The polkit state on the island runs in check.qml below.
bash "$root/tests/lock.sh"
# The profile picture (Face.qml, lib/FaceModel.js, Kit/FacePicture): the file
# check, the atomic copy and the picker's listing on real files
# (face-model.cjs), then the file check and the config load of lock.qml
# offscreen with every kind of bad ~/.face (0 bytes, not an image, 50 MP, a
# symlink loop, a FIFO, a directory, unreadable, over 32 MiB): it loads as
# fast, answers only `lock`, `secure` answers false. Offscreen it has no lock
# surfaces, so nothing there decodes the file: the decode under the lock-in
# motion is tst_lock_surface (lock.sh), the decode itself tst_face_picture
# (kit.sh), the card, the polkit prompt and the sheet's grid tst_auth_card,
# tst_polkit (lock.sh) and tst_face_grid (panels.sh).
bash "$root/tests/face.sh"
# The sleep fade (SleepFade.qml, SleepWatch.qml, lib/SleepFade.js): the
# machine in node, then a real Quickshell against a fake logind: the delay
# inhibitor held awake, released within 1 s of PrepareForSleep(true), taken
# again on wake, a missed wake going stale and the next sleep fading and
# releasing again, never stuck black, and gone with the shell on kill -9;
# lock.qml started while logind is preparing for sleep (settled on the first
# reading, its lock-in motion held for the wake, its own stale after 10 s).
bash "$root/tests/sleep-fade.sh"

# Retiring the leftovers (PLAN M10): the classic modes' notification cards
# (Hosts/NotifStack, the toasts' replacement) on a fake server, and the gate
# that keeps the retired pieces gone (no avatar anywhere, no old Hud, menus,
# media card, toasts or notification center, no old Theme surface colours,
# none of the island's namespaces in the shell-blur rule). The battery sheet
# runs in cc-data.cjs (panels.sh above) and check.qml below.
bash "$root/tests/notif-host.sh"
bash "$root/tests/retired.sh"

# Looks, the notch form and the compositor spring (PLAN M9): the Bridge
# stardate (every minute of two years against the Lua formula, and format()
# against printf's %.1f on every tie minute plus every 997th) with the looks'
# small pure pieces (hearts, faces, status lines, stars), the per-look
# contrast audit over all 37 packs, bin/bar's Linux branch against a fake qs
# (the macOS path still stops without OmniWM), and Hyprland's own check of
# hyprland.lua with the shellSpatial spring, when Hyprland is installed. The
# looks and the notch on the island run in check.qml below.
node "$root/tests/stardate.cjs"
node "$root/tests/look-contrast.cjs"
bash "$root/../../bin/tests/bar.sh"
bash "$root/../hypr/tests/verify.sh"

formatter=$(command -v qmlformat || printf /usr/lib/qt6/bin/qmlformat)
for file in "$root"/*.qml "$root"/Kit/*.qml "$root"/Island/*.qml "$root"/Lock/*.qml "$root"/Panels/*.qml "$root"/Panels/Sheets/*.qml "$root"/Hosts/*.qml "$root"/Looks/*.qml; do
    "$formatter" "$file" >/dev/null
done
# Singletons may import a sibling .js, so those ride along with the .qml.
cp "$root"/*.qml "$tmp/"
cp "$root/battery-top-up.py" "$tmp/"
cp "$root"/*.js "$tmp/" 2>/dev/null || true
# lib/ holds the scripts Motion.qml and Tokens.qml import; Kit/ is qs.Kit,
# Island/ is qs.Island, Lock/ is qs.Lock (M8), Panels/ is qs.Panels (M6),
# Hosts/ is qs.Hosts (M4), Looks/ holds the personal looks and assets/ their
# fonts (M9).
cp -R "$root/assets" "$root/launcher" "$root/Commons" "$root/Ui" "$root/lib" "$root/Kit" "$root/Island" "$root/Lock" "$root/Panels" "$root/Hosts" "$root/Looks" "$tmp/"
cp "$root/tests/check.qml" "$tmp/shell.qml"
# SHELL_CREW=off: the Crew singleton polls no fleet or /proc and runs no jump.
# SHELL_DRY_RUN=1: the control center, its sheets and the power menu read the
# services but change nothing (this runs on the session's D-Bus).
# XDG_STATE_HOME: Quickshell's state (Prefs' capsule.json, Do not disturb
# from the M6 beat) stays in $tmp, not ~/.local/state/quickshell/by-shell.
# About 25 s: the M4 bar check's fourteen beats (600 ms each) start once the
# launcher and control center checks are done (about 13 s in), the picker
# check's six (M7) once the bar check is done, and the last of them hold the
# final check. The timeout leaves room for a loaded machine.
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen SHELL_CREW=off SHELL_DRY_RUN=1 XDG_STATE_HOME="$tmp/.state" \
    timeout 45 qs -p "$tmp" --no-color 2>&1 | tee "$tmp/result"
grep -q CAPSULE_TEST_PASS "$tmp/result"
# Prefs writes capsule.json on first load, after FileView reports that it is absent.
! grep -E 'CAPSULE_TEST_FAIL|ReferenceError|TypeError|Failed to load|Binding loop|Required property|WARN scene:' "$tmp/result" \
    | grep -qv 'QML FileView.*capsule.json failed: File does not exist'
