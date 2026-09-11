#!/usr/bin/env python3
"""Verify clipboard bytes, copy/close/paste ordering, failure and cancellation."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='keystroke-transfer-') as temp:
    work = Path(temp)
    helper = work / 'helper.py'
    helper.write_text('''import pathlib, sys, time
work = pathlib.Path(__file__).parent
mode = sys.argv[1]
if mode == "fail": sys.exit(1)
if mode == "copy":
    text = sys.stdin.read()
    time.sleep(.06)
    (work / "clipboard").write_text(text)
with (work / "events").open("a") as f: f.write(f"{mode} {time.time()}\\n")
''')
    for scenario in ['copy', 'paste', 'cancel', 'fail']:
        events = work / 'events'
        events.write_text('')
        text = 'Open the document, please.\nKeep  two spaces! $(touch /tmp/no) 🐈'
        cfg = work / 'shell.qml'
        cfg.write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import %s
ShellRoot {
  property string scenario: %s
  ClipboardTransfer {
    id: transfer
    copyCommand: ["python3", %s, scenario === "fail" ? "fail" : "copy"]
    pasteCommand: ["python3", %s, "paste"]
    onCopied: {
      console.log("COPIED", Date.now())
      if (scenario === "cancel") transfer.cancel()
    }
    onCompleted: { console.log("DONE"); Qt.quit() }
    onFailed: function(message) { console.log("FAILED", message); Qt.quit() }
  }
  Timer { interval: 10; running: true; onTriggered: {
    if (!transfer.submit(%s, scenario !== "copy")) console.log("REJECTED")
    if (transfer.submit("duplicate", true)) console.log("DUPLICATE")
  } }
  Timer { interval: 350; running: scenario === "cancel"; onTriggered: Qt.quit() }
  Timer { interval: 2000; running: true; onTriggered: { console.log("TIMEOUT"); Qt.quit() } }
}
''' % (json.dumps((root/'voice').as_uri()), json.dumps(scenario), json.dumps(str(helper)), json.dumps(str(helper)), json.dumps(text)))
        env = os.environ.copy()
        env.pop('DISPLAY', None)
        env.pop('WAYLAND_DISPLAY', None)
        env.update(HOME=str(work), XDG_RUNTIME_DIR=str(work), XDG_CONFIG_HOME=str(work / '.config'),
                   XDG_DATA_HOME=str(work / '.local/share'), QT_QPA_PLATFORM='offscreen',
                   QT_QPA_PLATFORMTHEME='generic', QT_QUICK_BACKEND='software')
        result = subprocess.run(['quickshell', '-p', str(cfg)], env=env, capture_output=True, text=True, timeout=8)
        output = result.stdout + result.stderr
        assert not any(x in output for x in ['TIMEOUT', 'DUPLICATE', 'REJECTED', 'Failed to load']), output
        lines = [line.split() for line in events.read_text().splitlines()]
        if scenario == 'fail':
            assert 'FAILED' in output and 'COPIED' not in output and not lines, output
        else:
            assert 'COPIED' in output and 'FAILED' not in output, output
            assert (work/'clipboard').read_text() == text
            assert [v[0] for v in lines] == (['copy','paste'] if scenario == 'paste' else ['copy']), (output, lines)
            if scenario == 'paste':
                # Copy completion callback is the point the palette closes.
                import re
                closed = int(re.search(r'COPIED (\d+)', output)[1]) / 1000
                assert float(lines[1][1]) - closed >= .095, lines
    print('PASS: clipboard bytes, close-before-paste delay, cancellation, failure, duplicate guard')
