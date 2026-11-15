import QtQuick
import Quickshell
import qs.Lock
import "lib/LockMachine.js" as LockMachine

// tests/lock-pam.sh runs this as shell.qml, offscreen: Lock/LockAuth.qml with
// the real PamContext against tests/lock-pam-stacks.sh's test stacks (never
// /etc/pam.d, never the real password). Each case builds a fresh LockAuth,
// types, presses Enter and waits for the conversation to end:
//
//   wrong     t-pass, a wrong password: idle, "Wrong password", buffer empty
//   maxtries  t-maxtries: idle, an error message, buffer empty
//   error     t-error: idle, the TTY message, one shake for error + completed
//   missing   no such stack: start() refuses, idle, the TTY message
//   wipe      t-slow, the lock going away mid-check: aborted, and no
//             Success arrives afterwards even with the right password
//   esc       t-slow, Esc mid-check: the conversation keeps going, succeeds
//   pass      t-pass, the test password: unlocking
ShellRoot {
    id: root

    readonly property string pamDir: Quickshell.env("LOCK_PAM_DIR") ?? ""
    readonly property string secret: Quickshell.env("LOCK_PAM_SECRET") ?? ""

    readonly property var cases: [
        { name: "wrong", config: "t-pass", typed: "nope", want: { phase: "idle", message: LockMachine.TEXT.wrong, error: true, attempts: 1, shake: 1 } },
        { name: "maxtries", config: "t-maxtries", typed: "secret", want: { phase: "idle", error: true, attempts: 1, shake: 1 } },
        { name: "error", config: "t-error", typed: "secret", want: { phase: "idle", message: LockMachine.TEXT.broken, error: true, attempts: 1, shake: 1 } },
        { name: "missing", config: "t-missing", typed: "secret", want: { phase: "idle", message: LockMachine.TEXT.broken, error: true, attempts: 1 } },
        { name: "wipe", config: "t-slow", typed: "secret", wipeAfter: 400, settle: 3000, want: { phase: "idle", attempts: 0 } },
        { name: "esc", config: "t-slow", typed: "secret", clearAfter: 400, want: { phase: "unlocking" } },
        { name: "pass", config: "t-pass", typed: "secret", want: { phase: "unlocking", attempts: 0 } }
    ]
    property int index: -1
    property var auth: null
    property int elapsed: 0
    property bool wiped: false
    property bool cleared: false
    property var seen: []

    Component {
        id: authComponent
        LockAuth {}
    }

    function fail(why: string) {
        console.log("LOCK_PAM_FAIL:", why);
        Qt.quit();
    }

    function next() {
        if (root.auth) root.auth.destroy();
        root.index++;
        if (root.index >= root.cases.length) {
            console.log("LOCK_PAM_PASS");
            Qt.quit();
            return;
        }
        const c = root.cases[root.index];
        root.auth = authComponent.createObject(root, { config: c.config, configDirectory: root.pamDir });
        root.elapsed = 0;
        root.wiped = false;
        root.cleared = false;
        root.seen = [];
        root.auth.type(c.typed === "secret" ? root.secret : c.typed);
        if (root.auth.m.buffer.length === 0) return fail(c.name + ": typing reached no buffer");
        root.auth.submit();
        poll.restart();
    }

    Timer {
        id: poll
        interval: 100
        repeat: true
        onTriggered: {
            const c = root.cases[root.index];
            const m = root.auth.m;
            root.elapsed += interval;
            if (root.seen.indexOf(m.phase) < 0) root.seen = root.seen.concat([m.phase]);
            if (m.phase === "authenticating" && m.buffer !== "" && !m.pending) return root.fail(c.name + ": a buffer while PAM checks");
            if (c.wipeAfter !== undefined && !root.wiped && root.elapsed >= c.wipeAfter) {
                root.wiped = true;
                root.auth.wipe();
            }
            if (c.clearAfter !== undefined && !root.cleared && root.elapsed >= c.clearAfter) {
                root.cleared = true;
                root.auth.clear();
                if (root.auth.m.phase !== "authenticating") return root.fail(c.name + ": Esc ended the conversation");
            }
            if (m.phase === "unlocking" && c.want.phase !== "unlocking") return root.fail(c.name + ": unlocked");
            const settled = !LockMachine.running(m) && root.elapsed >= (c.settle ?? 0);
            if (!settled) {
                if (root.elapsed > 8000) root.fail(c.name + ": still " + m.phase + " after 8 s");
                return;
            }
            stop();
            for (const k of Object.keys(c.want)) {
                if (m[k] !== c.want[k]) return root.fail(c.name + ": " + k + " is " + JSON.stringify(m[k]) + ", want " + JSON.stringify(c.want[k]));
            }
            if (m.buffer !== "") return root.fail(c.name + ": the buffer survived");
            if (m.phase === "idle" && m.error && m.message === "") return root.fail(c.name + ": no message");
            if (c.name === "wipe" && root.auth.active) return root.fail("wipe: PAM still active");
            console.log("LOCK_PAM_CASE", c.name, "ok", root.seen.join(">"));
            root.next();
        }
    }

    Component.onCompleted: {
        if (root.pamDir === "" || root.secret === "") return fail("LOCK_PAM_DIR and LOCK_PAM_SECRET are required");
        next();
    }
}
