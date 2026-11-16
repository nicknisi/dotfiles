pragma Singleton
// Prefs.qml - the handful of choices the capsule remembers across restarts.
//
// Which bar mode it uses (pill, full, rail or the island), which edge it lives
// on and whether it is see-through, plus the island shell's own choices: the
// island's form, the look, the motion profile, reduced motion,
// do-not-disturb and whether the shell's polkit agent runs. They are changed
// in the shell rather than by editing a file, so they have to be written back
// somewhere or every reload would undo them.
//
// JsonAdapter does the serialising: each property below is a key in the file,
// the file's contents land in the properties on load, and any change writes
// the whole object back out. A file saved before a key existed loads with that
// key at its default. Quickshell.statePath keeps it under
// $XDG_STATE_HOME/quickshell alongside its own state.
//
// The night light's choices live here too (NightLight.qml): its warmth, its
// schedule (off, or From and To), the state the last toggle left without a
// schedule, and an override against the schedule with the moment it runs out.
import Quickshell
import Quickshell.Io
import QtQuick
import "BarGeometry.js" as BarGeometry
import "lib/NightLight.js" as NightLightRules

Singleton {
    id: root

    // Allowed values, first one the default. Reads validate against these, so a
    // hand-edited or stale file can never hand the shell a value it cannot draw.
    // barModes is also the order nextBarMode() cycles through.
    readonly property var barModes: ["pill", "full", "rail", "island"]
    readonly property var islandForms: ["float", "notch"]
    readonly property var looks: ["crew", "phosphor", "bridge", "arcade", "liner", "outrun"]
    readonly property var motions: ["spring", "current", "slow", "off"]

    // "pill" | "full" | "rail" | "island"
    readonly property string barMode: root.barModes.includes(store.barMode) ? store.barMode : "pill"
    // The edge the shell sits on: "top" | "bottom" | "left" | "right". Each
    // mode has its edges (BarGeometry.edgeFor, the Modes board): the pill any,
    // the full strip the top or the bottom, the rail the left or the right,
    // the island the top centre only. A mode that cannot use the remembered
    // edge reads its own here (full: top, rail: left, island: top) and leaves
    // the remembered one alone, so going back to the pill puts it where it
    // was. storedEdge is that remembered edge, whatever the mode.
    readonly property string storedEdge: ["top", "bottom", "left", "right"].includes(store.edge) ? store.edge : "top"
    readonly property string edge: BarGeometry.edgeFor(root.barMode, root.storedEdge)
    readonly property bool translucent: store.translucent

    readonly property bool vertical: root.edge === "left" || root.edge === "right"

    // "float" sits 8 px under the top edge; "notch" is flush with it.
    readonly property string islandForm: root.islandForms.includes(store.islandForm) ? store.islandForm : "float"
    // The personal look, separate from the theme pack (Look.qml, M9). "crew"
    // is the plain island and the default, so nothing changes until a look
    // is picked; setLook("none") stores it too.
    readonly property string look: root.looks.includes(store.look) ? store.look : "crew"
    // Motion profile: spring (default), current (today's 160 ms ease-out),
    // slow (spring at quarter speed, for review), off (no animation).
    readonly property string motion: root.motions.includes(store.motion) ? store.motion : "spring"
    // Snaps morphs and stops ambient loops, whatever the motion profile.
    readonly property bool reducedMotion: store.reducedMotion
    // Do not disturb, kept across reloads. NotificationState.dnd is the flag
    // everything reads and toggles; it mirrors this both ways (M6).
    readonly property bool dnd: store.dnd
    // The shell's own polkit agent (PLAN M8, ShellServices). Off until the
    // switch-over disables hyprpolkitagent: only one agent can own the
    // session, and both would fight for it.
    readonly property bool polkitAgent: store.polkitAgent
    // capsule.json has been read (or found missing) once. Until then every
    // value above is its default: the island waits for this before a look
    // change counts as a pick (M9 review: the stored look arriving after the
    // view was built peeked the sign-off on every start and hot reload).
    readonly property bool loaded: file.settled

    // The night light (NightLight.qml reads these; lib/NightLight.js has the
    // rules). Warmth in kelvin, 2500 to 6000 on 100 (4000 by default);
    // schedule "off" | "custom", with From and To as "HH:MM" (20:00 to 07:00);
    // nightLightManual is on or off without a schedule; nightLightOverride
    // ("" | "on" | "off") holds against the schedule until nightLightUntil
    // (epoch ms, the next schedule edge when it was set).
    readonly property int nightLightTemperature: NightLightRules.kelvin(store.nightLightTemperature)
    readonly property string nightLightSchedule: NightLightRules.schedule(store.nightLightSchedule)
    readonly property string nightLightFrom: NightLightRules.time(store.nightLightFrom, NightLightRules.DEFAULT_FROM)
    readonly property string nightLightTo: NightLightRules.time(store.nightLightTo, NightLightRules.DEFAULT_TO)
    readonly property bool nightLightManual: store.nightLightOn
    readonly property string nightLightOverride: store.nightLightOverride === "on" || store.nightLightOverride === "off" ? store.nightLightOverride : ""
    readonly property real nightLightUntil: Number(store.nightLightUntil) > 0 ? Number(store.nightLightUntil) : 0

    // Moves the bar to `edge`. The full strip on a side edge becomes the rail
    // and the rail on the top or the bottom becomes the full strip
    // (BarGeometry.moveTo), so a drop or a "Move Bar to Left" always lands on
    // the edge asked for. The island keeps its place and remembers the edge.
    function setEdge(edge: string): void {
        const next = BarGeometry.moveTo(root.barMode, edge);
        if (!next) return;
        store.edge = next.edge;
        if (next.mode !== root.barMode) store.barMode = next.mode;
    }

    function setBarMode(mode: string): void {
        if (!root.barModes.includes(mode)) return;
        store.barMode = mode;
    }

    // pill -> full -> rail -> island -> pill; anything else starts over at pill.
    function nextBarMode(mode: string): string {
        const i = root.barModes.indexOf(mode);
        return i < 0 ? "pill" : root.barModes[(i + 1) % root.barModes.length];
    }

    function cycleBarMode(): void { store.barMode = nextBarMode(store.barMode) }
    function toggleTranslucent(): void { store.translucent = !store.translucent }

    function setIslandForm(form: string): void {
        if (!root.islandForms.includes(form)) return;
        store.islandForm = form;
    }

    function setLook(name: string): void {
        const n = name === "none" ? "crew" : name;
        if (!root.looks.includes(n)) return;
        store.look = n;
    }

    function setMotion(profile: string): void {
        if (!root.motions.includes(profile)) return;
        store.motion = profile;
    }

    // A capsule.json written before M4 holds the old modes (BarGeometry
    // upgrade): Nick's "rail on the top" was the floating capsule along the
    // top, and M4's rail is the strip down a side. Converted once, on the
    // first load that finds no `layout` key, the way a move converts it, so
    // the edge it was on stays (the full strip on the top). Later loads find
    // the key and leave a rail chosen on the left, with the top remembered for
    // the pill, as it is.
    function upgradeLayout(): void {
        if (store.layout >= BarGeometry.LAYOUT) return;
        const next = BarGeometry.upgrade(store.barMode, store.edge);
        if (next.edge !== store.edge) store.edge = next.edge;
        if (next.mode !== store.barMode) store.barMode = next.mode;
        store.layout = BarGeometry.LAYOUT;
    }

    function setReducedMotion(on: bool): void { store.reducedMotion = on }
    function setDnd(on: bool): void { store.dnd = on }
    function setPolkitAgent(on: bool): void { store.polkitAgent = on }

    // The night light's keys from one patch: { temperature, schedule, from,
    // to, manual, override, until }, any subset (NightLight.qml builds them
    // with lib/NightLight.js). Junk is refused key by key.
    function setNightLight(patch): void {
        const p = patch || {};
        if (p.temperature !== undefined && isFinite(Number(p.temperature))) store.nightLightTemperature = NightLightRules.kelvin(p.temperature);
        if (NightLightRules.SCHEDULES.indexOf(p.schedule) >= 0) store.nightLightSchedule = p.schedule;
        if (p.from !== undefined && NightLightRules.parseTime(p.from) >= 0) store.nightLightFrom = NightLightRules.time(p.from, NightLightRules.DEFAULT_FROM);
        if (p.to !== undefined && NightLightRules.parseTime(p.to) >= 0) store.nightLightTo = NightLightRules.time(p.to, NightLightRules.DEFAULT_TO);
        if (typeof p.manual === "boolean") store.nightLightOn = p.manual;
        if (p.override === "" || p.override === "on" || p.override === "off") store.nightLightOverride = p.override;
        if (p.until !== undefined && isFinite(Number(p.until))) store.nightLightUntil = Math.max(0, Number(p.until));
    }

    // Writes wait for the end of the current event. Writing from inside
    // adapterUpdated lost every change after the first in the same call:
    // setLook("arcade") straight after setIslandForm("notch") read back "crew",
    // and the file kept "crew". One write per batch keeps them all.
    Timer {
        id: save
        interval: 0
        onTriggered: file.writeAdapter()
    }

    FileView {
        id: file
        path: Quickshell.statePath("capsule.json")
        watchChanges: true
        // Reads and writes run to the end before anything else (the file is
        // a few hundred bytes). Asynchronous, the change event of one write
        // can start a reload while the next write is still on its way, and
        // that reload reads the older file. Suspected, never reproduced,
        // behind check.qml's one "edge preference settles: pill/bottom"
        // failure (M10: 24 stressed runs and 8 from a seeded state passed
        // before this change too).
        blockWrites: true
        blockAllReads: true
        // An edit made after our last write is still unsaved; reloading now
        // would put the file's older value back over it.
        onFileChanged: if (!save.running) reload()
        onAdapterUpdated: save.restart()
        // Set after the adapter holds the file's values (JsonAdapter fills
        // them before loaded fires), so `loaded` never runs ahead of them.
        property bool settled: false
        onLoaded: {
            root.upgradeLayout();
            file.settled = true;
        }

        // First run on a machine: nothing saved yet. Writing the defaults out
        // is what makes every later load quiet (at the current layout: there
        // is nothing old to convert).
        onLoadFailed: {
            store.layout = BarGeometry.LAYOUT;
            writeAdapter();
            file.settled = true;
        }

        adapter: JsonAdapter {
            id: store
            property string edge: "top"
            property string barMode: "pill"
            property bool translucent: false
            property string islandForm: "float"
            property string look: "crew"
            property string motion: "spring"
            property bool reducedMotion: false
            property bool dnd: false
            // The bar rules the file follows (BarGeometry.LAYOUT); 0 before M4.
            property int layout: 0
            property bool polkitAgent: false
            // The night light (NightLight.qml).
            property int nightLightTemperature: 4000
            property string nightLightSchedule: "off"
            property string nightLightFrom: "20:00"
            property string nightLightTo: "07:00"
            property bool nightLightOn: false
            property string nightLightOverride: ""
            property real nightLightUntil: 0
        }
    }
}
