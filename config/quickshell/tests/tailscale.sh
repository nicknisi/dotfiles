#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cp "$root"/*.qml "$root"/*.js "$tmp/"
cp "$root/tests/tailscale.qml" "$tmp/shell.qml"
mkdir "$tmp/bin"
printf 'test transfer\n' >"$tmp/pick-me.txt"
cat >"$tmp/bin/tailscale" <<'PY'
#!/usr/bin/env python3
import json, os, pathlib, sys, time
root = pathlib.Path(os.environ['TAILSCALE_TEST_DIR'])
args = sys.argv[1:]
with (root / 'calls').open('a') as log:
    log.write(json.dumps(args) + '\n')
path = root / 'state'
state = json.loads(path.read_text()) if path.exists() else {'backend': 'Running', 'account': 'home', 'exit': ''}
if args[:1] == ['test']:
    state['backend'] = args[1]
elif args == ['status', '--json']:
    if state['backend'] == 'broken':
        print('daemon unavailable', file=sys.stderr); sys.exit(1)
    me = state['account']
    peer = {'HostName': me + '-server', 'DNSName': me + '.test.ts.net.', 'UserID': 1, 'Online': True, 'TaildropTarget': 1,
            'TailscaleIPs': ['100.64.0.2', 'fd7a:115c:a1e0::2'], 'ExitNodeOption': True, 'ExitNode': state['exit'] == '100.64.0.2'}
    print(json.dumps({'BackendState': state['backend'], 'CurrentTailnet': {'Name': me},
        'Self': {'HostName': 'laptop', 'UserID': 1, 'TailscaleIPs': ['100.64.0.1'], 'CapMap': {'https://tailscale.com/cap/file-sharing': None}},
        'Peer': {me: peer}})); sys.exit()
elif args == ['switch', '--list', '--json']:
    print(json.dumps([{'id': n, 'nickname': n.title(), 'selected': n == state['account']} for n in ['home', 'work']])); sys.exit()
elif args == ['exit-node', 'list']:
    def row(ip, host, country, city, status):
        return f'{ip:<18}{host:<38}{country:<22}{city:<22}{status}'
    print(row('IP', 'HOSTNAME', 'COUNTRY', 'CITY', 'STATUS'))
    print(row('100.64.0.9', 'us-nyc-wg-001.mullvad.ts.net', 'United States', 'New York', 'selected' if state['exit'] == '100.64.0.9' else '-'))
    sys.exit()
elif args == ['down']:
    state['backend'] = 'Stopped'
elif args == ['up']:
    state['backend'] = 'Running'
elif args[:1] == ['switch']:
    # The receiver must already be gone when a profile changes.
    if (root / 'receiver-live').exists():
        print('receiver still alive at account switch', file=sys.stderr); sys.exit(1)
    time.sleep(0.1)
    state['account'] = args[1]
elif args[:1] == ['set'] and args[1].startswith('--exit-node='):
    state['exit'] = args[1].split('=', 1)[1]
else:
    print('unexpected test command', args, file=sys.stderr); sys.exit(1)
path.write_text(json.dumps(state))
PY
cat >"$tmp/bin/taildrop" <<'PY'
#!/usr/bin/env python3
import json, os, pathlib, signal, sys, time
root = pathlib.Path(os.environ['TAILSCALE_TEST_DIR'])
if sys.argv[1] == 'send':
    (root / 'sent').write_text(json.dumps(sys.argv[2:]))
    time.sleep(0.2)
    sys.exit()
path = root / 'receiver-live'
path.touch()
def stop(*args):
    time.sleep(0.15)
    path.unlink(missing_ok=True)
    sys.exit()
signal.signal(signal.SIGTERM, stop)
print(json.dumps({'event': 'ready', 'directory': str(root / 'Downloads')}), flush=True)
while True: time.sleep(1)
PY
chmod +x "$tmp/bin/"*
# An interactive harness uses the same controls and mocked commands.
if [[ ${1:-} == --preview ]]; then
    cat >"$tmp/shell.qml" <<'QML'
import Quickshell
import QtQuick
import QtQuick.Layouts
ShellRoot {
    FloatingWindow {
        id: window
        title: "Tailscale test window"
        visible: true
        implicitWidth: 420
        implicitHeight: 720
        color: Theme.surface
        property bool tailscale: false
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            BarModule {
                text: "Back to network"
                visible: window.tailscale
                onClicked: window.tailscale = false
                Text { text: "‹ Network"; color: Theme.accent; font.family: Theme.font }
            }
            NetMenu {
                Layout.fillWidth: true
                visible: !window.tailscale
                onNavigate: window.tailscale = true
            }
            TailscaleMenu {
                Layout.fillWidth: true
                visible: window.tailscale
                shown: visible
            }
            Item { Layout.fillHeight: true }
        }
    }
}
QML
    env PATH="$tmp/bin:$PATH" TAILSCALE_TEST_DIR="$tmp" QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 qs -p "$tmp" --no-color
    exit
fi
# All Tailscale/Taildrop commands resolve to mocks, never the live daemon/inbox.
env -u WAYLAND_DISPLAY PATH="$tmp/bin:$PATH" TAILSCALE_TEST_DIR="$tmp" QT_QPA_PLATFORM=offscreen \
    timeout 20 qs -p "$tmp" --no-color 2>&1 | tee "$tmp/result"
grep -q TAILSCALE_UI_PASS "$tmp/result"
# The isolated Prefs store creates its defaults on first load.
! grep -E 'TAILSCALE_UI_FAIL|ReferenceError|TypeError|Failed to load|Binding loop|Required property|WARN scene:' "$tmp/result" \
    | grep -qv 'QML FileView.*capsule.json failed: File does not exist'
