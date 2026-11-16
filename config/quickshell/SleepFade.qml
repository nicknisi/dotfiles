// SleepFade.qml - every screen fades to black before the machine sleeps, and
// back up after (lib/SleepFade.js has the record and the reasons).
//
//   PrepareForSleep(true)   closing: a black overlay per screen fades in over
//                           400 ms and takes the pointer; then closed, and the
//                           delay inhibitor is released, so logind may sleep.
//                           The hold is capped at 1 s whatever happens.
//   PrepareForSleep(false)  opening: the screens start black (the last frame
//                           before sleep) and fade up over 400 ms with the
//                           pointer going through; then open, the overlay
//                           unmapped. The inhibitor is taken again at once.
//
// The inhibitor (SleepFade.INHIBIT) is systemd-inhibit --what=sleep
// --mode=delay holding logind's fd while its child `cat` reads a pipe only
// this shell writes to. Letting go stops the Process; if the shell dies, the
// kernel closes the pipe, cat sees EOF and exits, systemd-inhibit exits with
// it and logind drops the inhibitor with the fd (setpriv's parent death
// signal ends it too). It never outlives the shell, so a dead shell never
// delays sleep. A frozen one does: the pipe stays open and the 1 s cap runs
// on this shell's own event loop, so logind waits out InhibitDelayMaxSec
// (5 s by default, 15 s on milhouse). It is held only while the listener
// runs (no listener, no fade to wait for); if it ends on its own while
// wanted, it is taken again after 5 s.
//
// The lock is its own process on the session-lock surface, above every layer
// here, so while locked this overlay is under it and the lock darkens its
// own content (lock.qml, the same SleepWatch). Locking never waits on any of
// this: hypridle's before_sleep_cmd runs shell-lock as it always did, and
// its own inhibitor (inhibit_sleep = 3) holds sleep until the lock is up.
// A lock that starts during the fade reads the mark this writes,
// $XDG_RUNTIME_DIR/quickshell-sleep-fade (SleepFade.MARK): the time the
// screens began to darken (ms since the epoch) from closing until opening,
// 0 otherwise. It reads it before its first frame, so it starts black
// rather than lit, before its own watch has a reading (SleepFade.marked:
// fresh for WATCHDOG_MS, so a mark left by a dead shell soon counts for
// nothing; the lock's own watch overrides it as soon as it reads).
//
// Motion off (Motion.reduced): the overlay goes black and comes back at
// once; the release still follows the (zero-length) fade.
//
// `sleep` IPC: inspect. In the sandbox (Fixture.sandbox), also
// prepare true|false, which feeds SleepWatch the line gdbus would print for
// logind's signal (the sandbox has no system bus), and hold LEVEL (0..1, or
// -1 to let go), which pins the overlay's opacity for a mid-fade shot. The
// sandbox's inhibitor is a plain `cat`: nothing reaches logind.
import Quickshell
import Quickshell.Io
import QtQuick
import "lib/SleepFade.js" as SleepFade

