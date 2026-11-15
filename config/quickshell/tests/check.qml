// Run with ./config/quickshell/tests/check.sh. No real player is controlled.
import Quickshell
import QtQuick
import qs.Kit
import qs.Island
import "MenuAnchor.js" as MenuAnchor
import "BarGeometry.js" as BarGeometry
import "lib/WorkspaceOrder.js" as WorkspaceOrder
import "lib/CrewModel.js" as CrewModel
import "lib/IslandMachine.js" as IslandMachine
import "lib/Calendar.js" as Calendar

ShellRoot {
    id: test

    QtObject {
        id: player
        property string dbusName: "test.player"
        property string identity: "Test player"
        property string trackTitle: "A small song"
        property string trackArtist: "A small band"
        property string trackArtUrl: ""
        property bool isPlaying: false
        property bool canTogglePlaying: true
        property bool canGoPrevious: true
        property bool canGoNext: true
        property bool canSeek: true
        property bool positionSupported: true
        property bool lengthSupported: true
        property real length: 240
        property real position: 30
        property int nextCalls: 0
        property int previousCalls: 0
        signal postTrackChanged()
        function togglePlaying() { isPlaying = !isPlaying }
        function next() { nextCalls++ }
        function previous() { previousCalls++ }
    }

    FloatingWindow {
        visible: true
        implicitWidth: 392
        implicitHeight: 300
        MediaCard { id: card; width: 392; player: player }
        HudHome { id: home; width: 392; visible: false }
        CaffeineMenu { width: 320; visible: false }
        BatteryMenu { id: batteryMenu; width: 360; visible: false }
        Flip { id: flip; width: 80; height: 20; front: "19:57"; back: "Sat 5 Sep" }
        NickAvatar { id: avatar; width: 30; height: 30 }
        SurfaceShadow { id: outerShadow; surface: samplePanel }
        Rectangle {
            id: samplePanel
            x: 100; y: 100; width: 120; height: 80
            radius: Theme.panelRadius
            color: Theme.surface
            opacity: 0.5
            SurfaceShadow { id: innerShadow; surface: samplePanel }
        }
        // The island Kit on the real Tokens, Motion and Prefs.
        Surface { id: kitSurface; x: 240; y: 100; width: 120; height: 38; radius: 19 }
        Icon { id: kitIcon; x: 240; y: 150; name: "wifi" }
    }

    Hud {
        id: hud
        anchorItem: avatar
        now: new Date()
        monitor: ({ width: 800, height: 600 })
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
                    fakeNotifier.push({ id: 1, summary: "hi", body: "a <b>bold</b> &amp; plain body" });
                    test.check(v.islandState === "notif" && v.machine.item.id === 1 && v.machine.timer === 4200, "a notification takes the island for 4200 ms: " + JSON.stringify(v.machine));
                    test.check(v.targetSize[0] === 520 && v.targetSize[1] === 92, "notif targets 520 x 92");
                    test.check(v.notification?.summary === "hi" && v.notifCard.body === "a bold & plain body", "the banner shows the summary and a plain body: " + v.notifCard.body);
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
                    test.check(v.open("cal") === "ok" && v.islandState === "cal" && v.panelOpen && v.hudPage === "", "cal is the island's own panel");
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
                    // A hail behind a hand-off (the old Hud) waits for it to close.
                    v.open("cc");
                    fakeCrew.set(fakeCrew.four(true));
                    test.check(v.handedOff && v.islandState === "rest" && v.pendingHail === "%2", "a hail waits behind a hand-off");
                    // The Hud closing by itself: no machine change, only handedOff.
                    v.hudPage = "";
                } else if (step === 7) {
                    test.check(v.islandState === "hail" && v.pendingHail === "", "the hand-off closing lets the hail through");
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

    Connections {
        id: avatarFrames
        target: null
        property int changes: 0
        function onCurrentFrameChanged() { changes++ }
    }

    Timer {
        id: avatarCheck
        interval: 2300
        repeat: true
        property int step: 0
        onTriggered: {
            try {
                const greeting = test.child(avatar, "nickGreeting");
                const runner = test.child(avatar, "nickRunning");
                if (step++ === 0) {
                    test.check(greeting.running && avatarFrames.changes > greeting.frameCount, "hover animation advances beyond its first loop");
                    test.check(greeting.loops === AnimatedSprite.Infinite && greeting.frameRate === 4, "hover animation loops at a relaxed pace");
                    avatar.page = "theme";
                    test.check(!greeting.running, "menu stops the hidden hover animation");
                    avatar.moving = true;
                    avatarFrames.target = runner;
                    avatarFrames.changes = 0;
                    test.check(runner.visible && runner.running && !greeting.visible, "drag overrides menu costumes");
                } else {
                    // The crew check's eleven beats outlast this timer's two: wait a round.
                    if (crewCheck.running || m3Check.running) return;
                    test.check(avatarFrames.changes > 0, "running frames actually advance");
                    avatar.visible = false;
                    test.check(!runner.running, "hidden runner stops animating");
                    avatar.moving = false;
                    avatar.hovered = false;
                    avatar.page = "";
                    test.check(!test.child(avatar, "nickFace").running, "hidden portrait stops animating");
                    test.check(styleCheck.finished, "all sixteen layout and edge combinations settled");
                    test.check(islandCheck.finished, "the island check ran to the end");
                    test.check(crewCheck.finished, "the crew check ran to the end");
                    test.check(m3Check.finished, "the M3 check ran to the end");
                    test.check(Tokens.hex(Tokens.surface) === Tokens.d.surface && Tokens.hex(Tokens.onAccent) === Tokens.d.onAccent, "tokens settle on the switched palette");
                    console.log("CAPSULE_TEST_PASS");
                    Qt.quit();
                }
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
                    const expectedMode = modes[Math.floor((step - 1) / 4)];
                    const expectedEdge = edges[(step - 1) % 4];
                    const island = expectedMode === "island";
                    test.check(Prefs.barMode === expectedMode, "layout preference settles: " + expectedMode);
                    test.check(Theme.controlRadius === 12 && Theme.panelRadius === 28, "controls stay rounded in every layout");
                    test.check(Theme.barExtent === (island ? 46 : expectedMode === "full" ? 40 : 56), "reservation matches layout geometry: " + expectedMode);
                    // The island always sits at the top and keeps the stored edge for later.
                    const shownEdge = island ? "top" : expectedEdge;
                    test.check(Prefs.edge === shownEdge && Prefs.storedEdge === expectedEdge
                        && Prefs.vertical === ["left", "right"].includes(shownEdge), "edge preference settles: " + expectedMode + "/" + expectedEdge);
                    test.check(Theme.barExtent >= Theme.barHeight, "reservation includes bar inset");
                    test.check(Theme.contrast(Theme.accent, Theme.accentText) >= Math.max(Theme.contrast(Theme.accent, Theme.bg), Theme.contrast(Theme.accent, Theme.fg)), "accent text uses the contrasting palette color");
                }
                if (step === 16) {
                    Prefs.setBarMode("invalid"); Prefs.setEdge("invalid");
                    test.check(Prefs.barMode === "island" && Prefs.edge === "top" && Prefs.storedEdge === "right", "invalid preferences are rejected");
                    Prefs.setBarMode("pill");
                    test.check(Prefs.edge === "right", "leaving the island restores the stored edge");
                    Prefs.setBarMode(oldMode); Prefs.setEdge(oldEdge);
                    finished = true; stop(); return;
                }
                Prefs.setBarMode(modes[Math.floor(step / 4)]);
                Prefs.setEdge(edges[step % 4]);
                step++;
            } catch (error) { console.error("CAPSULE_TEST_FAIL: " + error.message); Qt.quit(); }
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
                    test.check(v.restAnchor.width === 360 && v.restAnchor.x === 320, "the hand-off anchor is the rest pill");
                    test.check(NotificationState.resolveAnchor(v.monitor)?.item === v.restAnchor, "the notification center hangs from the rest pill");
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
                    test.check(v.open("cc") === "ok" && v.hudPage === "home" && v.islandState === "rest", "cc hands off to the old Hud home");
                    // IPC has no input serial for a popup grab: the Hud opens
                    // without one and the window's focus grab covers it.
                    test.check(!v.hud.grabFocus && v.hudNeedsGrab, "an IPC hand-off opens the Hud without its own grab");
                    test.check(v.hud.anchorItem === v.restAnchor && v.hud.alignment === "center" && v.hud.edge === "top", "the old Hud drops from the rest pill");
                    test.check(v.handedOff, "no hover while a hand-off shows");
                    v.pointerEntered();
                    test.check(!v.dwell.running, "the dwell waits for the hand-off to close");
                    test.check(v.toggle("cc") === "ok" && v.hudPage === "", "toggle closes the hand-off");
                    test.check(v.open("cal") === "ok" && v.hudPage === "" && v.islandState === "cal", "cal is the island's own state (M3)");
                    test.check(v.close() === "ok" && v.hudPage === "" && v.islandState === "rest", "close clears everything");
                    test.check(!v.hudNeedsGrab, "no focus grab once the hand-off closes");
                    // A click hand-off (the hover layer's calendar) keeps the popup grab.
                    test.check(v.handOff("cal", true) === "ok" && v.hud.grabFocus && !v.hudNeedsGrab, "a click hand-off keeps the Hud's own grab");
                    v.open("cc");
                    test.check(v.hudPage === "home" && v.hud.grabFocus, "a page change keeps the grab the Hud opened with");
                    v.close();
                    // The focus grab clearing closes an IPC-opened Hud.
                    v.open("cc");
                    v.dismiss();
                    test.check(v.hudPage === "" && !v.hudNeedsGrab, "an outside click closes an IPC-opened Hud");
                    test.check(v.open("power").startsWith("error") && v.open("power").includes("M6"), "unbuilt states say when they land");
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
                        const extent = mode === "full" ? 40 : 56;
                        const w = vertical ? extent : 1920, h = vertical ? 1080 : extent;
                        const ox = origin === "right" ? 1920 - w : 0;
                        const oy = origin === "bottom" ? 1080 - h : 0;
                        for (const [target, x, y] of [["top", 960, 5], ["bottom", 960, 1075], ["left", 5, 540], ["right", 1915, 540]]) {
                            test.check(BarGeometry.nearestEdge(origin, 1920, 1080, w, h, x - ox, y - oy) === target, "drag from " + mode + "/" + origin + " to " + target);
                        }
                    }
                }

                test.check(test.child(batteryMenu, "topUp80").text === "Top up to 80%", "battery has an 80% action");
                test.check(test.child(batteryMenu, "topUp100").text === "Charge to 100%", "battery has a full-charge action");
                const savedCare = Battery.care;
                Battery.care = { supported: false, target: 0, recovery: false };
                test.check(!test.child(batteryMenu, "topUp80").enabled && !test.child(batteryMenu, "topUp100").enabled, "unsupported battery controls are disabled");
                Battery.topUp(80);
                test.check(!Battery.busy, "unsupported battery action does not request authorization");
                Battery.care = { supported: true, mode: "Custom", start: 50, end: 80, target: 100, recovery: true };
                test.check(test.child(batteryMenu, "stopTopUp").text === "Restore battery care", "interrupted top-up exposes recovery");
                test.check(!test.child(batteryMenu, "topUp80").enabled, "active top-up disables duplicate requests");
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
                NotificationState.registerAnchor(notificationScreen, avatar, "right");
                test.check(NotificationState.resolveAnchor({name: "other-screen"}) === null, "notifications never use another monitor's anchor");
                NotificationState.toggleCenter(notificationScreen);
                test.check(NotificationState.centerAnchorItem === avatar && NotificationState.centerEdge === "right", "notifications use the registered bell and edge");
                NotificationState.registerAnchor(notificationScreen, flip, "left");
                NotificationState.unregisterAnchor(notificationScreen, avatar);
                test.check(NotificationState.centerAnchorItem === flip && NotificationState.centerEdge === "left", "replacing an anchor updates the open center safely");
                NotificationState.unregisterAnchor(notificationScreen, flip);
                test.check(!NotificationState.centerOpen && NotificationState.centerAnchorItem === null, "destroying the active bar closes its notification popup");

                test.check(avatar.costume === 0 && !avatar.fullBody, "resting avatar shows Nick's portrait");
                test.check(test.child(avatar, "nickFace").running, "visible portrait can blink");
                for (const [page, costume] of [["home", 2], ["audio", 2], ["net", 3], ["bt", 3], ["display", 3], ["tailscale", 3], ["theme", 4], ["clock", 5], ["unknown", 0]]) {
                    avatar.page = page;
                    avatar.hovered = true;
                    const portrait = test.child(avatar, "nickCostume");
                    test.check(avatar.costume === costume && !avatar.fullBody, "menu costume takes priority over hover: " + page);
                    test.check(portrait.status === Image.Ready && portrait.sourceClipRect.x === costume * 32, "costume atlas loads the correct cell: " + page);
                }
                for (const edge of ["top", "bottom", "left", "right"]) {
                        hud.edge = edge;
                        for (const alignment of ["start", "center", "end"]) {
                            hud.alignment = alignment;
                            const p = MenuAnchor.position(edge, alignment, 30, 28, 392, 300, 16, 8);
                            if (edge === "top") test.check(p.y + 16 - 28 === 8, "top opens down with visible 8px gap");
                            if (edge === "bottom") test.check(-p.y - 16 - 300 === 8, "bottom opens up with visible 8px gap");
                            if (edge === "left") test.check(p.x + 16 - 30 === 8, "left opens right with visible 8px gap");
                            if (edge === "right") test.check(-p.x - 16 - 392 === 8, "right opens left with visible 8px gap");
                            if (alignment === "center") test.check(["left", "right"].includes(edge) ? p.y + 16 === (28 - 300) / 2 : p.x + 16 === (30 - 392) / 2, "calendar centers on its own trigger");
                        }
                }
                avatar.page = "";
                test.check(avatar.fullBody && test.child(avatar, "nickGreeting").running, "hover starts the full-body animation");
                avatarFrames.target = test.child(avatar, "nickGreeting");

                test.check(Media.choosePlayer([], "") === null, "empty player list");
                test.check(Media.choosePlayer([paused, playing], "") === playing, "prefer playing app");
                test.check(Media.choosePlayer([paused, playing], "paused") === paused, "retain chosen app");
                test.check(Media.choosePlayer([playing], "paused") === playing, "removed player fallback");

                const mediaPage = test.child(hud.contentItem, "mediaPage");
                test.check(mediaPage !== null, "dedicated media popup exists");
                mediaPage.player = player;
                hud.page = "media";
                test.check(mediaPage.active && mediaPage.parent.children[mediaPage.parent.currentIndex] === mediaPage, "media route selects playback controls, not system home");
                const popupPlay = test.child(mediaPage, "playPause");
                popupPlay.click();
                test.check(player.isPlaying, "popup playback control works");
                popupPlay.click();
                hud.page = "";
                test.check(!mediaPage.active, "closed media popup stops polling");

                const play = test.child(card, "playPause");
                const next = test.child(card, "next");
                const previous = test.child(card, "previous");
                const seek = test.child(card, "seek");
                test.check(play && next && previous && seek, "media controls exist");
                play.click();
                test.check(player.isPlaying, "play invokes player");
                play.click();
                test.check(!player.isPlaying, "pause invokes player");
                next.click();
                previous.click();
                test.check(player.nextCalls === 1 && player.previousCalls === 1, "track controls invoke player");
                seek.moved(0.5);
                test.check(player.position === 120, "seek uses seconds");
                seek.moved(2);
                test.check(player.position === 240, "seek clamps at track length");
                player.canSeek = false;
                seek.moved(0);
                test.check(!seek.enabled && player.position === 240, "unsupported seeking is inert");
                player.canGoNext = false;
                next.click();
                test.check(!next.enabled && player.nextCalls === 1, "unsupported next is inert");
                test.check(card.formatTime(65) === "1:05", "timestamp formatting");

                // A label only turns over when it has a second face. The
                // battery's back is UPower's estimate, which is an empty string
                // until it has worked out a rate, and flipping to nothing would
                // read as the number vanishing under the pointer.
                flip.flipped = true;
                test.check(flip.turned, "a flip with both faces turns");
                flip.back = "";
                test.check(!flip.turned, "a flip with nothing to say stays put");
                flip.back = "Sat 5 Sep";
                flip.flipped = false;
                test.check(!flip.turned, "a flip at rest shows its front");

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
                // readings, driven directly so no compositor is needed. Not
                // named `home`: that is the HudHome instance a few lines down.
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
                test.check(card.implicitHeight < 200, "media card stays compact");
                test.check(home.implicitHeight < 420, "HUD overview stays compact");
                player.canSeek = true;
                player.lengthSupported = false;
                test.check(!seek.enabled, "unknown duration cannot seek");
                player.lengthSupported = true;
                player.length = 0;
                test.check(!seek.enabled, "zero-duration track cannot seek");

                test.check(innerShadow.radius === Theme.panelRadius && outerShadow.radius === samplePanel.radius, "shadows follow panel corners");
                test.check(innerShadow.width === samplePanel.width && outerShadow.x === samplePanel.x, "child and sibling shadows follow surface geometry");
                test.check(innerShadow.z < 0 && outerShadow.z === samplePanel.z, "shadows draw behind their surfaces without falling behind the scrim");
                test.check(innerShadow.opacity === 1 && outerShadow.opacity === samplePanel.opacity, "surface opacity is applied once");
                test.check(Theme.shadowPadding >= innerShadow.blur, "compact panels reserve the full shadow extent");
                const shadowColor = String(innerShadow.color);
                Theme.palette = { accent: "#a53b62", foreground: "#202020", background: "#f7f3e8", lighter_background: "#e8e0d0", mode: "light" };
                test.check(String(innerShadow.color) === shadowColor && String(samplePanel.color) === String(Theme.surface), "theme switches recolor surfaces without tinting shadows");
                test.check(String(play.background.color) === String(Theme.accent), "controls follow changed theme");
                test.check(String(card.color) === String(Theme.raised), "card follows changed theme");

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
                card.player = null;
                test.check(!play.enabled && !seek.enabled && !next.enabled, "no-player controls disabled");
                styleCheck.oldMode = Prefs.barMode;
                styleCheck.oldEdge = Prefs.storedEdge;
                styleCheck.start();
                islandCheck.start();
                crewCheck.start();
                m3Check.start();
                avatarCheck.start();
            } catch (error) {
                console.error("CAPSULE_TEST_FAIL: " + error.message);
                Qt.quit();
            }
        }
    }
}
