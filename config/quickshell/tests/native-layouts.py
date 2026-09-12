#!/usr/bin/env python3
"""Check actual Wayland bar bounds using a temporary, non-reserving test bar.

Requires Hyprland. Does not change the running shell's preferences or services.
"""
import json
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

root = Path(__file__).resolve().parents[1]
assert os.environ.get('WAYLAND_DISPLAY'), 'Run inside the Hyprland session'
with tempfile.TemporaryDirectory(prefix='quickshell-native-layouts.') as directory:
    temp = Path(directory)
    config = temp / 'config'
    shutil.copytree(root, config, ignore=shutil.ignore_patterns('tests', 'target', '__pycache__'))
    (config / 'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
    Bar { id: bar; modelData: Quickshell.screens[0] }
    Reserve { id: reserve; modelData: Quickshell.screens[0]; exclusiveZone: 0; Component.onCompleted: exclusionMode = ExclusionMode.Ignore }
    IpcHandler {
        target: "bar-test"
        function layout(mode: string, edge: string): void { Prefs.setBarMode(mode); Prefs.setEdge(edge) }
        function inspect(): string { return JSON.stringify({screen: bar.screen.name, width: bar.screen.width, height: bar.screen.height, mode: bar.mode, edge: bar.edge, length: bar.bodyLength, nonReserving: reserve.exclusionMode === ExclusionMode.Ignore, reserveMode: reserve.exclusionMode, reserveZone: reserve.exclusiveZone, anchors: {top: bar.anchors.top, bottom: bar.anchors.bottom, left: bar.anchors.left, right: bar.anchors.right}}) }
    }
}
''')
    env = dict(os.environ, XDG_STATE_HOME=str(temp / 'state'))
    with (temp / 'runtime.log').open('w+') as log:
        process = subprocess.Popen(['qs', '-p', str(config), '--no-color'], env=env, stdout=log, stderr=subprocess.STDOUT)
        def ipc(method, *args):
            return subprocess.check_output(['qs', 'ipc', '--pid', str(process.pid), 'call', 'bar-test', method, *args], text=True, stderr=subprocess.DEVNULL, timeout=5)
        try:
            deadline = time.monotonic() + 10
            while True:
                try:
                    info = json.loads(ipc('inspect'))
                    break
                except subprocess.CalledProcessError:
                    assert time.monotonic() < deadline and process.poll() is None, 'Test bar did not start'
                    time.sleep(0.1)
            monitor = next(m for m in json.loads(subprocess.check_output(['hyprctl', '-j', 'monitors'])) if m['name'] == info['screen'])
            checks = []
            for mode in ['pill', 'full', 'rail']:
                for edge in ['top', 'bottom', 'left', 'right']:
                    ipc('layout', mode, edge)
                    extent = 48 if mode == 'full' else 84
                    w, h, x, y = info['width'], info['height'], monitor['x'], monitor['y']
                    vertical = edge in ['left', 'right']
                    expected = (x + w - extent if edge == 'right' else x,
                                y + h - extent if edge == 'bottom' else y,
                                extent if vertical else w, h if vertical else extent)
                    length = (h if vertical else w) * (0.8 if mode == 'rail' else 1) if mode != 'pill' else 518
                    reserve_bounds = (x + w - 1 if edge == 'right' else x if edge == 'left' else x + w // 2,
                                      y + h - 1 if edge == 'bottom' else y if edge == 'top' else y + h // 2, 1, 1)
                    deadline = time.monotonic() + 5
                    while True:
                        layers = json.loads(subprocess.check_output(['hyprctl', '-j', 'layers']))
                        actual = [(v['x'], v['y'], v['w'], v['h']) for entries in layers[info['screen']]['levels'].values() for v in entries if v['namespace'] == 'quickshell-capsule' and v['pid'] == process.pid]
                        actual_reserve = [(v['x'], v['y'], v['w'], v['h']) for entries in layers[info['screen']]['levels'].values() for v in entries if v['namespace'] == 'quickshell-capsule-reserve' and v['pid'] == process.pid]
                        current = json.loads(ipc('inspect'))
                        assert current['nonReserving'], ('Test must not change desktop work areas', current)
                        if actual == [expected] and actual_reserve == [reserve_bounds] and current['length'] == length and current['mode'] == mode and current['edge'] == edge:
                            break
                        assert time.monotonic() < deadline, (mode, edge, expected, actual, reserve_bounds, actual_reserve, current)
                        time.sleep(0.05)
                    checks.append({'mode': mode, 'edge': edge, 'bounds': actual[0], 'reserve_bounds': actual_reserve[0], 'body_length': length})
            print(json.dumps({'screen': info['screen'], 'scale': monitor['scale'], 'checks': checks}, indent=2))
            print('NATIVE_LAYOUTS_PASS: 12 combinations, main preferences and service unchanged')
        finally:
            process.terminate()
            process.wait(timeout=5)
            log.seek(0)
            output = log.read()
            errors = [line for line in output.splitlines() if any(s in line for s in ['ReferenceError', 'TypeError', 'Binding loop', 'Failed to load', 'Cannot assign'])]
            assert not errors, output
