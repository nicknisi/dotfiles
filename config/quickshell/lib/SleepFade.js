// SleepFade.js - the screens fading to black before sleep, as pure functions
// (SleepFade.qml and SleepWatch.qml run them; tests/sleep-fade.cjs pins them).
//
// logind announces sleep with PrepareForSleep(true) on
// org.freedesktop.login1.Manager, whatever started it (the lid, hypridle's
// idle timeout, a power menu, a plain `systemctl suspend`), and waits for
// every delay inhibitor to be released (or InhibitDelayMaxSec: 5 s by
// default, 15 s on milhouse, /etc/systemd/logind.conf.d) before the machine
// sleeps. On wake it sends PrepareForSleep(false).
//
// The main shell holds one delay inhibitor (what=sleep, mode=delay) while
// awake. Its record:
//
//   { state, hold }
//   state  open      awake; the overlay is unmapped
//          closing   PrepareForSleep(true): every screen fades to black over
//                    FADE_MS, the overlay taking the pointer
//          closed    black; the inhibitor released, so logind may sleep
//          opening   PrepareForSleep(false): the screens start black and
//                    fade up over FADE_MS, the pointer going through
//   hold   the inhibitor is wanted: true while open and opening, and while
//          closing until the fade has run (`faded`) or CAP_MS passed
//          (`cap`), whichever comes first; false once closed.
//
// Events: sleep, wake (the signal), faded (the fade's timer), cap (the
// hold's cap), risen (the fade up's timer), watchdog (WATCHDOG_MS of awake
// time after the signal with no wake, SleepWatch's `stale`: the listener
// missed it, so open anyway), lost (the listener died: never leave the
// screens black on a guess).
// The timers are event-loop timers, not the animation's own end: a layer
// under the session lock may get no frames, and the release must not wait
// for frames nobody sees.

var FADE_MS = 400;
var CAP_MS = 1000;
var WATCHDOG_MS = 10000;
var STATES = ["open", "closing", "closed", "opening"];

function initial() {
    return { state: "open", hold: true };
}

function rec(state, hold) {
    return { state: state, hold: hold };
}

function step(m, ev) {
    var s = m && STATES.indexOf(m.state) >= 0 ? m.state : "open";
    var hold = m ? m.hold !== false : true;
    switch (ev) {
    case "sleep":
        if (s === "open" || s === "opening") return rec("closing", true);
        return rec(s, hold);
    case "faded":
        return s === "closing" ? rec("closed", false) : rec(s, hold);
    case "cap":
        return s === "closing" ? rec("closing", false) : rec(s, hold);
    case "wake":
    case "watchdog":
    case "lost":
        if (s === "closing" || s === "closed") return rec("opening", true);
        return rec(s, true);
    case "risen":
        return s === "opening" ? rec("open", true) : rec(s, hold);
    }
    return rec(s, hold);
}

// The overlay's target opacity: 1 closing or closed, 0 otherwise.
function level(m) {
    var s = m ? m.state : "open";
    return s === "closing" || s === "closed" ? 1 : 0;
}
// The overlay is mapped unless open, and takes the pointer only while it
// darkens or is dark.
function mapped(m) {
    return !!m && m.state !== "open";
}
function blocking(m) {
    return !!m && (m.state === "closing" || m.state === "closed");
}

// ---- the listener ---------------------------------------------------------------

var BUS = "org.freedesktop.login1";
var PATH = "/org/freedesktop/login1";
var IFACE = "org.freedesktop.login1.Manager";

// One long-lived process for the session's life: gdbus subscribes to
// logind's signals (no eavesdropping, so no privilege). setpriv's parent
// death signal ends it with the shell however the shell ends.
var MONITOR = ["setpriv", "--pdeathsig", "TERM", "--", "gdbus", "monitor", "--system", "--dest", BUS, "--object-path", PATH];
// Run once each time the monitor reports logind's owner (it is subscribed by
// then): a signal sent before the subscription is still in the property.
var READ = ["gdbus", "call", "--system", "--dest", BUS, "--object-path", PATH, "--method", "org.freedesktop.DBus.Properties.Get", IFACE, "PreparingForSleep"];
// The inhibitor: systemd-inhibit holds logind's fd for as long as its child
// runs, and the child is `cat` on a pipe only the shell writes to. When the
// shell lets go (the Process stops) or dies (the kernel closes the pipe),
// cat reads EOF and exits, systemd-inhibit exits with it, the fd closes, and
// logind drops the inhibitor. setpriv's parent death signal is the second
// way: systemd-inhibit gets SIGTERM when the shell's thread goes.
var INHIBIT = ["setpriv", "--pdeathsig", "TERM", "--", "systemd-inhibit", "--what=sleep", "--mode=delay", "--who=Quickshell", "--why=Fading the screens to black", "cat"];

// What gdbus monitor prints for the signal (the sandbox's fixture feeds the
// same line through feed()).
function signalLine(sleeping) {
    return PATH + ": " + IFACE + ".PrepareForSleep (" + (sleeping ? "true" : "false") + ",)";
}

// A line from the monitor or the property read ->
//   { type: "prepare", sleeping }   the signal
//   { type: "property", sleeping }  the property read's "(<true>,)"
//   { type: "owner" }               "The name ... is owned by ..."
//   { type: "gone" }                "The name ... does not have an owner"
//   null                            anything else
function parse(line) {
    var s = String(line === undefined || line === null ? "" : line).trim();
    if (s === "") return null;
    var m = /^\/org\/freedesktop\/login1: org\.freedesktop\.login1\.Manager\.PrepareForSleep \((true|false),\)$/.exec(s);
    if (m) return { type: "prepare", sleeping: m[1] === "true" };
    m = /^\(<(true|false)>,\)$/.exec(s);
    if (m) return { type: "property", sleeping: m[1] === "true" };
    if (/^The name org\.freedesktop\.login1 is owned by /.test(s)) return { type: "owner" };
    if (/^The name org\.freedesktop\.login1 does not have an owner/.test(s)) return { type: "gone" };
    return null;
}

// The mark the main shell keeps for a lock that starts during the fade
// (SleepFade.qml writes it, lock.qml reads it before its first frame), a
// file in $XDG_RUNTIME_DIR: the time the screens began to darken, ms since
// the epoch, from closing until opening; 0 otherwise.
var MARK = "quickshell-sleep-fade";
// The mark's text says the screens are going dark now: a time within
// WATCHDOG_MS before `now` (a second of skew allowed). Old, zero, empty or
// garbage: no.
function marked(text, now) {
    var t = Number(String(text === undefined || text === null ? "" : text).trim());
    if (!isFinite(t) || t <= 0) return false;
    var age = Number(now) - t;
    return age >= -1000 && age < WATCHDOG_MS;
}

// The monitor's restart delay after its n-th exit in a row: 2, 4, 8 ... 60 s.
function backoff(n) {
    var k = Math.max(0, Math.floor(Number(n) || 0));
    return Math.min(60000, 2000 * Math.pow(2, Math.min(k, 5)));
}

if (typeof module !== "undefined")
    module.exports = {
        FADE_MS: FADE_MS, CAP_MS: CAP_MS, WATCHDOG_MS: WATCHDOG_MS, STATES: STATES, MONITOR: MONITOR, READ: READ, INHIBIT: INHIBIT,
        MARK: MARK, marked: marked,
        initial: initial, step: step, level: level, mapped: mapped, blocking: blocking, signalLine: signalLine, parse: parse, backoff: backoff
    };
