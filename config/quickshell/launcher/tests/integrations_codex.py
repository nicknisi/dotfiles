#!/usr/bin/env python3
"""Production QML transport/session with fake streaming, permissions and failures."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='launcher-codex-') as temp:
    work = Path(temp)
    (work / '.local/state/keystroke/questions').mkdir(parents=True)
    log = work / 'requests.jsonl'
    (work / 'shell.qml').write_text('''import QtQuick
import Quickshell
import %s
ShellRoot {
 id: test
 property int stage: 0
 function check(ok, msg) { if (!ok) { console.log("FAIL", msg); Qt.quit(); throw Error(msg) } }
 CodexSession { id: session; home: %s; server.command: ["python3", %s, %s] }
 Timer { interval: 25; repeat: true; running: true; onTriggered: {
   if (test.stage === 0) { session.newQuestion("first question"); test.stage = 1 }
   else if (test.stage === 1 && !session.busy && session.messages.length) {
     test.check(session.answer() === "Hello world", "early deltas reconcile with final text")
     test.check(session.recent.length === 1, "recent conversation saved")
     session.handleRequest(900, "item/commandExecution/requestApproval", {threadId: session.threadId})
     test.check(!session.approvals.length, "quick mode rejects approvals")
     session.phase = "running"; session.mode = "agent"; session.turnId = "permission-test"
     var p = {threadId: session.threadId, turnId: session.turnId, permissions: {}}
     session.handleRequest(901, "item/permissions/requestApproval", p); session.decide(false)
     session.handleRequest(902, "item/fileChange/requestApproval", p); session.decide(true)
     p.questions = [{id: "answer", question: "Fixture?"}]
     session.handleRequest(903, "item/tool/requestUserInput", p); session.decide(true, {answer: "literal answer"})
     session.handleRequest(904, "unsupported/capability", p)
     test.check(!session.approvals.length, "approval decisions drain queue")
     session.phase = "idle"; session.mode = "quick"; session.turnId = ""
     session.draft = "slow question"; session.submit(); test.stage = 2
   } else if (test.stage === 2 && session.phase === "running") {
     session.draft = "steer literal request"; session.submit(); session.stop(); test.stage = 3
   } else if (test.stage === 3 && !session.busy) {
     test.check(session.activity === "Stopped", "stop acknowledged")
     session.newQuestion("agent approval", %s); test.stage = 4
   } else if (test.stage === 4 && session.approvals.length) {
     test.check(session.approvals[0].id === "approval-1", "server approval routed")
     session.decide(false); test.stage = 5
   } else if (test.stage === 5 && !session.busy) {
     test.stage = 6; session.requestHandoff()
   } else if (test.stage === 7 && !session.busy && session.error) {
     test.check(session.draft === "crash now", "disconnect preserves uncertain draft")
     test.check(!!session.threadId, "disconnect preserves thread")
     test.stage = 8; session.requestHandoff()
   } else if (test.stage === 9 && !session.busy && session.error) {
     test.check(session.error.indexOf("unavailable") >= 0, "explicit unavailable model fails without inference")
     console.log("PASS Codex lifecycle"); Qt.quit()
   }
 } }
 Connections { target: session
   function onHandoffReady(id) {
     test.check(!session.server.ready, "writer released before handoff")
     if (test.stage === 6) { test.stage = 7; session.newQuestion("crash now"); return }
     test.check(test.stage === 8, "handoff after disconnect")
     session.settings = {model: "unavailable-fixture"}
     test.stage = 9; session.newQuestion("must not submit")
   }
 }
 Timer { interval: 12000; running: true; onTriggered: { console.log("FAIL timeout", test.stage, session.phase, session.error); Qt.quit() } }
}''' % tuple(json.dumps(str(p)) for p in [(root / 'codex').as_uri(), work, root / 'tests/integrations_codex_server.py', log, work]))
    env = dict(os.environ, HOME=str(work), XDG_RUNTIME_DIR=str(work),
               XDG_CONFIG_HOME=str(work / '.config'), XDG_DATA_HOME=str(work / '.local/share'),
               QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='generic', QT_QUICK_BACKEND='software')
    env.pop('DISPLAY', None)
    env.pop('WAYLAND_DISPLAY', None)
    run = subprocess.run(['quickshell', '-p', str(work / 'shell.qml')], env=env,
                         text=True, capture_output=True, timeout=18)
    output = run.stdout + run.stderr
    assert run.returncode == 0 and 'PASS Codex lifecycle' in output, output
    assert not any(s in output for s in ['FAIL', 'TypeError', 'ReferenceError']), output
    messages = [json.loads(line) for line in log.read_text().splitlines()]
    responses = {m['id']: m for m in messages if 'method' not in m}
    assert 'error' in responses[900] and 'error' in responses[904]
    assert responses[901]['result'] == {'permissions': {}, 'scope': 'turn'}
    assert responses[902]['result'] == {'decision': 'accept'}
    assert responses[903]['result'] == {'answers': {'answer': {'answers': ['literal answer']}}}
    assert any(m.get('method') == 'turn/steer' for m in messages)
    assert not any(m.get('params', {}).get('input', [{}])[0].get('text') == 'must not submit' for m in messages)
    print('PASS Codex streaming, default model, quick isolation, explicit agent approvals, steering, cancel, disconnect and writer release')
