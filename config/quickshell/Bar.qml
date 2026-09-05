// Bar.qml - one panel per monitor. shell.qml stamps this out with Variants, so
// plugging in a display over one of the three idle DP outputs gets a bar without
// any extra config.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: bar

    // Variants hands each delegate its model entry. `required` makes QML fail
    // loudly at load if that ever stops being true.
    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: Theme.bg

    // Fire-and-forget for click handlers.
    Process { id: runner }
    function run(cmd: string) {
        runner.command = ["sh", "-c", cmd];
        runner.startDetached();
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

    // Hyprland 0.56 parses dispatch payloads as Lua, so `workspace 3` is a syntax
    // error there. An existing workspace can skip the whole question and use its
    // own activate() method; only creating a new one needs a dispatch string.
    function goToWorkspace(n: int) {
        const existing = Hyprland.workspaces.values.find(w => w.id === n);
        if (existing) {
            existing.activate();
            return;
        }
        if (Hyprland.usingLua) Hyprland.dispatch(`hl.dsp.focus({ workspace = "${n}" })`);
        else Hyprland.dispatch(`workspace ${n}`);
    }

    component Sep: Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 1
        implicitHeight: 14
        color: Theme.muted
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

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 10

        // ---- workspaces ------------------------------------------------
        // Same behaviour as sketchybar's plugins/workspaces.sh: a pill is drawn
        // only when the workspace is focused or holds windows, and it carries one
        // glyph per distinct app on it.
        RowLayout {
            spacing: 5

            Repeater {
                model: bar.shownWorkspaces

                Rectangle {
                    id: pill
                    required property var modelData

                    readonly property bool focused: modelData.name === bar.focusedName
                    readonly property var glyphs: bar.glyphsFor(modelData)

                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: pillRow.implicitWidth + 14
                    implicitHeight: 20
                    radius: 5

                    color: focused ? Theme.glowFill : Theme.pillBg
                    border.width: 1
                    border.color: focused ? Theme.glowEdge : Theme.pillBorder

                    Row {
                        id: pillRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: pill.modelData.name
                            color: pill.focused ? Theme.blue : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
                            font.bold: true
                        }

                        Repeater {
                            model: pill.glyphs
                            Text {
                                required property string modelData
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData
                                color: pill.focused ? Theme.blue : Theme.muted
                                font.family: Theme.icons
                                font.pixelSize: Theme.fontSize
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.modelData.activate()
                    }
                }
            }
        }

        // ---- focused window title --------------------------------------
        Label {
            Layout.fillWidth: true
            Layout.maximumWidth: 500
            elide: Text.ElideRight
            color: Theme.muted
            font.bold: false
            text: Hyprland.activeToplevel?.title ?? ""
        }

        Item { Layout.fillWidth: true }

        // ---- cpu / memory ----------------------------------------------
        Label {
            text: `CPU ${Sys.cpu}%`
            color: Sys.cpu > 85 ? Theme.red : Theme.yellow
        }
        Sep {}
        Label {
            text: `MEM ${Sys.mem}%`
            color: Sys.mem > 85 ? Theme.red : Theme.cyan
        }
        Sep {}

        // ---- wifi -------------------------------------------------------
        // The MouseArea is the layout child and the row anchors inside it. The
        // other way round puts anchors on a layout-managed item, which Qt warns
        // about and treats as undefined behavior.
        MouseArea {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: wifiRow.implicitWidth
            implicitHeight: wifiRow.implicitHeight
            cursorShape: Qt.PointingHandCursor
            // No network picker written yet, so hand off to nmtui in a terminal.
            onClicked: bar.run("uwsm-app -- ghostty -e nmtui")

            RowLayout {
                id: wifiRow
                anchors.fill: parent
                spacing: 6

                Icon {
                    text: Net.connected ? "\uf1eb" : "\uf127"
                    color: {
                        if (!Net.radioOn) return Theme.muted;
                        if (!Net.connected) return Theme.red;
                        return Net.bars >= 3 ? Theme.green : Theme.yellow;
                    }
                }
                Label {
                    text: {
                        if (!Net.radioOn) return "wifi off";
                        if (!Net.connected) return "offline";
                        return Net.ssid;
                    }
                    color: Net.connected ? Theme.fg : Theme.muted
                }
            }
        }
        Sep {}

        // ---- volume ------------------------------------------------------
        // Click toggles mute, scroll changes volume in 2% steps.
        MouseArea {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: volRow.implicitWidth
            implicitHeight: volRow.implicitHeight
            cursorShape: Qt.PointingHandCursor
            enabled: Audio.ready
            onClicked: Audio.sink.audio.muted = !Audio.sink.audio.muted
            onWheel: event => {
                const step = event.angleDelta.y > 0 ? 0.02 : -0.02;
                Audio.sink.audio.volume = Math.max(0, Math.min(1, Audio.volume + step));
            }

            RowLayout {
                id: volRow
                anchors.fill: parent
                spacing: 6

                Icon {
                    text: Audio.muted ? "\uf026" : "\uf028"
                    color: Audio.muted ? Theme.red : Theme.fg
                }
                Label {
                    text: `${Math.round(Audio.volume * 100)}%`
                    color: Audio.muted ? Theme.muted : Theme.fg
                }
            }
        }
        Sep {}

        // ---- battery -----------------------------------------------------
        RowLayout {
            spacing: 6
            Layout.alignment: Qt.AlignVCenter
            visible: Battery.present

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
            }
            Label {
                text: `${Battery.percent}%`
                color: Battery.low ? Theme.red : Theme.fg
            }
            Label {
                text: Battery.timeText
                color: Theme.muted
                font.bold: false
                visible: text !== ""
            }
        }
        Sep {}

        // ---- clock --------------------------------------------------------
        Label {
            id: clock
            color: Theme.blue
            text: Qt.formatDateTime(clock.now, "ddd MMM dd  HH:mm")

            property date now: new Date()
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clock.now = new Date()
            }
        }
    }
}
