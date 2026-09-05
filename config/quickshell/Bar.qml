// Bar.qml - one panel per monitor. shell.qml stamps this out with Variants, so
// plugging in a display over one of the three idle DP outputs gets a bar without
// any extra config.
//
// The bar is drawn as one more tile in the dwindle layout: it floats in the same
// gap as every window, wears the same border width, and takes all three numbers
// from Hyprland through Theme rather than hardcoding them. Change gaps_out in
// hyprland.lua and the bar moves with the windows.
//
// It carries glyphs, not sentences. Point at a module and the words slide out;
// click one and its menu unfolds underneath. Only one menu is open at a time,
// which is what `openMenu` tracks.
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: bar

    // Variants hands each delegate its model entry. `required` makes QML fail
    // loudly at load if that ever stops being true.
    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    margins { top: Theme.gap; left: Theme.gap; right: Theme.gap }
    implicitHeight: Theme.barHeight
    color: "transparent"

    // The name of the one open menu, or "". Menus bind their `shown` to this
    // rather than owning it, so opening one closes the last.
    property string openMenu: ""
    function toggleMenu(name: string) {
        bar.openMenu = bar.openMenu === name ? "" : name;
    }

    // One clock for the whole bar: the module, its menu and the seconds hairline
    // all read the same instant.
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: bar.now = new Date()
    }

    // Workspaces worth drawing: focused, or holding at least one window. Sorted
    // numeric-first then alphabetically, so 1..9 lead and the lettered ones
    // follow in a stable order rather than in creation order. Named workspaces
    // get a synthetic negative id (-1337 and down) that shifts as they are
    // created and destroyed, so everything here keys on name.
    readonly property string focusedName: Hyprland.focusedWorkspace?.name ?? ""

    readonly property var shownWorkspaces: {
        const out = [];
        for (const w of Hyprland.workspaces.values) {
            const count = w.toplevels?.values?.length ?? 0;
            if (count === 0 && w.name !== bar.focusedName) continue;
            out.push(w);
        }
        out.sort((a, b) => {
            const an = parseInt(a.name), bn = parseInt(b.name);
            const aNum = !isNaN(an), bNum = !isNaN(bn);
            if (aNum && bNum) return an - bn;
            if (aNum !== bNum) return aNum ? -1 : 1;
            return a.name.localeCompare(b.name);
        });
        return out;
    }

    // One glyph per distinct app, matching how workspaces.sh deduplicated on
    // workspace|app-name. Two windows of the same app collapse to one icon; two
    // different apps that happen to share a glyph still show twice.
    function glyphsFor(ws): var {
        const seen = ({});
        const out = [];
        for (const t of (ws.toplevels?.values ?? [])) {
            const cls = String(t.lastIpcObject?.class ?? "");
            if (cls === "" || seen[cls]) continue;
            seen[cls] = true;
            out.push(Icons.forClass(cls));
        }
        return out;
    }

    component Label: Text {
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.bold: true
        color: Theme.fg
        Layout.alignment: Qt.AlignVCenter
    }

    component Icon: Text {
        font.family: Theme.icons
        font.pixelSize: Theme.iconSize
        color: Theme.fg
        Layout.alignment: Qt.AlignVCenter
    }

    // ---- the tile ----------------------------------------------------------
    Rectangle {
        id: frame
        anchors.fill: parent
        color: Theme.surface
        radius: Theme.radius
        border.width: Theme.borderWidth

        // Inactive border until one of its menus is open, at which point the bar
        // really is the focused thing on screen and borrows the accent Hyprland
        // paints on a focused window.
        border.color: bar.openMenu !== "" ? Theme.borderActive : Theme.borderIdle
        Behavior on border.color { ColorAnimation { duration: Theme.base } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 6

            // ---- workspaces ---------------------------------------------
            // No pill backgrounds. One accent rail slides between workspaces
            // instead, so switching reads as a single object moving rather than
            // as one chip lighting up while another goes out.
            Item {
                id: wsGroup
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: wsRow.implicitWidth
                implicitHeight: wsRow.implicitHeight

                Rectangle {
                    id: rail
                    y: wsGroup.height - height
                    height: Theme.borderWidth
                    color: Theme.borderActive
                    opacity: width > 0 ? 1 : 0

                    function follow(item) {
                        rail.x = item.x;
                        rail.width = item.width;
                    }

                    // The overshoot on x is the whole point: the rail arrives a
                    // hair past the new workspace and settles back.
                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.base
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.4
                        }
                    }
                    Behavior on width {
                        NumberAnimation { duration: Theme.base; easing.type: Easing.OutCubic }
                    }
                }

                RowLayout {
                    id: wsRow
                    anchors.fill: parent
                    spacing: 2

                    Repeater {
                        model: bar.shownWorkspaces

                        MouseArea {
                            id: ws
                            required property var modelData

                            readonly property bool focused: modelData.name === bar.focusedName
                            readonly property var glyphs: bar.glyphsFor(modelData)

                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: wsInner.implicitWidth + 14
                            implicitHeight: Theme.barHeight - Theme.borderWidth * 2 - 6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ws.modelData.activate()

                            // The rail is a sibling of the row, so it has to be
                            // told where each focused pill ends up. Position and
                            // width both move as apps open and close on the
                            // focused workspace, hence all three hooks.
                            onFocusedChanged: if (focused) rail.follow(ws)
                            onXChanged: if (focused) rail.follow(ws)
                            onWidthChanged: if (focused) rail.follow(ws)
                            Component.onCompleted: if (focused) rail.follow(ws)

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.raised
                                radius: Theme.radius
                                opacity: ws.containsMouse && !ws.focused ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.quick } }
                            }

                            RowLayout {
                                id: wsInner
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: ws.modelData.name
                                    color: ws.focused ? Theme.fg : Theme.muted
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 1
                                    font.bold: true
                                    Behavior on color { ColorAnimation { duration: Theme.base } }
                                }

                                Repeater {
                                    model: ws.glyphs

                                    Text {
                                        required property string modelData
                                        Layout.alignment: Qt.AlignVCenter
                                        text: modelData
                                        color: ws.focused ? Theme.accent : Theme.muted
                                        font.family: Theme.icons
                                        font.pixelSize: Theme.fontSize

                                        // Apps fade in as they open rather than
                                        // popping into the row.
                                        opacity: 0
                                        Component.onCompleted: opacity = 1
                                        Behavior on opacity { NumberAnimation { duration: Theme.base } }
                                        Behavior on color { ColorAnimation { duration: Theme.base } }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // ---- system ---------------------------------------------------
            // No numbers. CPU gets a sparkline because what matters is whether
            // it is climbing; memory gets a gauge because what matters is how
            // full it is. The two shapes are also what tells them apart, which
            // two identical strips never did. Both numbers are one hover away.
            BarModule {
                id: sysMod
                reveal: `cpu ${Sys.cpu}%  \u00b7  mem ${Sys.mem}%`

                Spark {
                    Layout.alignment: Qt.AlignVCenter
                    values: Sys.cpuHistory
                    tint: Sys.cpu > 85 ? Theme.red : Theme.yellow
                }
                Gauge {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 3
                    value: Sys.mem
                    tint: Sys.mem > 85 ? Theme.red : Theme.cyan
                }
            }

            // ---- wifi ------------------------------------------------------
            BarModule {
                id: netMod
                reveal: {
                    if (!Net.radioOn) return "wifi off";
                    return Net.connected ? Net.ssid : "offline";
                }
                highlighted: bar.openMenu === "net"
                onClicked: bar.toggleMenu("net")

                Icon {
                    text: Net.radioOn ? "\u{f05a9}" : "\u{f05aa}"
                    color: {
                        if (!Net.radioOn) return Theme.muted;
                        if (!Net.connected) return Theme.red;
                        return Net.bars >= 3 ? Theme.green : Theme.yellow;
                    }
                    Behavior on color { ColorAnimation { duration: Theme.base } }
                }
            }

            // ---- bluetooth -------------------------------------------------
            BarModule {
                id: btMod
                visible: Bt.present
                reveal: {
                    if (!Bt.enabled) return "bt off";
                    const n = Bt.connected.length;
                    if (n === 0) return "no devices";
                    return n === 1 ? Bt.labelFor(Bt.primary) : `${n} devices`;
                }
                highlighted: bar.openMenu === "bt"
                onClicked: bar.toggleMenu("bt")

                Icon {
                    text: {
                        if (!Bt.enabled) return "\u{f00b2}";              // md bluetooth-off
                        if (Bt.connected.length > 0) return "\u{f00b0}";  // md bluetooth-connect
                        return "\u{f00af}";                               // md bluetooth
                    }
                    color: {
                        if (!Bt.enabled) return Theme.muted;
                        return Bt.connected.length > 0 ? Theme.accent : Theme.fg;
                    }
                    Behavior on color { ColorAnimation { duration: Theme.base } }
                }
            }

            // ---- volume ----------------------------------------------------
            // Click opens the menu, scroll changes volume in 2% steps wherever
            // the pointer is on the module.
            BarModule {
                id: volMod
                reveal: Audio.muted ? "muted" : `${Math.round(Audio.volume * 100)}%`
                highlighted: bar.openMenu === "audio"
                enabled: Audio.ready
                onClicked: bar.toggleMenu("audio")
                onWheel: event => {
                    const step = event.angleDelta.y > 0 ? 0.02 : -0.02;
                    Audio.sink.audio.volume = Math.max(0, Math.min(1, Audio.volume + step));
                }

                Icon {
                    id: volIcon
                    text: Audio.muted ? "\u{f0581}" : "\u{f057e}"
                    color: Audio.muted ? Theme.red : Theme.fg

                    // A nudge on every volume change, so a scroll registers even
                    // before the number has finished sliding out.
                    Connections {
                        target: Audio
                        function onVolumeChanged() { bump.restart() }
                    }
                }
            }

            // ---- battery ---------------------------------------------------
            // The one number that stays on screen, because nothing else on the
            // desktop tells you and you cannot infer it.
            BarModule {
                id: battMod
                visible: Battery.present
                reveal: Battery.timeText

                Icon {
                    // Font Awesome battery ramp: f244 empty .. f240 full.
                    text: {
                        if (Battery.charging) return "\uf0e7";
                        const p = Battery.percent;
                        if (p > 87) return "\uf240";
                        if (p > 62) return "\uf241";
                        if (p > 37) return "\uf242";
                        if (p > 12) return "\uf243";
                        return "\uf244";
                    }
                    color: Battery.low ? Theme.red : (Battery.charging ? Theme.green : Theme.fg)
                    Behavior on color { ColorAnimation { duration: Theme.base } }
                }
                Label {
                    text: `${Battery.percent}%`
                    color: Battery.low ? Theme.red : Theme.fg
                    font.bold: false
                }
            }

            // ---- theme -----------------------------------------------------
            BarModule {
                id: themeMod
                reveal: Theme.name
                highlighted: bar.openMenu === "theme"
                onClicked: bar.toggleMenu("theme")

                Icon {
                    // md palette. Not f03d7, which the Nerd Font maps to a
                    // shipping box; the codepoints in this range are worth
                    // rendering before trusting.
                    text: "\u{f0e0c}"
                    color: Theme.accent
                    Behavior on color { ColorAnimation { duration: Theme.base } }
                }
            }
        }

        // ---- clock ---------------------------------------------------------
        // Anchored to the tile rather than placed in the row, because a layout
        // can only centre its middle item when the two beside it happen to be
        // the same width, and they never are.
        BarModule {
            id: clockMod
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            reveal: Qt.formatDateTime(bar.now, "ddd MMM d")
            highlighted: bar.openMenu === "clock"
            // A minute draining away under the time, which is the only place in
            // the bar that seconds appear at all.
            progress: bar.now.getSeconds() / 60
            onClicked: bar.toggleMenu("clock")

            Label {
                text: Qt.formatDateTime(bar.now, "HH:mm")
                color: Theme.fg
                font.letterSpacing: 0.8
            }
        }
    }

    // The volume glyph's nudge, parked out here so it is not a child of the
    // thing it animates.
    SequentialAnimation {
        id: bump
        NumberAnimation { target: volIcon; property: "scale"; to: 1.18; duration: 70; easing.type: Easing.OutCubic }
        NumberAnimation { target: volIcon; property: "scale"; to: 1.0; duration: 130; easing.type: Easing.OutBack }
    }

    // ---- menus -------------------------------------------------------------
    // Windows, not layout children, so they hang off the bar and only borrow a
    // module for positioning.
    BtMenu {
        anchorItem: btMod
        shown: bar.openMenu === "bt"
        onDismissed: bar.openMenu = ""
    }

    ClockMenu {
        anchorItem: clockMod
        now: bar.now
        shown: bar.openMenu === "clock"
        onDismissed: bar.openMenu = ""
    }

    NetMenu {
        anchorItem: netMod
        shown: bar.openMenu === "net"
        onDismissed: bar.openMenu = ""
    }

    AudioMenu {
        anchorItem: volMod
        shown: bar.openMenu === "audio"
        onDismissed: bar.openMenu = ""
    }

    ThemeMenu {
        anchorItem: themeMod
        shown: bar.openMenu === "theme"
        onDismissed: bar.openMenu = ""
    }
}
