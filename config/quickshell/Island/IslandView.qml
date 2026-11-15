import Quickshell
import QtQuick
import qs
import qs.Kit
import "../lib/IslandMachine.js" as IslandMachine
import "../lib/CrewModel.js" as CrewModel
import "../lib/Dictation.js" as Dictation
import "../lib/CcData.js" as CcData
import "../launcher/ui" as LauncherUi
import qs.Panels

// IslandView.qml - everything inside one island window, minus the window.
//
// Island.qml is the PanelWindow (layer shell, mask, focus grab, Hyprland);
// this is the part that holds state and draws, as a plain Item so the offscreen
// check (tests/check.qml) can build it in a FloatingWindow: PanelWindow has no
// backend there.
//
// What it does:
//   - holds the machine record (lib/IslandMachine.js) and wires the pointer
//     and timers to it: a 250 ms dwell before hover opens (the Crew panel when
//     the pointer rests on the bots), a 150 ms grace on leave, the state's own
//     timer restarted on every go();
//   - opens the Crew's moments (M2): a hail when an agent starts needing you
//     (5 s peek, held while the pointer rests on it and closed when it leaves,
//     pinned only by a click, queued behind an open panel or hand-off until
//     the island is back at rest), and vibes when the last one is handled.
//     A hail raised under the pointer must not take the keyboard: only a
//     pinned panel gets the focus grab and keys.forceActiveFocus(), so typing
//     in the window under it carries on (M2 review);
//   - sizes the body to the state (rest hugs its content; the Crew panel is
//     at least as wide as the rest pill, so the bots that opened it stay
//     under it) and lays the state layers inside it;
//   - holds the bots and the working sparkle still while `ambient` is false
//     (Island.qml clears it while the session is idle), and tells Context
//     whether it is drawing the lane (its git poll runs only then);
//   - draws the island's own states (M3): the calendar; a notification
//     from the session's server (one at a time, newest first, the rest
//     queued; Do not disturb holds back all but critical ones; the pointer
//     coming to it pauses it and leaving runs it on; the server expires it
//     once no screen's island holds it, and a new island adopts what is
//     still up); the OSD on
//     every Interrupt message; dictation while the voxtype daemon listens or
//     transcribes (VoxtypeOsd stays hidden in island mode); a mode flash when
//     keep awake or Do not disturb changes; the live segment on the rest
//     pill (recording with its Stop, the mic, keep awake, DND) and the
//     Context lane. Which of them has the island is lib/IslandMachine.js
//     (polkit > open panel > dict > osd > notif > flash > live > rest), and
//     a transient that ends returns to what it interrupted;
//   - shows the launcher as its `launcher` state (M5): Launcher.qml hands it
//     the engine (showLauncher) when the palette opens on this screen in
//     island mode, the body morphs to the content's size (760 x 472, or a
//     picker's), and the window takes the keyboard while it is up. Leaving
//     the state any other way (an outside click, IPC close) tells Launcher.qml
//     (launcherLeft), which closes the palette;
//   - draws the control center (M6): the status pill and `island open cc`
//     open the `cc` state (Island/CcLayer.qml, 760 x 560), and
//     `island open cc/<sheet>` opens it on a sheet; the footer's Power opens
//     the power menu (`power`, Island/PowerLayer.qml, 600 x 156), which
//     Island.qml puts over a scrim;
//   - moves between the palette and the control center in place (the M5 and
//     M6 integration): the control center's Clipboard opens the palette's
//     clipboard scope through `paletteHost` (shell.qml's Launcher.qml), so the
//     island goes from cc straight to its launcher state, and the palette's
//     Open Control center goes from launcher straight to cc (Launcher.qml's
//     `island` effect). The launcher, cc and power cover a banner rather than
//     drop it (IslandMachine.cover): it shows again once they close;
//   - shows the theme and wallpaper pickers as its `themes` and `wallpapers`
//     states (M7): ThemePicker.qml hands it the picker's model (showPicker)
//     when the picker opens on this screen in island mode, and the body
//     morphs to the panel (1240 x 600, or 780 wide and as tall as the
//     theme's wallpapers), between the two on Tab. `island open themes`
//     and the control center's Theme mini go through ThemePicker
//     (pickerHost), so the IPC and the cc open it in place too. Leaving the
//     two states any other way tells ThemePicker (pickerLeft), which closes
//     the picker and ends its live preview;
//   - hands off to the old surfaces where the island has nothing yet (PLAN
//     1.7): the control center's battery opens the old Hud's battery page
//     (the charge-limit top-up), anchored under the rest pill, and the
//     notification center anchors to the rest pill. While one shows, nothing
//     opens on the island by itself: the OSD and flashes are dropped and
//     notifications wait.
//
// A hand-off from a click opens the Hud with its usual xdg_popup grab, which
// needs the click's input serial. One from IPC (`island open battery`, a
// keybind) has no serial, and Qt refuses a grabbing popup without one
// ("Failed to create grabbing popup"), so the IPC path opens it without the
// grab and Island.qml's HyprlandFocusGrab covers the Hud too (hudNeedsGrab):
// an outside click still closes it.
//
// Data in: monitor, workspaces (lib/WorkspaceOrder.js shown() records), crew
// (the Crew singleton, or any object with its agents, total, spendToday,
// stale, jump() and hailed/vibes signals; tests/check.qml passes a fake),
// notifications (NotificationServer.qml, or an object with its arrived
// signal, tracked, find, timeoutFor, shows, and hold, forget and
// remainingFor: who expires what), voice (the launcher's
// VoiceSession) and whatever IslandView reads itself through
// `Fixture.data.<x> ?? live`.
Item {
    id: view

    property var monitor: null
    property var workspaces: []
    property var crew: Crew
    // The session's notification server (shell.qml), or a fake; null for none.
    property var notifications: null
    // The launcher's VoiceSession, for the daemon's dictation; null for none.
    property var voice: null
    // shell.qml's Launcher (Launcher.qml), for the control center's Clipboard;
    // null for none, and then the Clipboard runs the `clipboard` IPC as
    // Super+V does.
    property var paletteHost: null
    // shell.qml's ThemePicker (M7), for `island open themes|wallpapers` and
    // the control center's Theme mini; null for none (an error, and the mini
    // runs `theme picker themes`).
    property var pickerHost: null
    // What raises the OSD: Interrupt, or a fake with its shown(kind) signal,
    // kind, fraction (tests/check.qml: the real one fires as PipeWire binds).
    property var interrupt: Interrupt
    // Stand-ins for the live segment's services and Context.lane (tests/check.qml),
    // in their drawn shapes; null reads the services.
    property var liveData: null
    property var laneData: null
    // The window's devicePixelRatio: the bots snap their pixels to it.
    property real dpr: 1
    // Ambient loops (the bots) run only while this holds: Island.qml clears it
    // after a minute without input, so a waiting agent does not keep the
    // island redrawing on an unattended screen.
    property bool ambient: true
    property date now: new Date()

    property var machine: IslandMachine.initial()
    readonly property string islandState: machine.state
    readonly property bool pinned: machine.pinned
    readonly property bool panelOpen: IslandMachine.panelOpen(machine)
    // The old Hud page showing in place of an unbuilt state, "" for none.
    property string hudPage: ""
    readonly property bool handedOff: hudPage !== "" || (NotificationState.centerOpen && NotificationState.centerAnchorItem === restAnchor)
    // A Hud opened from IPC, without its own popup grab: the window's focus
    // grab stands in, so an outside click still closes it.
    readonly property bool hudNeedsGrab: hudPage !== "" && !hud.grabFocus
    readonly property bool pointerInside: hoverer.hovered

    // The launcher's engine (launcher/Keystroke.qml) once this island has shown
    // the palette (showLauncher); the content reads and drives it.
    property var launcherEngine: null
    readonly property bool launcherShown: machine.state === "launcher" && launcherEngine !== null
    // The palette is up and wants the keys (the focus grab hands them over).
    readonly property bool launcherFocus: launcherShown && launcherEngine.opened === true
    // Whether this window has the keyboard (Qt's active window).
    readonly property bool windowActive: Window.active
    property string lastState: "rest"
    // Whether the last record was an open panel (IslandMachine.panelOpen).
    property bool lastPanel: false
    signal launcherLeft
    // The pickers (M7): ThemePicker's PickerModel once this island has shown
    // one (showPicker); the panels read and drive it.
    property var pickerModel: null
    readonly property bool pickerState: machine.state === "themes" || machine.state === "wallpapers"
    readonly property bool pickerShown: pickerState && pickerModel !== null
    signal pickerLeft
    // True for a moment after an open panel (the launcher, a picker, cc),
    // while the island still has the keyboard: Island.qml turns its keyboard
    // focus off and on again (keyboardRelease below).
    property bool keyboardDrop: false

    readonly property var crewAgents: view.crew?.agents ?? []
    // The agent the hail card shows, and one waiting for the island to be free.
    property string hailId: ""
    property string pendingHail: ""
    readonly property var hailAgent: CrewModel.hailTarget({ agents: view.crewAgents }, view.hailId)
    readonly property int hailOthers: Math.max(0, view.crewAgents.filter(a => a.attention).length - (view.hailAgent ? 1 : 0))

    // What the hugging states measure. The Crew panel and hover take the rest
    // pill's (IslandMachine.size keeps them at least 460 and 720).
    readonly property real hugWidth: machine.state === "hail" ? hailLayer.hugWidth : machine.state === "vibes" ? vibesLayer.hugWidth : machine.state === "flash" ? flashLayer.hugWidth : machine.state === "launcher" ? launcherLayer.hugWidth : machine.state === "themes" ? themesLayer.hugWidth : machine.state === "wallpapers" ? wallsLayer.hugWidth : restLayer.hugWidth
    readonly property real hugHeight: machine.state === "launcher" ? launcherLayer.hugHeight : machine.state === "themes" ? themesLayer.hugHeight : machine.state === "wallpapers" ? wallsLayer.hugHeight : crewLayer.hugHeight
    readonly property var targetSize: IslandMachine.size(machine, view.hugWidth, view.hugHeight)
    readonly property string clock: Fixture.data.clock ?? Qt.formatDateTime(view.now, "HH:mm")
    readonly property string date: Fixture.data.date ?? Qt.formatDateTime(view.now, "dddd, MMMM d")
    // The Context lane (Context.lane). A fixture's `context` is a lane object,
    // or a string drawn as text alone (the M2 fixtures).
    readonly property var lane: {
        const f = Fixture.data.context;
        const blank = { kind: "", icon: "", text: "", extra: "", working: false, who: "", where: "", detail: "" };
        if (typeof f === "string") return Object.assign(blank, { kind: f === "" ? "" : "other", text: f });
        if (f && typeof f === "object") return Object.assign(blank, f);
        if (view.laneData) return Object.assign(blank, view.laneData);
        return Context.lane;
    }
    readonly property string context: view.lane.text
    // Context's git poll runs only while an island draws the lane: rest or
    // hover, with the session awake (M3 review).
    readonly property bool drawsLane: view.ambient && (machine.state === "rest" || machine.state === "hover")
    onDrawsLaneChanged: Context.watch(view, drawsLane)
    // The live segment (island-modes 6): { recording, elapsed, mic, awake, awakeLeft, dnd }.
    // A fixture's `live` may give { recording: { elapsed: s } | bool, mic: [names],
    // awake: { minutes } | bool, dnd }.
    readonly property var live: {
        const f = Fixture.data.live;
        if (f && typeof f === "object") {
            const rec = f.recording;
            const awake = f.awake;
            return {
                recording: rec === true || (rec !== null && typeof rec === "object"),
                elapsed: Dictation.clock(1000 * (Number(rec?.elapsed) || 0)),
                mic: Array.isArray(f.mic) ? f.mic : [],
                awake: awake === true || (awake !== null && typeof awake === "object"),
                awakeLeft: Number(awake?.minutes) > 0 ? Math.round(Number(awake.minutes)) + "m" : "",
                dnd: f.dnd === true
            };
        }
        if (view.liveData) return Object.assign({ recording: false, elapsed: "", mic: [], awake: false, awakeLeft: "", dnd: false }, view.liveData);
        const names = [];
        for (const node of Audio.recorders) {
            const name = Audio.appFor(node);
            if (name && names.indexOf(name) < 0) names.push(name);
        }
        return {
            recording: Capture.recording,
            elapsed: Capture.startedAt > 0 ? Dictation.clock(view.now.getTime() - Capture.startedAt) : "",
            mic: names,
            awake: Caffeine.active,
            awakeLeft: Caffeine.active && Caffeine.endsAt > 0 ? Math.max(1, Math.ceil((Caffeine.endsAt - view.now.getTime()) / 60000)) + "m" : "",
            dnd: NotificationState.dnd
        };
    }
    // A screen recording or an app on the microphone (the Bar's privacy glyphs).
    readonly property bool privacy: view.live.recording || view.live.mic.length > 0
    readonly property var media: {
        if (Fixture.data.media !== undefined) return Fixture.data.media;
        const p = Media.player;
        return p ? {
            title: p.trackTitle || p.identity || "",
            artist: p.trackArtist || "",
            playing: p.isPlaying === true,
            canPrevious: p.canGoPrevious !== false,
            canNext: p.canGoNext !== false
        } : null;
    }
    readonly property var status: Fixture.data.status ?? ({
        wifi: Net.radioOn && Net.connected,
        bt: Bt.enabled,
        tailscale: Tailscale.running,
        muted: Audio.muted,
        battery: Battery.percent,
        charging: Battery.charging,
        low: Battery.low
    })
    readonly property string tagline: Fixture.data.tagline ?? Tokens.tagline
    // The calendar's today: the fixture's "2026-11-14", else now.
    readonly property date today: {
        const f = String(Fixture.data.today ?? "").match(/^(\d{4})-(\d{2})-(\d{2})$/);
        return f ? new Date(Number(f[1]), Number(f[2]) - 1, Number(f[3])) : view.now;
    }

    // ---- the island's own states' data (M3) ----
    // The OSD: Interrupt's message, or the fixture's { kind, value, muted }.
    readonly property var osd: Fixture.data.osd ?? ({
        kind: view.interrupt?.kind || "volume",
        value: view.interrupt?.fraction ?? 0,
        muted: view.interrupt?.kind === "mic" ? Audio.micMuted : Audio.muted
    })
    // Dictation: "" | "listening" | "transcribing" (lib/Dictation.js), or the
    // fixture's { phase, elapsed (s), levels }.
    readonly property string dictPhase: Fixture.data.dict ? (Fixture.data.dict.phase ?? "listening") : Dictation.phase(view.voice)
    property double dictStartedAt: 0
    onDictPhaseChanged: {
        if (dictPhase === "listening" && dictStartedAt === 0) dictStartedAt = Date.now();
        if (dictPhase === "") dictStartedAt = 0;
        view.reconcile();
    }
    readonly property string dictElapsed: Fixture.data.dict ? Dictation.clock(1000 * (Number(Fixture.data.dict.elapsed) || 0)) : dictStartedAt > 0 ? Dictation.clock(view.now.getTime() - dictStartedAt) : "0:00"
    readonly property var dictLevels: Fixture.data.dict ? (Fixture.data.dict.levels ?? []) : (view.voice?.history ?? [])
    // The flash: { mode, on, sub }, from the last change, or the fixture's.
    property var flashData: ({ mode: "awake", on: false, sub: "" })
    readonly property var flash: Fixture.data.flash ?? view.flashData
    // The notification showing: the server's, or a fixture's `notif`.
    readonly property var notification: {
        const id = machine.state === "notif" ? (machine.item?.id ?? null) : null;
        if (id === null) return null;
        if (id < 0) return Fixture.data.notif ?? null;
        return view.notifications?.find(id) ?? null;
    }

    readonly property alias body: body
    readonly property alias rest: restLayer
    readonly property alias hover: hoverLayer
    readonly property alias crewPanel: crewLayer
    readonly property alias hailCard: hailLayer
    readonly property alias vibesCard: vibesLayer
    readonly property alias calendar: calLayer
    readonly property alias notifCard: notifLayer
    readonly property alias osdCard: osdLayer
    readonly property alias dictCard: dictLayer
    readonly property alias flashCard: flashLayer
    readonly property alias launcherCard: launcherLayer
    readonly property alias ccPanel: ccLayer
    readonly property alias powerMenu: powerLayer
    readonly property alias themesPanel: themesLayer
    readonly property alias wallpapersPanel: wallsLayer
    readonly property alias restAnchor: restAnchor
    readonly property alias hud: hud
    readonly property alias dwell: dwellTimer
    readonly property alias grace: graceTimer

    // Where each not-yet-built state lands, for the IPC's error text.
    readonly property var arrives: ({ polkit: "M8" })
    // The power menu's commands (launcher/providers/System.qml's), and the
    // last one asked for (tests, the sandbox: under Fixture.dryRun nothing runs).
    readonly property var powerCommands: CcData.POWER_COMMANDS
    property string powerRan: ""
    // The power menu shows over the scrim (Island.qml).
    readonly property bool scrimShown: machine.state === "power"
    // From the power menu on until the island is back to something that is
    // not an open panel: the island stays on Overlay (Island.qml) and the
    // scrim stays mapped, clear (Scrim.held). A panel opened over the power
    // menu (the palette, cc) then holds the focus grab with no surface
    // unmapped or moved under it: unmapping the scrim there had Hyprland
    // refocus the window below and the keyboard left the island (sandbox,
    // power -> launcher). Top -> Overlay (rest or cc -> power) keeps the
    // keys; Overlay -> Top is left until the grab has ended.
    property bool raised: false

    signal workspaceActivated(string name)

    implicitHeight: IslandMachine.WINDOW_HEIGHT

    // ---- the machine ---------------------------------------------------------

    function apply(next) {
        if (next !== view.machine) view.machine = next;
    }
    // The notification ids the last record referred to (shown, interrupted,
    // waiting). The server hears each change (hold): one the machine lets go
    // of without its sender or the user closing it has run its course here,
    // and the server expires it (it stays in the history), as an expired
    // toast does, once no other screen's island still holds it.
    property var heldIds: []
    function holdNotifications(ids) {
        if (JSON.stringify(ids) === JSON.stringify(view.heldIds)) return;
        const gone = view.heldIds.filter(id => ids.indexOf(id) < 0);
        view.heldIds = ids;
        const server = view.notifications;
        if (server?.hold) {
            server.hold(view, ids.filter(id => id >= 0));
            return;
        }
        for (const id of gone) {
            const n = id >= 0 ? server?.find(id) : null;
            if (n) n.expire();
        }
    }
    onMachineChanged: {
        // A new record restarts the state's timer; a notification queueing
        // behind it (same seq) does not.
        if (stateTimer.seq !== machine.seq || machine.timer <= 0) {
            stateTimer.stop();
            stateTimer.seq = machine.seq;
            if (machine.timer > 0) {
                stateTimer.interval = machine.timer;
                stateTimer.startedAt = Date.now();
                stateTimer.start();
                // A new timer: the banner's bar starts again, from what it has left.
                if (machine.state === "notif") notifLayer.serial++;
            }
        }
        if (!IslandMachine.watchesLeave(machine)) graceTimer.stop();
        // Back to unpinned hover, a held hail or a paused notif with the
        // pointer gone (the state it interrupted ended elsewhere): the leave
        // grace closes or resumes it.
        else if (!view.pointerInside) graceTimer.restart();
        if (machine.state !== "hail") view.hailId = "";
        // From the record itself: the panelOpen binding may not have caught
        // up inside this handler. The launcher's query field takes it there;
        // the control center and the power menu take the keys themselves,
        // once their layers are current.
        if (machine.state === "launcher") Qt.callLater(view.focusLauncher);
        else if (machine.state === "themes" || machine.state === "wallpapers") Qt.callLater(view.focusPicker);
        else if (IslandMachine.panelOpen(machine)) {
            if (machine.state === "cc" || machine.state === "power") Qt.callLater(view.focusPanel);
            else keys.forceActiveFocus();
        }
        // The last record's state and panel, noted before the signals below,
        // whose handlers can change the record again.
        const was = view.lastState, wasPanel = view.lastPanel;
        view.lastState = machine.state;
        view.lastPanel = IslandMachine.panelOpen(machine);
        // A panel closed: the island lets go of the keyboard if Hyprland had
        // no window to give it back to (keyboardRelease). The launcher (M5
        // review), the pickers, cc and power alike (M7 review).
        if (wasPanel && !view.lastPanel) keyboardRelease.restart();
        if (was === "launcher" && machine.state !== "launcher") {
            launcherRelease.stop();
            view.launcherLeft();
        }
        // Tab between the two pickers stays inside them. From the record, as
        // above: the pickerState binding may lag here.
        if ((was === "themes" || was === "wallpapers") && machine.state !== "themes" && machine.state !== "wallpapers") view.pickerLeft();
        if (machine.state === "power") view.raised = true;
        else if (!IslandMachine.panelOpen(machine)) view.raised = false;
        if (machine.state === "rest" && view.pendingHail !== "") Qt.callLater(view.retryHail);
        view.holdNotifications(IslandMachine.notifIds(machine));
        Qt.callLater(view.reconcile);
    }
    // ms the state's timer has to run (the machine's own when none is running).
    function timerLeft(): int {
        return stateTimer.running ? Math.max(0, stateTimer.interval - (Date.now() - stateTimer.startedAt)) : machine.timer;
    }

    // The conditions outside the record (dictation, a hand-off covering the
    // island): IslandMachine.settle after every change.
    function reconcile() {
        const next = IslandMachine.settle(machine, { dict: view.dictPhase !== "", blocked: view.handedOff });
        // A notif that shows under a parked pointer runs its course: only the
        // pointer coming to it pauses it (pointerEntered).
        if (next !== machine) apply(next);
    }

    function pointerEntered() {
        graceTimer.stop();
        if (machine.state === "rest" && !handedOff) dwellTimer.restart();
        // A peeking hail holds while you read it (held, not pinned: no
        // keyboard); a notification pauses with what it has left. Not while
        // the body is still growing: then the banner opened under a parked
        // pointer (the hover came from the morph, not the hand), and it runs
        // its course.
        else if (machine.state === "hail") apply(IslandMachine.enter(machine));
        else if (machine.state === "notif" && !body.morphing) apply(IslandMachine.enter(machine, "", view.timerLeft()));
    }
    function pointerLeft() {
        dwellTimer.stop();
        if (IslandMachine.watchesLeave(machine)) graceTimer.restart();
    }
    // The dwell ran out with the pointer still inside: hover, or the Crew
    // panel when the pointer rests on the bots (DECISION 1).
    function dwelled(onCrew: bool) {
        if (!handedOff) apply(IslandMachine.enter(machine, onCrew ? "crew" : "hover"));
    }
    function clickPill() {
        dwellTimer.stop();
        hudPage = "";
        apply(IslandMachine.click(machine));
    }
    // A click on the bots: the Crew panel, pinned.
    function clickCrew() {
        dwellTimer.stop();
        hudPage = "";
        apply(IslandMachine.click(machine, "crew"));
    }

    // ---- the Crew's moments ------------------------------------------------------

    // An agent started needing you. It takes the island when nothing outranks
    // a hail (IslandMachine.offer); otherwise it waits for rest.
    function hail(id: string) {
        if (view.handedOff || !CrewModel.hailTarget({ agents: view.crewAgents }, id)) {
            if (view.handedOff) view.pendingHail = id;
            return;
        }
        const next = IslandMachine.offer(machine, "hail");
        if (next === machine) {
            view.pendingHail = id;
            return;
        }
        view.pendingHail = "";
        // Before the morph, so the card measures the right words.
        view.hailId = id;
        apply(next);
        // Raised under the pointer (it took unpinned hover or the Crew panel,
        // or the pointer sat where the card opened): no enter event will come,
        // so it holds now, and closes when the pointer leaves.
        if (view.pointerInside) apply(IslandMachine.enter(machine));
    }
    // A hand-off closing leaves the machine at rest without a change, so the
    // waiting hail is retried from here too, and waiting notifications shown.
    onHandedOffChanged: {
        if (!handedOff && pendingHail !== "") Qt.callLater(retryHail);
        if (!handedOff) Qt.callLater(reconcile);
    }
    function retryHail() {
        const id = view.pendingHail;
        if (id === "" || machine.state !== "rest" || view.handedOff) return;
        view.pendingHail = "";
        const target = CrewModel.hailTarget({ agents: view.crewAgents }, id);
        if (target) view.hail(target.id);
    }
    // The last hail handled: vibes, in place of a showing hail or from rest.
    function vibe() {
        if (view.handedOff) return;
        if (machine.state === "hail") {
            apply(IslandMachine.go(machine, "vibes"));
            return;
        }
        const next = IslandMachine.offer(machine, "vibes");
        if (next !== machine) apply(next);
    }
    // The feed moved on: a hail whose agent no longer needs you closes.
    function crewUpdated() {
        if (machine.state === "hail" && !CrewModel.hailTarget({ agents: view.crewAgents }, view.hailId)) apply(IslandMachine.dismiss(machine));
        if (view.pendingHail !== "" && !CrewModel.hailTarget({ agents: view.crewAgents }, view.pendingHail)) view.pendingHail = "";
    }
    // Go to pane / window: jump, and the hail or panel has done its job.
    function jumpTo(id: string): string {
        const result = view.crew?.jump ? view.crew.jump(id) : "error: no crew";
        if (!String(result).startsWith("error")) apply(IslandMachine.dismiss(machine));
        return result;
    }

    Connections {
        target: view.crew
        ignoreUnknownSignals: true
        function onHailed(agent) {
            if (agent) view.hail(agent.id);
        }
        function onVibes() {
            view.vibe();
        }
        function onAgentsChanged() {
            view.crewUpdated();
        }
    }
    // Outside click (the focus grab clearing) or Esc.
    function dismiss() {
        dwellTimer.stop();
        if (hudNeedsGrab) hudPage = "";
        apply(IslandMachine.dismiss(machine));
    }
    // Esc steps back one level: the calendar to hover (its back button), a
    // sheet to the control center, anything else to rest (island-modes 11).
    function stepBack() {
        if (machine.state === "cal") return backToHover();
        if (machine.state === "cc" && ccLayer.content.sheet !== "") return ccLayer.content.back();
        dismiss();
    }
    // The control center's keys: its sheet when one is open (`island open
    // cc/<sheet>` from rest opens the sheet before this runs), else home.
    function focusPanel() {
        if (machine.state === "cc") ccLayer.content.focusHome(!view.ccByPointer);
        else if (machine.state === "power") powerLayer.forceActiveFocus();
    }

    // ---- the control center and the power menu (M6) -------------------------

    // The control center, on `sheet` when one is named ("" for home); false
    // when there is no such sheet.
    // Opened from the status pill: no focus ring on the Wi-Fi disc.
    property bool ccByPointer: false
    function openCc(sheet: string, byPointer: bool): bool {
        view.ccByPointer = byPointer === true;
        dwellTimer.stop();
        graceTimer.stop();
        hudPage = "";
        NotificationState.closeCenter();
        if (machine.state !== "cc") apply(IslandMachine.cover(machine, "cc"));
        if (sheet === "") {
            if (ccLayer.content.sheet !== "") ccLayer.content.closeSheet(true);
            return true;
        }
        return ccLayer.openSheet(sheet, null, !view.ccByPointer);
    }
    function openPower() {
        dwellTimer.stop();
        graceTimer.stop();
        hudPage = "";
        apply(IslandMachine.cover(machine, "power"));
    }
    // The control center's Clipboard: the palette's clipboard scope on this
    // screen. Launcher.qml shows it here (showLauncher), from cc straight to
    // the launcher state.
    function openClipboard() {
        if (!view.paletteHost) return false;
        view.paletteHost.openScope(view.monitor, "clipboard", { title: "Clipboard History" });
        return true;
    }
    // A power item: back to rest, then its command (never under a dry run).
    function runPower(id: string): string {
        const argv = view.powerCommands[id];
        if (!argv) return "error: no power item " + id;
        view.powerRan = id;
        apply(IslandMachine.dismiss(machine));
        if (!Fixture.dryRun) Quickshell.execDetached(argv);
        return "ok";
    }
    // The calendar's back button: hover, pinned.
    function backToHover() {
        apply(IslandMachine.go(machine, "hover"));
    }

    // ---- the island's own transients (M3) ------------------------------------

    // A notification arrived at the server. Do not disturb keeps all but a
    // critical one off the island (the server still expires it on time).
    function notified(n) {
        if (!n || !view.notifications) return;
        if (view.notifications.shows && !view.notifications.shows(n)) return;
        const item = { id: n.id, timeout: view.notifications.timeoutFor ? view.notifications.timeoutFor(n) : IslandMachine.notifTimeout(n.expireTimeout, false) };
        // Raised under a parked pointer it runs its course (M3 review): no
        // enter event came, and holding it there would keep it up until the
        // pointer moved.
        apply(view.handedOff ? IslandMachine.enqueue(machine, item) : IslandMachine.notify(machine, item));
    }
    // A new island takes up what is still up that it never heard arrive
    // (it came in a classic mode, or while the islands were being rebuilt),
    // for the rest of its time, a critical one until handled.
    // They queue, oldest first, and reconcile shows the newest (settle) once
    // nothing outranks a notif.
    function adopt() {
        const server = view.notifications;
        if (!server?.remainingFor) return;
        let next = machine;
        for (const n of server.tracked ?? []) {
            if (IslandMachine.notifIds(next).indexOf(n.id) >= 0 || (server.shows && !server.shows(n))) continue;
            const full = server.timeoutFor(n);
            const left = server.remainingFor(n);
            if (full > 0 && left < IslandMachine.RESUME_MIN) continue;
            next = IslandMachine.enqueue(next, { id: n.id, timeout: full > 0 ? left : 0 });
        }
        apply(next);
    }
    onNotificationsChanged: Qt.callLater(adopt)
    // The server's list changed: any notification it no longer tracks (its
    // sender closed it, or the center dismissed it) leaves the island.
    function serverListChanged() {
        const tracked = (view.notifications?.tracked ?? []).map(n => n.id);
        let next = machine;
        for (const id of IslandMachine.notifIds(machine))
            if (id >= 0 && tracked.indexOf(id) < 0) next = IslandMachine.drop(next, id);
        apply(next);
    }
    // The card's Open: focus the sender and invoke its default action
    // (NotificationState.open dismisses it); then the next one, or back.
    function openNotification() {
        const id = machine.item?.id ?? null;
        const n = view.notification;
        if (n && id >= 0) NotificationState.open(n);
        apply(id === null ? machine : id >= 0 ? IslandMachine.drop(machine, id) : IslandMachine.finish(machine));
    }
    function dismissNotification() {
        const id = machine.item?.id ?? null;
        const n = view.notification;
        if (n && id >= 0) n.dismiss();
        apply(id === null ? machine : id >= 0 ? IslandMachine.drop(machine, id) : IslandMachine.finish(machine));
    }

    // Every Interrupt message (volume, brightness, mic): the OSD, its 1400 ms
    // restarted. Dropped behind a hand-off or anything that outranks it.
    function osdShown() {
        if (view.handedOff) return;
        const next = IslandMachine.offer(machine, "osd");
        if (next !== machine) apply(next);
    }

    // Keep awake or Do not disturb changed: a flash, unless something
    // outranks it. Not in the first 2 s (Prefs and the services settling).
    property bool flashArmed: false
    Timer {
        interval: 2000
        running: true
        onTriggered: view.flashArmed = true
    }
    function flashMode(mode: string, on: bool, sub: string) {
        view.flashData = { mode: mode, on: on, sub: sub };
        if (!view.flashArmed || view.handedOff) return;
        const next = IslandMachine.offer(machine, "flash");
        if (next !== machine) apply(next);
    }
    function awakeChanged() {
        const sub = !Caffeine.active ? "Off" : Caffeine.endsAt > 0 ? "On for " + Caffeine.durationLabel(Caffeine.selectedMinutes) : "On until turned off";
        view.flashMode("awake", Caffeine.active, sub);
    }

    // Dictation's Stop: through Hyprland (media-keys.lua's
    // voxtype_copilot_stop), so a latched Copilot session's latch resets
    // with it and the next Copilot press starts dictating (M3 review). When
    // that config is not loaded, hyprctl answers something other than "ok"
    // and the daemon's own stop runs. The sandbox and a fixture have no daemon.
    readonly property string copilotStop: "(function() voxtype_copilot_stop() return hl.dsp.no_op() end)()"
    function stopDictation() {
        if (Fixture.data.dict || !view.voice || Fixture.sandbox) return;
        Quickshell.execDetached(["sh", "-c", 'out=$(hyprctl dispatch "$1" 2>&1); [ "$out" = ok ] || exec "$2" record stop', "stop", view.copilotStop, view.voice.command || "voxtype"]);
    }
    function stopRecording() {
        if (!Fixture.data.live && !Fixture.sandbox) Capture.stop();
    }

    // The hover's Context line: the window it describes, then rest.
    function openContext() {
        if (!Fixture.data.context) Context.toplevel?.activate();
        apply(IslandMachine.dismiss(machine));
    }
    function mediaAction(action: string) {
        if (Fixture.data.media !== undefined) return;
        const p = Media.player;
        if (!p) return;
        if (action === "previous") p.previous();
        else if (action === "next") p.next();
        else p.togglePlaying();
    }

    // `island hold` (the sandbox): the state stays up for a shot.
    function hold(): string {
        apply(IslandMachine.freeze(machine));
        return "ok";
    }

    Connections {
        target: view.notifications
        ignoreUnknownSignals: true
        function onArrived(notification) {
            view.notified(notification);
        }
        function onTrackedChanged() {
            view.serverListChanged();
        }
    }
    Connections {
        target: view.interrupt
        ignoreUnknownSignals: true
        function onShown(which) {
            view.osdShown();
        }
    }
    Connections {
        target: Caffeine
        function onActiveChanged() {
            view.awakeChanged();
        }
    }
    Connections {
        target: NotificationState
        function onDndChanged() {
            view.flashMode("dnd", NotificationState.dnd, NotificationState.dnd ? "On" : "Off");
        }
    }
    // A letter clicked or wheeled: the dwell is over, so hover does not open
    // on top of the letters just used. Only a fresh pointer entry re-arms it.
    function workspaceUsed(name: string) {
        dwellTimer.stop();
        view.workspaceActivated(name);
    }

    // The IPC's verbs. Each returns "ok" or a line starting "error".
    function open(state: string): string {
        dwellTimer.stop();
        graceTimer.stop();
        if (state === "rest") return close();
        if (state === "hover") {
            hudPage = "";
            apply(IslandMachine.go(machine, "hover"));
            return "ok";
        }
        if (state === "cc" || state.startsWith("cc/")) {
            const sheet = state.slice(3);
            if (sheet !== "" && CcData.sheetName(sheet) === "") return "error: no sheet \"" + sheet + "\" (sheets: " + CcData.SHEETS.filter(n => n !== "tray").join(" ") + ")";
            return openCc(sheet, false) ? "ok" : "error: the " + sheet + " sheet could not load";
        }
        if (state === "power") {
            openPower();
            return "ok";
        }
        // The old Hud's battery page (the charge limit), the one hand-off left.
        if (state === "battery") return handOff("battery", false);
        if (state === "cal") {
            hudPage = "";
            apply(IslandMachine.go(machine, "cal"));
            return "ok";
        }
        if (state === "osd" || state === "flash") {
            hudPage = "";
            apply(IslandMachine.go(machine, state));
            return "ok";
        }
        if (state === "dict") {
            if (view.dictPhase === "") return "error: no dictation running (the Copilot key starts one)";
            hudPage = "";
            apply(IslandMachine.go(machine, "dict"));
            return "ok";
        }
        if (state === "notif") {
            // A fixture's `notif`, else the newest waiting notification.
            const q = machine.queue ?? [];
            const item = Fixture.data.notif ? { id: -1, timeout: IslandMachine.notifTimeout(Fixture.data.notif.expireTimeout ?? -1, Fixture.data.notif.critical === true) } : q[q.length - 1];
            if (!item) return "error: no notification waiting (try notify-send)";
            hudPage = "";
            const base = IslandMachine.drop(IslandMachine.go(machine, "rest"), item.id);
            apply(IslandMachine.notify(base, item));
            return "ok";
        }
        if (state === "crew") {
            hudPage = "";
            apply(IslandMachine.go(machine, "crew"));
            return "ok";
        }
        if (state === "hail") {
            const target = CrewModel.hailTarget({ agents: view.crewAgents }, "");
            if (!target) return "error: no agent needs you";
            hudPage = "";
            view.hailId = target.id;
            apply(IslandMachine.go(machine, "hail"));
            return "ok";
        }
        if (state === "vibes") {
            hudPage = "";
            apply(IslandMachine.go(machine, "vibes"));
            return "ok";
        }
        if (state === "launcher") return "error: the launcher opens through Launcher.qml (`qs ipc call launcher open`, or `island open launcher`)";
        // The pickers open through ThemePicker, which hands them back here.
        if (state === "themes" || state === "wallpapers") {
            if (!view.pickerHost) return "error: no theme picker";
            view.pickerHost.openOn(view.monitor, state);
            return "ok";
        }
        if (!IslandMachine.isState(state)) return "error: unknown island state \"" + state + "\" (states: " + IslandMachine.STATES.join(" ") + ")";
        return "error: the " + state + " state arrives in " + (arrives[state] ?? "a later milestone");
    }
    function close(): string {
        dwellTimer.stop();
        graceTimer.stop();
        hudPage = "";
        apply(IslandMachine.go(machine, "rest"));
        return "ok";
    }
    // The palette opened on this screen in island mode (Launcher.qml): the
    // island becomes it. Called again for a palette that reopens before the
    // last close finished. A banner it covers waits on the queue and shows
    // again when the palette closes (IslandMachine.cover).
    function showLauncher(engine): string {
        dwellTimer.stop();
        graceTimer.stop();
        launcherRelease.stop();
        keyboardRelease.stop();
        hudPage = "";
        NotificationState.closeCenter();
        view.launcherEngine = engine;
        if (machine.state !== "launcher") apply(IslandMachine.cover(machine, "launcher"));
        else view.focusLauncher();
        return "ok";
    }
    // The palette closed: back to rest once the activated row's flash has
    // peaked (`delay` ms), so a launch still reads as "that row".
    function releaseLauncher(delay: int) {
        if (machine.state !== "launcher") return;
        if (delay > 0) {
            launcherRelease.interval = delay;
            launcherRelease.restart();
        } else
            apply(IslandMachine.dismiss(machine));
    }
    // The picker opened on this screen in island mode (ThemePicker.qml): the
    // island becomes the `themes` or `wallpapers` state, in place from
    // whatever it showed (a banner it covers waits on the queue, as under the
    // launcher). Called again on Tab, and for a picker that reopens.
    function showPicker(model, state: string): string {
        if (state !== "themes" && state !== "wallpapers") return "error: no picker state \"" + state + "\"";
        // A closed model would leave the state up with nothing to close it.
        if (!model || model.opened !== true) return "error: the picker is closed";
        dwellTimer.stop();
        graceTimer.stop();
        keyboardRelease.stop();
        hudPage = "";
        NotificationState.closeCenter();
        view.pickerModel = model;
        if (machine.state !== state) apply(IslandMachine.cover(machine, state));
        else view.focusPicker();
        return "ok";
    }
    // The picker closed: back to rest, unless the island has already left
    // the picker states (the palette, cc or the calendar opening over it is
    // what closed it). From the record: inside onMachineChanged, where
    // pickerLeft brings this round, the pickerState binding can still say
    // themes, and dismissing then closed the palette or cc too (M7 review).
    function releasePicker() {
        if (machine.state === "themes" || machine.state === "wallpapers") apply(IslandMachine.dismiss(machine));
    }
    function focusPicker() {
        const c = machine.state === "themes" ? themesLayer.content : machine.state === "wallpapers" ? wallsLayer.content : null;
        if (c && view.pickerShown) c.forceActiveFocus();
    }
    // The control center's Theme mini: the themes picker on this screen, in
    // place (ThemePicker hands it back through showPicker).
    function openThemes(): bool {
        if (!view.pickerHost) return false;
        view.pickerHost.openOn(view.monitor, "themes");
        return true;
    }
    function focusLauncher() {
        if (view.launcherShown && view.launcherEngine.opened) view.launcherEngine.focusInput();
    }
    function isOpen(state: string): bool {
        if (state.startsWith("cc/")) return machine.state === "cc" && ccLayer.content.sheet === CcData.sheetName(state.slice(3));
        if (state === "battery") return hudPage === "battery";
        return machine.state === state;
    }
    function toggle(state: string): string {
        return isOpen(state) && state !== "rest" ? close() : open(state);
    }
    // An old Hud page, for what the island has no state for yet: back to
    // rest, and the old menu drops from the rest pill. The control center's
    // battery opens "battery" (the charge-limit top-up); "cal" maps to the
    // clock page and "cc" to the old home (kept for M4's classic hosts).
    // `clicked` says whether a pointer press led here: only then can the Hud
    // take its own popup grab. A Hud already showing just changes page and
    // keeps the grab it opened with.
    function handOff(state: string, clicked: bool): string {
        apply(IslandMachine.go(machine, "rest"));
        NotificationState.closeCenter();
        if (hudPage === "") hud.grabFocus = clicked;
        hudPage = state === "cal" ? "clock" : state === "cc" ? "home" : state;
        return "ok";
    }

    function inspect() {
        return {
            screen: view.monitor?.name ?? "",
            state: machine.state,
            pinned: machine.pinned,
            held: machine.held === true,
            panelOpen: view.panelOpen,
            hud: view.hudPage,
            launcher: { shown: view.launcherShown, focus: view.launcherFocus, windowActive: view.windowActive, loaded: launcherLayer.content !== null,
                fieldFocus: launcherLayer.content ? launcherLayer.content.fieldItem.activeFocus : false },
            hudShown: view.hud.visible,
            hudGrab: view.hud.grabFocus,
            target: { width: targetSize[0], height: targetSize[1], radius: body.targetRadius },
            body: { x: body.x, y: body.y, width: body.width, height: body.height, radius: body.radius },
            workspaces: (view.workspaces || []).map(w => w.name),
            focused: restLayer.strip.focusedName,
            shape: restLayer.strip.shapeName,
            item: machine.item ?? null,
            queue: (machine.queue ?? []).map(i => i.id),
            back: machine.back?.state ?? "",
            // The control center (M6): its sheet, how far the sheet is from
            // home (760 out, 0 in) and its last press; the power menu's pick.
            cc: {
                sheet: ccLayer.content.sheet,
                sheetOffset: ccLayer.content.sheetOffset,
                last: ccLayer.model.last,
                dryRun: ccLayer.model.dryRun,
                // The item holding the keys, by objectName ("" for none or
                // an unnamed one): sandbox key runs walk to a mini by it.
                focus: view.Window.activeFocusItem?.objectName ?? ""
            },
            power: { selected: powerLayer.selectedId, ran: view.powerRan, scrim: view.scrimShown, raised: view.raised },
            // The pickers (M7): the model's kind, focus and filter, whether a
            // panel has the keys, and the preview on screen.
            picker: {
                shown: view.pickerShown,
                kind: view.pickerModel ? view.pickerModel.kind : "",
                focused: view.pickerModel?.focused?.name ?? "",
                index: view.pickerModel ? view.pickerModel.index : -1,
                filter: view.pickerModel ? view.pickerModel.filter : "",
                rows: view.pickerModel ? view.pickerModel.rows.length : 0,
                focus: (themesLayer.content?.activeFocus ?? false) || (wallsLayer.content?.activeFocus ?? false),
                preview: Tokens.previewPalette?.name ?? "",
                surface: Tokens.hex(Tokens.surface)
            },
            lane: view.lane,
            live: view.live,
            // Where the measured parts sit, logical px in the view.
            parts: view.parts(),
            crew: {
                // The strip's top-left in the view, logical px (the sandbox
                // shots measure the bots from it).
                strip: (() => {
                        const p = restLayer.crewStrip.mapToItem(view, 0, 0);
                        return { x: p.x, y: p.y, width: restLayer.crewStrip.width };
                    })(),
                bots: restLayer.crewStrip.ids,
                more: restLayer.crewStrip.more,
                stale: restLayer.crewStrip.stale,
                rows: crewLayer.ids,
                // The bots move on one clock per group: its step (ms, 0 still) and whether it ticks.
                clock: { step: restLayer.crewStrip.clock.step, ticking: restLayer.crewStrip.clock.ticking },
                ambient: view.ambient,
                selected: crewLayer.selected,
                hail: view.machine.state === "hail" ? (view.hailAgent?.id ?? "") : "",
                pendingHail: view.pendingHail
            }
        };
    }

    // Item -> { x, y, width, height } in the view, or null when hidden.
    function box(item) {
        if (!item || !item.visible) return null;
        const p = item.mapToItem(view, 0, 0);
        return { x: Math.round(p.x * 100) / 100, y: Math.round(p.y * 100) / 100, width: item.width, height: item.height };
    }
    function parts() {
        const todayIndex = calLayer.cells.findIndex(c => c.today);
        const cell = todayIndex >= 0 ? calLayer.grid.children[todayIndex] : null;
        return {
            segment: box(restLayer.segment),
            dot: box(restLayer.segment.dot),
            micIcon: box(restLayer.segment.micIcon),
            micLabel: box(restLayer.segment.micLabel),
            awakeIcon: box(restLayer.segment.awakeIcon),
            awakeLabel: box(restLayer.segment.awakeLabel),
            lane: box(restLayer.laneRow),
            tagline: box(hoverLayer.taglineText),
            today: cell ? box(cell) : null,
            osdTrack: box(osdLayer.track),
            osdFill: box(osdLayer.fill),
            dictStop: box(dictLayer.stopButton),
            notifProgress: box(notifLayer.progress),
            launcher: box(launcherLayer),
            launcherList: launcherLayer.content ? box(launcherLayer.content.listItem) : null,
            launcherCard: launcherLayer.content ? box(launcherLayer.content.cardItem) : null,
            launcherRow: launcherLayer.content ? box(launcherLayer.content.selectedRow) : null,
            cc: box(ccLayer),
            ccTile: box(ccLayer.content.tiles.itemAt(0)),
            ccDisc: box(ccLayer.content.tiles.itemAt(0)?.disc ?? null),
            ccMedia: box(ccLayer.content.media),
            ccPlay: box(ccLayer.content.media.playButton),
            ccLevels: box(ccLayer.content.levels),
            ccMini: box(ccLayer.content.minis.itemAt(0)),
            ccNotes: box(ccLayer.content.notes),
            ccFooter: box(ccLayer.content.footer),
            ccPower: box(ccLayer.content.powerButton),
            ccSheet: box(ccLayer.content.sheetItem),
            power: box(powerLayer),
            themes: box(themesLayer),
            themesGrid: themesLayer.content ? box(themesLayer.content.grid) : null,
            themesCard: themesLayer.content ? box(themesLayer.content.focusedCard) : null,
            themesFilter: themesLayer.content ? box(themesLayer.content.filterPill) : null,
            wallpapers: box(wallsLayer),
            wallpapersGrid: wallsLayer.content ? box(wallsLayer.content.grid) : null,
            wallpapersCard: wallsLayer.content ? box(wallsLayer.content.focusedCard) : null,
            powerItem: box(powerLayer.repeater.itemAt(0)),
            powerHint: box(powerLayer.hint)
        };
    }

    // ---- timers ----------------------------------------------------------------

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: view.now = new Date()
    }
    Timer {
        id: dwellTimer
        interval: IslandMachine.DWELL
        onTriggered: if (view.pointerInside) view.dwelled(restLayer.crewHovered)
    }
    Timer {
        id: graceTimer
        interval: IslandMachine.LEAVE_GRACE
        onTriggered: if (!view.pointerInside) view.apply(IslandMachine.leave(view.machine))
    }
    Timer {
        id: launcherRelease
        onTriggered: if (view.machine.state === "launcher" && !(view.launcherEngine?.opened)) view.apply(IslandMachine.dismiss(view.machine))
    }
    // A panel (the palette, a picker, cc, power) closed and Hyprland had no
    // window to give the keyboard back to (nothing had focus when it opened):
    // the island, OnDemand, keeps it, and the next window to map is not
    // focused, so an app launched from an empty workspace got no keys (M5
    // review; the pickers and cc in the M7 review). Once the focus grab has ended,
    // drop it: keyboard focus None for a moment, then OnDemand again. Never
    // while a panel holds the grab (changing keyboardFocus then remaps the
    // surface and ends the grab).
    Timer {
        id: keyboardRelease
        interval: 150
        onTriggered: {
            if (!view.windowActive || IslandMachine.panelOpen(view.machine) || view.hudPage !== "") return;
            view.keyboardDrop = true;
            keyboardRestore.restart();
        }
    }
    Timer {
        id: keyboardRestore
        interval: 100
        onTriggered: view.keyboardDrop = false
    }
    Timer {
        id: stateTimer
        property int seq: 0
        // When it last started (ms since the epoch), for timerLeft().
        property double startedAt: 0
        onTriggered: view.apply(IslandMachine.expire(view.machine, seq))
    }

    // Esc closes an open panel. Focus lands here when one opens; the window
    // only has the keyboard once it is clicked (OnDemand).
    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: view.stepBack()
        // The Crew panel: Up and Down move the selection, Enter jumps.
        // The hail card: Enter is Go, once a click has pinned it (a key left
        // over from an earlier panel must not jump from a hail that opened by
        // itself).
        Keys.onUpPressed: if (view.machine.state === "crew") crewLayer.move(-1)
        Keys.onDownPressed: if (view.machine.state === "crew") crewLayer.move(1)
        Keys.onReturnPressed: {
            if (view.machine.state === "crew") crewLayer.activate();
            else if (view.machine.state === "hail" && view.machine.pinned && view.hailAgent) view.jumpTo(view.hailAgent.id);
        }
    }

    // ---- the island --------------------------------------------------------------

    IslandBody {
        id: body
        x: Math.round((view.width - width) / 2)
        y: IslandMachine.TOP_INSET
        targetWidth: view.targetSize[0]
        targetHeight: view.targetSize[1]
        Accessible.role: Accessible.Grouping
        Accessible.name: "Island"

        HoverHandler {
            id: hoverer
            onHoveredChanged: hovered ? view.pointerEntered() : view.pointerLeft()
        }

        RestLayer {
            id: restLayer
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            current: view.machine.state === "rest"
            workspaces: view.workspaces
            clock: view.clock
            lane: view.lane
            live: view.live
            crew: view.crewAgents
            crewStale: view.crew?.stale === true
            dpr: view.dpr
            crewAnimated: view.ambient
            // Idle never holds it (a privacy signal); a shot's `still` does.
            dotAnimated: Fixture.data.still !== true
            onPin: view.clickPill()
            onPinCrew: view.clickCrew()
            onStopRecording: view.stopRecording()
            onWorkspaceActivated: name => view.workspaceUsed(name)
        }

        HoverLayer {
            id: hoverLayer
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            // 720, or the rest pill's width when that is wider.
            width: IslandMachine.size({ state: "hover" }, restLayer.hugWidth)[0]
            current: view.machine.state === "hover"
            clock: view.clock
            date: view.date
            media: view.media
            status: view.status
            lane: view.lane
            tagline: view.tagline
            animated: view.ambient
            onPin: view.clickPill()
            onOpenCalendar: view.apply(IslandMachine.go(view.machine, "cal"))
            onOpenControlCenter: view.openCc("", true)
            onOpenContext: view.openContext()
            onPrevious: view.mediaAction("previous")
            onTogglePlaying: view.mediaAction("toggle")
            onNext: view.mediaAction("next")
        }

        CalendarLayer {
            id: calLayer
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            current: view.machine.state === "cal"
            today: view.today
            onBack: view.backToHover()
        }

        NotifLayer {
            id: notifLayer
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            current: view.machine.state === "notif"
            notification: view.notification
            timeout: view.machine.item?.timeout ?? 0
            running: view.machine.state === "notif" && view.machine.timer > 0
            timeLeft: view.machine.timer > 0 ? view.machine.timer : (view.machine.left ?? 0)
            onOpen: view.openNotification()
            onDismiss: view.dismissNotification()
        }

        OsdLayer {
            id: osdLayer
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            current: view.machine.state === "osd"
            kind: view.osd.kind ?? "volume"
            value: Number(view.osd.value) || 0
            muted: view.osd.muted === true
        }

        DictLayer {
            id: dictLayer
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            current: view.machine.state === "dict"
            phase: view.dictPhase !== "" ? view.dictPhase : "listening"
            elapsed: view.dictElapsed
            levels: view.dictLevels
            animated: view.ambient
            onStop: view.stopDictation()
        }

        FlashLayer {
            id: flashLayer
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            current: view.machine.state === "flash"
            mode: view.flash.mode ?? "awake"
            isOn: view.flash.on === true
            sub: view.flash.sub ?? ""
        }

        CrewPanel {
            id: crewLayer
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            current: view.machine.state === "crew"
            agents: view.crewAgents
            total: view.crew?.total ?? 0
            spendToday: view.crew?.spendToday ?? null
            dpr: view.dpr
            restWidth: restLayer.width
            animated: view.ambient
            onPin: view.clickPill()
            onJump: id => view.jumpTo(id)
        }

        HailCard {
            id: hailLayer
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            current: view.machine.state === "hail"
            agent: view.hailAgent
            others: view.hailOthers
            dpr: view.dpr
            animated: view.ambient
            onPin: view.clickPill()
            onGo: if (view.hailAgent) view.jumpTo(view.hailAgent.id)
        }

        VibesCard {
            id: vibesLayer
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            current: view.machine.state === "vibes"
            dpr: view.dpr
            animated: view.ambient
        }

        // The launcher (M5): launcher/ui/LauncherContent.qml, no background of
        // its own (the body is the material), at its own size. Built while the
        // state is up or fading out; it takes the engine only while current.
        Layer {
            id: launcherLayer
            readonly property var content: launcherLoader.item
            readonly property real hugWidth: content ? content.implicitWidth : 0
            readonly property real hugHeight: content ? content.implicitHeight : 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: content ? content.implicitWidth : 760
            height: content ? content.implicitHeight : 472
            current: view.launcherShown

            Loader {
                id: launcherLoader
                anchors.fill: parent
                active: view.launcherEngine !== null && (launcherLayer.current || launcherLayer.visible)
                sourceComponent: LauncherUi.LauncherContent {
                    engine: view.launcherEngine
                    active: launcherLayer.current
                }
            }
        }

        CcLayer {
            id: ccLayer
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            current: view.machine.state === "cc"
            monitor: view.monitor
            animated: view.ambient
            onClose: view.dismiss()
            onPower: view.openPower()
            onHandOff: page => view.handOff(page, true)
            openClipboard: view.paletteHost ? view.openClipboard : null
            openThemes: view.pickerHost ? view.openThemes : null
        }

        // The theme and wallpaper pickers (M7): Panels/ThemesPanel.qml and
        // Panels/WallpapersPanel.qml over ThemePicker's model, no background
        // of their own, at their own size. Built while the state is up or
        // fading out, so a closed picker costs the island nothing.
        Layer {
            id: themesLayer
            readonly property var content: themesLoader.item
            readonly property real hugWidth: content ? content.implicitWidth : 0
            readonly property real hugHeight: content ? content.implicitHeight : 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: content ? content.implicitWidth : 1240
            height: content ? content.implicitHeight : 600
            current: view.pickerShown && view.machine.state === "themes"

            Loader {
                id: themesLoader
                anchors.fill: parent
                active: view.pickerModel !== null && (themesLayer.current || themesLayer.visible)
                sourceComponent: ThemesPanel {
                    picker: view.pickerModel
                    active: themesLayer.current
                    dpr: view.dpr
                    availableWidth: view.width
                }
                onLoaded: if (themesLayer.current) Qt.callLater(view.focusPicker)
            }
        }
        Layer {
            id: wallsLayer
            readonly property var content: wallsLoader.item
            readonly property real hugWidth: content ? content.implicitWidth : 0
            readonly property real hugHeight: content ? content.implicitHeight : 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: 780
            height: content ? content.implicitHeight : 444
            current: view.pickerShown && view.machine.state === "wallpapers"

            Loader {
                id: wallsLoader
                anchors.fill: parent
                active: view.pickerModel !== null && (wallsLayer.current || wallsLayer.visible)
                sourceComponent: WallpapersPanel {
                    picker: view.pickerModel
                    active: wallsLayer.current
                    dpr: view.dpr
                }
                onLoaded: if (wallsLayer.current) Qt.callLater(view.focusPicker)
            }
        }

        PowerLayer {
            id: powerLayer
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            current: view.machine.state === "power"
            onRun: id => view.runPower(id)
            onCancel: view.dismiss()
        }
    }

    // The rest pill's place, whatever the body is doing: what the old menus,
    // the Interrupt popup and the notification center hang from.
    Item {
        id: restAnchor
        x: Math.round((view.width - width) / 2)
        y: IslandMachine.TOP_INSET
        width: restLayer.hugWidth
        height: IslandMachine.REST_HEIGHT
    }

    // ---- hand-offs to the old surfaces (PLAN 1.7) ----------------------------------

    Hud {
        id: hud
        anchorItem: restAnchor
        alignment: "center"
        edge: "top"
        monitor: view.monitor ?? ({ width: 1920, height: 1200 })
        now: view.now
        page: view.hudPage
        pickerHost: view.pickerHost
        // The battery page's "Back to controls" is the control center now,
        // not the old Hud home (M6 review).
        onNavigate: page => {
            if (page === "home") view.openCc("", true);
            else view.hudPage = page;
        }
        onDismissed: view.hudPage = ""
        // grabFocus is set by handOff() each time the Hud opens.
    }

    function registerBell() {
        if (view.monitor) NotificationState.registerAnchor(view.monitor, restAnchor, "top");
    }
    Component.onCompleted: {
        registerBell();
        Context.watch(view, view.drawsLane);
        Qt.callLater(adopt);
    }
    onMonitorChanged: registerBell()
    Component.onDestruction: {
        if (view.monitor) NotificationState.unregisterAnchor(view.monitor, restAnchor);
        if (view.notifications && view.notifications.forget) view.notifications.forget(view);
        Context.watch(view, false);
    }
}
