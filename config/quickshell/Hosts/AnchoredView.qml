import Quickshell
import QtQuick
import QtQuick.Layouts
import qs
import qs.Kit
import qs.Island
import "../lib/Anchored.js" as Anchored
import "../lib/CcData.js" as CcData

// AnchoredView.qml - what the classic bars' panel host shows and does
// (PLAN M4, island-modes 12.4); Hosts/AnchoredHost.qml is the window around
// it, as Island.qml is IslandView's. tests/check.qml runs this in a
// FloatingWindow, since PanelWindow has no offscreen backend.
//
// It shows, against the module that asked (BarView.openMenu, menuAnchor and
// menuAlignment; lib/Anchored.js MENUS says which panel a menu opens):
//   cc     the control center (Island/CcLayer: Panels/ControlCenter and its
//          sheets), the same 760 x 560 content the island morphs into;
//   cal    the calendar (Island/CalendarLayer, 400 x 368), under the clock,
//          closable: no chevron back, a trailing x as on the pages;
//   power  the power menu (Island/PowerLayer, 600 x 156), anchored like the
//          others (island-modes 3.2: to the module the control center hangs
//          from), over the scrim, rgba(bg, .56); on a strip the scrim stops
//          at the strip, which is one piece with the panel;
//   page   Appearance (the bar's mode, edge and translucency), the one old
//          page left (it has no sheet), on the same frame under one header
//          (its title and subtitle; the page's own header is hidden:
//          BarMenu.framed). The battery is the control center's Battery
//          sheet (M10).
//
// The theme picker (M7) replaced ThemeMenu's page (PLAN 1.3): Appearance's
// Theme packs, the control center's Theme mini and `bar open theme` close
// this panel and open the picker's free panel on this screen (pickerHost,
// shell.qml's ThemePicker; without one, `theme picker themes`).
//
// Placement, corners, hairlines and motion are lib/Anchored.js place(): the
// pill's panel floats 8 from the bar and grows from the module's corner; the
// full strip's drops out of it and the rail's slides out of it, flush, square
// where they join and round on the free corners, with no hairline along the
// seam (the bar leaves its own out there: seamFrom/seamTo, except over the
// panel's own hairline sides: seamStartLine/seamEndLine). Hosts/
// AnchoredFrame.qml draws it, on whole device pixels (dpr, the bar's).
// Closing reverses the motion while the content fades out over
// Motion.exitFade (Kit/Layer). One panel into another (cc to power, cc to
// the calendar): the outgoing layer stays where it was laid out while it
// fades (leaving, leavingAt), and only the incoming one takes the new
// place. Esc steps back (a sheet to the control center), then closes.
//
// open/toggle/inspect are `bar open|toggle|inspect` (Hosts/BarIpc.qml);
// opened that way, the first control draws its focus ring (control-lock 2.9).
Item {
    id: host

    // The bar's BarView, and its screen ({ width, height, name }).
    required property Item view
    property var monitor: null
    // Where the bar window's top-left sits on the screen.
    property point barOrigin: Qt.point(0, 0)
    property date now: new Date()
    // shell.qml's ThemePicker (openOn(screen, kind)), or null.
    property var pickerHost: null
    // shell.qml's ScreenCorners (through Bar and AnchoredHost), or null. The
    // host's window is a full-screen Overlay surface mapped after the corner
    // strips, so the power menu's scrim would grey them: it paints the
    // corners over it (corners.drawn).
    property var corners: null
    // What the last theme hand-off did: "picker" or "exec" (tests, inspect).
    property string themesRan: ""
    // Device pixels per logical px: the bar's window (always mapped; this
    // host's own window maps only once a panel shows).
    readonly property real dpr: view.dpr ?? 1

    // ---- what shows ------------------------------------------------------------
    readonly property string menu: view.openMenu
    readonly property var target: Anchored.target(menu)
    readonly property bool shown: target !== null
    // The panel on screen ("" for none): cc | cal | power | page. Kept through
    // the close, so the panel can leave.
    property string kind: ""
    // appearance, while kind is "page".
    property string page: ""
    // Opened by `bar open` (IPC): the first control takes the focus ring.
    property bool byKey: false
    property bool ipcOpening: false
    // Anchored.place()'s result for the panel showing, in screen px.
    property var shape: null
    // Where the motion starts: shape.from on an open or a close, the drawn
    // rectangle when one panel morphs into another.
    property var fromRect: null
    // 0 closed, 1 in place.
    property real progress: 0
    property string powerRan: ""
    // One panel into another: the panel that is fading out ("" for none) and
    // where its content sits on screen until it has gone.
    property string leaving: ""
    property point leavingAt: Qt.point(0, 0)

    readonly property real drawnX: host.lerp("x")
    readonly property real drawnY: host.lerp("y")
    readonly property real drawnWidth: Math.max(0, host.lerp("width"))
    readonly property real drawnHeight: Math.max(0, host.lerp("height"))
    function lerp(key: string): real {
        const a = host.fromRect?.[key] ?? 0;
        const b = host.shape?.[key] ?? 0;
        return a + (b - a) * host.progress;
    }

    // The stretch of the bar the panel covers (BarView's coordinates), while
    // a flush strip's panel is on screen.
    readonly property bool seamed: host.kind !== "" && (host.shape?.seam ?? "") !== ""
    readonly property bool alongY: view.vertical
    readonly property real seamFrom: host.seamed ? (host.alongY ? host.drawnY - host.barOrigin.y - view.body.y : host.drawnX - host.barOrigin.x - view.body.x) : 0
    readonly property real seamTo: host.seamed ? host.seamFrom + (host.alongY ? host.drawnHeight : host.drawnWidth) : 0
    // The panel's hairline on the seam's start and end sides (its left and
    // right on a horizontal strip, its top and bottom on the rail): the bar
    // keeps its line over them, so the corner closes.
    readonly property bool seamStartLine: host.seamed && (host.shape?.hairline?.[host.alongY ? "top" : "left"] ?? false)
    readonly property bool seamEndLine: host.seamed && (host.shape?.hairline?.[host.alongY ? "bottom" : "right"] ?? false)
    // The bar's inner edge, in screen px (AnchoredFrame clips the panel there).
    readonly property real seamAt: {
        const b = host.barRect();
        const e = view.edge;
        return e === "top" ? b.y + b.height : e === "bottom" ? b.y : e === "left" ? b.x + b.width : b.x;
    }

    readonly property alias ccLayer: ccLayer
    readonly property alias calLayer: calLayer
    readonly property alias powerLayer: powerLayer
    readonly property alias pageLayer: pageLayer
    readonly property alias frame: frame

    // The input region the window keeps (AnchoredHost.qml's mask): the
    // panel, or the whole screen under the power menu's scrim.
    readonly property Item hitItem: host.kind === "power" ? scrim : hit

    // ---- geometry --------------------------------------------------------------
    function screenSize(): var {
        return { width: host.monitor?.width ?? host.width, height: host.monitor?.height ?? host.height };
    }
    function toScreen(r): var {
        return { x: r.x + host.barOrigin.x, y: r.y + host.barOrigin.y, width: r.width, height: r.height };
    }
    function barRect(): var {
        return host.toScreen(view.surfaceRect());
    }
    function moduleRect(): var {
        return host.toScreen(view.rectOf(view.menuAnchor));
    }
    function sizeFor(kind: string): var {
        if (kind === "page")
            return { width: Anchored.SIZES.page.width, height: pageLayer.implicitHeight };
        return Anchored.SIZES[kind] ?? { width: 0, height: 0 };
    }
    function placeFor(kind: string): var {
        return Anchored.place({
            mode: view.mode,
            edge: view.edge,
            screen: host.screenSize(),
            bar: host.barRect(),
            module: host.moduleRect(),
            align: view.menuAlignment,
            size: host.sizeFor(kind),
            dpr: host.dpr
        });
    }
    function drawnRect(): var {
        return { x: host.drawnX, y: host.drawnY, width: host.drawnWidth, height: host.drawnHeight };
    }
    // Where a layer sits inside the frame's content holder: at its origin
    // when it is the panel showing; the outgoing one where it was laid out.
    function layerX(kind: string): real {
        return kind !== host.kind && kind === host.leaving ? host.leavingAt.x - frame.holderX : 0;
    }
    function layerY(kind: string): real {
        return kind !== host.kind && kind === host.leaving ? host.leavingAt.y - frame.holderY : 0;
    }
    function sameRect(a, b): bool {
        return !!a && !!b && a.x === b.x && a.y === b.y && a.width === b.width && a.height === b.height;
    }

    // ---- open, switch, close ---------------------------------------------------
    onMenuChanged: host.sync()
    function sync(): void {
        // From the menu itself: `target` may not have re-evaluated yet when
        // menuChanged reaches this handler.
        const t = Anchored.target(view.openMenu);
        // Theme is the picker now (M7), not a page here. Later: closing from
        // inside this change would loop the `menu` binding.
        if (t && t.page === "theme") {
            Qt.callLater(host.openThemes);
            return;
        }
        if (!t) {
            if (host.kind !== "")
                host.leave();
            return;
        }
        const wasShowing = host.kind !== "" && !host.closing;
        const fresh = host.kind === "";
        const prevKind = host.kind;
        if (fresh)
            host.byKey = host.ipcOpening;
        host.page = t.page ?? "";
        host.kind = t.panel;
        const next = host.placeFor(host.kind);
        if (!wasShowing) {
            // A fresh open, or reopened mid-close: from the module (or from
            // behind the strip), continuing from wherever the close got to
            // when it is the same panel.
            if (fresh || prevKind !== host.kind || !host.sameRect(host.shape, next))
                host.progress = 0;
            host.shape = next;
            host.fromRect = next.from;
        } else if (!host.sameRect(host.shape, next) || prevKind !== host.kind) {
            // One panel into another (cc -> power, a sheet's module elsewhere
            // on the bar): from where it is drawn now. The outgoing layer
            // keeps the place it was laid out in while it fades, so it is
            // cut by the moving frame rather than moved with it.
            if (prevKind !== host.kind) {
                host.leaving = prevKind;
                host.leavingAt = Qt.point(frame.holderX, frame.holderY);
            }
            host.fromRect = host.drawnRect();
            host.shape = next;
            host.progress = 0;
        }
        host.closing = false;
        anim.stop();
        anim.to = 1;
        anim.start();
        if (host.kind === "cc") {
            if (t.sheet !== "")
                ccLayer.openSheet(t.sheet, t.sheet === "tray" ? { item: view.trayItem } : null, host.byKey);
            else if (ccLayer.content.sheet !== "")
                ccLayer.content.closeSheet(true);
        }
        Qt.callLater(host.focusPanel);
    }
    property bool closing: false
    function leave(): void {
        host.closing = true;
        host.fromRect = host.shape?.from ?? host.drawnRect();
        anim.stop();
        anim.to = 0;
        anim.start();
    }
    function finished(): void {
        if (!host.closing)
            return;
        host.closing = false;
        host.kind = "";
        host.page = "";
        host.shape = null;
        host.fromRect = null;
        host.byKey = false;
        host.progress = 0;
    }
    NumberAnimation {
        id: anim
        target: host
        property: "progress"
        duration: Motion.spatial
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.spring
        // A morph done: the outgoing layer has long faded.
        onFinished: {
            host.leaving = "";
            host.finished();
        }
        onStopped: if (host.progress === 0) host.finished()
    }
    // A page's height follows its content.
    Connections {
        target: pageLayer
        function onImplicitHeightChanged() {
            if (host.kind === "page" && !host.closing) {
                host.shape = host.placeFor("page");
                if (host.progress >= 1) host.fromRect = host.shape;
            }
        }
    }

    function close(): void {
        if (view.openMenu !== "")
            view.openMenu = "";
    }
    // Esc: a sheet back to the control center, then close.
    function stepBack(): void {
        if (host.kind === "cc" && ccLayer.content.sheet !== "")
            return ccLayer.content.back();
        host.close();
    }
    // The theme picker on this screen (M7): this panel closes first, so the
    // picker's free panel takes the keys. Under a dry run with no picker,
    // nothing runs.
    function openThemes(): bool {
        host.close();
        if (host.pickerHost) {
            host.themesRan = "picker";
            host.pickerHost.openOn(host.monitor, "themes");
        } else {
            host.themesRan = "exec";
            if (!Fixture.dryRun)
                Quickshell.execDetached(["theme", "picker", "themes"]);
        }
        return true;
    }
    function focusPanel(): void {
        if (!host.shown)
            return;
        if (host.kind === "cc")
            ccLayer.content.focusHome(host.byKey);
        else if (host.kind === "power")
            powerLayer.forceActiveFocus();
        else if (host.kind === "page")
            pageColumn.focusFirst();
        else
            keys.forceActiveFocus();
    }
    function runPower(id: string): string {
        const argv = CcData.POWER_COMMANDS[id];
        if (!argv)
            return "error: no power item " + id;
        host.powerRan = id;
        host.close();
        if (!Fixture.dryRun)
            Quickshell.execDetached(argv);
        return "ok";
    }

    // ---- IPC (Hosts/BarIpc.qml) -------------------------------------------------
    // state: cc | cc/<sheet> | cal | power | battery (cc/battery) |
    // appearance | theme.
    function open(state: string): string {
        const m = Anchored.menuFor(state);
        if (!m)
            return "error: no panel \"" + state + "\" (cc, cc/<sheet>, cal, power, battery, appearance, theme)";
        if (m.sheet !== "" && CcData.sheetName(m.sheet) === "")
            return "error: no sheet \"" + m.sheet + "\" (" + CcData.SHEETS.join(" ") + ")";
        if (m.menu === "theme") {
            host.openThemes();
            return "ok";
        }
        host.ipcOpening = true;
        const clock = m.menu === "clock";
        view.menuAnchor = clock ? view.clockButton : view.systemButton;
        view.menuAlignment = clock ? "center" : "end";
        if (view.openMenu === m.menu)
            host.sync();
        else
            view.openMenu = m.menu;
        host.ipcOpening = false;
        if (m.sheet !== "" && !ccLayer.openSheet(m.sheet, null, true))
            return "error: the sheet " + m.sheet + " did not open";
        return "ok";
    }
    function toggle(state: string): string {
        const m = Anchored.menuFor(state);
        if (m && host.shown && view.openMenu === m.menu && (m.sheet === "" || CcData.sheetName(m.sheet) === ccLayer.content.sheet)) {
            host.close();
            return "ok";
        }
        return host.open(state);
    }
    function inspect(): var {
        const s = host.shape;
        const r = item => item ? { name: item.objectName, highlighted: item.highlighted === true, ringed: item.ringed === true } : null;
        return {
            screen: host.monitor?.name ?? "",
            mode: view.mode,
            edge: view.edge,
            menu: view.openMenu,
            kind: host.kind,
            page: host.page,
            shown: host.shown,
            progress: host.progress,
            byKey: host.byKey,
            sheet: ccLayer.content.sheet,
            ccLast: ccLayer.model.last,
            powerRan: host.powerRan,
            themesRan: host.themesRan,
            bar: host.barRect(),
            module: view.menuAnchor ? host.moduleRect() : null,
            anchor: r(view.menuAnchor),
            shape: s ? { x: s.x, y: s.y, width: s.width, height: s.height, radii: s.radii, hairline: s.hairline, seam: s.seam, motion: s.motion, origin: s.origin, gap: s.gap } : null,
            drawn: host.drawnRect(),
            frame: frame.drawn,
            seam: { from: view.seamFrom, to: view.seamTo, at: host.seamAt },
            focus: host.Window.activeFocusItem?.objectName ?? "",
            hit: { x: host.hitItem.x, y: host.hitItem.y, width: host.hitItem.width, height: host.hitItem.height },
            scrim: scrim.opacity,
            scrimRect: { x: scrim.x, y: scrim.y, width: scrim.width, height: scrim.height },
            seamLines: { start: host.seamStartLine, end: host.seamEndLine },
            leaving: host.leaving,
            dpr: host.dpr,
            corners: hostCorners.visible ? hostCorners.radius : 0,
            cornersSkip: hostCorners.skipEdge
        };
    }

    // ---- what is drawn -------------------------------------------------------
    // The input region over the panel.
    Item {
        id: hit
        x: host.drawnX
        y: host.drawnY
        width: host.drawnWidth
        height: host.drawnHeight
    }

    // The power menu's scrim, rgba(bg, .56), over everything but the panel
    // and, on a strip, the strip it joins (strip and panel are one piece); a
    // click on it cancels.
    Rectangle {
        id: scrim
        readonly property real cut: host.view.flush ? host.seamAt : 0
        readonly property string side: host.view.flush ? host.view.edge : ""
        anchors.fill: parent
        anchors.topMargin: scrim.side === "top" ? scrim.cut : 0
        anchors.bottomMargin: scrim.side === "bottom" ? host.height - scrim.cut : 0
        anchors.leftMargin: scrim.side === "left" ? scrim.cut : 0
        anchors.rightMargin: scrim.side === "right" ? host.width - scrim.cut : 0
        color: Tokens.scrim
        opacity: host.shown && host.kind === "power" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.effects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spring
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: host.close()
        }
    }

    // Esc and the calendar's keys land here; the panels take theirs first.
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: host.stepBack()

        AnchoredFrame {
            id: frame
            anchors.fill: parent
            visible: host.kind !== ""
            shape: host.shape
            panelX: host.drawnX
            panelY: host.drawnY
            panelWidth: host.drawnWidth
            panelHeight: host.drawnHeight
            seamAt: host.seamAt
            contentX: host.shape?.x ?? 0
            contentY: host.shape?.y ?? 0
            contentWidth: host.shape?.width ?? 0
            contentHeight: host.shape?.height ?? 0
            pinned: (host.shape?.motion ?? "grow") === "grow"

            // Clicks on the panel stay on it.
            MouseArea {
                anchors.fill: parent
            }

            CcLayer {
                id: ccLayer
                x: host.layerX("cc")
                y: host.layerY("cc")
                current: host.shown && host.kind === "cc"
                monitor: host.monitor
                animated: true
                // The Theme mini: the picker on this screen (M7); without a
                // picker host, CcModel's own close and `theme picker themes`.
                openThemes: host.pickerHost ? host.openThemes : null
                onClose: host.close()
                onPower: host.view.openMenu = "power"
            }

            CalendarLayer {
                id: calLayer
                x: host.layerX("cal")
                y: host.layerY("cal")
                current: host.shown && host.kind === "cal"
                closable: true
                today: {
                    const f = String(Fixture.data.today ?? "").match(/^(\d{4})-(\d{2})-(\d{2})$/);
                    return f ? new Date(Number(f[1]), Number(f[2]) - 1, Number(f[3])) : host.now;
                }
                onBack: host.close()
            }

            PowerLayer {
                id: powerLayer
                x: host.layerX("power")
                y: host.layerY("power")
                current: host.shown && host.kind === "power"
                onRun: id => host.runPower(id)
                onCancel: host.close()
            }

            // Appearance, on the frame: a header (title and subtitle, close)
            // over the page, whose own header is hidden.
            Layer {
                id: pageLayer
                x: host.layerX("page")
                y: host.layerY("page")
                width: Anchored.SIZES.page.width
                implicitHeight: pageColumn.implicitHeight + 32
                height: implicitHeight
                current: host.shown && host.kind === "page"

                ColumnLayout {
                    id: pageColumn
                    x: 16
                    y: 16
                    width: parent.width - 32
                    spacing: 12

                    function focusFirst() {
                        const page = pages.children[pages.currentIndex];
                        if (page)
                            page.forceActiveFocus();
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                objectName: "pageTitle"
                                Layout.fillWidth: true
                                text: host.page === "appearance" ? "Appearance" : ""
                                color: Tokens.fg
                                font.family: "Adwaita Sans"
                                font.pixelSize: 15
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                            Text {
                                objectName: "pageSubtitle"
                                Layout.fillWidth: true
                                text: pages.children[pages.currentIndex]?.subtitle ?? ""
                                visible: text !== ""
                                color: Tokens.inkDim
                                font.family: "Adwaita Sans"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                        BarChip {
                            objectName: "pageClose"
                            text: "Close"
                            cornerRadius: 8
                            implicitWidth: 32
                            implicitHeight: 32
                            padding: 0
                            onClicked: host.close()
                            Icon {
                                name: "x"
                                size: 16
                                color: Tokens.inkDim
                                Layout.alignment: Qt.AlignCenter
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                            }
                        }
                    }
                    StackLayout {
                        id: pages
                        Layout.fillWidth: true
                        Layout.preferredHeight: children[currentIndex]?.implicitHeight ?? 0
                        currentIndex: 0
                        AppearanceMenu {
                            objectName: "appearancePage"
                            framed: true
                            shown: host.shown && host.page === "appearance"
                            // Theme packs: the picker (M7), not a page.
                            onNavigate: page => page === "theme" ? host.openThemes() : host.view.openMenu = page
                            onDismissed: host.close()
                        }
                    }
                }
                MenuNavigation {
                    scope: pageColumn
                }
            }
        }
    }

    // Over the power menu's scrim: the rounded screen corners, but for the
    // two on a flush strip's edge, where the scrim stops and the strips' own
    // show. No panel reaches a screen corner, so nothing else needs them.
    ScreenCornerSet {
        id: hostCorners
        objectName: "hostCorners"
        anchors.fill: parent
        radius: scrim.visible ? (host.corners?.drawn ?? 0) : 0
        skipEdge: scrim.side
    }
}
