// AudioMenu.qml - output and input: what is playing, what is listening, and
// which device each of them is using.
//
// The per-app faders are the reason this exists rather than a bare slider on the
// bar. They are the one thing scrolling the module cannot do, and the one thing
// that otherwise means opening pavucontrol.
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

BarMenu {
    id: menu

    menuWidth: 310
    title: "Audio"
    subtitle: `${Audio.labelFor(Audio.sink)}  ·  ${Audio.labelFor(Audio.source)}`

    // A glyph that toggles mute, a slider, and the number. Output and input are
    // the same row with different sources, so they are the same component.
    component Level: RowLayout {
        id: lvl

        property string glyph: ""
        property string mutedGlyph: ""
        property bool off: false
        property real value: 0
        property color tint: Theme.accent

        signal moved(real v)
        signal toggled()

        Layout.fillWidth: true
        spacing: 8

        MouseArea {
            id: toggle
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 20
            implicitHeight: 20
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: lvl.toggled()

            Text {
                anchors.centerIn: parent
                font.family: Theme.icons
                font.pixelSize: 15
                color: lvl.off ? Theme.red : (toggle.containsMouse ? Theme.accent : Theme.fg)
                text: lvl.off ? lvl.mutedGlyph : lvl.glyph
                Behavior on color { ColorAnimation { duration: Theme.quick } }
            }
        }

        MenuSlider {
            Layout.fillWidth: true
            value: lvl.off ? 0 : lvl.value
            tint: lvl.off ? Theme.muted : lvl.tint
            onMoved: v => lvl.moved(v)
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 32
            horizontalAlignment: Text.AlignRight
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
            color: lvl.off ? Theme.muted : Theme.fg
            text: `${Math.round(lvl.value * 100)}%`
        }
    }

    // One row in a device list. The rail on the left is the same mark the bar
    // slides between workspaces: in this shell it always means "this is the one".
    component DeviceRow: MouseArea {
        id: dev

        property string label: ""
        property bool current: false

        Layout.fillWidth: true
        implicitHeight: 26
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.raised
            opacity: dev.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.quick } }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.borderWidth
            height: parent.height - 8
            color: Theme.borderActive
            visible: dev.current
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            Text {
                Layout.alignment: Qt.AlignVCenter
                font.family: Theme.icons
                font.pixelSize: 14
                color: dev.current ? Theme.accent : Theme.muted
                text: Icons.forSink(dev.label)
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
                font.bold: dev.current
                color: dev.current ? Theme.fg : Theme.muted
                text: dev.label
            }
        }
    }

    // A named app with its own fader.
    component StreamRow: RowLayout {
        id: stream

        property var node: null
        property color tint: Theme.cyan

        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.preferredWidth: 92
            Layout.alignment: Qt.AlignVCenter
            elide: Text.ElideRight
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
            color: Theme.fg
            text: Audio.appFor(stream.node)
        }

        MenuSlider {
            Layout.fillWidth: true
            value: stream.node?.audio?.volume ?? 0
            tint: stream.tint
            onMoved: v => Audio.setVolume(stream.node, v)
        }
    }

    // ---- output ------------------------------------------------------------
    MenuHeading { text: "output" }

    Level {
        glyph: "\u{f057e}"       // md volume-high
        mutedGlyph: "\u{f0581}"  // md volume-off
        off: Audio.muted
        value: Audio.volume
        tint: Theme.accent
        onToggled: if (Audio.ready) Audio.sink.audio.muted = !Audio.muted
        onMoved: v => Audio.setVolume(Audio.sink, v)
    }

    Repeater {
        // A single output is not a choice, so it is not drawn as one.
        model: Audio.sinks.length > 1 ? Audio.sinks : []

        DeviceRow {
            required property var modelData
            label: Audio.labelFor(modelData)
            current: Audio.isDefault(modelData)
            onClicked: Audio.setDefault(modelData)
        }
    }

    // ---- input -------------------------------------------------------------
    MenuHeading { text: "input" }

    Level {
        glyph: "\uf130"          // fa microphone
        mutedGlyph: "\uf131"     // fa microphone-slash
        off: Audio.micMuted
        value: Audio.micVolume
        tint: Theme.green
        onToggled: if (Audio.source?.audio) Audio.source.audio.muted = !Audio.micMuted
        onMoved: v => Audio.setVolume(Audio.source, v)
    }

    Repeater {
        model: Audio.sources.length > 1 ? Audio.sources : []

        DeviceRow {
            required property var modelData
            label: Audio.labelFor(modelData)
            current: Audio.isDefaultSource(modelData)
            onClicked: Audio.setDefaultSource(modelData)
        }
    }

    // ---- apps --------------------------------------------------------------
    MenuHeading {
        text: "playing"
        visible: Audio.streams.length > 0
    }

    Repeater {
        model: Audio.streams
        StreamRow {
            required property var modelData
            node: modelData
            tint: Theme.cyan
        }
    }

    // Worth its own section rather than a footnote: this is the list of things
    // currently holding the microphone open.
    MenuHeading {
        text: "listening"
        visible: Audio.recorders.length > 0
    }

    Repeater {
        model: Audio.recorders
        StreamRow {
            required property var modelData
            node: modelData
            tint: Theme.green
        }
    }

    MenuHint {
        visible: Audio.streams.length === 0 && Audio.recorders.length === 0
        text: "no app is playing or recording"
    }
}
