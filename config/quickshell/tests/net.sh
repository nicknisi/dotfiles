#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cp "$root"/{Net,NetMenu,BarMenu,BarModule,MenuAction,MenuHint,Theme,Prefs,TailscaleIcon}.qml "$tmp/"
cp "$root/tests/net.qml" "$tmp/shell.qml"
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
sed -i 's/^import Quickshell.Networking$/import "network"/' "$tmp"/{Net,NetMenu,shell}.qml
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
    }
    property QtObject wifi: QtObject {
        property int type: DeviceType.Wifi
        property bool scannerEnabled: false
        property var networks: ({ values: [Networking.hotel] })
    }
}
QML
# Qt's offscreen platform refuses URL opens, allowing the error path to be checked safely.
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen \
    timeout 10 qs -p "$tmp" --no-color 2>&1 | tee "$tmp/result"
grep -q NETWORK_TEST_PASS "$tmp/result"
# Three automatic attempts (startup, new detection, reconnect) and three manual
# retries. Connectivity flaps and late detection after manual sign-in add none.
[[ $(grep -Fc "QPlatformServices::openUrl() for 'http://neverssl.com/'" "$tmp/result") == 6 ]]
# The isolated Prefs store creates its defaults on first load.
! grep -E 'NETWORK_TEST_FAIL|ReferenceError|TypeError|Failed to load|Binding loop|Required property|WARN scene:' "$tmp/result" \
    | grep -qv 'QML FileView.*capsule.json failed: File does not exist'