Scope {
    id: root

    readonly property bool sandbox: Fixture.sandbox
    // The per-screen overlay windows (SleepNights.qml). tests/sleep-fade.sh
    // runs offscreen, where no layer-shell backend exists, and turns them off.
    property bool overlay: true
    readonly property bool mapped: SleepFade.mapped(root.m) || root.pinned >= 0
    readonly property bool blocking: SleepFade.blocking(root.m)
    property var m: SleepFade.initial()
    readonly property int fadeMs: Motion.reduced ? 0 : SleepFade.FADE_MS
    // The sandbox's pinned opacity, -1 for none.
    property real pinned: -1
    readonly property real level: root.pinned >= 0 ? root.pinned : SleepFade.level(root.m)
    // When the last sleep began and when its inhibitor let go (ms since the
    // epoch), for inspect().
    property real sleptAt: 0
    property real releasedAt: 0
    property bool inhibitorUp: false
    property int inhibitorStarts: 0

    function send(ev: string): void {
        const was = root.m;
        const next = SleepFade.step(was, ev);
        if (next.state === was.state && next.hold === was.hold) return;
        root.m = next;
        if (next.state !== was.state) root.entered(next.state);
    }
    function entered(state: string): void {
        fade.stop();
        cap.stop();
        rise.stop();
        if (state === "closing") {
            root.sleptAt = Date.now();
            root.writeMark(root.sleptAt);
            fade.interval = root.fadeMs;
            fade.restart();
            cap.restart();
        } else if (state === "opening") {
            root.writeMark(0);
            rise.interval = root.fadeMs;
            rise.restart();
        }
    }
    // The inhibitor is held while the record wants it and the listener runs:
    // with no listener there is no fade to wait for, and logind must not wait
    // out InhibitDelayMaxSec (5 s by default, 15 s on milhouse) on a lock
    // nobody will release.
    readonly property bool wantInhibitor: root.m.hold && (!watch.listening || watch.running)
    onWantInhibitorChanged: root.syncInhibitor()
    function syncInhibitor(): void {
        if (root.wantInhibitor) {
            if (inhibitor.running || retake.running) return;
            root.inhibitorStarts++;
            inhibitor.running = true;
        } else {
            retake.stop();
            if (!inhibitor.running) return;
            root.releasedAt = Date.now();
            inhibitor.running = false;
        }
    }

    // Still preparing this long (awake time) with no wake signal: the
    // listener missed it, so the screens open (the `watchdog` event).
    // SleepWatch drops `preparing` with it, so the next PrepareForSleep(true)
    // fades and releases again. tests/sleep-fade.sh shortens it.
    property alias staleMs: watch.staleMs

    SleepWatch {
        id: watch
        listening: !root.sandbox
        onPrepare: sleeping => root.send(sleeping ? "sleep" : "wake")
        onRunningChanged: if (!running && root.m.state !== "open") root.send("lost")
        onStale: {
            console.warn("sleep fade: no wake signal " + watch.staleMs + " ms after PrepareForSleep; opening");
            root.send("watchdog");
        }
    }

    Timer {
        id: fade
        onTriggered: root.send("faded")
    }
    Timer {
        id: cap
        interval: SleepFade.CAP_MS
        onTriggered: root.send("cap")
    }
    Timer {
        id: rise
        onTriggered: root.send("risen")
    }

    Process {
        id: inhibitor
        // A dry run (the sandbox, SHELL_DRY_RUN=1) holds a plain `cat`.
        command: Fixture.dryRun ? ["cat"] : SleepFade.INHIBIT
        stdinEnabled: true
        onStarted: root.inhibitorUp = true
        onExited: code => {
            root.inhibitorUp = false;
            if (root.wantInhibitor) {
                console.warn("sleep fade: the inhibitor ended (" + code + "); taking it again in 5 s");
                retake.restart();
            }
        }
    }
    Timer {
        id: retake
        interval: 5000
        onTriggered: root.syncInhibitor()
    }
    Component.onCompleted: {
        root.syncInhibitor();
        // Open: a mark left by an earlier instance (a reload mid-sleep, a
        // crash) is cleared.
        root.writeMark(0);
    }

    // ---- the mark a starting lock reads ----------------------------------------------------
    readonly property string markPath: {
        const d = Quickshell.env("XDG_RUNTIME_DIR");
        return d ? String(d) + "/" + SleepFade.MARK : "";
    }
    // Not on a dry run outside the sandbox (SHELL_DRY_RUN=1 changes nothing
    // a real lock would read).
    readonly property bool marks: root.markPath !== "" && (!Fixture.dryRun || Fixture.sandbox)
    function writeMark(value: real): void {
        if (root.marks) mark.setText(String(value) + "\n");
    }
    FileView {
        id: mark
        path: root.marks ? root.markPath : ""
        // A few bytes, written before anything else runs: done before the
        // lock hypridle starts on the same signal has loaded.
        blockWrites: true
        printErrors: false
    }

    // ---- the overlay, one per screen ---------------------------------------------------
    // SleepNights.qml, by URL: PanelWindow will not even compile where no
    // layer-shell backend exists (tests/sleep-fade.sh runs offscreen with
    // `overlay` off), and this file must load there.
    LazyLoader {
        id: nights
        active: root.overlay
        source: Qt.resolvedUrl("SleepNights.qml")
        onItemChanged: if (item) item.fade = root
    }

    function inspect(): var {
        return {
            state: root.m.state,
            hold: root.m.hold,
            inhibitor: root.inhibitorUp,
            inhibitorStarts: root.inhibitorStarts,
            level: root.level,
            mapped: root.mapped,
            blocking: root.blocking,
            windows: nights.item ? nights.item.count : 0,
            fadeMs: root.fadeMs,
            releasedAfter: root.releasedAt >= root.sleptAt && root.sleptAt > 0 ? Math.round(root.releasedAt - root.sleptAt) : -1,
            listening: watch.listening,
            monitor: watch.running,
            preparing: watch.preparing,
            stales: watch.stales,
            last: watch.last,
            sandbox: root.sandbox
        };
    }

    IpcHandler {
        target: "sleep"
        function inspect(): string {
            return JSON.stringify(root.inspect());
        }
        // Sandbox only: logind's signal, as gdbus would print it.
        function prepare(sleeping: bool): string {
            if (!root.sandbox) return "error: sandbox only";
            watch.feed(SleepFade.signalLine(sleeping));
            return "ok " + root.m.state;
        }
        // Sandbox only: pin the overlay at LEVEL (0..1) for a shot; -1 lets go.
        function hold(level: real): string {
            if (!root.sandbox) return "error: sandbox only";
            root.pinned = level >= 0 ? Math.min(1, level) : -1;
            return "ok";
        }
    }
}
