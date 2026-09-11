#!/usr/bin/env python3
"""Query production providers without activating an action or opening an app."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'assets/emoji-test.txt').read_text()
expected = []
for line in source.splitlines():
    match = re.match(r'^([0-9A-F ]+)\s*;\s*fully-qualified\s*#\s*\S+\s+E[\d.]+\s+(.+)$', line)
    if match:
        expected.append({'e': ''.join(chr(int(c, 16)) for c in match[1].split()), 'k': match[2]})
assert len(expected) == 3944
assert json.loads((root / 'assets/emojis.json').read_text()) == expected
assert 'UNICODE LICENSE V3' in (root / 'assets/LICENSE-Unicode.txt').read_text()
with tempfile.TemporaryDirectory(prefix='launcher-providers-') as temp:
    work = Path(temp)
    (work / 'fixture-document.txt').write_text('isolated file search fixture')
    (work / 'shell.qml').write_text('''import QtQuick
import Quickshell
import %s as Providers
ShellRoot {
 id: test
 function check(ok, msg) { if (!ok) { console.log("FAIL", msg); Qt.quit(); throw Error(msg) } }
 function ctx(query, scope, settings) { return {query: query, scope: scope || "", settings: settings || {}, pending: function(){}} }
 QtObject { id: stub; function requery(options) {} }
 Providers.Emoji { id: emoji; host: stub }
 Providers.Colors { id: colors }
 Providers.Converter { id: converter; host: stub }
 Providers.Files { id: files; host: stub }
 Providers.Dictation { id: dictation }
 Providers.AiWeb { id: ai }
 Timer { interval: 50; repeat: true; running: true; onTriggered: {
   if (!emoji.emojis.length || !files.available) return
   var found = files.query(test.ctx("fixture-document", "files", {files:true, folders:true, hidden:false, limit:10, searchMode:"literal"}))
   var time = converter.query(test.ctx("now in london", "converter", {timezone:"UTC"}))
   if (!found.length || !time.length) return
   test.check(emoji.emojis.length === 3944, "full Unicode dataset loaded")
   for (var word of ["rocket", "woman scientist", "flag: Japan", "phoenix", "face with bags under eyes"]) {
     var rows = emoji.query(test.ctx(":" + word))
     test.check(rows.length > 0 && rows[0].action.type === "copy", "searchable emoji " + word)
   }
   test.check(found[0].title === "fixture-document.txt", "isolated fd search")
   test.check(JSON.stringify(found[0].altAction.argv) === JSON.stringify(["uwsm-app","--","ghostty","--working-directory=" + Quickshell.env("HOME")]), "Ghostty file handoff")
   test.check(converter.query(test.ctx("32 F to C", "converter"))[0].title === "0 °C", "temperature conversion")
   test.check(time[0].action.type === "copy", "timezone helper")
   var values = colors.query(test.ctx("#ff6644", "", {format:"hex"})).filter(x => x.tier === "answer")
   test.check(values.length === 3 && values[0].action.text === "#FF6644", "HEX RGB HSL")
   var text = "Unchanged prose!\\nTwo lines."
   var copied = dictation.provider.query(test.ctx(text)).find(x => x.id === "copy-query")
   test.check(copied.action.text === text && copied.altAction.paste, "dictation copy/paste explicit actions")
   var web = ai.query(test.ctx("literal prompt", "", {provider:"claude",mode:"browser",autoSend:false}))
   test.check(web.some(x => x.action.url === "https://claude.ai/new?q=literal%%20prompt"), "AI browser handoff")
   console.log("PASS providers"); Qt.quit()
 } }
 Timer { interval: 8000; running: true; onTriggered: { console.log("FAIL provider timeout", emoji.emojis.length, files.available); Qt.quit() } }
}''' % json.dumps((root / 'providers').as_uri()))
    env = dict(os.environ, HOME=str(work), XDG_RUNTIME_DIR=str(work), XDG_CONFIG_HOME=str(work / '.config'),
               XDG_DATA_HOME=str(work / '.local/share'), QT_QPA_PLATFORM='offscreen',
               QT_QPA_PLATFORMTHEME='generic', QT_QUICK_BACKEND='software')
    env.pop('DISPLAY', None)
    env.pop('WAYLAND_DISPLAY', None)
    run = subprocess.run(['quickshell', '-p', str(work / 'shell.qml')], env=env,
                         text=True, capture_output=True, timeout=12)
    output = run.stdout + run.stderr
    assert run.returncode == 0 and 'PASS providers' in output, output
    assert not any(s in output for s in ['FAIL', 'TypeError', 'ReferenceError']), output
    print('PASS full Unicode dataset, searchable emoji, colors, timezone/converter, isolated fd/Ghostty, dictation and AI query actions')
