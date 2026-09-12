#!/usr/bin/env python3
"""Exercise production QML transport/session and view against a fake server."""
import os,json,pathlib,tempfile,subprocess,shutil
root=pathlib.Path(__file__).resolve().parents[1]
shim=os.environ.get('LAUNCHER_QML_SHIM_ROOT')
if not shim:
 print('SKIP ConversationView: set LAUNCHER_QML_SHIM_ROOT to the host directory containing Commons/ and Ui/')
 raise SystemExit(0)
shim=pathlib.Path(shim).resolve()
assert (shim/'Commons').is_dir() and (shim/'Ui').is_dir(), 'Host Commons/ and Ui/ shims are required'
with tempfile.TemporaryDirectory(prefix='keystroke-codex-test-') as temp:
 p=pathlib.Path(temp);(p/'.local/state/keystroke/questions').mkdir(parents=True)
 (p/'codex').symlink_to(root/'codex');(p/'qs').symlink_to(shim)
 for name in ['ui','voice']: (p/name).symlink_to(root/name)
 for name in ['Commons','Ui']: (p/name).symlink_to(shim/name)
 # qs.Commons uses the production root Theme singleton, not a fake theme kit.
 for name in ['Theme.qml', 'Prefs.qml']: shutil.copy2(shim/name, p/name)
 theme=p/'.local/state/theme/current';theme.mkdir(parents=True);(theme/'colors.json').write_text('{}')
 tools=p/'bin';tools.mkdir();(tools/'hyprctl').write_text('#!/bin/sh\nexit 1\n');(tools/'hyprctl').chmod(0o700)
 (p/'shell.qml').write_text('''import QtQuick
import QtTest
import Quickshell
import "codex"
ShellRoot {
 id: test
 property int stage: 0
 function check(value,message) { if (!value) { console.log("FAIL",message); Qt.quit(); throw Error(message) } }
 CodexSession { id: session; home: %s; server.command: ["python3",%s,%s] }
 Window { visible: true; width: 700; height: 580
   ConversationView { id: view; anchors.fill: parent; session: session; host: stub }
 }
 QtObject { id: stub
   property color foreground: "#eeeeee"; property color muted: "#aaaaaa"; property color accent: "#aabbff"; property color background: "#222222"
   property string fontFamily: "sans-serif"
   property int fontInput: 20; property int fontTitle: 16; property int fontBody: 14; property int fontLabel: 12; property int fontCaption: 10
   property string voiceTrigger: "tap"
   function isSuperKey(key) { return key===Qt.Key_Super_L || key===Qt.Key_Super_R }
   function voiceBegin(trigger) {}
   property var voice: ({active:false,phase:"idle",level:0,history:[]})
   property int backCalls: 0
   function goBack() { backCalls++; return true }
   function cancel() { session.dismiss() }
   function isModifierKey(key) { return key===Qt.Key_Shift }
   function voiceCancel() { voice = ({active:false,phase:"idle",level:0,history:[]}) }
   function voiceStop() { voice = ({active:true,phase:"transcribing",level:0,history:[]}) }
 }
 TestCase { id: keys; name: "ConversationKeys"; when: false }
 Timer { interval: 100; running: true; onTriggered: {
   session.newQuestion("");view.beginVoice();view.transcript("Open the document, please.",false)
   view.transcript("Open the document, please. Keep two lines!\\nSecond line.",true)
   test.check(session.draft.indexOf("Open the document,")===0 && session.draft.indexOf("Second line.")>0,"voice preserves complete prose")
   var editor=keys.findChild(view,"composer");test.check(!!editor,"composer is reachable")
   view.focusInput();session.draft="edit me";editor.cursorPosition=4
   keys.keyClick(Qt.Key_Left);test.check(stub.backCalls===0 && editor.cursorPosition===3,"Left edits a nonempty draft")
   session.draft="";keys.keyClick(Qt.Key_Left);keys.keyClick(Qt.Key_Backspace)
   test.check(stub.backCalls===2,"empty composer uses palette back navigation")
   session.draft="first question"
   view.focusInput();stub.voice=({active:true,phase:"listening",level:0,history:[]})
   keys.keyClick(Qt.Key_Return);test.check(!session.busy && stub.voice.phase==="transcribing","Enter finishes voice without sending")
   keys.keyClick(Qt.Key_A);test.check(!stub.voice.active,"manual correction cancels voice")
   session.draft="first question";view.focusInput();keys.keyClick(Qt.Key_Return);test.stage=1
 } }
 Timer { interval: 50; repeat: true; running: true; onTriggered: {
   if (test.stage===1 && !session.busy && session.messages.length) {
     test.check(session.answer()==="Hello world","early deltas and final reconcile");
     session.handleRequest(900,"item/commandExecution/requestApproval",{threadId:session.threadId,command:"bad"});test.check(!session.approvals.length,"quick mode rejects local tool approvals");
     session.phase="running";session.mode="agent";session.turnId="approval-test";
     session.handleRequest(901,"item/fileChange/requestApproval",{threadId:session.threadId,turnId:"approval-test",reason:"fixture permission"});test.check(session.approvals.length===1,"agent approval routed");
     keys.keyClick(Qt.Key_Return);test.check(!session.approvals.length,"decline resolves approval");session.phase="idle";session.mode="quick";session.turnId="";
     test.check(session.recent.length===1,"durable recent index")
     session.draft="slow question";session.submit();test.stage=2
   } else if(test.stage===2 && session.phase==="running") {session.stop();test.stage=3}
   else if(test.stage===3 && !session.busy) {
     test.check(session.activity==="Stopped","stop acknowledged");session.newQuestion("next question");test.stage=4
   } else if(test.stage===4 && !session.busy) {test.stage=5;session.requestHandoff()}
   else if(test.stage===6 && !session.busy && session.error) {
     test.check(session.draft==="crash now","disconnect preserves unsent or uncertain draft");
     test.check(!!session.threadId,"disconnect retains saved conversation");test.stage=7;session.requestHandoff()
   }
 } }
 Connections { target: session
   function onHandoffReady(id) {
     test.check(!session.server.ready,"server releases writer before handoff")
     if(test.stage===5) {test.stage=6;session.newQuestion("crash now");return}
     test.check(test.stage===7,"handoff waits");console.log("PASS Codex stream, voice keys, approvals, cancel, disconnect, writer release and view");Qt.quit()
   }
 }
 Timer { interval: 12000; running: true; onTriggered: {console.log("FAIL timeout",test.stage,session.phase,session.error);Qt.quit()} }
}'''%(json.dumps(str(p)),json.dumps(str(root/'tests/integrations_codex_server.py')),json.dumps(str(p/'requests.jsonl'))))
 env=os.environ.copy();env.pop('DISPLAY',None);env.pop('WAYLAND_DISPLAY',None);env.pop('HYPRLAND_INSTANCE_SIGNATURE',None);env.update(PATH=str(tools)+os.pathsep+env.get('PATH',''),DBUS_SESSION_BUS_ADDRESS='unix:path='+str(p/'no-session-bus'),HOME=str(p),XDG_RUNTIME_DIR=str(p),XDG_CONFIG_HOME=str(p/'.config'),XDG_DATA_HOME=str(p/'.local/share'),QML_IMPORT_PATH=str(p),QT_QPA_PLATFORM='offscreen',QT_QPA_PLATFORMTHEME='generic',QT_QUICK_BACKEND='software')
 r=subprocess.run(['quickshell','-p',str(p/'shell.qml')],env=env,text=True,capture_output=True,timeout=18)
 out=r.stdout+r.stderr
 assert 'PASS Codex' in out and 'FAIL' not in out,out
 assert 'TypeError' not in out and 'ReferenceError' not in out,out
 print(out)
