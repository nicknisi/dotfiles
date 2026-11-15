import QtQuick
import Quickshell
import Quickshell.Services.Pam
import "../lib/LockMachine.js" as LockMachine

// LockAuth.qml - the lock's one password buffer and its PAM conversation
// (PLAN M8, control-lock 4.6): lib/LockMachine.js's record, kept here and
// moved only by the real PamContext's signals and the surfaces' key intents.
//
// lock.qml owns one of these. `m` is the record the surfaces draw; `unlocking`
// turns true only when PAM said Success to a conversation this lock started
// (LockMachine.completed), and that is the one way lock.qml unlocks.
//
// PAM: `config` "hyprlock" in /etc/pam.d (it includes `login`, the stack
// hyprlock uses today: pam_faillock with deny 10 and unlock_time 120). Only
// lock.qml's sandbox mode changes either, to run tests against a test stack.
//
// Logging: the PAM error's name, never the buffer, never a response, never a
// PAM message (faillock's carry the user name).
Scope {
    id: auth

    property string config: "hyprlock"
    property string configDirectory: "/etc/pam.d"

    property var m: LockMachine.initial()
    readonly property bool unlocking: m.phase === "unlocking"
    readonly property bool running: LockMachine.running(m)
    readonly property bool active: pam.active

    function apply(next) {
        auth.m = LockMachine.perform(next, pam);
    }
    function type(text: string) {
        apply(LockMachine.type(auth.m, text));
    }
    function erase() {
        apply(LockMachine.erase(auth.m));
    }
    function clear() {
        apply(LockMachine.clear(auth.m));
    }
    function submit() {
        apply(LockMachine.submit(auth.m));
    }
    // The lock going away: nothing kept, a running conversation aborted.
    function wipe() {
        apply(LockMachine.wipe(auth.m));
    }

    PamContext {
        id: pam
        config: auth.config
        configDirectory: auth.configDirectory

        onPamMessage: auth.apply(LockMachine.message(auth.m, {
            text: pam.message,
            isError: pam.messageIsError,
            responseRequired: pam.responseRequired,
            responseVisible: pam.responseVisible
        }))
        onCompleted: result => auth.apply(LockMachine.completed(auth.m, result))
        onError: error => {
            console.warn("lock: PAM error:", PamError.toString(error));
            auth.apply(LockMachine.errored(auth.m));
        }
    }

    // A conversation stuck past LockMachine.TIMEOUT is aborted and fails.
    Timer {
        interval: LockMachine.TIMEOUT
        running: auth.running
        onTriggered: auth.apply(LockMachine.timeout(auth.m))
    }

    // Quitting or a reload: the record goes with it, and PamContext ends its
    // own conversation when it is destroyed. No unlock here: a lock object
    // destroyed while locked leaves the session locked.
    Component.onDestruction: auth.m = LockMachine.initial()
}
