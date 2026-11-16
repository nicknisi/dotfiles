// Run with ./config/quickshell/tests/check.sh. No real player is controlled.
// Nothing here loads the pieces M10 retired (the old Hud and its pages, the
// media card, the toasts, the notification center); tests/retired.sh keeps
// them gone.
import Quickshell
import QtQuick
import qs.Kit
import qs.Island
import qs.Hosts
import qs.Panels
import qs.Panels.Sheets
import "launcher/ui" as LauncherUi
import "BarGeometry.js" as BarGeometry
import "lib/WorkspaceOrder.js" as WorkspaceOrder
import "lib/CrewModel.js" as CrewModel
import "lib/IslandMachine.js" as IslandMachine
import "lib/Calendar.js" as Calendar
import "lib/Anchored.js" as Anchored
import "launcher/core/Match.js" as Match
import "launcher/core/Glyphs.js" as Glyphs

ShellRoot {
    id: test

    FloatingWindow {
        visible: true
        implicitWidth: 728
        implicitHeight: 528
        // The charge limit (M10: the old BatteryMenu's page is the control
        // center's Battery sheet) on the live Battery; SHELL_DRY_RUN keeps a
        // press from running anything. Not shown, so Battery polls nothing.
        BatterySheet { id: batterySheet; width: 728; height: 528 }
        // NotificationState's center anchors (its API outlived the old
        // NotificationCenter): two stand-in bells.
        Item { id: bellA; width: 30; height: 30 }
        Item { id: bellB; width: 30; height: 30 }
        // The island Kit on the real Tokens, Motion and Prefs.
        Surface { id: kitSurface; x: 240; y: 100; width: 120; height: 38; radius: 19 }
        Icon { id: kitIcon; x: 240; y: 150; name: "wifi" }
    }

    // The island (PLAN M1) without its PanelWindow, which has no offscreen
    // backend: IslandView is everything inside it. W C D S with D focused,
    // from records in Hyprland's creation order.
    FloatingWindow {
        visible: true
        implicitWidth: 1000
        implicitHeight: 608
        IslandView {
            id: islandView
            anchors.fill: parent
            interrupt: quietInterrupt
            liveData: ({})
            monitor: ({ name: "check-island", width: 1000, height: 700 })
            workspaces: WorkspaceOrder.shown([
                { name: "S", windows: 1 }, { name: "D", windows: 2 }, { name: "special:scratch", windows: 1 },
                { name: "W", windows: 3 }, { name: "N", windows: 0 }, { name: "C", windows: 1 }], "D")
        }
    }

    // The Crew (PLAN M2) on a second island, fed by a fake with the Crew
    // singleton's shape: the real one is off here (SHELL_CREW=off) and polls
    // nothing. set() applies a payload like Crew.rebuild does, raising
    // hailed / vibes on the CrewModel edges unless told to stay quiet.
    QtObject {
        id: fakeCrew
        readonly property real now: 1794715378
        property var model: CrewModel.empty()
        readonly property var agents: model.agents
        readonly property int total: model.total
        readonly property int attention: model.attention
        readonly property var spendToday: model.spendToday
        property bool stale: false
        property var jumps: []
        signal hailed(var agent)
        signal vibes
        function agent(pane, kind, status, attention, extra) {
            return Object.assign({ pane: pane, windowId: "@0", session: "projects", label: "island mocks", agentType: kind,
                status: status, needsAttention: attention, ts: now, timestampKind: "observed", project: "~/Developer/dotfiles" }, extra || {});
        }
        // Pi waiting, a Riker worker, Claude Code working, Codex asleep: crew-4.
        function four(piNeeds) {
            return { fleet: { agents: [
                agent("%2", "pi", piNeeds ? "QUESTION" : "BUSY", piNeeds, { label: "artifact" }),
                agent("%0", "claude", "BUSY", false),
                agent("%3", "codex", "IDLE", false, { ts: now - 720, timestampKind: "state_change" })] },
                scan: { agents: [{ kind: "pi", host: "riker", state: "running", label: "#12 Rebuild", pid: 6010,
                    where: "~/Developer/dotfiles/.riker/worktrees/12", pane: "" }], spend: { today: 4.37 } } };
        }
        function many() {
            const a = [];
            for (let i = 0; i < 12; i++)
                a.push(agent("%" + (20 + i), "claude", i < 2 ? "DONE" : "BUSY", i < 2, { label: "job " + i }));
            return { fleet: { agents: a }, scan: null };
        }
        function set(payload, quiet) {
            const next = CrewModel.build(payload, now);
            const e = CrewModel.edges(model, next);
            model = next;
            if (quiet) return;
            if (e.hails.length > 0) hailed(CrewModel.find(next, e.hails[0]));
            if (e.vibes) vibes();
        }
        function jump(id) {
            jumps = jumps.concat([id]);
            return "ok";
        }
    }

    FloatingWindow {
        visible: true
        implicitWidth: 1000
        implicitHeight: 608
        IslandView {
            id: crewView
            anchors.fill: parent
            crew: fakeCrew
            interrupt: quietInterrupt
            liveData: ({})
            dpr: 1.5
            monitor: ({ name: "check-crew", width: 1000, height: 700 })
            workspaces: WorkspaceOrder.shown([{ name: "W", windows: 1 }, { name: "D", windows: 1 }], "D")
        }
    }

    // The island's own states (PLAN M3) on a third island, with stand-ins for
    // what feeds them. Interrupt fires as PipeWire binds, so the islands get a
    // quiet one; check.sh's qs runs on the real session bus, where a real
    // NotificationServer would fight the desktop's for the bus name, so the
    // notifications come from a fake with NotificationServer.qml's shape; the
    // voice has VoiceSession's daemon fields.
    QtObject {
        id: quietInterrupt
        property string kind: ""
        property real fraction: 0
        signal shown(string which)
    }
    QtObject {
        id: fakeNotifier
        property var tracked: []
        property var expired: []
        property var dismissed: []
        // NotificationServer.shows reads NotificationState.dnd; the fake keeps
        // its own, so the other islands see no flash.
        property bool dnd: false
        signal arrived(var notification)
        function find(id) {
            return tracked.find(n => n.id === id) ?? null;
        }
        function timeoutFor(n) {
            return IslandMachine.notifTimeout(n.expireTimeout, n.critical === true);
        }
        function shows(n) {
            return !dnd || n.critical === true;
        }
        // NotificationServer's holds, on the same IslandMachine.holdIds.
        property var holders: []
        function hold(owner, ids) {
            const r = IslandMachine.holdIds(holders, owner, ids);
            holders = r.holders;
            for (const id of r.released)
                find(id)?.expire();
        }
        function forget(owner) {
            holders = holders.filter(h => h.owner !== owner);
        }
        property var deadlines: ({})
        function remainingFor(n) {
            const at = deadlines[n.id] ?? 0;
            return at > 0 ? Math.max(0, at - Date.now()) : 0;
        }
        function push(fields) {
            const n = Object.assign({ appName: "notify-send", summary: "", body: "", appIcon: "", image: "", expireTimeout: -1, critical: false }, fields);
            n.expire = () => fakeNotifier.close(n.id, "expired");
            n.dismiss = () => fakeNotifier.close(n.id, "dismissed");
            const d = Object.assign({}, deadlines);
            const t = timeoutFor(n);
            d[n.id] = t > 0 ? Date.now() + t : 0;
            deadlines = d;
            tracked = tracked.concat([n]);
            arrived(n);
            return n;
        }
        // One that came in before the island was there (a classic mode): no arrived.
        function pushQuietly(fields) {
            const n = Object.assign({ appName: "notify-send", summary: "", body: "", appIcon: "", image: "", expireTimeout: -1, critical: false }, fields);
            n.expire = () => fakeNotifier.close(n.id, "expired");
            n.dismiss = () => fakeNotifier.close(n.id, "dismissed");
            const d = Object.assign({}, deadlines);
            const t = timeoutFor(n);
            d[n.id] = t > 0 ? Date.now() + t : 0;
            deadlines = d;
            tracked = tracked.concat([n]);
            return n;
        }
        // how: "expired", "dismissed", or anything else for the sender closing it.
        function close(id, how) {
            if (how === "expired") expired = expired.concat([id]);
            else if (how === "dismissed") dismissed = dismissed.concat([id]);
            tracked = tracked.filter(n => n.id !== id);
        }
    }
    QtObject {
        id: fakeVoice
        property string daemonState: "idle"
        readonly property bool daemonListening: daemonState === "recording" || daemonState === "streaming"
        property bool active: false
        property bool osdSuppressed: false
        property var history: []
        property string command: "/bin/false"
    }
    QtObject {
        id: fakeInterrupt
        property string kind: ""
        property real fraction: 0
        signal shown(string which)
    }

    // 1600 wide: with everything live the pill passes 1000, and a window as
    // narrow as that put the body under the offscreen platform's pointer
    // (hover opened by itself).
    FloatingWindow {
        visible: true
        implicitWidth: 1600
        implicitHeight: 608
        IslandView {
            id: m3View
            anchors.fill: parent
            interrupt: fakeInterrupt
            notifications: fakeNotifier
            voice: fakeVoice
            liveData: ({})
            monitor: ({ name: "check-m3", width: 1000, height: 700 })
            workspaces: WorkspaceOrder.shown([{ name: "W", windows: 1 }, { name: "D", windows: 1 }], "D")
        }
    }

    // How often the breathing marks change (step 6 to 8).
    QtObject {
        id: breathCount
        property int sparkle: 0
        property int dot: 0
    }
    Connections {
        target: m3View.rest.laneIcon
        function onOpacityChanged() {
            breathCount.sparkle++;
        }
    }
    Connections {
        target: m3View.rest.segment.dot
        function onOpacityChanged() {
            breathCount.dot++;
        }
    }
    // A second screen's island on the same server (step 10), built late so
    // the beats before it see one island.
    QtObject {
        id: second
        property var island: null
    }
    Component {
        id: secondIsland
        IslandView {
            interrupt: fakeInterrupt
            notifications: fakeNotifier
            voice: fakeVoice
            liveData: ({})
            monitor: ({ name: "check-m3b", width: 1000, height: 700 })
            workspaces: WorkspaceOrder.shown([{ name: "W", windows: 1 }], "W")
        }
    }

    // M3 in fifteen beats, 600 ms apart (each lets the morph settle): a
    // notification, a second one queueing, the OSD over it and back, Dismiss
    // showing the next, dictation over that and back, a closed island
    // expiring what it let go of, the sender closing one, Do not disturb, the
    // calendar and its way back, a flash, the live segment fading in and
    // widening the pill with the Context lane, the breathing marks on their
    // stepped clock (and the dot through idle), hover keeping the width of a
    // pill past 720, a banner paused under the pointer and resumed, and a
    // second island adopting, holding and letting go (M3 review).
    Timer {
        id: m3Check
        interval: 600
        repeat: true
        property int step: 0
        property bool finished: false
        onTriggered: {
            try {
                const v = m3View;
                const box = item => item.mapToItem(v, 0, 0);
                if (step === 0) {
                    test.check(v.islandState === "rest" && !v.rest.segment.visible && v.rest.hugWidth === 360, "M3 island starts at rest with nothing live: " + JSON.stringify(v.machine));
                    fakeNotifier.push({ id: 1, summary: "hi", body: "a <b>bold</b> &amp; plain body", actions: [{ identifier: "reply", text: "Reply", invoke: () => {} }] });
                    test.check(v.islandState === "notif" && v.machine.item.id === 1 && v.machine.timer === 4200, "a notification takes the island for 4200 ms: " + JSON.stringify(v.machine));
                    test.check(v.targetSize[0] === 520 && v.targetSize[1] === 92, "notif targets 520 x 92");
                    test.check(v.notification?.summary === "hi" && v.notifCard.body === "a bold & plain body", "the banner shows the summary and a plain body: " + v.notifCard.body);
                    test.check(!v.notifCard.actionsShown && !v.notifCard.actionsRow.visible && v.notifCard.bodyLines === 1 && v.notifCard.height === 92, "the island's banner draws the board: no action pills, one body line, 92 high (the classic cards grow, M10)");
                    fakeNotifier.push({ id: 2, summary: "build failed", critical: true });
                    test.check(v.machine.item.id === 1 && JSON.stringify(v.machine.queue.map(i => i.id)) === "[2]", "a second one queues behind it");
                    fakeInterrupt.kind = "volume";
                    fakeInterrupt.fraction = 0.45;
                    fakeInterrupt.shown("volume");
                    test.check(v.islandState === "osd" && v.machine.back?.state === "notif" && v.machine.timer === 1400, "the OSD interrupts the notification for 1400 ms");
                    test.check(v.targetSize[0] === 340 && v.targetSize[1] === 44, "osd targets 340 x 44");
                } else if (step === 1) {
                    test.check(v.body.width === 340 && v.body.height === 44 && v.body.radius === 22, "osd settles at 340 x 44, radius 22: " + v.body.width + " x " + v.body.height + " r " + v.body.radius);
                    test.check(v.osdCard.fill.width === Math.round(v.osdCard.track.width * 0.45) && v.osdCard.icon === "vol1" && v.osdCard.valueText === "45", "the fill is 45% of the track");
                    v.apply(IslandMachine.expire(v.machine, v.machine.seq));
                    test.check(v.islandState === "notif" && v.machine.item.id === 1 && v.machine.timer === 4200, "the OSD ending returns to the notification, its timer restarted");
                    v.dismissNotification();
                    test.check(JSON.stringify(fakeNotifier.dismissed) === "[1]" && fakeNotifier.expired.length === 0, "Dismiss dismisses it on the server");
                    test.check(v.islandState === "notif" && v.machine.item.id === 2 && v.machine.timer === 0, "the critical one shows next, with no timer: " + JSON.stringify(v.machine));
                    test.check(!v.notifCard.progress.parent.visible, "a critical notification has no countdown");
                    fakeVoice.daemonState = "recording";
                    test.check(v.dictPhase === "listening", "the daemon recording is dictation");
                } else if (step === 2) {
                    test.check(v.islandState === "dict" && v.machine.back?.state === "notif", "dictation takes the island over the notification: " + JSON.stringify(v.machine));
                    test.check(v.body.width === 360 && v.body.height === 48 && v.body.radius === 24, "dict settles at 360 x 48, radius 24: " + v.body.width + " x " + v.body.height + " r " + v.body.radius);
                    fakeNotifier.push({ id: 3, summary: "third" });
                    test.check(v.islandState === "dict" && v.machine.queue?.length === 1, "a notification during dictation waits");
                    fakeVoice.daemonState = "transcribing";
                    test.check(v.islandState === "dict" && v.dictCard.label === "Finishing", "transcribing keeps the dict state");
                    fakeVoice.daemonState = "idle";
                    test.check(v.islandState === "notif" && v.machine.item.id === 2, "dictation ending returns to the notification it covered: " + JSON.stringify(v.machine));
                    v.close();
                    test.check(fakeNotifier.expired.indexOf(2) >= 0, "closing the island expires the one it showed (it stays in the history)");
                } else if (step === 3) {
                    test.check(v.islandState === "notif" && v.machine.item.id === 3, "the waiting one shows once the island is free: " + JSON.stringify(v.machine));
                    v.apply(IslandMachine.expire(v.machine, v.machine.seq));
                    test.check(v.islandState === "rest" && fakeNotifier.expired.indexOf(3) >= 0, "its timeout expires it");
                    fakeNotifier.push({ id: 4, summary: "gone soon" });
                    fakeNotifier.close(4, "sender");
                    test.check(v.islandState === "rest", "the sender closing it takes it off the island");
                    fakeNotifier.dnd = true;
                    fakeNotifier.push({ id: 5, summary: "quiet" });
                    test.check(v.islandState === "rest", "Do not disturb keeps a notification off the island");
                    fakeNotifier.push({ id: 6, summary: "battery low", critical: true });
                    test.check(v.islandState === "notif" && v.machine.item.id === 6, "but not a critical one");
                    fakeNotifier.dnd = false;
                    v.dismissNotification();
                    fakeNotifier.close(5, "expired");
                    test.check(v.islandState === "rest", "dismissed");
                    test.check(v.open("cal") === "ok" && v.islandState === "cal" && v.panelOpen, "cal is the island's own panel");
                    test.check(v.targetSize[0] === 400 && v.targetSize[1] === 368, "cal targets 400 x 368");
                } else if (step === 4) {
                    test.check(v.body.width === 400 && v.body.height === 368, "cal settles at 400 x 368");
                    const today = new Date();
                    test.check(v.calendar.cells.length === 42 && v.calendar.title === Calendar.title(today.getFullYear(), today.getMonth()), "this month, six rows of seven");
                    const t = v.calendar.cells.filter(c => c.today);
                    test.check(t.length === 1 && t[0].day === today.getDate(), "today is marked once");
                    test.check(v.inspect().parts.today !== null, "inspect finds today's cell");
                    v.stepBack();
                    test.check(v.islandState === "hover" && v.pinned, "Esc in the calendar goes back to hover, pinned");
                    v.dismiss();
                    test.check(v.islandState === "rest", "an outside click closes it");
                    v.flashMode("awake", true, "On for 1 hour");
                    test.check(v.islandState === "flash" && v.machine.timer === 1400 && v.targetSize[1] === 52, "a mode change flashes for 1400 ms");
                    test.check(v.targetSize[0] === v.flashCard.width && v.flashCard.width < 360, "the flash hugs its words: " + v.flashCard.width);
                    test.check(String(v.flashCard.ring.border.color) === String(Tokens.accent) && !v.flashCard.slash.visible, "on: an accent ring, no slash");
                } else if (step === 5) {
                    test.check(v.body.height === 52 && v.body.radius === 26, "flash settles 52 high, radius 26");
                    v.apply(IslandMachine.expire(v.machine, v.machine.seq));
                    test.check(v.islandState === "rest", "and settles back");
                    v.liveData = { recording: true, elapsed: "0:42" };
                    v.laneData = { kind: "terminal", icon: "terminal", text: "dotfiles", extra: "main +2" };
                    test.check(v.rest.segment.visible && String(v.rest.segment.dot.color) === String(Tokens.bad) && v.rest.segment.stopButton.visible, "a recording: the bad dot and Stop");
                    // island-modes 6: the pill widens while the segment fades in, after the stagger.
                    test.check(v.rest.segment.opacity === 0 && v.rest.segment.fading, "the segment starts transparent and fades in: " + v.rest.segment.opacity);
                    test.check(v.rest.laneRow.visible && v.rest.laneIcon.name === "terminal" && v.rest.laneExtra.text === "main +2", "the Context lane: terminal, dotfiles, main +2");
                } else if (step === 6) {
                    test.check(v.rest.segment.opacity === 1 && !v.rest.segment.fading, "and is opaque once the fade is done");
                    // Rows lay out at polish time, so the widths are read a beat later.
                    test.check(v.rest.hugWidth > 360 && v.targetSize[0] === v.rest.width, "the pill widens around them: " + v.rest.hugWidth);
                    test.check(v.body.width === v.rest.width, "the body follows the pill");
                    const clock = v.rest.width / 2;
                    test.check(Math.abs(box(v.rest.segment).x - box(v.rest).x - (clock + v.rest.clockText.implicitWidth / 2 + IslandMachine.SEGMENT_GAP)) <= 1, "the segment sits 12 right of the centred clock");
                    const laneRight = box(v.rest.laneRow).x - box(v.rest).x + v.rest.laneRow.width;
                    test.check(Math.abs(laneRight - (v.rest.width - 16)) <= 1, "the lane keeps 16 from the edge");
                    v.liveData = { recording: true, elapsed: "12:34", mic: ["Zoom", "Firefox", "OBS"], awake: true, awakeLeft: "52m", dnd: true };
                    v.laneData = { kind: "agent", icon: "sparkle", working: true, text: "a-repository-with-a-long-name", who: "Claude Code", where: "a-repository-with-a-long-name", detail: "main +2" };
                    test.check(String(v.rest.laneIcon.color) === String(Tokens.accent), "an agent working: the sparkle in accent");
                    test.check(v.rest.segment.micText === "Zoom +2", "several apps on the mic: the first, +2");
                    breathCount.sparkle = 0;
                    breathCount.dot = 0;
                } else if (step === 7) {
                    // M3 review: the sparkle and the dot breathe on a 250 ms
                    // step, so 600 ms is two or three frames, not one per
                    // vsync (a NumberAnimation gave about 36 here).
                    test.check(v.rest.breathClock.step === 250 && v.rest.breathClock.ticking && !v.rest.crewStrip.clock.ticking, "no bots move: the breathing runs on the pill's own 250 ms clock: " + JSON.stringify({ step: v.rest.breathClock.step, ticking: v.rest.breathClock.ticking, running: v.rest.breathClock.running, strip: v.rest.crewStrip.clock.ticking, sparkle: v.rest.sparkleBreathes, dot: v.rest.dotBreathes, current: v.rest.current, loops: Motion.loops, state: v.islandState }));
                    test.check(breathCount.sparkle >= 1 && breathCount.sparkle <= 4, "the working sparkle changes once a step, not once a frame: " + breathCount.sparkle + " in 600 ms");
                    test.check(breathCount.dot >= 1 && breathCount.dot <= 4, "the recording dot too: " + breathCount.dot + " in 600 ms");
                    test.check(Math.abs(Motion.breath(0, 1600, 0.45) - 1) < 1e-9 && Math.abs(Motion.breath(800, 1600, 0.45) - 0.45) < 1e-9 && Math.abs(Motion.breath(1600, 1600, 0.45) - 1) < 1e-9, "Motion.breath: 1, 0.45 half way, 1 again");
                    // Idle (no input for a minute): the sparkle holds still,
                    // the recording dot does not (a privacy signal).
                    v.ambient = false;
                    breathCount.sparkle = 0;
                    breathCount.dot = 0;
                } else if (step === 8) {
                    test.check(v.rest.laneIcon.opacity === 1 && breathCount.sparkle === 0, "idle: the sparkle holds still at full opacity");
                    test.check(breathCount.dot >= 1 && v.rest.breathClock.ticking, "idle: the recording dot keeps breathing: " + breathCount.dot);
                    v.ambient = true;
                    test.check(v.rest.hugWidth > 720, "everything live widens the pill past 720: " + v.rest.hugWidth);
                    test.check(v.open("hover") === "ok" && v.targetSize[0] === v.rest.width && v.hover.width === v.rest.width, "hover keeps the pill's width past 720, so it never opens from under the pointer");
                    test.check(v.hover.contextLine.visible, "hover's Context line shows who and where");
                    test.check(v.hover.sparkleClock.step === 250 && v.hover.sparkleClock.running && !v.rest.breathClock.ticking, "hover's sparkle steps at 250 ms too, and the pill's clock stops under it");
                    v.close();
                    v.liveData = {};
                    v.laneData = null;
                    test.check(v.rest.segment.visible && v.rest.segment.fading && v.rest.segment.width > 0, "nothing live: the segment fades out at its width");
                } else if (step === 9) {
                    test.check(v.rest.hugWidth === 360 && !v.rest.segment.visible, "back to 360 with nothing live: " + v.rest.hugWidth);
                    // The pointer coming to a banner pauses it with what it has
                    // left; leaving runs it on from there (M3 review [GUESS]).
                    fakeNotifier.push({ id: 7, summary: "pause me" });
                    test.check(v.islandState === "notif" && v.machine.item.id === 7 && v.machine.timer === 4200 && !v.machine.held, "a banner runs its timer: " + JSON.stringify(v.machine));
                    // A hover that comes while the body is still growing is the
                    // banner opening under a parked pointer: it runs its course.
                    v.pointerEntered();
                    test.check(v.body.morphing && !v.machine.held && v.machine.timer === 4200, "opening under a parked pointer does not pause it: " + JSON.stringify(v.machine));
                    v.pointerLeft();
                } else if (step === 10) {
                    v.pointerEntered();
                    test.check(v.machine.held && v.machine.timer === 0 && v.machine.left > 3000 && v.machine.left <= 4200 && !v.notifCard.running, "the pointer coming to it pauses it: " + JSON.stringify(v.machine));
                    v.pointerLeft();
                    test.check(v.grace.running, "leaving starts the grace");
                } else if (step === 11) {
                    test.check(v.islandState === "notif" && v.machine.item.id === 7 && !v.machine.held && v.machine.timer >= IslandMachine.RESUME_MIN && v.machine.timer <= 4200 && v.notifCard.running,
                        "after the grace it runs on for what it had left: " + JSON.stringify(v.machine));
                    test.check(fakeNotifier.expired.indexOf(7) < 0, "and is not expired by leaving");
                    // A second screen's island: it adopts what is up and was
                    // never offered to it (8 came in "before the switch").
                    fakeNotifier.pushQuietly({ id: 8, summary: "from the pill" });
                    second.island = secondIsland.createObject(m3View.parent, { width: 1600, height: 608 });
                } else if (step === 12) {
                    const w = second.island;
                    test.check(w.islandState === "notif" && w.machine.item.id === 8 && JSON.stringify(w.machine.queue.map(i => i.id)) === "[7]", "a new island adopts what is still up, newest first: " + JSON.stringify(w.machine));
                    test.check(w.machine.item.timeout > IslandMachine.RESUME_MIN && w.machine.item.timeout <= 4200, "for the rest of its time: " + w.machine.item.timeout);
                    // One island's timer running out while the other holds 7: not expired.
                    v.apply(IslandMachine.expire(v.machine, v.machine.seq));
                    test.check(v.islandState === "rest" && fakeNotifier.expired.indexOf(7) < 0, "7 ends on the first island, but the second still holds it, so it is not expired");
                    w.close();
                    test.check(fakeNotifier.expired.indexOf(8) >= 0 && fakeNotifier.expired.indexOf(7) < 0, "8, held by the second alone, expires when it lets go: " + JSON.stringify(fakeNotifier.expired));
                } else if (step === 13) {
                    const w = second.island;
                    test.check(w.islandState === "notif" && w.machine.item.id === 7, "the second island shows the one it queued");
                    test.check(fakeNotifier.holders.length === 1 && fakeNotifier.holders[0].owner === w, "only the second island holds anything");
                    // destroy() is deferred: the check waits a beat.
                    w.destroy();
                    second.island = null;
                } else {
                    test.check(fakeNotifier.expired.indexOf(7) < 0 && fakeNotifier.holders.length === 0, "an island going away lets go without expiring: " + JSON.stringify(fakeNotifier.expired));
                    fakeNotifier.close(7, "sender");
                    finished = true;
                    stop();
                }
                step++;
            } catch (error) {
                console.error("CAPSULE_TEST_FAIL: " + error.message);
                Qt.quit();
            }
        }
    }

    // The Crew in eleven beats, 500 ms apart: the bots on the rest pill, the
    // dwell on them opening the Crew panel, a click pinning it, rows and keys
    // and jumps, then the moments: vibes, a hail peeking, held under the
    // pointer without the keyboard and pinned by a click, a hail waiting
    // behind a pinned panel or a hand-off, and the attention clearing; last, a
    // 600 px pill whose bots must stay under the Crew panel they open.
    Timer {
        id: crewCheck
        interval: 500
        repeat: true
        property int step: 0
        property bool finished: false
        onTriggered: {
            try {
                const v = crewView;
                const strip = v.rest.crewStrip;
                if (step === 0) {
                    test.check(v.crew === fakeCrew && !strip.visible && strip.width === 0, "no agents: no crew zone");
                    fakeCrew.set(fakeCrew.many(), true);
                    test.check(strip.ids.length === CrewModel.MAX_BOTS && strip.more === 4, "twelve agents: eight bots and +4");
                    const first = strip.botAt(0);
                    test.check(first.mood === "needs" && String(first.tint) === String(Tokens.accent), "the waiting bot is accent");
                    test.check(first.sprite.cell === 2 && first.width === 16, "bots are 16 px of 2 px cells at dpr 1.5");
                    test.check(strip.botAt(2).mood === "working" && String(strip.botAt(2).tint) === String(Tokens.fg), "working bots are fg");
                } else if (step === 1) {
                    test.check(v.rest.hugWidth > 360 && v.targetSize[0] === 4 * Math.ceil(v.rest.hugWidth / 4), "eight bots and +4 widen the rest pill: "
                        + v.rest.hugWidth + " -> " + v.targetSize[0]);
                    fakeCrew.set(fakeCrew.four(true), true);
                    test.check(JSON.stringify(strip.ids) === JSON.stringify(["%2", "pid:6010", "%0", "%3"]), "crew-4 sorts needs first: " + JSON.stringify(strip.ids));
                    test.check(strip.botAt(1).spriteName === "hat" && strip.botAt(3).spriteName === "sleep" && !strip.botAt(3).moving, "the hat, and the sleeper holds still");
                    test.check(strip.botAt(0).moving && strip.botAt(2).moving && strip.botAt(2).phase === 2, "the second working bot starts half a bob later");
                    test.check(strip.clock.step === 125 && strip.clock.ticking && strip.botAt(0).clock === strip.clock && strip.botAt(2).clock === strip.clock,
                        "the strip's bots share one 125 ms clock: " + strip.clock.step);
                    v.ambient = false;
                    test.check(!strip.clock.ticking && strip.botAt(0).offset === 0, "an idle session holds the bots still");
                    v.ambient = true;
                    // Resting on the bots opens the Crew panel, unpinned.
                    v.dwelled(true);
                    test.check(v.islandState === "crew" && !v.pinned && !v.panelOpen, "the dwell on the bots opens the Crew panel unpinned");
                    // The strip relays out on the next polish, so the pill (and the panel's
                    // width with it) settles in the next beat; step 3 checks 460.
                    test.check(v.targetSize[0] === Math.max(460, v.rest.width) && v.targetSize[1] === 332,
                        "the Crew panel targets the wider of 460 and the pill, 332 tall for four rows: " + v.targetSize);
                    test.check(v.crewPanel.current && !v.rest.current, "the crew layer takes over");
                    v.pointerLeft();
                } else if (step === 2) {
                    test.check(v.islandState === "rest", "leaving the unpinned Crew panel goes back to rest");
                    test.check(strip.width === 4 * 16 + 3 * 6 && v.rest.hugWidth === 360, "four bots fit the 360 minimum: " + strip.width + ", " + v.rest.hugWidth);
                    v.dwelled(false);
                    test.check(v.islandState === "hover", "the dwell elsewhere still opens hover");
                    v.close();
                    v.clickCrew();
                    test.check(v.islandState === "crew" && v.pinned && v.panelOpen, "a click on the bots pins the Crew panel");
                } else if (step === 3) {
                    const p = v.crewPanel;
                    test.check(v.body.width === 460 && v.body.height === 332 && v.body.x === 270 && v.body.radius === 28,
                        "the Crew panel settles at 460 x 332, x 270, radius 28: " + v.body.width + " x " + v.body.height + " @" + v.body.x + " r " + v.body.radius);
                    // The board's spacer: the footer sits two gaps under the last row.
                    const lastRow = p.rowAt(3).mapToItem(p, 0, 0).y + 52;
                    test.check(p.footer.mapToItem(p, 0, 0).y === lastRow + 8 && p.footer.height === 8 + 14 && lastRow + 8 + 8 + 14 + 16 === 332,
                        "the footer text starts 16 under the last row and 16 above the edge: row ends " + lastRow);
                    // Row bots: one clock, staggered like the rest pill.
                    test.check(p.rowAt(1).bot.clock === p.clock && p.rowAt(2).bot.clock === p.clock && p.clock.ticking,
                        "the rows' bots share the panel's clock");
                    test.check(p.rowAt(1).bot.phase === 0 && p.rowAt(2).bot.phase === 2, "the second working row bobs half a beat later");
                    // The needs row's text reads at 4.5:1 on accentTint.
                    const whereC = Tokens.contrast(p.rowAt(0).whereLine.color, Tokens.accentTint);
                    const stateC = Tokens.contrast(p.rowAt(0).stateLine.color, Tokens.accentTint);
                    test.check(whereC >= 4.5 && stateC >= 4.5, "the needs row's where line and state read at 4.5:1: " + whereC.toFixed(2) + ", " + stateC.toFixed(2));
                    test.check(String(p.rowAt(2).whereLine.color) === String(Tokens.inkDim), "other rows keep inkDim");
                    test.check(p.ids.length === 4 && p.rowAt(0).height === 52 && p.rowAt(0).width === 428, "four rows, 52 tall, 428 wide inside the 16 padding");
                    test.check(String(p.rowAt(0).color) === String(Tokens.accentTint) && String(p.rowAt(2).color) === String(Qt.rgba(0, 0, 0, 0)), "the waiting row sits on accentTint");
                    test.check(p.rowAt(0).y === 0 && p.rowAt(1).y === 60, "rows 8 apart");
                    // The feed answers again with the same agents: nothing rebuilt.
                    const bots = strip.builds, rowsBuilt = p.builds;
                    const again = fakeCrew.four(true);
                    again.fleet.agents[1].label = "renamed";
                    fakeCrew.set(again, true);
                    test.check(p.builds === rowsBuilt && strip.builds === bots, "the same ids keep their rows and bots");
                    test.check(p.rowAt(2).agent.where === "dotfiles \u00b7 renamed", "and the rows read the new answer");
                    // Keys: Down starts on the waiting row, Enter on Riker does nothing, on Pi it jumps.
                    p.move(1);
                    test.check(p.selected === 0 && p.rowAt(0).border.width === 1, "the selection starts on the waiting row, ringed");
                    p.move(1);
                    p.activate();
                    test.check(fakeCrew.jumps.length === 0 && v.islandState === "crew", "Riker has no window to jump to");
                    p.move(-1);
                    p.activate();
                    test.check(fakeCrew.jumps.join() === "%2" && v.islandState === "rest", "Enter on a row jumps and closes the panel");
                    test.check(p.selected === -1, "the selection clears when the panel closes");
                } else if (step === 4) {
                    // Pi answered: the last one handled brings vibes.
                    fakeCrew.set(fakeCrew.four(false));
                    test.check(v.islandState === "vibes" && v.machine.timer === 4000 && v.vibesCard.current, "attention clearing brings vibes for 4 s");
                    test.check(v.targetSize[1] === 44 && v.targetSize[0] === 4 * Math.ceil(v.vibesCard.hugWidth / 4), "vibes hugs its line, 44 tall: " + v.targetSize);
                    // Pi asks again: a hail outranks vibes.
                    fakeCrew.set(fakeCrew.four(true));
                    test.check(v.islandState === "hail" && !v.pinned && v.machine.timer === 5000, "a new question raises a 5 s hail");
                    const w = v.hailCard.words;
                    test.check(w.title === "Pi needs you" && w.subtitle === "Waiting for approval in tmux \u00b7 dotfiles" && w.button === "Go to pane",
                        "the hail says who, why and where: " + JSON.stringify(w));
                    test.check(v.targetSize[1] === 52 && v.targetSize[0] >= 360 && v.targetSize[0] % 4 === 0, "the hail card is 52 tall: " + v.targetSize);
                    test.check(v.hailCard.ring.width === 36 && v.hailCard.ring.border.width === 2
                        && String(v.hailCard.ring.border.color) === String(Tokens.accent), "the ring is 36 px with a 2 px accent border");
                } else if (step === 5) {
                    test.check(v.body.height === 52 && v.body.radius === 26, "the hail settles 52 tall, radius 26: " + v.body.height + " r " + v.body.radius);
                    // The pointer on a hail holds it, without the focus grab or the keyboard.
                    v.pointerEntered();
                    test.check(v.islandState === "hail" && !v.pinned && !v.panelOpen && v.machine.held && v.machine.timer === 0,
                        "resting on the hail holds it, unpinned: no grab, no keyboard");
                    v.pointerLeft();
                    test.check(v.grace.running, "leaving a held hail starts the grace");
                    v.pointerEntered();
                    test.check(!v.grace.running && v.islandState === "hail", "coming back within the grace keeps it");
                    v.clickPill();
                    test.check(v.pinned && v.panelOpen && !v.machine.held, "a click on the hail pins it: now it takes the keyboard");
                    v.hailCard.go();
                    test.check(fakeCrew.jumps.join() === "%2,%2" && v.islandState === "rest", "Go to pane jumps and closes");
                    // A hail behind a pinned panel waits for rest.
                    v.open("crew");
                    fakeCrew.set(fakeCrew.four(false));
                    test.check(v.islandState === "crew", "vibes never covers a pinned panel");
                    fakeCrew.set(fakeCrew.four(true));
                    test.check(v.islandState === "crew" && v.pendingHail === "%2", "a hail waits behind the pinned Crew panel");
                    v.close();
                } else if (step === 6) {
                    test.check(v.islandState === "hail" && v.inspect().crew.hail === "%2" && v.pendingHail === "", "the waiting hail shows once the island is back at rest");
                    fakeCrew.set(fakeCrew.four(false));
                    test.check(v.islandState === "vibes", "the attention clearing closes the hail, then vibes");
                    v.close();
                    // A hail behind the battery sheet (M10: cc/battery, where
                    // the old Hud's page, the last hand-off, went) waits for it.
                    test.check(v.open("battery") === "ok" && v.islandState === "cc" && v.isOpen("cc/battery"), "battery is the control center's Battery sheet");
                    fakeCrew.set(fakeCrew.four(true));
                    test.check(v.islandState === "cc" && v.pendingHail === "%2", "a hail waits behind the battery sheet");
                    v.close();
                } else if (step === 7) {
                    test.check(v.islandState === "hail" && v.pendingHail === "", "the sheet closing lets the hail through");
                    // A held hail closes when the pointer has gone (the grace runs out).
                    v.pointerEntered();
                    v.pointerLeft();
                    test.check(v.machine.held && v.grace.running, "a held hail with the pointer gone waits out the grace");
                } else if (step === 8) {
                    test.check(v.islandState === "rest", "a held hail closes once the pointer has left");
                    fakeCrew.set({ fleet: { agents: [] }, scan: null }, true);
                    test.check(!strip.visible && v.open("hail").startsWith("error"), "an empty crew hides the bots and has nobody to hail");
                    test.check(v.inspect().crew.bots.length === 0, "inspect reports the bots");
                    // A wide pill: twelve agents and a Context label (DECISION 1).
                    fakeCrew.set(fakeCrew.many(), true);
                    v.laneData = { kind: "other", text: "dotfiles" };
                } else if (step === 9) {
                    test.check(v.rest.width >= 600 && v.body.width === v.rest.width, "eight bots, +4 and Context widen the pill past 600: " + v.rest.width);
                    // Resting on the bots at the pill's right end opens the Crew panel at
                    // the pill's width, so they stay under the pointer while it morphs.
                    v.dwelled(true);
                    test.check(v.islandState === "crew" && v.targetSize[0] === v.rest.width && v.targetSize[1] === CrewModel.panelHeight(12),
                        "the Crew panel keeps the pill's width: " + v.targetSize + " for a " + v.rest.width + " pill");
                } else {
                    const p = strip.mapToItem(v.body, 0, 0);
                    test.check(v.body.width === v.rest.width && v.crewPanel.width === v.body.width && v.crewPanel.rowAt(0).width === v.body.width - 32,
                        "the panel settles at the pill's width with full-width rows: " + v.body.width);
                    test.check(p.x >= 0 && p.x + strip.width <= v.body.width && p.y >= 0 && p.y + strip.height <= v.body.height,
                        "every bot lies inside the open Crew panel: strip " + p.x + ".." + (p.x + strip.width) + " in 0.." + v.body.width);
                    v.close();
                    v.laneData = null;
                    fakeCrew.set({ fleet: { agents: [] }, scan: null }, true);
                    finished = true;
                    stop();
                }
                step++;
            } catch (error) {
                console.error("CAPSULE_TEST_FAIL: " + error.message);
                Qt.quit();
            }
        }
    }

    // The last word, once every other check has run to the end.
    Timer {
        id: finalCheck
        interval: 2300
        repeat: true
        onTriggered: {
            try {
                // The bar check (about 25 s in, after the launcher and
                // control center checks) and the picker check after it hold
                // this one; the rest are done by then.
                if (crewCheck.running || m3Check.running || launcherCheck.running || m6Check.running || m8Check.running || mergeCheck.running || barCheck.running || !barCheck.finished || pickerCheck.running || !pickerCheck.finished) return;
                test.check(styleCheck.finished, "all sixteen layout and edge combinations settled");
                test.check(islandCheck.finished, "the island check ran to the end");
                test.check(crewCheck.finished, "the crew check ran to the end");
                test.check(m3Check.finished, "the M3 check ran to the end");
                test.check(launcherCheck.finished, "the launcher check ran to the end");
                test.check(m6Check.finished, "the M6 check ran to the end");
                test.check(m8Check.finished, "the M8 polkit check ran to the end");
                test.check(mergeCheck.finished, "the launcher and control center check ran to the end");
                test.check(barCheck.finished, "the M4 bar check ran to the end");
                test.check(pickerCheck.finished, "the picker check ran to the end");
                test.check(Tokens.hex(Tokens.surface) === Tokens.d.surface && Tokens.hex(Tokens.onAccent) === Tokens.d.onAccent, "tokens settle on the switched palette");
                console.log("CAPSULE_TEST_PASS");
                Qt.quit();
            } catch (error) {
                console.error("CAPSULE_TEST_FAIL: " + error.message);
                Qt.quit();
            }
        }
    }

    Timer {
        id: styleCheck
        interval: 100
        repeat: true
        property int step: 0
        property string oldMode: Prefs.barMode
        property string oldEdge: Prefs.edge
        property bool finished: false
        onTriggered: {
            try {
                const modes = ["pill", "full", "rail", "island"];
                const edges = ["top", "bottom", "left", "right"];
                if (step > 0) {
                    // Each step asks for a mode, then an edge. The full bar
                    // moved to a side becomes the rail, the rail moved to the
                    // top or the bottom becomes the full bar (M4).
                    const askedMode = modes[Math.floor((step - 1) / 4)];
                    const expectedEdge = edges[(step - 1) % 4];
                    const side = expectedEdge === "left" || expectedEdge === "right";
                    const expectedMode = askedMode === "full" && side ? "rail" : askedMode === "rail" && !side ? "full" : askedMode;
                    const island = expectedMode === "island";
                    test.check(Prefs.barMode === expectedMode, "layout preference settles: " + askedMode + "/" + expectedEdge + " -> " + expectedMode);
                    // The reserve from the geometry's own numbers: the bar's
                    // thickness and its inset on both sides, the island's extent.
                    const extent = island ? Theme.islandExtent : BarGeometry.THICK + 2 * BarGeometry.inset(expectedMode);
                    test.check(Theme.barExtent === extent, "reservation matches layout geometry: " + expectedMode + " " + Theme.barExtent + " for " + extent);
                    test.check(Theme.barInset === (expectedMode === "pill" || island ? 8 : 0), "the pill floats 8 in; the full bar and the rail are flush");
                    // The island always sits at the top and keeps the stored edge for later.
                    const shownEdge = island ? "top" : expectedEdge;
                    test.check(Prefs.edge === shownEdge && Prefs.storedEdge === expectedEdge
                        && Prefs.vertical === ["left", "right"].includes(shownEdge), "edge preference settles: " + expectedMode + "/" + expectedEdge);
                    test.check(BarGeometry.edgeFor(expectedMode, expectedEdge) === Prefs.edge, "Prefs reads BarGeometry's edge rule");
                    test.check(Theme.barExtent >= Theme.barHeight, "reservation includes bar inset");
                }
                if (step === 16) {
                    Prefs.setBarMode("invalid"); Prefs.setEdge("invalid");
                    test.check(Prefs.barMode === "island" && Prefs.edge === "top" && Prefs.storedEdge === "right", "invalid preferences are rejected");
                    Prefs.setBarMode("pill");
                    test.check(Prefs.edge === "right", "leaving the island restores the stored edge");
                    // A mode switch reads its own edge and keeps the stored one.
                    Prefs.setBarMode("full");
                    test.check(Prefs.edge === "top" && Prefs.storedEdge === "right" && Theme.barExtent === BarGeometry.THICK, "the full bar on a remembered side edge reads the top");
                    Prefs.setBarMode("rail");
                    test.check(Prefs.edge === "right" && Theme.barExtent === BarGeometry.THICK, "the rail goes back to the remembered right edge");
                    Prefs.setEdge("bottom");
                    test.check(Prefs.barMode === "full" && Prefs.edge === "bottom", "the rail moved to the bottom is the full bar");
                    Prefs.setBarMode("pill");
                    test.check(Prefs.edge === "bottom", "and the pill follows the remembered edge");
                    Prefs.setBarMode(oldMode); Prefs.setEdge(oldEdge); Prefs.setBarMode(oldMode);
                    finished = true; stop(); return;
                }
                Prefs.setBarMode(modes[Math.floor(step / 4)]);
                Prefs.setEdge(edges[step % 4]);
                step++;
            } catch (error) { console.error("CAPSULE_TEST_FAIL: " + error.message); Qt.quit(); }
        }
    }

    // The launcher (PLAN M5): launcher/ui/LauncherContent.qml on a fake
    // engine with Keystroke.qml's shape (the real one reads and writes the
    // launcher's config under $HOME, which check.sh does not isolate), shown
    // by a fourth island as its launcher state and by a free-standing content
    // as the classic modes' panel would hold it.
    QtObject {
        id: fakeLauncher
        property bool opened: false
        property string mode: "palette"
        readonly property bool dmenuActive: mode === "select" || mode === "input"
        property int dmenuWidth: 300
        property int dmenuMaxHeight: 0
        property string dmenuPrompt: "Pick one"
        property string scope: ""
        property string scopeTitle: ""
        property var history: []
        property var rows: []
        property int selected: 0
        property bool selectionTouched: false
        readonly property var current: rows.length && selected >= 0 && selected < rows.length ? rows[selected] : ({})
        property bool ctrlHeld: false
        readonly property int shortcutRows: 8
        property bool pending: false
        property bool showLoading: false
        property string errorMessage: ""
        property string statusMessage: ""
        property var confirmPending: null
        property bool capturing: false
        property string captureChord: ""
        property string capturePartial: ""
        property var captureCurrent: null
        property var captureRow: null
        property var captureCheck: ({ message: "", state: "" })
        property bool captureReady: false
        property bool dictationMode: false
        readonly property bool clipboardChoice: false
        readonly property bool providerViewActive: false
        property var paletteSettings: ({ showPreview: true })
        property string matchQuery: ""
        property var voice: ({ active: false, phase: "idle", level: 0, history: [], liveText: "" })
        property string voiceTrigger: "tap"
        readonly property var motion: ({ flashRise: 0, flashFall: 0 })
        property real levelOpacity: 1
        property var levelTransform: ({ x: 0 })
        property Item attachedView: null
        property var detachedFrom: []
        property int focusCalls: 0
        property int cancels: 0
        property int activations: 0
        property var searchProxy: QtObject {
            property string text: ""
            property int cursorPosition: 0
        }
        property var viewProxy: QtObject {
            property Component sourceComponent: null
            property var item: null
        }
        property ListModel results: ListModel {}
        signal flashed(string uid)
        property Item listView: null
        onSelectedChanged: if (listView) listView.currentIndex = selected
        function attach(view, field, list) {
            if (attachedView && attachedView !== view) attachedView.detached();
            attachedView = view;
            listView = list;
            list.currentIndex = selected;
        }
        function detach(view) {
            if (attachedView !== view) return;
            detachedFrom = detachedFrom.concat([view]);
            attachedView = null;
            listView = null;
        }
        function typed(t) { searchProxy.text = t }
        function focusInput() { focusCalls++ }
        function cancel() { cancels++; opened = false }
        function edited() {}
        function usefulPreview(row) { return false }
        function bindable(row) { return row && row.id === "region" }
        function select(d) { selected = (selected + d + rows.length) % rows.length }
        function selectPage(d) { select(d) }
        function selectFromPointer(i, item, mouse) {}
        function activate(alt) { activations++ }
        function activateAt(i) {}
        function goBack() {}
        function beginCapture() {}
        function isSuperKey(k) { return false }
        function isModifierKey(k) { return false }
        function voiceStop() {}
        function voiceCancel() {}
        // Rows the way Keystroke.display() lays them into the model.
        function show(list, query) {
            matchQuery = query;
            rows = list;
            selected = 0;
            results.clear();
            let last = "";
            for (const r of list) {
                results.append({ uid: r.uid, providerKey: r.providerKey, title: r.title, subtitle: r.subtitle || "", icon: r.icon || "", iconFont: "",
                    iconSource: "", section: r.section || "", sectionStart: (r.section || "") !== last, accessory: r.accessory || "", disabled: false,
                    badge: "", hint: r.hint || "", ranges: query ? JSON.stringify(Match.ranges(query, r.title)) : "[]",
                    glyph: Glyphs.forRow(r), meta: r.meta || "", mono: r.mono === true });
                last = r.section || "";
            }
            if (listView) listView.currentIndex = selected;
        }
    }
    QtObject {
        id: launcherLeft
        property int count: 0
    }
    FloatingWindow {
        visible: true
        implicitWidth: 1000
        implicitHeight: 608
        IslandView {
            id: launcherIsland
            anchors.fill: parent
            interrupt: quietInterrupt
            liveData: ({})
            monitor: ({ name: "check-launcher", width: 1000, height: 700 })
            workspaces: WorkspaceOrder.shown([{ name: "W", windows: 1 }], "W")
            onLauncherLeft: launcherLeft.count++
        }
    }
    FloatingWindow {
        visible: true
        implicitWidth: 800
        implicitHeight: 520
        LauncherUi.LauncherContent {
            id: panelContent
            x: 20
            y: 20
            width: implicitWidth
            height: implicitHeight
            engine: fakeLauncher
            active: false
        }
    }
    readonly property var launcherRows: [
        { uid: "system/region", id: "region", providerKey: "system", providerName: "Desktop", section: "Capture", title: "Screenshot Region",
          subtitle: "Select an area, save it, and copy it", accessory: "PRINT", action: { type: "exec", argv: ["capture", "shot", "region"] } },
        { uid: "system/screen", id: "screen", providerKey: "system", providerName: "Desktop", section: "Capture", title: "Screenshot Screen",
          subtitle: "The whole screen", accessory: "Shift + PRINT", action: { type: "exec", argv: ["capture", "shot", "screen"] } },
        { uid: "clipboard/12", id: "12", providerKey: "clipboard", providerName: "Clipboard", section: "Clipboard", title: "capture shot region",
          subtitle: "", meta: "Text", mono: true, glyph: "text", action: { type: "copy" } }
    ]
    // The launcher in four beats, 600 ms apart.
    Timer {
        id: launcherCheck
        interval: 600
        repeat: true
        property int step: 0
        property bool finished: false
        onTriggered: {
            try {
                const v = launcherIsland, e = fakeLauncher;
                if (step === 0) {
                    e.opened = true;
                    e.show(test.launcherRows, "shot");
                    test.check(v.showLauncher(e) === "ok" && v.islandState === "launcher" && v.panelOpen, "the palette opens as the island's launcher state");
                    test.check(v.launcherShown && v.launcherFocus, "the palette wants the keyboard while it is up");
                    const c = v.launcherCard.content;
                    test.check(c !== null && e.attachedView === c, "the island's content takes the engine");
                    test.check(c.implicitWidth === 760 && c.implicitHeight === 472 && v.targetSize[0] === 760 && v.targetSize[1] === 472, "the island targets the palette's 760 x 472: " + v.targetSize);
                    test.check(v.body.width < 760, "the body morphs to it");
                    test.check(v.open("launcher").startsWith("error") && v.open("launcher").includes("launcher open"), "the island's own open points at the launcher IPC");
                } else if (step === 1) {
                    const c = v.launcherCard.content;
                    test.check(v.body.width === 760 && v.body.height === 472 && v.body.radius === 28 && v.body.x === 120, "760 x 472, radius 28, centred: " + v.body.width + " x " + v.body.height + " @" + v.body.x);
                    const list = v.box(c.listItem), card = v.box(c.cardItem);
                    test.check(list.x === 130 && list.y === 72 && list.width === 420, "the list is 440 wide with 8 10 padding under the 56 header: " + JSON.stringify(list));
                    test.check(card.x === 560 && card.y === 76 && card.width === 306 && card.height === 352, "the detail card is 306 x 352 at 12 / 14: " + JSON.stringify(card));
                    test.check(String(c.cardItem.color) === String(Tokens.raised) && String(c.cardItem.border.color) === String(Tokens.hairline), "the card is raised with a hairline ring");
                    const row = c.selectedRow;
                    test.check(row !== null && row.selected && row.height === 48 && row.title === "Screenshot Region", "the first row is selected, 48 high");
                    test.check(String(row.children[0].color) === String(Tokens.accentTint), "the selected row sits on accentTint");
                    test.check(JSON.stringify(Match.ranges("shot", row.title)) === JSON.stringify([[6, 10]]) && row.ranges === "[[6,10]]", "the row carries its match ranges, the run as the board marks it: " + row.ranges);
                    test.check(c.sectioned, "a query mixing Capture and Clipboard shows section headers");
                    test.check(row.keys.length === 1 && row.keys[0] === "PRINT", "the chord trails as keycaps");
                    // Actions on a command row (M5 review): the hotkey and the provider's settings, not a paste.
                    const dc = c.cardItem;
                    test.check(JSON.stringify(dc.menuItems.map(i => i.id)) === JSON.stringify(["hotkey", "settings"]) && dc.menuItems[1].label === "Desktop settings",
                        "the card's Actions lists the row's other actions: " + JSON.stringify(dc.menuItems));
                    dc.openMenu();
                    test.check(dc.menuOpen && test.child(dc, "launcherActionsMenu").visible, "Actions opens its list");
                    dc.moveMenu(1);
                    test.check(dc.menuIndex === 1, "the list moves");
                    e.selected = 1;
                    test.check(!dc.menuOpen, "and closes when the selection moves");
                    e.selected = 0;
                    test.check(Glyphs.forRow({ providerKey: "system", id: "action-screenshot-window", parent: "capture" }) === "window"
                        && Glyphs.forRow({ providerKey: "system", id: "action-screenshot-screen", parent: "capture" }) === "monitor", "capture rows draw window and monitor, as the board does");
                    // A picker hugs its rows at its own width, with no card and no footer.
                    e.dmenuWidth = 420;
                    e.mode = "select";
                    test.check(c.implicitWidth === 420 && c.implicitHeight === 56 + 3 * 50 - 2 + 16 && v.targetSize[0] === 420 && v.targetSize[1] === c.implicitHeight, "a picker is its width and as tall as its rows: " + v.targetSize);
                    test.check(!c.cardShown, "no detail card in a picker");
                    e.mode = "palette";
                    // A colour answer swaps the body.
                    e.show([{ uid: "colors/hex", id: "hex", providerKey: "colors", providerName: "Colors", tier: "answer", answerKind: "color", section: "Colors",
                        title: "#82FB9C", subtitle: "HEX", swatch: "#82FB9C", caption: "#82FB9C", hint: "" }], "#82fb9c");
                    test.check(c.colorAnswer && !c.cardShown && c.answerRow.providerName === "Colors", "a colour answers in place, the chip names Colors");
                    e.show(test.launcherRows, "shot");
                    // An outside click (the focus grab clearing) leaves the state: the palette closes.
                    v.dismiss();
                    test.check(v.islandState === "rest" && launcherLeft.count === 1, "leaving the launcher state tells the launcher");
                    test.check(!v.launcherFocus, "and lets the keyboard go at once");
                } else if (step === 2) {
                    test.check(v.body.width === 360 && v.body.height === 38, "back at rest");
                    test.check(e.attachedView === null && e.detachedFrom.length === 1, "the island's content let go of the engine");
                    test.check(v.launcherCard.content === null, "and was unloaded once it faded");
                    // The panel host: the same view, free-standing.
                    panelContent.active = true;
                    test.check(e.attachedView === panelContent && panelContent.implicitWidth === 760 && panelContent.implicitHeight === 472, "the free panel's content takes the engine");
                    test.check(panelContent.fieldItem.font.pixelSize === 16 && panelContent.cardItem.width === 306, "the same frame in the panel");
                    panelContent.active = false;
                    test.check(e.attachedView === null, "an inactive content holds nothing");
                    // A close after a launch waits for the flash, then rest.
                    e.opened = true;
                    v.showLauncher(e);
                    test.check(e.attachedView === v.launcherCard.content, "reopening on the island moves the engine back");
                    e.opened = false;
                    v.releaseLauncher(300);
                    test.check(v.islandState === "launcher", "the close waits for the activation flash");
                } else if (step === 3) {
                    test.check(v.islandState === "rest" && launcherLeft.count === 2, "then the island goes back to rest");
                    // The voice layout, from the session's levels.
                    panelContent.active = true;
                    test.check(e.attachedView === panelContent, "the panel takes it back");
                    e.voice = { active: true, phase: "listening", level: 0.5, history: [0, 0.25, 0.5, 1], liveText: "open the control center" };
                    test.check(panelContent.voiceActive && panelContent.dense && !panelContent.cardShown, "voice takes the header and the dense rows");
                    const vrow = panelContent.selectedRow;
                    test.check(vrow !== null && vrow.height === 46 && !vrow.compactText && vrow.subtitle.indexOf("Capture › ") === 0,
                        "voice rows: 46 high, the title at 13 and the crumb before the subtitle: " + (vrow ? vrow.subtitle : "none"));
                    e.voice = { active: false, phase: "idle", level: 0, history: [], liveText: "" };
                    panelContent.active = false;
                    finished = true;
                    stop();
                }
                step++;
            } catch (error) {
                console.error("CAPSULE_TEST_FAIL: " + error.message);
                Qt.quit();
            }
        }
    }

    // The island in three beats: rest as drawn, hover opening on the spatial
    // spring, then the hand-offs and the IPC verbs.
    Timer {
        id: islandCheck
        interval: 600
        repeat: true
        property int step: 0
        property bool finished: false
        onTriggered: {
            try {
                const v = islandView;
                if (step === 0) {
                    test.check(v.islandState === "rest" && !v.pinned && !v.panelOpen, "the island starts at rest: " + JSON.stringify(v.machine));
                    test.check(v.body.width === 360 && v.body.height === 38 && v.body.radius === 19, "rest is 360 x 38, radius 19: "
                        + v.body.width + " x " + v.body.height + " r " + v.body.radius);
                    test.check(v.body.x === 320 && v.body.y === 8, "rest sits top centre, 8 down");
                    test.check(v.rest.hugWidth === 360, "four letters and the clock hug to the 360 minimum");
                    test.check(String(v.body.color) === String(Tokens.surface) && String(v.body.border.color) === String(Tokens.hairline), "the body wears surface and hairline");
                    const strip = v.rest.strip;
                    test.check(JSON.stringify(strip.names) === JSON.stringify(["W", "C", "D", "S"]) && strip.focusedName === "D", "W C D S with D focused");
                    test.check(strip.shapeName === "Cookie6Sided" && String(strip.shape.color) === String(Tokens.accent), "the focused shape is the boards' cookie in accent");
                    test.check(v.rest.current && !v.hover.current, "the rest layer shows");
                    test.check(v.restAnchor.width === 360 && v.restAnchor.x === 320, "the rest anchor is the rest pill");
                    test.check(NotificationState.resolveAnchor(v.monitor) === null, "the island registers no notification center anchor (M10: the old center is gone)");
                    // Pointer: the dwell starts on enter and stops on leave.
                    v.pointerEntered();
                    test.check(v.dwell.running && v.dwell.interval === 250, "hover waits for a 250 ms dwell");
                    v.pointerLeft();
                    test.check(!v.dwell.running && v.islandState === "rest", "leaving before the dwell keeps rest");
                    // A letter used inside the dwell ends it: hover must not open over it.
                    v.pointerEntered();
                    v.rest.strip.activated("W");
                    test.check(!v.dwell.running && v.islandState === "rest", "a letter click or wheel inside the dwell cancels it");
                    v.pointerLeft();
                    // No focused toplevel offscreen: the Context lane is empty, and nothing is live.
                    test.check(v.context === "" && !v.rest.laneRow.visible && !v.rest.segment.visible, "no Context lane and no live segment without a window or a recorder");
                    // A click on the pill pins hover at once.
                    v.clickPill();
                    test.check(v.islandState === "hover" && v.pinned && v.panelOpen, "a click pins hover");
                    test.check(v.targetSize[0] === 720 && v.targetSize[1] === 136, "hover targets 720 x 136");
                    test.check(v.body.width < 720 && v.body.width >= 360, "the body morphs rather than jumps");
                    test.check(v.hover.current && !v.rest.current, "the hover layer takes over");
                } else if (step === 1) {
                    test.check(v.body.width === 720 && v.body.height === 136 && v.body.radius === 28, "hover settles at 720 x 136, radius 28: "
                        + v.body.width + " x " + v.body.height + " r " + v.body.radius);
                    test.check(v.body.x === 140, "hover stays centred");
                    v.pointerLeft();
                    test.check(v.islandState === "hover", "pinned hover ignores the pointer leaving");
                    v.dismiss();
                    test.check(v.islandState === "rest", "an outside click closes pinned hover");
                    // The IPC verbs, minus the window lookup.
                    test.check(v.open("hover") === "ok" && v.pinned, "open hover pins it");
                    test.check(v.toggle("hover") === "ok" && v.islandState === "rest", "toggle closes what is open");
                    // M6: cc is the island's own state; M10: so is the battery,
                    // the last hand-off to the old Hud, as the cc/battery sheet.
                    test.check(v.open("cc") === "ok" && v.islandState === "cc" && v.panelOpen, "cc is the island's own state (M6)");
                    test.check(v.toggle("cc") === "ok" && v.islandState === "rest", "toggle closes cc");
                    test.check(v.open("battery") === "ok" && v.islandState === "cc" && v.panelOpen && v.isOpen("cc/battery") && v.isOpen("battery"), "battery opens the control center's Battery sheet (M10)");
                    test.check(v.ccPanel.content.sheetItem?.objectName === "ccSheet-battery", "the Battery sheet loads");
                    test.check(v.toggle("battery") === "ok" && v.islandState === "rest", "toggle closes it");
                    test.check(v.open("cal") === "ok" && v.islandState === "cal", "cal is the island's own state (M3)");
                    test.check(v.close() === "ok" && v.islandState === "rest", "close clears everything");
                    // The focus grab clearing closes the battery sheet like any panel.
                    v.open("battery");
                    v.dismiss();
                    test.check(v.islandState === "rest", "an outside click closes the battery sheet");
                    test.check(v.open("polkit").startsWith("error: no authentication request"), "polkit opens only for a waiting request (M8)");
                    test.check(v.open("notif").startsWith("error: no notification") && v.open("dict").startsWith("error: no dictation"), "notif and dict need something to show");
                    test.check(v.open("bogus").startsWith("error: unknown"), "unknown states are refused");
                    const info = v.inspect();
                    test.check(info.state === "rest" && info.target.width === 360 && info.workspaces.join("") === "WCDS" && info.focused === "D", "inspect reports state and geometry");
                    v.pointerLeft();
                } else {
                    test.check(v.body.width === 360 && v.body.height === 38 && v.body.radius === 19, "back at rest");
                    finished = true;
                    stop();
                }
                step++;
            } catch (error) {
                console.error("CAPSULE_TEST_FAIL: " + error.message);
                Qt.quit();
            }
        }
    }

    // The control center and the power menu (PLAN M6) on their own island,
    // after the crew and M3 checks (Do not disturb changing would flash on
    // their islands). SHELL_DRY_RUN=1: the model and the sheets read the
    // services and change nothing, except where a beat turns it off for the
    // DND tile, whose state lives in this run's own Prefs.
    FloatingWindow {
        visible: true
        implicitWidth: 1000
        implicitHeight: 608
        IslandView {
            id: m6View
            anchors.fill: parent
            interrupt: quietInterrupt
            liveData: ({})
            laneData: ({})
            monitor: ({ name: "check-m6", width: 1000, height: 700 })
            workspaces: WorkspaceOrder.shown([{ name: "W", windows: 1 }], "W")
        }
    }
    Timer {
        id: m6Check
        interval: 600
        repeat: true
        running: true
        property int step: 0
        property bool finished: false
        onTriggered: {
            try {
                const v = m6View;
                const cc = v.ccPanel.content;
                const model = v.ccPanel.model;
                if (step === 0) {
                    if (crewCheck.running || m3Check.running) return;
                    test.check(model.dryRun && Fixture.dryRun, "SHELL_DRY_RUN keeps the control center from changing anything");
                    test.check(v.open("cc") === "ok" && v.islandState === "cc" && v.panelOpen, "open cc is the island's cc state");
                    test.check(v.targetSize[0] === 760 && v.targetSize[1] === 560, "cc targets 760 x 560");
                    const tiles = [0, 1, 2, 3].map(i => cc.tiles.itemAt(i)?.objectName).join(" ");
                    test.check(tiles === "ccTile-wifi ccTile-bt ccTile-ts ccTile-dnd", "the four tiles, by objectName: " + tiles);
                    const minis = [0, 1, 2, 3, 4, 5].map(i => cc.minis.itemAt(i)?.objectName).join(" ");
                    test.check(minis === "ccMini-awake ccMini-power ccMini-display ccMini-theme ccMini-record ccMini-clipboard", "the six minis: " + minis);
                    test.check(String(cc.media.playButton.ink) === String(Tokens.bg) && String(cc.media.playButton.fill) === String(Tokens.fg), "play is bg on fg, never onAccent");
                } else if (step === 1) {
                    test.check(v.body.width === 760 && v.body.height === 560 && v.body.radius === 28, "cc settles at 760 x 560, radius 28: " + v.body.width + " x " + v.body.height + " r " + v.body.radius);
                    test.check(v.body.x === 120 && v.body.y === 8, "cc sits top centre, 8 down");
                    const footer = cc.footer.mapToItem(cc, 0, 0);
                    test.check(footer.y + cc.footer.height + 16 === 552 && cc.height === 560, "content is 552 inside 560: " + (footer.y + cc.footer.height + 16));
                    test.check(v.inspect().parts.ccTile.width === 174 && v.inspect().parts.ccTile.height === 70, "tiles are 174 x 70");
                    // The hover's status pill opens it too (the M1 hand-off is gone).
                    v.close();
                    v.open("hover");
                    v.hover.openControlCenter();
                    test.check(v.islandState === "cc", "the status pill opens the cc state");
                    test.check(v.ccByPointer, "by the pointer, so no focus ring lands on the Wi-Fi disc");
                    test.check(v.open("cc/bogus").startsWith("error: no sheet"), "an unknown sheet is refused");
                    test.check(v.open("cc/wifi") === "ok" && cc.sheet === "wifi" && cc.sheetItem?.objectName === "ccSheet-wifi", "open cc/wifi opens the Wi-Fi sheet");
                    test.check(v.isOpen("cc/wifi") && !v.isOpen("cc/sound") && !v.ccByPointer, "isOpen knows the sheet; IPC opens count as keys");
                } else if (step === 2) {
                    test.check(cc.sheetOffset === 0 && cc.sheetItem.width === 728 && cc.sheetItem.height === 528, "the sheet slid in to 0 and fills 728 x 528: " + cc.sheetOffset);
                    test.check(v.inspect().cc.sheet === "wifi", "inspect reports the sheet");
                    v.stepBack();
                    test.check(cc.sheet === "" && v.islandState === "cc", "Esc steps back out of the sheet first");
                    for (const name of ["wifi", "sound", "tailscale", "bt", "notifications", "display", "awake", "battery"]) {
                        test.check(v.open("cc/" + name) === "ok" && cc.sheetItem?.objectName === "ccSheet-" + name, "the " + name + " sheet loads");
                        test.check(cc.sheetItem.shown && cc.sheetItem.sheetData.groups.length > 0, "the " + name + " sheet shows groups");
                    }
                    test.check(v.open("cc/net") === "ok" && cc.sheet === "wifi" && v.open("cc/audio") === "ok" && cc.sheet === "sound", "the launcher's page names reach the same sheets");
                    test.check(v.open("cc") === "ok" && cc.sheet === "" && v.islandState === "cc", "open cc goes back to home");
                } else if (step === 3) {
                    test.check(cc.sheetOffset === 760 && cc.sheetLoader.source.toString() === "" && cc.home.opacity === 1, "home is back and the sheet unloaded: " + cc.sheetOffset + " " + cc.home.opacity);
                    // Do not disturb from the tile is NotificationState.dnd, kept in Prefs.dnd.
                    model.dryRun = false;
                    const was = NotificationState.dnd;
                    cc.tiles.itemAt(3).toggled(!was);
                    test.check(NotificationState.dnd === !was && Prefs.dnd === !was, "the DND tile toggles NotificationState.dnd and Prefs.dnd");
                    test.check(model.home.tiles[3].on === !was && model.home.tiles[3].sub === (!was ? "On" : "Off"), "the tile follows it");
                    Prefs.setDnd(was);
                    test.check(NotificationState.dnd === was, "Prefs.dnd changing (a reload, another writer) reaches NotificationState");
                    model.dryRun = true;
                    test.check(model.run("tile", { key: "wifi", on: false }) === "ok" && model.last.startsWith("tile"), "a dry run logs the press and changes nothing");
                    // The footer's Power: the power state over the scrim.
                    model.run("power", null);
                    test.check(v.islandState === "power" && v.scrimShown && v.panelOpen, "Power opens the power state over the scrim");
                    test.check(v.powerMenu.selectedId === "lock", "Lock is selected when it opens");
                } else if (step === 4) {
                    test.check(v.body.width === 600 && v.body.height === 156, "power settles at 600 x 156: " + v.body.width + " x " + v.body.height);
                    test.check(v.body.x === 200, "power sits top centre");
                    const pm = v.powerMenu;
                    test.check(["lock", "suspend", "logout", "reboot", "shutdown"].every((id, i) => pm.repeater.itemAt(i).objectName === "powerItem-" + id), "power items by objectName");
                    pm.select(pm.indexForKey("s"));
                    test.check(pm.selectedId === "suspend" && v.islandState === "power", "a letter selects and does not run");
                    pm.run(pm.selectedId);
                    test.check(v.powerRan === "suspend" && v.islandState === "rest" && !v.scrimShown, "Enter runs it (not under a dry run) and the island goes back to rest");
                    v.open("power");
                    pm.cancel();
                    test.check(v.islandState === "rest", "Esc cancels the power menu");
                    // The footer's battery (the charge limit) opens the Battery
                    // sheet (M10: the old Hud's page); back is the control center.
                    v.open("cc");
                    model.run("battery", null);
                    test.check(v.islandState === "cc" && cc.sheet === "battery" && cc.sheetItem?.objectName === "ccSheet-battery", "the battery opens the Battery sheet");
                    const bs = cc.sheetItem;
                    test.check(bs.title === "Battery" && bs.sheetData.hasSwitch === false && bs.sheetData.groups.some(g => g.label === "Charge limit"), "the charge limit, no switch: " + JSON.stringify(bs.sheetData.groups.map(g => g.label)));
                    v.stepBack();
                    test.check(cc.sheet === "" && v.islandState === "cc", "back from the battery sheet is the control center");
                    v.close();
                    v.open("cc");
                    model.run("lock", null);
                    test.check(v.islandState === "rest", "Lock closes the island first");
                    const info = v.inspect();
                    test.check(info.cc.dryRun && info.power.ran === "suspend" && "ccPower" in info.parts, "inspect reports cc and power");
                    // The launcher's System pages load the same sheets, in every
                    // bar mode; the theme page is gone (M7: Theme Picker runs
                    // `theme picker themes`).
                    const system = Qt.createComponent(Qt.resolvedUrl("launcher/providers/System.qml"));
                    test.check(system.status === Component.Ready, "the System provider compiles: " + system.errorString());
                    let backs = 0;
                    const host = { goBack() { backs++; }, cancel() {} };
                    const provider = system.createObject(m6View, { host: host });
                    const pages = { audio: "ccSheet-sound", net: "ccSheet-wifi", bt: "ccSheet-bt", display: "ccSheet-display", tailscale: "ccSheet-tailscale" };
                    for (const page in pages) {
                        provider.activePage = page;
                        const view = provider.view.createObject(m6View, { host: host });
                        const sheet = test.child(view, pages[page]);
                        test.check(view.sheet && sheet !== null && sheet.shown, "System > " + page + " loads " + pages[page]);
                        if (page === "net") {
                            sheet.navigate("sound");
                            test.check(provider.activePage === "audio" && test.child(view, "ccSheet-sound") !== null, "a sheet's navigate(\"sound\") is the launcher's audio page");
                            test.child(view, "ccSheet-sound").back();
                            test.check(backs === 1, "a sheet's back is the launcher's goBack");
                        }
                        view.destroy();
                    }
                    const themeRow = provider.commandRow(provider.commands.find(c => c.id === "theme-controls"), {}, 0);
                    test.check(themeRow.title === "Theme Picker" && JSON.stringify(themeRow.action) === JSON.stringify({ type: "exec", argv: ["theme", "picker", "themes"] }) && themeRow.verb === "Run",
                        "System > Themes > Theme Picker runs `theme picker themes`: " + JSON.stringify(themeRow.action));
                    test.check(provider.commands.every(c => !c.page), "no System command opens a page of its own");
                    provider.activePage = "theme";
                    const themeView = provider.view.createObject(m6View, { host: host });
                    const loaded = (item) => (item.children ?? []).some(c => (c.title === "Theme" && c.menuWidth === 360) || loaded(c));
                    test.check(!themeView.sheet && !loaded(themeView), "a theme page loads no ThemeMenu");
                    themeView.destroy();
                    provider.destroy();
                    // `island open cc/<sheet>` from rest: the keys end on the
                    // sheet, not the hidden Wi-Fi disc (focusPanel runs later).
                    v.close();
                    test.check(v.open("cc/wifi") === "ok" && cc.sheet === "wifi", "cc/wifi from rest");
                } else if (step === 5) {
                    test.check(cc.sheetLoader.focus && !cc.tiles.itemAt(0).disc.focus && cc.sheetItem.keyboard, "the sheet holds the keys (by key, so its ring shows), not the Wi-Fi disc");
                    // The Tailscale sheet on a tailnet (the M6 review's binding
                    // loop showed only with machines): the footer is on, and with
                    // This machine selected it opens the machines that take files.
                    Fixture.data = ({ sheets: { tailscale: { now: 1794674700000, installed: true, running: true, state: "Connected", self: { name: "milhouse", ipv4: "100.101.12.4" },
                                    peers: [{ id: "riker", name: "riker", os: "linux", ipv4: "100.88.3.21", canSend: true }, { id: "mbp", name: "nick-mbp", os: "macOS" }],
                                    offline: [{ id: "pixel", name: "pixel-9", os: "android", lastSeen: 1794667500000 }],
                                    accounts: [{ id: "p1", label: "work", selected: true }, { id: "p2", label: "home" }] },
                                sound: { sink: "Speakers", volume: 0.62, micVolume: 0.8, sinks: [{ key: "s", name: "Speakers", isDefault: true }], sources: [{ key: "m", name: "Built-in mic", isDefault: true }] } } });
                    test.check(v.open("cc/tailscale") === "ok" && cc.sheetItem?.objectName === "ccSheet-tailscale", "the Tailscale sheet on a fixture");
                    const ts = cc.sheetItem;
                    test.check(ts.sheetData.footerEnabled && ts.footerButton.enabled && ts.currentRow.key === "self", "Taildrop's footer is on with This machine selected");
                    test.check(ts.sheetData.groups.some(g => g.label === "Accounts" && g.rows.length === 2), "two accounts show as Accounts");
                    ts.footerClicked();
                    test.check(ts.page === "send" && ts.sheetData.groups[0].rows.map(r => r.key).join(" ") === "riker", "the footer opens the machines that take files: " + ts.page);
                    ts.activate(ts.sheetData.groups[0].rows[0]);
                    test.check(ts.sentTo === "riker" && ts.page === "" && v.islandState === "cc", "a dry run picks riker and changes nothing");
                    ts.current = 2;
                    test.check(ts.currentRow.key === "riker", "riker selected");
                    ts.footerClicked();
                    test.check(ts.sentTo === "riker" && ts.page === "", "the footer sends to a selected machine directly");
                    test.check(v.open("cc/sound") === "ok", "the Sound sheet on a fixture");
                    const levels = cc.sheetItem.sheetData.groups.map(g => g.rows[0]);
                    test.check(levels[0].slider === 0.62 && levels[0].action === "outputMute" && levels[1].slider === 0.8 && levels[1].action === "micMute", "the default output and input carry their levels");
                    Fixture.data = ({});
                    v.close();
                    finished = true;
                    stop();
                }
                step++;
            } catch (error) {
                console.error("CAPSULE_TEST_FAIL: " + error.message);
                Qt.quit();
            }
        }
    }

    // A polkit request (PLAN M8) on its own island, against
    // Island/FixtureAuthFlow.qml: the real PolkitAgent is never built here.
    // It takes the island over the scrim, holds it while it waits, refuses
    // the other panels, clears the typed answer on every way out, and only
    // shows on its own screen.
    FloatingWindow {
        visible: true
        implicitWidth: 1000
        implicitHeight: 320
        IslandView {
            id: m8View
            anchors.fill: parent
            interrupt: quietInterrupt
            liveData: ({})
            laneData: ({})
            polkitUser: "nicknisi"
            monitor: ({ name: "check-m8", width: 1000, height: 700 })
            workspaces: WorkspaceOrder.shown([{ name: "W", windows: 1 }], "W")
        }
    }
    Component {
        id: m8FlowComponent
        FixtureAuthFlow {
            accept: "hunter2"
        }
    }
    Timer {
        id: m8Check
        interval: 600
        repeat: true
        running: true
        property int step: 0
        property bool finished: false
        property var flow: null
        onTriggered: {
            try {
                const v = m8View;
                const pk = v.polkitCard;
                if (step === 0) {
                    if (crewCheck.running || m3Check.running) return;
                    test.check(v.open("polkit").startsWith("error: no authentication request"), "no request, no polkit state");
                    flow = m8FlowComponent.createObject(m8View);
                    v.polkitFlow = flow;
                    test.check(v.islandState === "polkit" && v.polkitPending && v.panelOpen, "a waiting request takes the island");
                    test.check(v.scrimShown && v.raised, "over the scrim, raised to Overlay");
                    test.check(v.open("cc").startsWith("error") && v.open("power").startsWith("error") && v.islandState === "polkit", "cc and power refuse while it waits");
                } else if (step === 1) {
                    test.check(v.body.width === 480 && v.body.height === 272 && v.body.radius === 28, "polkit settles at 480 x 272, radius 28: " + v.body.width + " x " + v.body.height + " r " + v.body.radius);
                    test.check(v.body.x === 260 && v.body.y === 8, "top centre, 8 down: " + v.body.x + "," + v.body.y);
                    test.check(pk.label === "Password for nicknisi", "the label names the user: " + pk.label);
                    // What renders, not the markup (M8 review: StyledText dropped
                    // the face and this passed on the string alone): the path in
                    // Monaspace wraps the fixture's message to two lines, and the
                    // field sits where the board's does, 114 under the island's top.
                    test.check(pk.messageText.textFormat === Text.RichText && pk.messageLines === 2 && pk.messageText.height === 36, "the program path in Monaspace wraps the message to two lines: " + pk.messageLines);
                    test.check(pk.authButton.opacity === 1, "Authenticate is full accent while the request waits, the field empty");
                    test.check(pk.field.objectName === "polkitField" && pk.cancelButton.objectName === "polkitCancel" && pk.authButton.objectName === "polkitAuth", "objectNames");
                    const parts = v.inspect().parts;
                    test.check(parts.polkitField.width === 440 && parts.polkitField.height === 40, "the field is 440 x 40: " + JSON.stringify(parts.polkitField));
                    test.check(parts.polkitField.y - parts.polkit.y === 114, "the field's top is 114 under the island's: " + (parts.polkitField.y - parts.polkit.y));
                    pk.field.typed("nope");
                    test.check(pk.buffer === "nope" && pk.field.length === 4 && pk.field.bullets.text === "••••", "the field draws bullets");
                    test.check(v.inspect().polkit.typed === -1, "inspect never reports the answer outside the sandbox");
                    pk.field.submitted();
                    test.check(flow.submits === 1 && !flow.lastMatched && pk.buffer === "", "a wrong answer goes to the flow and leaves the field");
                    test.check(pk.errorText.length > 0 && pk.errorLine.visible && pk.field.failed, "the flow's error shows in bad");
                    test.check(v.islandState === "polkit", "a failure keeps the request up");
                    // Anything else moving the island: it comes back.
                    v.apply(IslandMachine.go(v.machine, "hover"));
                } else if (step === 2) {
                    test.check(v.islandState === "polkit", "the island returns to a waiting request");
                    pk.field.typed("hunter");
                    pk.field.typed("2");
                    pk.field.cleared();
                    test.check(pk.buffer === "", "Ctrl+U clears the answer");
                    pk.field.typed("hunter2");
                    pk.submit();
                    test.check(flow.lastMatched && flow.isSuccessful && pk.buffer === "", "the right answer succeeds and leaves the field");
                    test.check(!v.polkitPending && v.islandState === "rest" && !v.scrimShown, "a completed request gives the island back");
                    flow.destroy();
                    flow = m8FlowComponent.createObject(m8View);
                    v.polkitFlow = flow;
                    pk.field.typed("half");
                    pk.field.escaped();
                    test.check(flow.cancels === 1 && flow.isCancelled && pk.buffer === "", "Esc cancels the request and clears the field");
                    test.check(v.islandState === "rest", "and the island goes back to rest");
                } else if (step === 3) {
                    flow.destroy();
                    flow = m8FlowComponent.createObject(m8View);
                    v.polkitFlow = flow;
                    pk.field.typed("x");
                    v.dismiss();
                    test.check(flow.isCancelled && v.islandState === "rest" && pk.buffer === "", "an outside click cancels");
                    flow.destroy();
                    flow = m8FlowComponent.createObject(m8View);
                    v.polkitHere = false;
                    v.polkitFlow = flow;
                    test.check(v.islandState === "rest" && v.open("polkit").includes("on this screen"), "another screen's request stays there");
                    v.polkitFlow = null;
                    v.polkitHere = true;
                    flow.destroy();
                    flow = null;
                    test.check(v.open("hover") === "ok", "the island works again with no request");
                    v.close();
                    finished = true;
                    stop();
                }
                step++;
            } catch (error) {
                console.error("CAPSULE_TEST_FAIL: " + error.message);
                Qt.quit();
            }
        }
    }

    // The launcher (M5) and the control center (M6) on one island: cc's
    // Clipboard opens the palette in place, the palette's Open Control center
    // goes to cc, and cc and power cover a banner rather than drop it. After
    // the launcher check, whose fake engine it borrows. `mergeShell` stands in
    // for Launcher.qml: openScope opens the engine on this island, as place()
    // does, and leaving the launcher state closes it, as onLauncherLeft does.
    QtObject {
        id: mergeShell
        property var calls: []
        property var states: []
        property int left: 0
        function openScope(screen, route, options) {
            calls = calls.concat([{ screen: screen?.name ?? "", route: route, title: options?.title ?? "" }]);
            fakeLauncher.scope = route;
            fakeLauncher.opened = true;
            mergeView.showLauncher(fakeLauncher);
        }
    }
    FloatingWindow {
        visible: true
        implicitWidth: 1000
        implicitHeight: 608
        IslandView {
            id: mergeView
            anchors.fill: parent
            interrupt: quietInterrupt
            liveData: ({})
            laneData: ({})
            paletteHost: mergeShell
            monitor: ({ name: "check-merge", width: 1000, height: 700 })
            workspaces: WorkspaceOrder.shown([{ name: "W", windows: 1 }], "W")
            onIslandStateChanged: mergeShell.states = mergeShell.states.concat([islandState])
            onLauncherLeft: {
                mergeShell.left++;
                if (fakeLauncher.opened) fakeLauncher.cancel();
            }
        }
    }
    Timer {
        id: mergeCheck
        interval: 600
        repeat: true
        running: true
        property int step: 0
        property bool finished: false
        onTriggered: {
            try {
                const v = mergeView, e = fakeLauncher;
                const cc = v.ccPanel.content;
                if (step === 0) {
                    if (!launcherCheck.finished) return;
                    e.opened = false;
                    e.scope = "";
                    test.check(v.open("cc") === "ok" && v.islandState === "cc", "cc opens");
                    mergeShell.states = [];
                    // The Clipboard mini (a dry run still opens the palette: only the island changes).
                    test.check(v.ccPanel.model.run("mini", "clipboard") === "ok", "the Clipboard mini runs");
                    test.check(mergeShell.calls.length === 1 && mergeShell.calls[0].route === "clipboard" && mergeShell.calls[0].title === "Clipboard History"
                        && mergeShell.calls[0].screen === "check-merge", "it opens the palette's clipboard scope on this screen: " + JSON.stringify(mergeShell.calls));
                    test.check(v.islandState === "launcher" && v.launcherShown && JSON.stringify(mergeShell.states) === JSON.stringify(["launcher"]),
                        "cc goes straight to the launcher state, no stop at rest: " + JSON.stringify(mergeShell.states));
                    test.check(v.targetSize[0] === 760 && v.targetSize[1] === 472 && v.panelOpen, "the island targets the palette, still an open panel");
                } else if (step === 1) {
                    test.check(v.body.width === 760 && v.body.height === 472, "the body settles from 760 x 560 to the palette's 760 x 472: " + v.body.width + " x " + v.body.height);
                    test.check(e.attachedView === v.launcherCard.content && !v.ccPanel.current, "the palette's content holds the engine, cc is hidden");
                    // Open Control center: Launcher.qml's island effect calls open("cc") on the palette's island.
                    mergeShell.states = [];
                    test.check(v.open("cc") === "ok" && v.islandState === "cc", "the palette's Open Control center opens cc");
                    test.check(JSON.stringify(mergeShell.states) === JSON.stringify(["cc"]) && mergeShell.left === 1 && !e.opened,
                        "launcher -> cc in one step, and leaving the launcher state closed the palette: " + JSON.stringify(mergeShell.states));
                    v.releaseLauncher(0);
                    test.check(v.islandState === "cc", "the palette's own close afterwards leaves cc alone");
                } else if (step === 2) {
                    test.check(v.body.width === 760 && v.body.height === 560, "cc settles at 760 x 560");
                    test.check(cc.tiles.itemAt(0).disc.focus, "cc holds the keys after the palette: the Wi-Fi disc (by key)");
                    test.check(!v.keyboardDrop && v.launcherCard.content === null, "the island keeps the keyboard for cc, and the palette's content is gone");
                    // The System provider's row, in this run's bar mode.
                    const system = Qt.createComponent(Qt.resolvedUrl("launcher/providers/System.qml"));
                    const provider = system.createObject(mergeView, { host: null });
                    const row = provider.catalog({ settings: {} }).find(r => r.id === "control-center");
                    test.check(!!row, "Open Control center is listed in every bar mode (" + Prefs.barMode + ")");
                    const any = row ?? provider.commandRow(provider.commands.find(c => c.id === "control-center"), {}, 0);
                    test.check(JSON.stringify(provider.activate(any)) === JSON.stringify({ type: "island", state: "cc" }), "it asks for the island's cc state");
                    test.check(Glyphs.forRow(Object.assign({ providerKey: "system" }, any)) === "sliders", "its tile draws sliders, as the voice board does");
                    provider.destroy();
                    // A banner cc covers comes back once cc closes.
                    v.close();
                    v.apply(IslandMachine.notify(v.machine, { id: -7, timeout: 0 }));
                    test.check(v.islandState === "notif", "a critical banner shows");
                    test.check(v.open("cc") === "ok" && v.islandState === "cc" && JSON.stringify((v.machine.queue ?? []).map(i => i.id)) === "[-7]", "cc covers it: it waits on the queue");
                    v.dismiss();
                } else if (step === 3) {
                    test.check(v.islandState === "notif" && v.machine.item?.id === -7 && v.machine.timer === 0, "closing cc shows it again, still untimed");
                    v.openPower();
                    test.check(v.islandState === "power" && JSON.stringify((v.machine.queue ?? []).map(i => i.id)) === "[-7]", "the power menu covers it too");
                    test.check(v.raised && v.scrimShown, "the power menu raises the island over its scrim");
                    // The palette over the power menu: the dim goes, but the island stays
                    // raised (the scrim mapped, clear) until the grab ends.
                    mergeShell.openScope(null, "", {});
                    test.check(v.islandState === "launcher" && !v.scrimShown && v.raised, "power -> launcher: no dim, still raised");
                    v.dismiss();
                } else if (step === 4) {
                    test.check(v.islandState === "notif" && v.machine.item?.id === -7 && !v.raised, "and it comes back after the power menu and the palette, the island lowered");
                    v.apply(IslandMachine.drop(v.machine, -7));
                    test.check(v.islandState === "rest", "back to rest");
                    finished = true;
                    stop();
                }
                step++;
            } catch (error) {
                console.error("CAPSULE_TEST_FAIL: " + error.message);
                Qt.quit();
            }
        }
    }

    // The classic bars in the new material (PLAN M4): BarView and the
    // anchored panel host (Hosts/AnchoredView, AnchoredHost's content; its
    // PanelWindow has no offscreen backend) in a 1920 x 1200 window, on the
    // real singletons. Beats 600 ms apart, so each spatial motion (400) has
    // settled; it starts once the checks that read Prefs.barMode are done.
    FloatingWindow {
        visible: true
        implicitWidth: 1920
        implicitHeight: 1200
        color: "transparent"
        BarView {
            id: m4Bar
            screen: ({ width: 1920, height: 1200 })
            workspaces: [{ name: "W", urgent: false, activate: () => {} }, { name: "D", urgent: false, activate: () => {} }]
            focusedName: "D"
            trayItems: []
            seamFrom: m4Host.seamFrom
            seamTo: m4Host.seamTo
            seamStartLine: m4Host.seamStartLine
            seamEndLine: m4Host.seamEndLine
        }
        AnchoredView {
            id: m4Host
            anchors.fill: parent
            view: m4Bar
            monitor: ({ name: "check-m4", width: 1920, height: 1200 })
        }
    }
    Timer {
        id: barCheck
        interval: 600
        repeat: true
        running: true
        property int step: 0
        property bool finished: false
        property string oldMode: "pill"
        property string oldEdge: "top"
        function texts(item) {
            let out = item.visible !== false && typeof item.text === "string" && item.text !== "" ? [item.text] : [];
            for (const c of (item.children ?? []))
                out = out.concat(texts(c));
            return out;
        }
        onTriggered: {
            try {
                const h = m4Host, b = m4Bar;
                const settled = () => h.progress === 1 && !h.closing;
                if (step === 0) {
                    if (!styleCheck.finished || !launcherCheck.finished || !m6Check.finished || !mergeCheck.finished) return;
                    oldMode = Prefs.barMode;
                    oldEdge = Prefs.storedEdge;
                    Prefs.setBarMode("pill");
                    Prefs.setEdge("top");
                } else if (step === 1) {
                    // The pill: 518 x 40, 8 down, radius 20, ring and shadow; 56 reserved.
                    test.check(Theme.barExtent === BarGeometry.THICK + 2 * BarGeometry.INSET && b.body.x === 701 && b.body.y === 8 && b.body.width === 518 && b.body.height === 40, "the pill sits 8 down, centred: " + JSON.stringify(b.surfaceRect()));
                    test.check(b.surface.radius === 20 && b.surface.border.width === 1 && String(b.surface.border.color) === String(Tokens.hairline) && String(b.surface.color) === String(Tokens.surface), "the pill: radius 20, the hairline ring, opaque");
                    test.check(!b.innerLine.visible, "no inner-edge line on the pill");
                    test.check(h.open("cc") === "ok", "bar open cc");
                    test.check(h.kind === "cc" && h.shown && b.openMenu === "home" && b.menuAnchor === b.systemButton && h.byKey, "cc from the status module, by key: " + JSON.stringify({ kind: h.kind, shown: h.shown, menu: b.openMenu, anchor: b.menuAnchor === b.systemButton, byKey: h.byKey }));
                    const m = h.moduleRect();
                    test.check(h.shape.y === 56 && h.shape.x + 760 === Math.min(1912, m.x + m.width) && h.shape.width === 760 && h.shape.height === 560, "8 under the pill, right edges aligned: " + JSON.stringify(h.shape) + " " + JSON.stringify(m));
                    test.check(JSON.stringify(h.shape.radii) === JSON.stringify({ topLeft: 28, topRight: 28, bottomRight: 28, bottomLeft: 28 }) && h.shape.seam === "" && h.shape.motion === "grow" && h.shape.origin === "topRight", "the pill's panel: four round corners, grows from the module's top-right");
                    test.check(h.progress < 1 && h.drawnWidth < 760, "it grows rather than jumping");
                    test.check(b.systemButton.highlighted && b.systemButton.ringed, "the status module wears accentTint and the accent ring");
                    test.check(h.seamFrom === 0 && h.seamTo === 0, "no seam on the pill");
                } else if (step === 2) {
                    test.check(settled() && h.drawnWidth === 760 && h.drawnHeight === 560, "cc grew to 760 x 560: " + h.progress);
                    test.check(h.ccLayer.current && h.ccLayer.visible && h.ccLayer.content.shown, "the control center shows");
                    test.check(JSON.stringify(h.frame.drawn.radii) === JSON.stringify(h.shape.radii) && JSON.stringify(h.frame.drawn.hairline) === JSON.stringify(h.shape.hairline), "the frame draws the shape's corners and sides");
                    test.check(h.hitItem.width === 760 && h.hitItem.x === h.shape.x, "the input region is the panel");
                    test.check(h.open("cc/wifi") === "ok" && h.ccLayer.content.sheet === "wifi", "bar open cc/wifi opens the sheet");
                    test.check(h.open("cc/nope").indexOf("error") === 0 && h.open("hover").indexOf("error") === 0, "unknown panels are errors");
                    const info = h.inspect();
                    test.check(info.kind === "cc" && info.sheet === "wifi" && info.mode === "pill" && info.anchor.name === "barStatus", "inspect says what is open: " + JSON.stringify(info.anchor));
                    // The clock: its calendar, centred under it (a morph).
                    b.toggleMenu("clock", b.clockButton, "center");
                    test.check(h.kind === "cal" && b.menuAlignment === "center", "the clock asks for the calendar");
                    const c = h.moduleRect();
                    test.check(Math.abs(h.shape.x + 200 - (c.x + c.width / 2)) <= 0.5 && h.shape.x === Math.round(h.shape.x) && h.shape.y === 56 && h.shape.width === 400 && h.shape.height === 368 && h.shape.origin === "top", "centred under the clock: " + JSON.stringify(h.shape));
                } else if (step === 3) {
                    test.check(settled() && h.calLayer.current && !h.ccLayer.current, "the calendar replaced the control center");
                    test.check(h.calLayer.closable && h.calLayer.closeButton.visible && !h.calLayer.backChevron.visible, "no level to go back to: no chevron, a trailing close");
                    // The cells: built once for the day, not on the clock's tick.
                    const noon = new Date(h.now.getFullYear(), h.now.getMonth(), h.now.getDate(), 12, 0, 0);
                    h.now = noon;
                    const cells = h.calLayer.cells;
                    h.now = new Date(noon.getTime() + 1000);
                    test.check(h.calLayer.cells === cells, "a tick of the clock keeps the calendar's cells");
                    test.check(b.clockButton.highlighted && !b.systemButton.highlighted, "the highlight moved to the clock");
                    h.stepBack();
                    test.check(b.openMenu === "" && !h.shown && h.closing, "Esc closes the calendar");
                } else if (step === 4) {
                    test.check(h.kind === "" && h.progress === 0 && h.shape === null, "closed and gone");
                    test.check(!b.clockButton.highlighted, "no highlight once closed");
                    Prefs.setBarMode("full");
                } else if (step === 5) {
                    // The full strip: flush, 40, the inner hairline only.
                    test.check(Prefs.edge === "top" && Theme.barExtent === BarGeometry.THICK && b.body.x === 0 && b.body.y === 0 && b.body.width === 1920 && b.body.height === 40, "the full strip runs edge to edge, flush: " + JSON.stringify(b.surfaceRect()));
                    test.check(b.surface.radius === 0 && b.surface.border.width === 0 && b.innerLine.visible && b.innerLine.y === 39 && b.innerLine.height === 1, "square, no ring, a 1 px hairline on the inner edge");
                    test.check(h.open("cc") === "ok", "bar open cc on the full strip");
                    test.check(h.shape.x === 1160 && h.shape.y === 40 && h.shape.seam === "top" && h.shape.motion === "drop", "flush under the strip, touching the right edge: " + JSON.stringify(h.shape));
                    test.check(JSON.stringify(h.shape.radii) === JSON.stringify({ topLeft: 0, topRight: 0, bottomRight: 0, bottomLeft: 28 }), "round only on the free corner: " + JSON.stringify(h.shape.radii));
                    test.check(JSON.stringify(h.shape.hairline) === JSON.stringify({ top: false, right: false, bottom: true, left: true }), "hairline on the left and the bottom only");
                    test.check(h.fromRect.y === 40 - 560 && h.fromRect.x === 1160, "it drops from behind the strip");
                    test.check(h.seamFrom === 1160 && h.seamTo === 1920 && h.seamAt === 40, "the seam: the panel's stretch of the strip: " + h.seamFrom + ".." + h.seamTo);
                    test.check(h.seamStartLine && !h.seamEndLine, "the panel's left side draws its hairline, its right one is on the screen edge");
                    test.check(test.child(b.innerLine, "barLineBefore").width === 1161 && !test.child(b.innerLine, "barLineAfter").visible, "the strip leaves its hairline out along the seam, but over the panel's left hairline, so the corner closes: " + test.child(b.innerLine, "barLineBefore").width);
                    test.check(b.systemButton.highlighted && !b.systemButton.ringed && b.systemButton.background.border.width === 0, "accentTint, no ring, on the strip");
                } else if (step === 6) {
                    test.check(settled() && h.drawnY === 40, "it dropped into place");
                    // The control center's Power button: the power menu over the
                    // scrim, anchored like the control center (island-modes 3.2).
                    h.ccLayer.power();
                    test.check(b.openMenu === "power" && h.kind === "power", "cc's Power opens the power menu");
                    test.check(h.shape.y === 40 && h.shape.x === 1320 && h.shape.seam === "top" && h.shape.width === 600 && h.shape.height === 156 && h.shape.motion === "drop", "anchored to the status module, flush under the strip at the right: " + JSON.stringify(h.shape));
                    test.check(b.systemButton.highlighted, "the status module stays highlighted");
                    // The outgoing control center stays where it was laid out
                    // while it fades; only the power menu takes the new place.
                    test.check(h.leaving === "cc" && Math.abs(h.ccLayer.mapToItem(h, 0, 0).x - 1160) < 0.01 && Math.abs(h.powerLayer.mapToItem(h, 0, 0).x - h.drawnX) < 0.01, "the control center leaves from its own place: " + h.ccLayer.mapToItem(h, 0, 0).x);
                    test.check(h.hitItem.x === 0 && h.hitItem.y === 40 && h.hitItem.width === 1920 && h.hitItem.height === 1160, "the scrim takes the screen's input below the strip: " + JSON.stringify(h.inspect().hit));
                } else if (step === 7) {
                    test.check(settled() && h.powerLayer.current && h.inspect().scrim === 1 && h.leaving === "", "the power menu over the scrim");
                    test.check(h.inspect().scrimRect.y === 40 && h.inspect().scrimRect.height === 1160, "the scrim stops at the strip, one piece with the panel");
                    test.check(String(Tokens.scrim) === String(Qt.rgba(Tokens.bg.r, Tokens.bg.g, Tokens.bg.b, 0.56)) || Tokens.scrim.a > 0.55, "the scrim is rgba(bg, .56)");
                    test.check(h.runPower("lock") === "ok" && h.powerRan === "lock" && b.openMenu === "", "a power item runs (a dry run here) and closes");
                    test.check(h.runPower("nope").indexOf("error") === 0, "no such item");
                } else if (step === 8) {
                    test.check(h.kind === "", "closed");
                    Prefs.setBarMode("rail");
                } else if (step === 9) {
                    // The rail: flush, full height, down the left (the stored top reads left).
                    test.check(Prefs.edge === "left" && Prefs.storedEdge === "top" && Theme.barExtent === BarGeometry.THICK && b.body.x === 0 && b.body.y === 0 && b.body.width === 40 && b.body.height === 1200, "the rail is the flush full-height strip: " + JSON.stringify(b.surfaceRect()));
                    test.check(b.innerLine.visible && b.innerLine.x === 39 && b.innerLine.width === 1, "its hairline on the right only");
                    test.check(h.open("cc") === "ok", "bar open cc on the rail");
                    test.check(h.shape.x === 40 && h.shape.y === 640 && h.shape.seam === "left" && h.shape.motion === "slide", "beside the status module, flush with the rail and the screen's bottom: " + JSON.stringify(h.shape));
                    test.check(JSON.stringify(h.shape.radii) === JSON.stringify({ topLeft: 0, topRight: 28, bottomRight: 0, bottomLeft: 0 }) && JSON.stringify(h.shape.hairline) === JSON.stringify({ top: true, right: true, bottom: false, left: false }), "round top-right only, hairline top and right");
                    test.check(h.fromRect.x === 40 - 760, "it slides from behind the rail");
                } else if (step === 10) {
                    test.check(settled() && h.drawnX === 40 && h.seamFrom === 640 && h.seamTo === 1200, "slid into place, the seam along the rail");
                    // The battery (M10: the old page on the frame went): the
                    // control center's Battery sheet, in the cc frame.
                    test.check(h.open("battery") === "ok" && h.kind === "cc" && h.ccLayer.content.sheet === "battery", "bar open battery opens the Battery sheet");
                    test.check(h.ccLayer.content.sheetItem?.objectName === "ccSheet-battery" && h.inspect().sheet === "battery", "the Battery sheet loads, and inspect says so");
                } else if (step === 11) {
                    test.check(settled() && h.ccLayer.current && h.shape.width === 760 && h.shape.height === 560, "the battery sheet in the control center's 760 x 560: " + JSON.stringify(h.shape));
                    test.check(h.toggle("battery") === "ok" && b.openMenu === "", "toggle closes it");
                    test.check(h.open("appearance") === "ok" && h.page === "appearance", "bar open appearance");
                } else if (step === 12) {
                    test.check(settled() && h.pageLayer.current && h.shape.width === 392 && h.shape.height === h.pageLayer.implicitHeight && h.shape.height > 100, "the page shows on the frame: " + h.shape.height);
                    test.check(test.child(h.pageLayer, "pageSubtitle").visible && test.child(h.pageLayer, "pageSubtitle").text === "Bar layout, edge, and theme packs", "the page's subtitle in the frame's header: " + test.child(h.pageLayer, "pageSubtitle").text);
                    const t = texts(h.pageLayer);
                    test.check(["Pill", "Full bar", "Rail", "Island"].every(m => t.indexOf(m) >= 0), "AppearanceMenu lists the four modes: " + t.join("|"));
                    test.check(t.filter(x => x === "Appearance").length === 1, "titled once");
                    const icons = ["modePill", "modeFull", "modeRail", "modeIsland"].map(n => test.child(h.pageLayer, n)?.iconName ?? "");
                    test.check(new Set(icons).size === 4 && icons.every(n => n !== ""), "one icon per mode: " + icons.join(" "));
                    h.stepBack();
                    test.check(b.openMenu === "", "Esc closes the page");
                    // The theme picker replaced ThemeMenu's page (M7): Theme
                    // packs, `bar open theme` and the control center's Theme
                    // mini close the panel and open the picker on this bar's
                    // screen (shell.qml's ThemePicker as pickerHost).
                    const picks = [];
                    h.pickerHost = { openOn: (screen, kind) => picks.push((screen?.name ?? "") + " " + kind) };
                    test.check(h.open("appearance") === "ok" && h.page === "appearance", "Appearance again");
                    const appearance = test.child(h.pageLayer, "appearancePage");
                    test.check(appearance !== null && appearance.shown, "the appearance page shows");
                    appearance.navigate("theme");
                    test.check(JSON.stringify(picks) === JSON.stringify(["check-m4 themes"]) && b.openMenu === "" && h.themesRan === "picker",
                        "Theme packs opens the theme picker on the bar's screen and closes the page: " + JSON.stringify(picks) + " [" + b.openMenu + "]");
                    test.check(h.open("theme") === "ok" && picks.length === 2 && b.openMenu === "", "bar open theme opens the picker, no page: " + JSON.stringify(picks));
                    test.check(h.open("cc") === "ok" && h.ccLayer.model.run("mini", "theme") === "ok" && picks.length === 3 && b.openMenu === "",
                        "the control center's Theme mini opens the picker and closes cc: " + JSON.stringify(picks) + " [" + b.openMenu + "]");
                    h.pickerHost = null;
                    // The bell, then a mode switch closes what is open.
                    b.toggleMenu("notifications", b.notificationsButton);
                    test.check(h.kind === "cc" && h.ccLayer.content.sheet === "notifications", "the bell opens the Notifications sheet");
                    Prefs.setEdge("right");
                    test.check(Prefs.barMode === "rail" && Prefs.edge === "right" && b.openMenu === "", "moving the bar closes its panel");
                } else if (step === 13) {
                    test.check(h.kind === "", "closed on the move");
                    Prefs.setBarMode(oldMode);
                    Prefs.setEdge(oldEdge);
                    Prefs.setBarMode(oldMode);
                    finished = true;
                    stop();
                }
                step++;
            } catch (error) {
                console.error("CAPSULE_TEST_FAIL: " + error.message);
                Qt.quit();
            }
        }
    }

    // The theme and wallpaper pickers (PLAN M7) as the island's themes and
    // wallpapers states, with the live preview through the real Tokens.
    // `pickerShell` stands in for ThemePicker.qml (its PanelWindow cannot
    // load offscreen) around the real PickerModel, PickerPreview and
    // PickerRouter, with rows as `theme _rows` prints them for hackerman and
    // catppuccin-latte: openOn() opens the model and places it on the island
    // for that screen, as ThemePicker's openOn() and place() do, on two
    // islands (two screens). Leaving the picker states closes it through the
    // router, as in the shell.
    QtObject {
        id: pickerShell
        property var calls: []
        property var applies: []
        property var target: null
        readonly property var model: checkPicker
        // Island.qml as the router sees it: its `view`.
        readonly property var islands: [{ view: pickerView }, { view: pickerView2 }]
        readonly property var latte: ({ background: "#eff1f5", foreground: "#4c4f69", accent: "#1e66f5", red: "#d20f39", green: "#40a02b", yellow: "#df8e1d", blue: "#1e66f5", magenta: "#ea76cb", cyan: "#179299", muted: "#acb0be", dark_foreground: "#9ca0b0", bright_magenta: "#ea76cb", darker_background: "#d7d8dc", mode: "light" })
        readonly property var hacker: ({ background: "#0b0c16", foreground: "#ddf7ff", accent: "#82fb9c", red: "#50f872", green: "#4fe88f", yellow: "#50f7d4", blue: "#829dd4", magenta: "#86a7df", cyan: "#7cf8f7", muted: "#2d3450", dark_foreground: "#6a6e95", bright_magenta: "#cddbf4", darker_background: "#06060c", mode: "dark" })
        function row(name, palette, current) {
            return { name: name, label: name, image: "", tagline: name, swatches: [], current: current, mode: palette.mode, bg: palette.background, fg: palette.foreground, palette: palette };
        }
        function rows() {
            const out = [];
            for (let i = 0; i < 20; i++) out.push(row("pack-" + i, hacker, false));
            out[3] = row("catppuccin-latte", latte, false);
            out[11] = row("hackerman", hacker, true);
            return out;
        }
        function islandFor(screen) {
            const name = screen?.name ?? "";
            return islands.find(i => i.view.monitor.name === name) ?? null;
        }
        function place() {
            checkRouter.place(checkPicker.opened ? islandFor(target) : null);
        }
        function openOn(screen, kind) {
            calls = calls.concat([{ screen: screen?.name ?? "", kind: kind }]);
            target = screen;
            checkPicker.open(kind === "wallpapers" || kind === "backgrounds" ? "backgrounds" : "themes");
            checkPicker.setRows("themes", rows());
            checkPicker.setRows("backgrounds", [{ name: "/w/1-a.jpg", label: "A", image: "", tagline: "hackerman", swatches: [], current: true }, { name: "/w/2-b.jpg", label: "B", image: "", tagline: "hackerman", swatches: [], current: false }]);
            place();
        }
    }
    PickerModel {
        id: checkPicker
        onApplied: (row, kind) => {
            pickerShell.applies = pickerShell.applies.concat([kind + " " + row.name]);
            if (kind === "themes") checkPreview.pin(row);
            close();
        }
        onCloseRequested: close()
        onOpenedChanged: pickerShell.place()
        onKindChanged: if (opened) pickerShell.place()
    }
    PickerPreview {
        id: checkPreview
        model: checkPicker
    }
    PickerRouter {
        id: checkRouter
        model: checkPicker
    }
    // Enter's runner, on commands that fail and succeed.
    PickerRun {
        id: checkRun
        property var results: []
        onEnded: (argv, code, output) => results = results.concat([{ argv: argv, code: code, output: output }])
    }
    FloatingWindow {
        visible: true
        implicitWidth: 1300
        implicitHeight: 656
        IslandView {
            id: pickerView
            anchors.fill: parent
            interrupt: quietInterrupt
            liveData: ({})
            laneData: ({})
            pickerHost: pickerShell
            monitor: ({ name: "check-picker", width: 1300, height: 800 })
            workspaces: WorkspaceOrder.shown([{ name: "W", windows: 1 }], "W")
        }
    }
    // The second screen's island.
    FloatingWindow {
        visible: true
        implicitWidth: 1300
        implicitHeight: 656
        IslandView {
            id: pickerView2
            anchors.fill: parent
            interrupt: quietInterrupt
            liveData: ({})
            laneData: ({})
            pickerHost: pickerShell
            monitor: ({ name: "check-picker-2", width: 1300, height: 800 })
            workspaces: WorkspaceOrder.shown([{ name: "W", windows: 1 }], "W")
        }
    }
    Timer {
        id: pickerCheck
        interval: 600
        repeat: true
        running: true
        property int step: 0
        property bool finished: false
        property bool activated: false
        property string base: ""
        function key(k, text) {
            return checkPicker.handleKey({ key: k, modifiers: 0, text: text ?? "", isAutoRepeat: false });
        }
        onTriggered: {
            try {
                const v = pickerView, m = checkPicker;
                const themes = v.themesPanel.content, walls = v.wallpapersPanel.content;
                if (step === 0) {
                    // After the M6 and merge checks: their own islands animate Tokens-bound colours.
                    // And after the M4 bar check, which switches Prefs.barMode and moves the keys
                    // between its own windows: one check at a time keeps both deterministic.
                    if (!mergeCheck.finished || !m6Check.finished || !barCheck.finished) return;
                    // The keys go to this island's window first, as the
                    // compositor gives them to the island in a session. The
                    // bar check moves them between its own windows; once
                    // M10 turned its battery beat into a control center
                    // sheet, this window came out of it with no active focus
                    // item, and forceActiveFocus() gave the panel none.
                    if (!activated) {
                        v.Window.window.requestActivate();
                        activated = true;
                        return;
                    }
                    base = Tokens.hex(Tokens.surface);
                    // Enter's runner, checked at the last beat: a failing run
                    // reports its code and last lines, a good one 0.
                    checkRun.run(["sh", "-c", "echo one; echo two; echo three; echo it broke >&2; exit 3"]);
                    checkRun.run(["true"]);
                    test.check(v.open("themes") === "ok" && JSON.stringify(pickerShell.calls) === JSON.stringify([{ screen: "check-picker", kind: "themes" }]),
                        "`island open themes` goes through the picker host, on this island's screen: " + JSON.stringify(pickerShell.calls));
                    test.check(v.islandState === "themes" && v.pickerShown && v.panelOpen, "the island is the themes state, an open panel");
                    test.check(v.targetSize[0] === 1240 && v.targetSize[1] === 600, "it targets 1240 x 600: " + v.targetSize);
                    test.check(m.focused?.name === "hackerman" && Tokens.previewPalette === null, "focus starts on the applied theme, which does not preview");
                } else if (step === 1) {
                    test.check(v.body.width === 1240 && v.body.height === 600, "the body settles at 1240 x 600: " + v.body.width + " x " + v.body.height);
                    test.check(themes !== null && themes.activeFocus, "the themes panel holds the keys");
                    test.check(themes.columns === 8 && themes.grid.width === 1200 && themes.grid.height === 486, "8 columns, 3 rows in view");
                    const card = themes.focusedCard;
                    test.check(card && card.objectName === "themeCard-hackerman" && card.height === 154 && card.noteText.text === "Current", "the focused card is hackerman's, 154 high, noted Current: " + card?.objectName + " " + card?.height + " " + card?.noteText?.text);
                    // Focus catppuccin-latte: the whole island previews it.
                    test.check(m.focusName("catppuccin-latte") && Tokens.previewPalette?.name === "catppuccin-latte", "focusing catppuccin-latte previews it through Tokens.previewPalette");
                } else if (step === 2) {
                    test.check(Tokens.hex(Tokens.surface) === "#e8ebef" && Tokens.d.surface === "#e8ebef", "600 ms later the island's surface is latte's #e8ebef: " + Tokens.hex(Tokens.surface));
                    test.check(themes.focusedCard.noteText.text === "Previewing", "the card says Previewing");
                    // Esc with no filter closes, and the preview goes with it.
                    test.check(key(Qt.Key_Escape) && !m.opened, "Esc closes the picker");
                    test.check(Tokens.previewPalette === null, "the preview is dropped");
                    test.check(v.islandState === "rest", "the island goes back to rest");
                } else if (step === 3) {
                    test.check(Tokens.hex(Tokens.surface) === base, "the surface is back to the applied theme's " + base + ": " + Tokens.hex(Tokens.surface));
                    // The control center's Theme mini opens the picker in place.
                    test.check(v.open("cc") === "ok" && v.islandState === "cc", "cc opens");
                    test.check(v.ccPanel.model.run("mini", "theme") === "ok" && v.islandState === "themes" && pickerShell.calls.length === 2,
                        "the Theme mini goes straight to the themes state: " + v.islandState);
                    // A filter, then Tab: the wallpapers state, the filter cleared.
                    key(Qt.Key_P, "p");
                    key(Qt.Key_A, "a");
                    test.check(m.filter === "pa" && m.focused?.name === "pack-0", "typing filters, and focus falls back to the first match: " + m.focused?.name);
                    test.check(key(Qt.Key_Tab) && v.islandState === "wallpapers" && m.filter === "" && m.wallIndex === 0, "Tab morphs to the wallpapers state, filter cleared: " + v.islandState + " " + m.kind + " [" + m.filter + "] " + m.wallIndex);
                    test.check(v.targetSize[0] === 780 && v.targetSize[1] === 252, "two wallpapers: 780 x 252: " + v.targetSize);
                } else if (step === 4) {
                    test.check(v.body.width === 780 && v.body.height === 252, "the body settles at 780 x 252");
                    test.check(walls !== null && walls.activeFocus && walls.focusedCard?.objectName === "wallpaperCard-1-a.jpg", "the wallpapers panel holds the keys, on the applied wallpaper");
                    test.check(Tokens.previewPalette === null, "wallpapers never preview");
                    // Shift+Tab back, then Enter on latte: applied, and the preview pinned.
                    test.check(key(Qt.Key_Backtab) && v.islandState === "themes", "Shift+Tab goes back to themes");
                    m.focusName("catppuccin-latte");
                    test.check(key(Qt.Key_Return) && JSON.stringify(pickerShell.applies) === JSON.stringify(["themes catppuccin-latte"]), "Enter applies catppuccin-latte");
                    test.check(!m.opened && v.islandState === "rest" && Tokens.previewPalette?.name === "catppuccin-latte" && checkPreview.pinnedName === "catppuccin-latte",
                        "the picker closes and latte stays pinned until colors.json names it");
                    checkPreview.unpin();
                    test.check(Tokens.previewPalette === null, "unpinned");
                    // `island close` from a picker state closes the picker too.
                    v.open("wallpapers");
                    test.check(v.islandState === "wallpapers" && m.opened && m.kind === "backgrounds", "`island open wallpapers` opens the wallpapers picker");
                    v.close();
                    test.check(!m.opened && v.islandState === "rest", "`island close` closes it (pickerLeft)");
                } else if (step === 5) {
                    test.check(Tokens.hex(Tokens.surface) === base, "and the surface is the applied theme's again");
                    // The palette, cc or the calendar opened over a picker take
                    // the island; the picker closes (M7 review: the picker's
                    // release dismissed them too, back to rest).
                    v.open("themes");
                    const e = fakeLauncher;
                    e.opened = true;
                    test.check(v.showLauncher(e) === "ok" && v.islandState === "launcher" && v.launcherShown && !m.opened,
                        "the palette over the themes picker: the launcher state, the picker closed: " + v.islandState + " " + m.opened);
                    v.releasePicker();
                    test.check(v.islandState === "launcher", "a late picker release leaves the palette alone");
                    e.opened = false;
                    v.releaseLauncher(0);
                    test.check(v.islandState === "rest", "the palette closes to rest");
                    v.open("themes");
                    test.check(v.open("cc") === "ok" && v.islandState === "cc" && !m.opened, "cc over the themes picker: cc, the picker closed: " + v.islandState);
                    v.close();
                    v.open("wallpapers");
                    test.check(v.open("cal") === "ok" && v.islandState === "cal" && !m.opened, "the calendar over the wallpapers picker: cal, the picker closed: " + v.islandState);
                    v.close();
                    // The picker over the palette still takes the island.
                    e.opened = true;
                    v.showLauncher(e);
                    v.open("themes");
                    test.check(v.islandState === "themes" && m.opened, "the themes picker over the palette");
                    test.check(key(Qt.Key_Escape) && !m.opened && v.islandState === "rest", "Esc closes it to rest");
                    e.opened = false;
                    // Two screens (M7 review): reopening on the second moves the
                    // picker there, still open, and Esc closes it there.
                    const v2 = pickerView2;
                    pickerShell.openOn(v.monitor, "themes");
                    test.check(v.islandState === "themes" && v2.islandState === "rest" && checkRouter.shownIsland?.view === v, "the picker opens on the first island");
                    pickerShell.openOn(v2.monitor, "themes");
                    test.check(m.opened && v.islandState === "rest" && v2.islandState === "themes" && v2.pickerShown && checkRouter.shownIsland?.view === v2,
                        "reopened on the second screen: the first island rests, the second shows it, still open: " + [m.opened, v.islandState, v2.islandState]);
                    test.check(key(Qt.Key_Escape) && !m.opened && v2.islandState === "rest" && v.islandState === "rest", "Esc closes it on the second island");
                    test.check(v2.showPicker(m, "themes") === "error: the picker is closed" && v2.islandState === "rest", "an island refuses a closed picker");
                    const r = checkRun.results;
                    const bad = r.find(x => x.argv[0] === "sh"), good = r.find(x => x.argv[0] === "true");
                    test.check(r.length === 2 && bad && bad.code === 3 && bad.output === "two\nthree\nit broke", "a failed run reports exit 3 and its last three lines: " + JSON.stringify(r));
                    test.check(good && good.code === 0 && good.output === "", "a good run reports 0 and nothing else: " + JSON.stringify(good));
                    finished = true;
                    stop();
                }
                step++;
            } catch (error) {
                console.error("CAPSULE_TEST_FAIL: " + error.message);
                Qt.quit();
            }
        }
    }

    function check(condition, message) {
        if (!condition) throw new Error(message);
    }
    function child(item, name) {
        if (item.objectName === name) return item;
        for (const c of (item.children ?? [])) {
            const found = child(c, name);
            if (found) return found;
        }
        return null;
    }

    Timer {
        interval: 200
        running: true
        onTriggered: {
            try {
                const paused = { dbusName: "paused", isPlaying: false };
                const playing = { dbusName: "playing", isPlaying: true };
                test.check(Prefs.nextBarMode("pill") === "full", "pill cycles to full");
                test.check(Prefs.nextBarMode("full") === "rail", "full cycles to rail");
                test.check(Prefs.nextBarMode("rail") === "island", "rail cycles to island");
                test.check(Prefs.nextBarMode("island") === "pill", "island cycles to pill");
                test.check(Prefs.nextBarMode("bogus") === "pill", "an unknown mode cycles to pill");
                for (const mode of ["pill", "full", "rail"]) {
                    for (const origin of ["top", "bottom", "left", "right"]) {
                        const vertical = origin === "left" || origin === "right";
                        const extent = BarGeometry.THICK + 2 * BarGeometry.inset(mode);
                        const w = vertical ? extent : 1920, h = vertical ? 1080 : extent;
                        const ox = origin === "right" ? 1920 - w : 0;
                        const oy = origin === "bottom" ? 1080 - h : 0;
                        for (const [target, x, y] of [["top", 960, 5], ["bottom", 960, 1075], ["left", 5, 540], ["right", 1915, 540]]) {
                            test.check(BarGeometry.nearestEdge(origin, 1920, 1080, w, h, x - ox, y - oy) === target, "drag from " + mode + "/" + origin + " to " + target);
                        }
                    }
                }

                // The charge limit (M10: BatteryMenu's page is the Battery sheet).
                const savedCare = Battery.care;
                Battery.care = { supported: false, target: 0, recovery: false };
                let batteryRows = batterySheet.sheetData.groups[0].rows;
                test.check(batteryRows.map(r => r.title).join() === "Top up to 80%,Charge to 100%", "battery has the 80% and full-charge actions: " + batteryRows.map(r => r.title));
                test.check(batteryRows.every(r => r.inert && r.action === ""), "unsupported battery controls are inert");
                Battery.topUp(80);
                test.check(!Battery.busy, "unsupported battery action does not request authorization");
                Battery.care = { supported: true, mode: "Custom", start: 50, end: 80, target: 100, recovery: true };
                batteryRows = batterySheet.sheetData.groups[0].rows;
                test.check(batteryRows.length === 1 && batteryRows[0].title === "Restore battery care", "interrupted top-up exposes recovery");
                test.check(!batteryRows.some(r => r.action === "topUp"), "active top-up disables duplicate requests");
                batterySheet.activated(batteryRows[0]);
                test.check(batterySheet.ran === "stop" && !Battery.busy, "under a dry run the sheet's press runs nothing: " + batterySheet.ran);
                Battery.care = savedCare;

                test.check(!Caffeine.active && Caffeine.selectedMinutes === 60, "stay-awake defaults to a one-hour timer");
                const caffeineStarted = Date.now();
                Caffeine.start(120);
                test.check(Caffeine.active && Caffeine.selectedMinutes === 120, "a duration starts idle inhibition");
                test.check(Caffeine.endsAt >= caffeineStarted + 120 * 60000, "a timed duration records its deadline");
                Caffeine.stop();
                test.check(!Caffeine.active && Caffeine.endsAt === 0, "stay-awake can be stopped early");
                Caffeine.start(-1);
                test.check(Caffeine.active && Caffeine.endsAt === 0, "an indefinite duration has no deadline");
                Caffeine.stop();
                Caffeine.selectedMinutes = 60;

                NotificationState.clear();
                NotificationState.remember({ appName: "Test", summary: "Saved", body: "One", critical: false });
                NotificationState.remember({ appName: "Test", summary: "Urgent", body: "Two", critical: true });
                test.check(NotificationState.count === 2 && NotificationState.unread === 2, "notifications enter history as unread");
                test.check(NotificationState.history.get(0).summary === "Urgent" && NotificationState.history.get(0).critical, "newest notification is first");
                const notificationScreen = ({ name: "test-screen" });
                NotificationState.toggleCenter(notificationScreen);
                test.check(NotificationState.centerOpen && NotificationState.centerScreen === notificationScreen
                    && NotificationState.unread === 0, "opening notification sidebar marks history read");
                NotificationState.toggleCenter(notificationScreen);
                test.check(!NotificationState.centerOpen, "notification sidebar toggles closed on the same screen");
                NotificationState.toggleDnd();
                test.check(NotificationState.dnd, "do not disturb toggles on");
                NotificationState.toggleDnd();
                NotificationState.clear();
                test.check(NotificationState.count === 0 && !NotificationState.dnd, "notification history clears without changing DND");
                NotificationState.registerAnchor(notificationScreen, bellA, "right");
                test.check(NotificationState.resolveAnchor({name: "other-screen"}) === null, "notifications never use another monitor's anchor");
                NotificationState.toggleCenter(notificationScreen);
                test.check(NotificationState.centerAnchorItem === bellA && NotificationState.centerEdge === "right", "notifications use the registered bell and edge");
                NotificationState.registerAnchor(notificationScreen, bellB, "left");
                NotificationState.unregisterAnchor(notificationScreen, bellA);
                test.check(NotificationState.centerAnchorItem === bellB && NotificationState.centerEdge === "left", "replacing an anchor updates the open center safely");
                NotificationState.unregisterAnchor(notificationScreen, bellB);
                test.check(!NotificationState.centerOpen && NotificationState.centerAnchorItem === null, "destroying the active bar closes its notification popup");

                test.check(Media.choosePlayer([], "") === null, "empty player list");
                test.check(Media.choosePlayer([paused, playing], "") === playing, "prefer playing app");
                test.check(Media.choosePlayer([paused, playing], "paused") === paused, "retain chosen app");
                test.check(Media.choosePlayer([playing], "paused") === playing, "removed player fallback");

                // Nothing speaks before the shell has settled, otherwise
                // PipeWire binding the sink at login reads as a volume change.
                Interrupt.kind = "";
                Interrupt.primed = false;
                Interrupt.show("volume");
                test.check(!Interrupt.active, "unprimed interrupts are dropped");

                Interrupt.primed = true;
                Interrupt.show("brightness");
                test.check(Interrupt.kind === "brightness" && Interrupt.active, "a primed interrupt speaks");
                test.check(Interrupt.metered, "brightness draws a meter");

                // Last writer wins: the newest event is the one you caused.
                Interrupt.show("mic");
                test.check(Interrupt.kind === "mic", "the newest interrupt takes the slot");
                test.check(!Interrupt.metered, "the mic has no quantity to meter");
                test.check(Interrupt.label === "mic on", "the mic says its state in words");
                Interrupt.kind = "";
                test.check(!Interrupt.active, "a cleared interrupt is silent");

                // The context lane reads the focused window. These are the
                // readings, driven directly so no compositor is needed.
                const homeDir = Quickshell.env("HOME");
                test.check(Context.classify("com.mitchellh.ghostty", false) === "terminal", "ghostty is a terminal");
                test.check(Context.classify("com.mitchellh.ghostty", true) === "agent", "a terminal wearing an agent title is an agent");
                test.check(Context.classify("helium", false) === "browser", "helium is a browser");
                test.check(Context.classify("", false) === "", "no app, no kind");
                test.check(Context.agentParts("◑ Bar ricing redesign")[2] === "Bar ricing redesign", "an agent title splits off its spinner");
                test.check(Context.agentParts("✳ Waiting")[1] === "✳", "the still glyph counts too");
                test.check(Context.agentParts("/home/x/y") === null, "a path is not an agent");
                test.check(Context.pageTitle("Some page - Helium") === "Some page", "the browser suffix goes");
                test.check(Context.pageTitle("A - B - Helium") === "A - B", "only the last suffix goes");
                test.check(Context.pageTitle("No suffix") === "No suffix", "a bare title is left alone");
                test.check(Context.shortPath(homeDir + "/Developer/dotfiles") === "~/Developer/dotfiles", "home folds to ~");
                test.check(Context.shortPath(homeDir) === "~", "home itself is ~");
                test.check(Context.shortPath("/tmp") === "/tmp", "a path outside home stays");
                test.check(Context.describe("terminal", homeDir + "/x", "") === "~/x", "a shell shows its directory");
                test.check(Context.describe("terminal", "nvim", "") === "nvim", "a shell running something shows that");
                test.check(Context.describe("music", "Spotify", "Band – Song") === "Band – Song", "a player shows the track");
                test.check(Context.describe("music", "Spotify", "") === "Spotify", "a silent player shows its title");
                // The lane (PLAN M3): repo basenames, agent titles, a terminal
                // outside a repo, never a page title.
                test.check(Context.baseName(homeDir + "/Developer/dotfiles") === "dotfiles" && Context.baseName(homeDir + "/Developer/dotfiles/") === "dotfiles", "a repo shows its basename");
                test.check(Context.baseName(homeDir) === "~" && Context.expand("~/x") === homeDir + "/x", "home is ~");
                test.check(Context.stableTitle("◑ Bar ricing - 󱙺 dotfiles") === Context.stableTitle("✳ Bar ricing - 󱙺 dotfiles"), "a spinner turning is not a new window");
                test.check(Context.appName("com.mitchellh.ghostty", "") === "Ghostty" && Context.appName("brave-origin", "") === "Brave Origin" && Context.appName("x", "Firefox") === "Firefox", "app names");
                test.check(Context.branchText("main", 0) === "main" && Context.branchText("main", 2) === "main +2" && Context.branchText("", 4) === "", "+N is the dirty file count");
                const crewRows = [
                    { id: "%0", pane: "%0", host: "tmux", kind: "claude", label: "Hypr launcher text color", window: "󱙺 dotfiles", project: "~/Developer/dotfiles", mood: "working" },
                    { id: "%2", pane: "%2", host: "tmux", kind: "pi", label: "Make a detailed artifact with charts, graphs, animations, e…", window: "π Developer", project: "~/Developer", mood: "needs" }
                ];
                const agentTitle = "✳ Hypr launcher text color - 󱙺 dotfiles";
                const client = Context.clientFor(agentTitle, ["%9\t/tmp\tzsh - other", "%0\t" + homeDir + "/Developer/dotfiles\t✻ Hypr launcher text color - 󱙺 dotfiles"]);
                test.check(client?.pane === "%0" && client.path === homeDir + "/Developer/dotfiles", "tmux names the client whose title the window shows");
                test.check(Context.agentFor(agentTitle, "%0", crewRows)?.kind === "claude", "the agent in that pane");
                test.check(Context.agentFor("π - Make a detailed artifact with charts, graphs, animations, e… - Developer - π Developer", "", crewRows)?.kind === "pi", "a label fleet cut short still matches its window");
                test.check(Context.agentFor("zsh - 󱙺 dotfiles", "", crewRows) === null, "a shell beside an agent is not that agent");
                const agentLane = Context.laneFor({ kind: "agent", title: agentTitle, appName: "Ghostty", agent: crewRows[0], cwd: homeDir + "/Developer/dotfiles", top: homeDir + "/Developer/dotfiles", branch: "main", dirty: 2 });
                test.check(agentLane.icon === "sparkle" && agentLane.text === "dotfiles" && agentLane.extra === "" && agentLane.working
                    && agentLane.who === "Claude Code" && agentLane.where === "dotfiles" && agentLane.detail === "main +2", "an agent title: sparkle, the repo, Claude Code, main +2: " + JSON.stringify(agentLane));
                const waitingLane = Context.laneFor({ kind: "agent", title: "✳ Waiting", appName: "Ghostty", agent: null, cwd: "", top: "" });
                test.check(!waitingLane.working && waitingLane.text === "Agent", "an unknown agent at the still glyph waits");
                test.check(Context.laneFor({ kind: "agent", title: "◐ Thinking", agent: null }).working, "a turning glyph works");
                test.check(!Context.laneFor({ kind: "agent", title: "◐ Thinking", agent: crewRows[1] }).working && Context.laneFor({ kind: "agent", title: "◐ x", agent: crewRows[1] }).who === "Pi", "the feed's mood wins over the glyph");
                const termLane = Context.laneFor({ kind: "terminal", title: "zsh - 󱙺 dotfiles", appName: "Ghostty", cwd: homeDir + "/Developer/dotfiles/config", top: homeDir + "/Developer/dotfiles", branch: "main", dirty: 2 });
                test.check(termLane.icon === "terminal" && termLane.text === "dotfiles" && termLane.extra === "main +2", "a terminal in a dirty repo: dotfiles, main +2");
                const outsideLane = Context.laneFor({ kind: "terminal", title: "zsh", appName: "Ghostty", cwd: homeDir + "/Downloads", top: "", branch: "", dirty: 0 });
                test.check(outsideLane.text === "Downloads" && outsideLane.extra === "" && outsideLane.detail === "", "a terminal outside a repo: its directory, no branch");
                test.check(Context.laneFor({ kind: "terminal", title: "zsh", cwd: homeDir, top: "" }).text === "~", "at home: ~");
                test.check(Context.laneFor({ kind: "terminal", title: "nvim notes.md", appName: "Ghostty", cwd: "", top: "" }).text === "nvim", "no directory known: the program");
                const webLane = Context.laneFor({ kind: "browser", title: "Kapwork | Is this worth doing? - Brave Origin", appName: "Brave Origin" });
                test.check(webLane.icon === "globe" && webLane.text === "Brave Origin", "a browser shows its name, never the page");
                test.check(Context.laneFor({ kind: "music", title: "Spotify", appName: "Spotify", track: "Neon Grid" }).text === "Neon Grid", "a player shows the track title");
                test.check(Context.laneFor({ kind: "" }).text === "", "nothing focused, no lane");
                // A theme switch recolours the surfaces and leaves the
                // shadow alone (one neutral shadow for every palette).
                const shadowColor = Tokens.hex(Tokens.shadow);
                Theme.palette = { accent: "#a53b62", foreground: "#202020", background: "#f7f3e8", lighter_background: "#e8e0d0", mode: "light" };
                test.check(Tokens.shadow.r === 0 && Tokens.shadow.g === 0 && Tokens.shadow.b === 0, "theme switches leave the shadow neutral: " + shadowColor + " -> " + Tokens.hex(Tokens.shadow));

                // Island foundation (PLAN M0) on the real singletons: Tokens
                // follows Theme.palette, Motion follows Prefs, Kit reads both.
                test.check(Tokens.p === Theme.palette && Tokens.mode === "light" && !Tokens.dark, "tokens read the live palette");
                test.check(Tokens.d.surface === "#eeebe0" && Tokens.d.onAccent === "#f7f3e8", "tokens derive a palette written before the tokens");
                test.check(String(kitSurface.color) === String(Tokens.surface) && String(kitSurface.border.color) === String(Tokens.hairline), "Kit surface wears the tokens");
                test.check(kitIcon.path !== "" && Math.abs(kitIcon.strokeWidth - 1.2) < 1e-9, "Kit icon draws at 1.2 px on 16");
                test.check(Fixture.sandbox === false && Object.keys(Fixture.data).length === 0, "fixtures stay inert outside the sandbox");
                const oldMotion = Prefs.motion, oldReduced = Prefs.reducedMotion;
                Prefs.setMotion("spring");
                Prefs.setReducedMotion(false);
                test.check(Motion.profile === "spring" && Motion.spatial === 400 && Motion.effects === 245
                    && Motion.stagger === 80 && Motion.exitFade === 123 && Motion.loops, "spring is 400/245/80/123");
                Prefs.setMotion("current");
                test.check(Motion.spatial === 160 && Motion.effects === 90 && Motion.spring === Motion.easeOut, "current is today's ease-out");
                Prefs.setMotion("warp");
                test.check(Prefs.motion === "current", "an unknown motion profile is rejected");
                Prefs.setMotion("spring");
                Prefs.setReducedMotion(true);
                test.check(Motion.reduced && Motion.spatial === 0 && Motion.effects === 0 && !Motion.loops, "reduced motion zeroes every duration");
                Prefs.setMotion(oldMotion);
                Prefs.setReducedMotion(oldReduced);
                styleCheck.oldMode = Prefs.barMode;
                styleCheck.oldEdge = Prefs.storedEdge;
                styleCheck.start();
                islandCheck.start();
                crewCheck.start();
                m3Check.start();
                launcherCheck.start();
                finalCheck.start();
            } catch (error) {
                console.error("CAPSULE_TEST_FAIL: " + error.message);
                Qt.quit();
            }
        }
    }
}
