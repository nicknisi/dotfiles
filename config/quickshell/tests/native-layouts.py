#!/usr/bin/env python3
"""Check actual Wayland bar bounds using a temporary, non-reserving test bar.

Requires Hyprland. Does not change the running shell's preferences or services.

The bar rules are M4's (PLAN M4, BarGeometry.js): the pill floats on any edge
in a 56 deep window, 518 long plus the media chip; the full strip runs edge to
edge on the top or the bottom and the rail the whole height of the left or the
right, both flush in a 40 deep window. Moving the full strip to a side makes
it the rail there and the rail to the top or the bottom the full strip
(BarGeometry.moveTo), so each (mode, edge) asked for lands as that pair. The
bar's mode, length and media room live on its BarView (`bar.view`).
"""
import json
import math
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
        function inspect(): string { return JSON.stringify({screen: bar.screen.name, width: bar.screen.width, height: bar.screen.height, mode: bar.view.mode, edge: bar.edge, length: bar.view.bodyLength, mediaExtra: bar.view.mediaExtra, dpr: bar.view.dpr, nonReserving: reserve.exclusionMode === ExclusionMode.Ignore, reserveMode: reserve.exclusionMode, reserveZone: reserve.exclusiveZone, anchors: {top: bar.anchors.top, bottom: bar.anchors.bottom, left: bar.anchors.left, right: bar.anchors.right}}) }
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
            for asked in ['pill', 'full', 'rail']:
                for edge in ['top', 'bottom', 'left', 'right']:
                    ipc('layout', asked, edge)
                    vertical = edge in ['left', 'right']
                    # BarGeometry.moveTo: full on a side is the rail, the rail on the top or the bottom the full strip.
                    mode = 'rail' if asked == 'full' and vertical else 'full' if asked == 'rail' and not vertical else asked
                    flush = mode in ['full', 'rail']
                    extent = 40 if flush else 56
                    w, h, x, y = info['width'], info['height'], monitor['x'], monitor['y']
                    expected = (x + w - extent if edge == 'right' else x,
                                y + h - extent if edge == 'bottom' else y,
                                extent if vertical else w, h if vertical else extent)
                    reserve_bounds = (x + w - 1 if edge == 'right' else x if edge == 'left' else x + w // 2,
                                      y + h - 1 if edge == 'bottom' else y if edge == 'top' else y + h // 2, 1, 1)
                    deadline = time.monotonic() + 5
                    while True:
                        layers = json.loads(subprocess.check_output(['hyprctl', '-j', 'layers']))
                        actual = [(v['x'], v['y'], v['w'], v['h']) for entries in layers[info['screen']]['levels'].values() for v in entries if v['namespace'] == 'quickshell-capsule' and v['pid'] == process.pid]
                        actual_reserve = [(v['x'], v['y'], v['w'], v['h']) for entries in layers[info['screen']]['levels'].values() for v in entries if v['namespace'] == 'quickshell-capsule-reserve' and v['pid'] == process.pid]
                        current = json.loads(ipc('inspect'))
                        along = h if vertical else w
                        extra = current['mediaExtra']
                        dpr = current['dpr'] or 1
                        # The pill's length on whole device pixels (BarView.snap).
                        length = along if flush else math.floor(max(40, min(along - 16, 518 + extra)) * dpr + 0.5) / dpr
                        assert current['nonReserving'], ('Test must not change desktop work areas', current)
                        if actual == [expected] and actual_reserve == [reserve_bounds] and current['length'] == length and current['mode'] == mode and current['edge'] == edge:
                            break
                        assert time.monotonic() < deadline, (mode, edge, expected, actual, reserve_bounds, actual_reserve, current)
                        time.sleep(0.05)
                    checks.append({'asked': asked, 'mode': mode, 'edge': edge, 'bounds': actual[0], 'reserve_bounds': actual_reserve[0], 'body_length': length})
            print(json.dumps({'screen': info['screen'], 'scale': monitor['scale'], 'checks': checks}, indent=2))
            print('NATIVE_LAYOUTS_PASS: 12 combinations, main preferences and service unchanged')
        finally:
            process.terminate()
            process.wait(timeout=5)
            log.seek(0)
            output = log.read()
            errors = [line for line in output.splitlines() if any(s in line for s in ['ReferenceError', 'TypeError', 'Binding loop', 'Failed to load', 'Cannot assign'])]
            assert not errors, output
