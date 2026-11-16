#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
# No live Wi-Fi changes, Tailscale processes, or browser launches in this test.
cat >"$tmp/Tailscale.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    readonly property bool running: false
    readonly property bool busy: false
    readonly property bool needsLogin: false
    readonly property string error: ""
    readonly property string stateText: "Test"
}
QML
# The built-in module takes precedence over QML_IMPORT_PATH. Redirect only its
# import in these temporary copies, leaving the service and UI logic unchanged.
module="$tmp/network"
mkdir -p "$module"
printf 'singleton Networking 1.0 Networking.qml\n' >"$module/qmldir"
for spec in 'NetworkConnectivity:Unknown, None, Portal, Limited, Full' \
    'DeviceType:None, Wifi, Wired' 'ConnectionState:Unknown, Connecting, Connected, Disconnecting, Disconnected' \
    'WifiSecurityType:Open, Owe'; do
    name=${spec%%:*}
    printf '%s 1.0 %s.qml\n' "$name" "$name" >>"$module/qmldir"
    printf 'import QtQuick\nQtObject { enum Values { %s } }\n' "${spec#*:}" >"$module/$name.qml"
done
cat >"$module/Networking.qml" <<'QML'
pragma Singleton
import QtQuick
QtObject {
    readonly property bool mock: true
    property bool wifiEnabled: true
    property bool canCheckConnectivity: true
    property bool connectivityCheckEnabled: true
    property int connectivity: NetworkConnectivity.Portal
    property int checks: 0
    function checkConnectivity() { checks++ }
    property var devices: ({ values: [wifi] })
    property QtObject hotel: QtObject {
        property string name: "Test Hotel"
        property bool connected: true
        property bool known: true
        property int security: WifiSecurityType.Open
        property real signalStrength: 80
        property bool stateChanging: false
        property int state: ConnectionState.Connected
        // The Wi-Fi sheet's presses (net-sheet.qml).
        property int disconnects: 0
        function disconnect() { disconnects++ }
        function connect() {}
    }
    property QtObject wifi: QtObject {
        property int type: DeviceType.Wifi
        property bool scannerEnabled: false
        property var networks: ({ values: [Networking.hotel] })
    }
}
QML
# The control center's Wi-Fi sheet (PLAN M6) on the mock: the whole shell's
# files (Tokens and the Kit it draws with), the sheet and its frame. Net.qml's
# own rules (net.qml) run through the same sheet since NetMenu went (M10).
sheet=$tmp/sheet
mkdir -p "$sheet/Panels/Sheets"
cp "$root"/*.qml "$root"/*.js "$sheet/"
cp -R "$root/lib" "$root/Kit" "$sheet/"
cp "$root/Panels/Sheets/SheetFrame.qml" "$root/Panels/Sheets/WifiSheet.qml" "$sheet/Panels/Sheets/"
cp "$tmp/Tailscale.qml" "$sheet/"
cp -R "$module" "$sheet/network"
cp "$root/tests/net-sheet.qml" "$sheet/shell.qml"
cp "$root/tests/net.qml" "$sheet/net.qml"
grep -lx 'import Quickshell.Networking' "$sheet"/*.qml | xargs sed -i 's/^import Quickshell.Networking$/import "network"/'
sed -i 's/^import Quickshell.Networking$/import "..\/..\/network"/' "$sheet/Panels/Sheets/WifiSheet.qml"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen XDG_STATE_HOME="$tmp/state" \
    timeout 10 qs -p "$sheet" --no-color 2>&1 | tee "$tmp/sheet-result"
grep -q NETWORK_SHEET_TEST_PASS "$tmp/sheet-result"
# One automatic attempt at startup and the one press on the connected row.
[[ $(grep -Fc "QPlatformServices::openUrl() for 'http://neverssl.com/'" "$tmp/sheet-result") == 2 ]]
! grep -E 'NETWORK_SHEET_TEST_FAIL|ReferenceError|TypeError|Failed to load|Binding loop|Required property|is not a type|WARN scene:' "$tmp/sheet-result" \
    | grep -qv 'QML FileView.*capsule.json failed: File does not exist'

# Net.qml's captive-portal rules (net.qml) through the same sheet, in its own run.
cp "$sheet/net.qml" "$sheet/shell.qml"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen XDG_STATE_HOME="$tmp/state2" \
    timeout 10 qs -p "$sheet" --no-color 2>&1 | tee "$tmp/result"
grep -q NETWORK_TEST_PASS "$tmp/result"
# Three automatic attempts (startup, new detection, reconnect) and three manual
# retries. Connectivity flaps and late detection after manual sign-in add none.
[[ $(grep -Fc "QPlatformServices::openUrl() for 'http://neverssl.com/'" "$tmp/result") == 6 ]]
# The isolated Prefs store creates its defaults on first load.
! grep -E 'NETWORK_TEST_FAIL|ReferenceError|TypeError|Failed to load|Binding loop|Required property|is not a type|WARN scene:' "$tmp/result" \
    | grep -qv 'QML FileView.*capsule.json failed: File does not exist'
