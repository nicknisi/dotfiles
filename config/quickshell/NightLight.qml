pragma Singleton
// NightLight.qml - the night light, on the hyprsunset that already runs as a
// systemd user service (hyprsunset.service, v0.4.0 on milhouse).
//
// On is `hyprctl hyprsunset temperature <K>`, off is `hyprctl hyprsunset
// identity`: one call per change, never one per tick. The shell never starts
// or stops the daemon by itself; the sheet's "Start hyprsunset" row runs
// `systemctl --user start hyprsunset` when asked.
//
// What it should be at a moment is lib/NightLight.js effective(): the stored
// choices (Prefs, so capsule.json in the state dir: warmth, schedule off or
// From/To, the manual state, an override and when it runs out) at `now`.
// A toggle without a schedule is the manual state; against a schedule it is
// an override until the next schedule edge.
//
// When it applies (each one hyprctl call, only if hyprsunset may not hold
// what it should):
//   - the shell starts (once Prefs has read the file);
//   - `on` or the warmth changes (the warmth 150 ms after a drag settles);
//   - hyprsunset (re)starts: its state resets to its own profile, identity
//     here. One long-lived `journalctl --user --follow` hears the user
//     manager's lines about the unit (USER_UNIT: Started, Stopping, Stopped,
//     Failed) and hyprsunset's own output (_SYSTEMD_USER_UNIT). A lifecycle
//     line is followed by one call a second later, a few more after a
//     Started while the socket comes up. A Stopped line's call fails, which
//     is how the tile learns it is unavailable;
//   - one of hyprsunset's own profiles fires while it would leave the screen
//     other than it should (config/hypr/hyprsunset.conf's 07:00 identity
//     inside an evening window, or a manual on that morning): its journal
//     line "Switched to new profile from: 7:0" is followed by one call a
//     second later. hyprsunset only fires on time while awake: after a night
//     of suspend it switches 6 to 50 s after the wake (milhouse's journal),
//     which can be after the minute timer's first tick, so the put-back
//     follows hyprsunset's line, not the clock. Its other lines (the CTM it
//     logs for every request) are ignored. Without the journal the minute
//     timer sees the profile time pass and puts it back 3 s later, and once
//     more `lateMs` later when that tick ends a gap (a resume).
// The minute timer compares times only: it moves `now`, and only a change of
// `on` (a schedule edge) or a profile firing spawns anything.
//
// available: the last call reached hyprsunset. `reason` says why not:
// "checking" (no call yet), "stopped" (no socket: not running), "error"
// (hyprsunset answered something else, `message`), "session" (no Hyprland
// session, no HYPRLAND_INSTANCE_SIGNATURE: hyprctl has nothing to talk to),
// "dry" (Fixture.dryRun: the sandbox and check.sh, which share the session's
// Hyprland and must never change the real screen). While unavailable the
// choices can still change; on and off are refused (the switch is disabled
// and the tile opens the sheet), and whatever is stored applies when
// hyprsunset comes back. `active` (on and available) is what the screen
// shows: the moon in the island's status pill and the bar's status module.
//
// Sunset to sunrise is not offered: nothing on this machine stores a
// location. The time zone comes from the network (NetworkManager dispatcher
// 10-timezone, `timedatectl set-timezone`), and tzdata's zone1970.tab only
// knows the zone's reference city (Chicago for America/Chicago), which can be
// half an hour or more off anywhere else in the zone.
//
// The `nightlight` IPC target: toggle, on, off, temperature <K>, schedule
// <off | HH:MM-HH:MM>, inspect.
import Quickshell
import Quickshell.Io
import QtQuick
import "lib/NightLight.js" as Rules

