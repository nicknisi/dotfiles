// SleepWatch.qml - logind's PrepareForSleep as a property (lib/SleepFade.js).
//
// One long-lived `gdbus monitor` on the system bus for as long as
// `listening` (SleepFade.MONITOR, under setpriv's parent death signal, so it
// ends with the shell), its lines fed to SleepFade.parse(). Each time it
// reports logind's owner (it is subscribed by then) one `gdbus call` reads
// PreparingForSleep, so a sleep that began before the subscription (the lock
// starting from hypridle's before_sleep_cmd) still counts; a signal seen
// since wins over that read. One more read starts with the monitor, without
// waiting for the subscription, so the first value comes as early as it can
// (the lock's start waits on it); its answer counts only until the read
// after the subscription has answered. If the monitor exits it comes back after
// SleepFade.backoff() (2 s, doubling to 60 s), and `preparing` drops to
// false meanwhile: nothing stays dark on a listener that is gone.
//
// A wake signal can be missed (the listener restarting across it). After
// `staleMs` (SleepFade.WATCHDOG_MS, 10 s) of awake time still `preparing`
// (Qt's timers run on the monotonic clock, which stops while the machine
// sleeps), `preparing` drops to false and `stale` fires: the next
// PrepareForSleep(true) then counts again rather than matching a value that
// never went back.
//
// `settled`: whether `preparing` is known yet. False from the start until
// the first reading (the property read or a signal) has been applied; always
// true while not listening (nothing to wait for). lock.qml darkens at once,
// without the 400 ms fade, until it is settled: a lock started during a
// sleep goes black the moment it learns, not over the lock-in motion.
//
// Used by SleepFade.qml (the main shell's fade) and lock.qml (the lock's own
// darkening). Neither waits on it for anything else. The sandbox has no
// system bus: `listening` is off there and its fixture verbs call feed()
// with SleepFade.signalLine(), the very line gdbus prints.
import Quickshell
import Quickshell.Io
import QtQuick
import "lib/SleepFade.js" as SleepFade

Scope {
    id: root

    property bool listening: true
    // PrepareForSleep(true) seen (or read), and no PrepareForSleep(false) since.
    property bool preparing: false
    // A signal arrived since the monitor last (re)started.
    property bool signalled: false
    // The last line that meant something, for inspect().
    property string last: ""
    property int exits: 0
    readonly property bool running: monitor.running
    // A first reading has been applied (see the header).
    property bool heard: false
    readonly property bool settled: !root.listening || root.heard
    property int staleMs: SleepFade.WATCHDOG_MS
    property int stales: 0

    signal prepare(bool sleeping)
    // Still preparing staleMs after the signal: `preparing` dropped without
    // a `prepare`.
    signal stale

    function set(sleeping: bool): void {
        if (root.preparing === sleeping) return;
        root.preparing = sleeping;
        root.prepare(sleeping);
    }
    function feed(line: string): void {
        const ev = SleepFade.parse(line);
        if (!ev) return;
        root.last = ev.type + (ev.sleeping === undefined ? "" : " " + ev.sleeping);
        if (ev.type === "prepare") {
            root.signalled = true;
            root.set(ev.sleeping);
            root.hear();
        } else if (ev.type === "property") {
            if (!root.signalled) root.set(ev.sleeping);
            root.hear();
        } else if (ev.type === "owner") {
            root.exits = 0;
            if (!reader.running) reader.running = true;
        }
    }
    // The read after the subscription has answered: the early one's answer
    // (sent before it) no longer counts.
    property bool readSubscribed: false

    // After this turn of the event loop, so whatever follows `preparing`
    // (lock.qml's night) has taken the first value before it counts as
    // settled.
    function hear(): void {
        if (!root.heard) Qt.callLater(() => root.heard = true);
    }

    Timer {
        id: staleTimer
        interval: root.staleMs
        running: root.preparing
        onTriggered: {
            root.stales++;
            root.last = "stale";
            root.preparing = false;
            root.stale();
        }
    }

    Component.onCompleted: {
        if (!root.listening) return;
        monitor.running = true;
        early.running = true;
    }
    onListeningChanged: {
        again.stop();
        monitor.running = root.listening;
    }
    Process {
        id: monitor
        command: SleepFade.MONITOR
        stdout: SplitParser {
            onRead: data => root.feed(data)
        }
        onStarted: root.signalled = false
        onExited: {
            root.set(false);
            if (!root.listening) return;
            again.interval = SleepFade.backoff(root.exits);
            root.exits++;
            again.restart();
        }
    }
    Timer {
        id: again
        onTriggered: if (root.listening && !monitor.running) monitor.running = true
    }
    Process {
        id: reader
        command: SleepFade.READ
        stdout: StdioCollector {
            onStreamFinished: {
                root.readSubscribed = true;
                root.feed(text);
            }
        }
    }
    Process {
        id: early
        command: SleepFade.READ
        stdout: StdioCollector {
            onStreamFinished: if (!root.readSubscribed) root.feed(text)
        }
    }
}
