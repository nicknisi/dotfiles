import Quickshell
import QtQuick
import QtQuick.Layouts
import qs
import qs.Kit
import "../lib/IslandMachine.js" as IslandMachine

// IslandView.qml - everything inside one island window, minus the window.
//
// Island.qml is the PanelWindow (layer shell, mask, focus grab, Hyprland);
// this is the part that holds state and draws, as a plain Item so the offscreen
// check (tests/check.qml) can build it in a FloatingWindow: PanelWindow has no
// backend there.
//
// What it does:
//   - holds the machine record (lib/IslandMachine.js) and wires the pointer
//     and timers to it: a 250 ms dwell before hover opens, a 150 ms grace on
//     leave, the state's own timer restarted on every go();
//   - sizes the body to the state (rest hugs its content) and lays the state
//     layers inside it;
//   - hands off to the old surfaces where the island state is not built yet
//     (PLAN 1.7): the status pill opens the old Hud home and the clock its
//     clock page, both anchored under the rest pill; the Interrupt popup
//     (volume, brightness, mic) shows under the rest pill; the notification
//     center anchors to the rest pill.
//
// A hand-off from a click opens the Hud with its usual xdg_popup grab, which
// needs the click's input serial. One from IPC (`island open cc`, a keybind)
// has no serial, and Qt refuses a grabbing popup without one ("Failed to
// create grabbing popup"), so the IPC path opens it without the grab and
// Island.qml's HyprlandFocusGrab covers the Hud too (hudNeedsGrab): an
// outside click still closes it.
//
// Data in: monitor, workspaces (lib/WorkspaceOrder.js shown() records) and
// whatever IslandView reads itself through `Fixture.data.<x> ?? live`. The
// Context text slot reads only the fixture: PLAN M2 keeps it empty on the
// desktop until M3 gives Context board-like labels (raw titles and paths
// widened the pill to about 480).
Item {
    id: view

    property var monitor: null
    property var workspaces: []
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

    readonly property var targetSize: IslandMachine.size(machine, restLayer.hugWidth)
    readonly property string clock: Fixture.data.clock ?? Qt.formatDateTime(view.now, "HH:mm")
    readonly property string date: Fixture.data.date ?? Qt.formatDateTime(view.now, "dddd, MMMM d")
    readonly property string context: Fixture.data.context ?? ""
    // A screen recording or an app on the microphone: the Bar's privacy
    // glyphs, as one dot on the rest pill until M3's live segment.
    readonly property bool privacy: Fixture.data.privacy ?? (Capture.recording || Audio.recorders.length > 0)
    readonly property var media: {
        if (Fixture.data.media !== undefined) return Fixture.data.media;
        const p = Media.player;
        return p ? { title: p.trackTitle || p.identity || "", artist: p.trackArtist || "" } : null;
    }
    readonly property var status: Fixture.data.status ?? ({
        wifi: Net.radioOn && Net.connected,
        bt: Bt.enabled,
        tailscale: Tailscale.running,
        muted: Audio.muted,
        battery: Battery.percent
    })

    readonly property alias body: body
    readonly property alias rest: restLayer
    readonly property alias hover: hoverLayer
    readonly property alias restAnchor: restAnchor
    readonly property alias hud: hud
    readonly property alias dwell: dwellTimer

    // Where each not-yet-built state lands, for the IPC's error text.
    readonly property var arrives: ({ launcher: "M5", cal: "M3", notif: "M3", osd: "M3", dict: "M3", flash: "M3", cc: "M6", power: "M6", polkit: "M8" })

    signal workspaceActivated(string name)

    implicitHeight: IslandMachine.WINDOW_HEIGHT

    // ---- the machine ---------------------------------------------------------

    function apply(next) {
        if (next !== view.machine) view.machine = next;
    }
    onMachineChanged: {
        stateTimer.stop();
        if (machine.timer > 0) {
            stateTimer.seq = machine.seq;
            stateTimer.interval = machine.timer;
            stateTimer.start();
        }
        if (machine.state !== "hover" || machine.pinned) graceTimer.stop();
        // From the record itself: the panelOpen binding may not have caught
        // up inside this handler.
        if (IslandMachine.panelOpen(machine)) keys.forceActiveFocus();
    }

    function pointerEntered() {
        graceTimer.stop();
        if (machine.state === "rest" && !handedOff) dwellTimer.restart();
    }
    function pointerLeft() {
        dwellTimer.stop();
        if (machine.state === "hover" && !machine.pinned) graceTimer.restart();
    }
    function clickPill() {
        dwellTimer.stop();
        hudPage = "";
        apply(IslandMachine.click(machine));
    }
    // Outside click (the focus grab clearing) or Esc.
    function dismiss() {
        dwellTimer.stop();
        if (hudNeedsGrab) hudPage = "";
        apply(IslandMachine.dismiss(machine));
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
        if (state === "cc" || state === "cal") return handOff(state, false);
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
    function isOpen(state: string): bool {
        if (state === "cc") return hudPage === "home";
        if (state === "cal") return hudPage === "clock";
        return machine.state === state;
    }
    function toggle(state: string): string {
        return isOpen(state) && state !== "rest" ? close() : open(state);
    }
    // cc and cal before their states exist: back to rest, and the old menu
    // drops from the rest pill. `clicked` says whether a pointer press led
    // here: only then can the Hud take its own popup grab. A Hud already
    // showing just changes page and keeps the grab it opened with.
    function handOff(state: string, clicked: bool): string {
        apply(IslandMachine.go(machine, "rest"));
        NotificationState.closeCenter();
        if (hudPage === "") hud.grabFocus = clicked;
        hudPage = state === "cal" ? "clock" : "home";
        return "ok";
    }

    function inspect() {
        return {
            screen: view.monitor?.name ?? "",
            state: machine.state,
            pinned: machine.pinned,
            panelOpen: view.panelOpen,
            hud: view.hudPage,
            hudShown: view.hud.visible,
            hudGrab: view.hud.grabFocus,
            target: { width: targetSize[0], height: targetSize[1], radius: body.targetRadius },
            body: { x: body.x, y: body.y, width: body.width, height: body.height, radius: body.radius },
            workspaces: (view.workspaces || []).map(w => w.name),
            focused: restLayer.strip.focusedName,
            shape: restLayer.strip.shapeName
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
        onTriggered: if (view.pointerInside && !view.handedOff) view.apply(IslandMachine.enter(view.machine))
    }
    Timer {
        id: graceTimer
        interval: IslandMachine.LEAVE_GRACE
        onTriggered: if (!view.pointerInside) view.apply(IslandMachine.leave(view.machine))
    }
    Timer {
        id: stateTimer
        property int seq: 0
        onTriggered: view.apply(IslandMachine.expire(view.machine, seq))
    }

    // Esc closes an open panel. Focus lands here when one opens; the window
    // only has the keyboard once it is clicked (OnDemand).
    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: view.dismiss()
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
            context: view.context
            privacy: view.privacy
            onPin: view.clickPill()
            onWorkspaceActivated: name => view.workspaceUsed(name)
        }

        HoverLayer {
            id: hoverLayer
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            current: view.machine.state === "hover"
            clock: view.clock
            date: view.date
            media: view.media
            status: view.status
            onPin: view.clickPill()
            onOpenCalendar: view.handOff("cal", true)
            onOpenControlCenter: view.handOff("cc", true)
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
        onNavigate: page => view.hudPage = page
        onDismissed: view.hudPage = ""
        // grabFocus is set by handOff() each time the Hud opens.
    }

    function registerBell() {
        if (view.monitor) NotificationState.registerAnchor(view.monitor, restAnchor, "top");
    }
    Component.onCompleted: registerBell()
    onMonitorChanged: registerBell()
    Component.onDestruction: if (view.monitor) NotificationState.unregisterAnchor(view.monitor, restAnchor)

    // Volume, brightness and the mic: Bar.qml's popup, under the rest pill
    // until the osd state lands in M3.
    PopupWindow {
        id: feedback
        anchor.item: restAnchor
        anchor.rect.x: (restAnchor.width - implicitWidth) / 2
        anchor.rect.y: restAnchor.height + 8
        anchor.adjustment: PopupAdjustment.Slide
        visible: Interrupt.active && view.hudPage === "" && !NotificationState.centerOpen && view.machine.state === "rest"
        color: "transparent"
        implicitWidth: 210
        implicitHeight: 40
        mask: Region {}
        ShellSurface {
            anchors.fill: parent
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                Text {
                    text: Interrupt.glyph
                    font.family: Theme.icons
                    color: Theme.accent
                    font.pixelSize: 14
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 3
                    color: Theme.raised
                    visible: Interrupt.metered
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, Interrupt.fraction))
                        height: 3
                        color: Theme.accent
                    }
                }
                Text {
                    text: Interrupt.label
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: Theme.fg
                }
            }
        }
    }
}