Singleton {
    id: root

    // ---- the choices (Prefs) --------------------------------------------------

    readonly property int temperature: Prefs.nightLightTemperature
    readonly property string schedule: Prefs.nightLightSchedule
    readonly property string from: Prefs.nightLightFrom
    readonly property string to: Prefs.nightLightTo
    readonly property var choices: ({
            schedule: Prefs.nightLightSchedule,
            from: Prefs.nightLightFrom,
            to: Prefs.nightLightTo,
            manual: Prefs.nightLightManual,
            override: Prefs.nightLightOverride,
            until: Prefs.nightLightUntil
        })

    // The clock the schedule reads, epoch ms. The minute timer moves `now`
    // from nowMs(); a test sets `clock` to a function and calls tick().
    property var clock: null
    property double now: Date.now()
    function nowMs(): real {
        return typeof root.clock === "function" ? Number(root.clock()) : Date.now();
    }

    readonly property var wanted: Rules.effective(root.choices, root.now)
    readonly property bool on: root.wanted.on
    // When `on` next flips by the schedule (0: nothing ahead), and as "HH:MM".
    readonly property real changesAt: root.wanted.changesAt
    readonly property string until: Rules.clock(root.changesAt)
    readonly property bool overridden: root.wanted.overridden

    // ---- hyprsunset -----------------------------------------------------------

    readonly property string unit: "hyprsunset.service"
    readonly property bool inSession: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") !== ""
    readonly property bool live: !Fixture.dryRun && root.inSession
    property bool available: false
    property string reason: Fixture.dryRun ? "dry" : root.inSession ? "checking" : "session"
    property string message: ""
    readonly property bool active: root.on && root.available
    // What hyprsunset holds as far as this knows ({ on, temperature }), null
    // when it may hold anything (never applied, restarted, a profile fired).
    property var applied: null
    property bool dirty: true
    // hyprctl runs so far, and the last one (inspect, tests).
    property int calls: 0
    property string lastCommand: ""
    property bool started: false

    // hyprsunset.conf's profiles (lib/NightLight.js parseProfiles).
    readonly property string confPath: (Quickshell.env("XDG_CONFIG_HOME") || ((Quickshell.env("HOME") || "") + "/.config")) + "/hypr/hyprsunset.conf"
    property var profiles: []
    property real lastTick: 0

    function same(a, b): bool {
        if (!a || !b) return false;
        if (!a.on && !b.on) return true;
        return a.on === b.on && Rules.kelvin(a.temperature) === Rules.kelvin(b.temperature);
    }

    // ---- choices ----------------------------------------------------------------

    function refusal(): string {
        if (root.available) return "";
        if (root.reason === "dry") return "error: dry run, hyprsunset is left alone";
        if (root.reason === "session") return "error: no Hyprland session";
        if (root.reason === "checking") return "error: hyprsunset has not answered yet";
        return "error: " + (root.message || "hyprsunset is not running");
    }

    function setOn(on: bool): string {
        const no = root.refusal();
        if (no !== "") return no;
        root.tick();
        root.write(Rules.setOn(root.choices, root.now, on));
        return "ok";
    }
    function toggle(): string {
        return root.setOn(!root.on);
    }
    function setTemperature(k: real): string {
        const v = Rules.kelvin(k);
        if (!isFinite(Number(k)) || Number(k) < Rules.MIN_K - Rules.STEP_K / 2 || Number(k) > Rules.MAX_K + Rules.STEP_K / 2)
            return "error: warmth runs from " + Rules.MIN_K + " to " + Rules.MAX_K + " K";
        Prefs.setNightLight({ temperature: v });
        return "ok " + v;
    }
    // mode "off" or "custom"; from and to "HH:MM" ("" keeps them). A new
    // schedule drops any override: it says what should happen from now. Off
    // keeps the light as it is ("On and off by hand"): the manual state
    // becomes what it shows now, not what the last toggle without a
    // schedule left, maybe days ago.
    function setSchedule(mode: string, from: string, to: string): string {
        if (Rules.SCHEDULES.indexOf(mode) < 0) return "error: schedule off or custom";
        const f = from === "" ? root.from : from;
        const t = to === "" ? root.to : to;
        if (Rules.parseTime(f) < 0 || Rules.parseTime(t) < 0) return "error: times are HH:MM";
        if (Rules.parseTime(f) === Rules.parseTime(t)) return "error: From and To are the same time";
        root.tick();
        const patch = { schedule: mode, from: Rules.time(f, Rules.DEFAULT_FROM), to: Rules.time(t, Rules.DEFAULT_TO), override: "", until: 0 };
        if (mode === "off") patch.manual = root.on;
        root.write(patch);
        return "ok";
    }
    // which "from" | "to", by `steps` of Rules.TIME_STEP minutes.
    function stepTime(which: string, steps: int): string {
        if (which !== "from" && which !== "to") return "error: from or to";
        const next = Rules.stepTime(which === "from" ? root.from : root.to, steps, which === "from" ? root.to : root.from);
        return root.setSchedule("custom", which === "from" ? next : "", which === "to" ? next : "");
    }

    // The sheet's explicit action: the one place the shell starts the daemon.
    function startDaemon(): string {
        if (!root.live) return root.refusal();
        if (!starter.running) starter.running = true;
        return "ok";
    }
    // Asks hyprsunset again (the control center or the sheet opening while
    // it is unavailable): one call.
    function refresh(): void {
        if (!root.live || root.available || ctl.running) return;
        root.dirty = true;
        root.sync();
    }

    // ---- applying ---------------------------------------------------------------

    property bool pendingSync: false
    // Calls left after a Started line, while hyprsunset's socket comes up.
    property int retries: 0

    function sync(): void {
        if (!root.live || !root.started) return;
        if (ctl.running) {
            root.pendingSync = true;
            return;
        }
        const want = { on: root.on, temperature: root.temperature };
        if (!root.dirty && root.available && root.same(root.applied, want)) return;
        ctl.want = want;
        ctl.command = Rules.command(want);
        root.calls++;
        root.lastCommand = ctl.command.join(" ");
        ctl.running = true;
    }
    function finished(code: int, text: string): void {
        const r = Rules.reply(code, text);
        if (r.ok) {
            root.available = true;
            root.reason = "";
            root.message = "";
            root.applied = ctl.want;
            root.dirty = false;
            root.retries = 0;
        } else {
            root.available = false;
            root.reason = r.kind === "stopped" ? "stopped" : "error";
            root.message = r.message;
            root.applied = null;
            root.dirty = true;
            if (root.retries > 0) {
                root.retries--;
                retryLater.restart();
            }
        }
        if (root.pendingSync) {
            root.pendingSync = false;
            root.sync();
        }
    }

    // A patch of several keys, as one change. Prefs writes them one at a
    // time and `on` follows each, so schedule Off with the manual state
    // flipped in the same patch read off, then on again: two calls for a
    // light that never changed. Only where `on` ends up counts.
    property bool writing: false
    function write(patch): void {
        const was = root.on;
        root.writing = true;
        Prefs.setNightLight(patch);
        root.writing = false;
        if (root.on !== was) root.sync();
    }

    // Each change of `on` is one call; the warmth waits for a drag to settle.
    onOnChanged: if (!root.writing) root.sync()
    onTemperatureChanged: if (root.on) warmthLater.restart()
    Timer {
        id: warmthLater
        interval: 150
        onTriggered: root.sync()
    }
    // The next try after a Started line's call failed.
    Timer {
        id: retryLater
        interval: 1500
        onTriggered: root.sync()
    }

    Process {
        id: ctl
        property var want: null
        stdout: StdioCollector { id: ctlOut }
        stderr: StdioCollector { id: ctlErr }
        onExited: code => root.finished(code, (ctlOut.text + "\n" + ctlErr.text).trim())
    }

    Process {
        id: starter
        command: ["systemctl", "--user", "start", root.unit]
        // The journal's Started line applies; without a journal, this does.
        onExited: {
            root.dirty = true;
            root.retries = 3;
            daemonLater.restart();
        }
    }

    // ---- the clock --------------------------------------------------------------

    function start(): void {
        if (root.started) return;
        root.started = true;
        root.now = root.nowMs();
        root.lastTick = root.now;
        root.dirty = true;
        root.sync();
        if (root.live) watch.running = true;
        minute.arm();
    }
    Component.onCompleted: if (Prefs.loaded) root.start()
    Connections {
        target: Prefs
        function onLoadedChanged() {
            if (Prefs.loaded) root.start();
        }
    }

    // A tick further from the last one than this ends a gap: a resume.
    readonly property real resumeGap: 150000
    // The fallback put-back after a profile was due and no line said it
    // fired (the journal down, or a hyprsunset that says it differently).
    property int lateMs: 60000
    // hyprsunset said it switched profile since the last tick.
    property bool heardSwitch: false

    // Compares times; spawns nothing by itself.
    function tick(): void {
        const prev = root.lastTick > 0 ? root.lastTick : root.nowMs();
        const t = root.nowMs();
        root.lastTick = t;
        root.now = t;
        // An override that ran out: the schedule decides again, and the file
        // says so too (a restart reads the same).
        if (Prefs.nightLightOverride !== "" && t >= Prefs.nightLightUntil) root.write({ override: "", until: 0 });
        const heard = root.heardSwitch;
        root.heardSwitch = false;
        const p = Rules.crossed(root.profiles, prev, t);
        // Already put back on hyprsunset's own line, or nothing to put back.
        if (!p || heard || !Rules.profileDiffers(p, { on: root.on, temperature: root.temperature })) return;
        root.dirty = true;
        if (watch.running) {
            // Its line says when the switch lands, on time or late after a
            // resume; this only covers a line that never comes.
            lateLater.restart();
            return;
        }
        profileLater.restart();
        if (t - prev > root.resumeGap) lateLater.restart();
    }
    Timer {
        id: minute
        // Just past the next minute, so 20:00 turns it on at 20:00:00.5. A
        // coarse timer that fires a little early only makes the next wait
        // short.
        function arm() {
            minute.interval = 60000 - (Date.now() % 60000) + 500;
            minute.restart();
        }
        onTriggered: {
            root.tick();
            minute.arm();
        }
    }
    // After hyprsunset's own profile switch has landed (no journal: by the
    // clock).
    Timer {
        id: profileLater
        interval: 3000
        onTriggered: root.sync()
    }
    // Once more, past a late switch after a resume, or a line that never came.
    Timer {
        id: lateLater
        interval: root.lateMs
        onTriggered: {
            root.dirty = true;
            root.sync();
        }
    }

    FileView {
        id: conf
        path: root.confPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.profiles = Rules.parseProfiles(conf.text())
        onLoadFailed: root.profiles = []
    }

    // ---- hyprsunset's lifecycle ---------------------------------------------------

    // The user manager's lines about the unit (USER_UNIT) and hyprsunset's
    // own output (_SYSTEMD_USER_UNIT). Rules.journalEvent sorts them: a
    // lifecycle line, a profile switch, or nothing (the banner, and the CTM
    // lines it logs for every request, so each call of ours reads a few
    // lines and does nothing with them).
    property int watchRestarts: 0
    property string watchState: "idle"
    // The last profile switch hyprsunset reported, "HH:MM" (inspect).
    property string lastSwitch: ""
    function journal(line: string): void {
        const e = Rules.journalEvent(line, root.unit);
        if (!e) return;
        if (e.kind === "lifecycle") root.lifecycle(e.started);
        else root.switched(e.minute);
    }
    function lifecycle(started: bool): void {
        root.dirty = true;
        root.retries = started ? 3 : 0;
        daemonLater.restart();
    }
    // hyprsunset applied one of its profiles by itself. Put back only when it
    // left the screen other than it should be (an unknown profile may hold
    // anything).
    function switched(minute: int): void {
        root.heardSwitch = true;
        root.lastSwitch = minute < 0 ? "?" : Rules.formatTime(minute);
        profileLater.stop();
        lateLater.stop();
        const p = Rules.profileAt(root.profiles, minute);
        if (p && !Rules.profileDiffers(p, { on: root.on, temperature: root.temperature })) return;
        root.dirty = true;
        switchLater.restart();
    }
    Timer {
        id: daemonLater
        interval: 1000
        onTriggered: root.sync()
    }
    Timer {
        id: switchLater
        interval: 1000
        onTriggered: root.sync()
    }
    Process {
        id: watch
        command: ["journalctl", "--user", "--follow", "--lines=0", "--quiet", "--output=cat", "USER_UNIT=" + root.unit, "+", "_SYSTEMD_USER_UNIT=" + root.unit]
        stdout: SplitParser {
            onRead: line => root.journal(line)
        }
        onRunningChanged: if (running) root.watchState = "watching"
        onExited: code => {
            root.watchState = "exited " + code;
            // Three tries, further apart each time, then it stays down.
            if (!root.live || root.watchRestarts >= 3) return;
            watchLater.interval = [5000, 30000, 120000][root.watchRestarts];
            root.watchRestarts++;
            watchLater.restart();
        }
    }
    Timer {
        id: watchLater
        onTriggered: if (root.live && !watch.running) watch.running = true
    }

    // ---- IPC ----------------------------------------------------------------------

    function inspect(): string {
        return JSON.stringify({
            on: root.on,
            active: root.active,
            available: root.available,
            reason: root.reason,
            message: root.message,
            live: root.live,
            temperature: root.temperature,
            schedule: root.schedule,
            from: root.from,
            to: root.to,
            override: Prefs.nightLightOverride,
            overridden: root.overridden,
            until: root.until,
            applied: root.applied,
            calls: root.calls,
            lastCommand: root.lastCommand,
            watch: root.watchState,
            lastSwitch: root.lastSwitch,
            profiles: root.profiles.map(p => Rules.formatTime(p.minute) + (p.identity ? " identity" : " " + p.temperature + " K"))
        });
    }

    IpcHandler {
        target: "nightlight"
        function toggle(): string { return root.toggle() }
        function on(): string { return root.setOn(true) }
        function off(): string { return root.setOn(false) }
        // Kelvin, 2500 to 6000 on 100.
        function temperature(kelvin: string): string { return root.setTemperature(Number(kelvin)) }
        // off, or HH:MM-HH:MM (From and To).
        function schedule(spec: string): string {
            if (spec === "off") return root.setSchedule("off", "", "");
            const m = /^\s*(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})\s*$/.exec(spec);
            if (!m) return "error: schedule off or HH:MM-HH:MM";
            return root.setSchedule("custom", m[1], m[2]);
        }
        function inspect(): string { return root.inspect() }
    }
}
