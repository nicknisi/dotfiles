#!/usr/bin/env python3
"""Real QML process lifecycle with a delayed local JSON-lines worker."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='keystroke-matching-session-') as temp:
    work = Path(temp)
    shutil.copytree(root / 'matching', work / 'matching')
    fake = work / 'worker.py'
    log = work / 'workers'
    fake.write_text('''import json,os,sys,time
from pathlib import Path
with Path(sys.argv[1]).open('a') as f: f.write(str(os.getpid())+' '+sys.argv[2]+'\\n')
time.sleep(.15)
print(json.dumps({'type':'ready'}),flush=True)
for line in sys.stdin:
 r=json.loads(line)
 if 'rows' in r: rows=r['rows']
 time.sleep(.15)
 print(json.dumps({'type':'result','id':r['id'],'matches':[{'id':rows[0]['id'],'score':.8}] if rows else []}),flush=True)
''')
    (work / 'shell.qml').write_text('''import QtQuick
import Quickshell
import "matching"
ShellRoot {
 id: test
 property int stage: 0
 function check(ok,msg) { if(!ok) { console.log("FAIL",msg); Qt.quit(); throw Error(msg) } }
 Session { id: session; enabled: true }
 Timer { interval: 25; repeat: true; running: true; onTriggered: {
   if(test.stage===0) {
     var helper = decodeURIComponent(Qt.resolvedUrl("helpers/matching-start.lua").toString().replace("file://", ""))
     test.check(JSON.stringify(session.command) === JSON.stringify(["luajit", helper, "--model", "small", "--offline"]), "production matching starts offline through LuaJIT")
     // Only the delayed protocol fixture is Python, never the production helper.
     session.command = Qt.binding(function() { return ["python3", %s, %s, session.model] })
     session.submit("old","old",[{id:"old",text:"old"}]); test.stage=1
   }
   else if(test.stage===1 && session.inFlight) { session.submit("new","new",[{id:"new",text:"new"}]); test.stage=2 }
   else if(test.stage===2 && session.resultKey) {
     test.check(session.resultKey==="new" && session.matches[0].id==="new","stale response discarded and newest catalog used")
     session.enabled=false
     test.check(!session.loaded && !session.starting && !session.resultKey && !session.matches.length,"off unloads and clears results immediately")
     test.stage=3
   } else if(test.stage===3 && !session.stopping) {
     session.submit("off","off",[{id:"off",text:"off"}])
     test.check(!session.queued && !session.starting,"off cannot start worker")
     session.enabled=true; session.model="large"
     session.submit("large","large",[{id:"large",text:"large"}]); test.stage=4
   } else if(test.stage===4 && session.starting) {
     session.model="small"
     session.submit("small","small",[{id:"small",text:"small"}]); test.stage=5
   } else if(test.stage===5 && session.resultKey) {
     test.check(session.resultKey==="small" && session.matches[0].id==="small","model switch during loading replaces worker")
     session.unloadIdle(); test.stage=50
   } else if(test.stage===50 && !session.stopping) {
     session.submit("small","small",[{id:"small",text:"small"}])
     test.check(!session.loaded && !session.queued && session.resultKey==="small","idle unload retains result without reloading on a status refresh")
     session.submit("wake","wake",[{id:"wake",text:"wake"}]); test.stage=51
   } else if(test.stage===51 && session.resultKey==="wake") {
     test.check(session.matches[0].id==="wake","new query rebuilds catalog after idle unload")
     session.submit("cancel","cancel",[{id:"cancel",text:"cancel"}]); session.cancelRequest()
     test.check(!session.queued && !session.resultKey,"cancellation clears queued work")
     session.fail("fixture setup failure")
     test.check(session.failed && session.error.length > 0,"failure is visible")
     session.retry()
     test.check(session.setupRequested && !session.failed,"retry explicitly allows setup")
     test.stage=6
   } else if(test.stage===6 && session.ready && !session.busy) {
     session.enabled=false
     test.check(!session.setupRequested,"off revokes setup permission")
     test.stage=7
   } else if(test.stage===7 && !session.stopping) { console.log("PASS matching lifecycle"); Qt.quit() }
 } }
 Timer { interval:10000; running:true; onTriggered:{ console.log("FAIL timeout",test.stage,session.error,session.status); Qt.quit() } }
}
''' % (json.dumps(str(fake)), json.dumps(str(log))))
    env = dict(os.environ, HOME=str(work), XDG_RUNTIME_DIR=str(work), XDG_CONFIG_HOME=str(work / '.config'), XDG_DATA_HOME=str(work / '.local/share'), QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='generic', QT_QUICK_BACKEND='software')
    env.pop('DISPLAY', None)
    env.pop('WAYLAND_DISPLAY', None)
    result = subprocess.run(['quickshell','-p',str(work/'shell.qml')], env=env, capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and 'PASS matching lifecycle' in output and 'FAIL' not in output, output
    assert 'TypeError' not in output and 'ReferenceError' not in output, output
    for record in log.read_text().splitlines():
        pid = int(record.split()[0])
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            continue
        raise AssertionError(f'Model worker {pid} leaked after off')
    print('PASS matching: stale replies, newest catalog, off unload, model switch during load, cancellation, no leaked worker')
