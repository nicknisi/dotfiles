// Controls existing MPRIS players. Artwork never overrides the shell palette.
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card

    property bool active: false
    property var player: Media.player
    readonly property bool playing: player?.isPlaying ?? false
    readonly property bool canSeek: !!player && player.canSeek && player.positionSupported
        && player.lengthSupported && player.length > 0
    property real position: 0

    implicitWidth: 380
    implicitHeight: content.implicitHeight + 24
    radius: 22
    bottomLeftRadius: 12
    color: Theme.raised
    onPlayerChanged: refreshPosition()
    onActiveChanged: if (active) refreshPosition()

    function refreshPosition() { position = Math.max(0, player?.position ?? 0) }
    function formatTime(seconds) {
        const s = Math.max(0, Math.floor(seconds || 0));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // MPRIS position is interpolated on read, not notified every second.
    Timer {
        interval: 1000
        repeat: true
        running: card.active && !!card.player && card.player.positionSupported
        onTriggered: card.refreshPosition()
    }
    Connections {
        target: card.player
        function onPositionChanged() { card.refreshPosition() }
        function onPostTrackChanged() {
            card.refreshPosition();
            if (card.active) settle.restart();
        }
    }

    ColumnLayout {
        id: content
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Item {
                Layout.preferredWidth: 108
                Layout.preferredHeight: 112

                Rectangle {
                    x: 3
                    y: 7
                    width: 102
                    height: 102
                    radius: 20
                    rotation: 7
                    color: Theme.glowFill
                }
                ClippingRectangle {
                    id: art
                    y: 3
                    width: 104
                    height: 104
                    radius: 18
                    rotation: artHover.hovered ? -5 : (card.playing ? -2 : 2)
                    color: Theme.sunken
                    Behavior on rotation { NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack } }

                    Image {
                        id: cover
                        anchors.fill: parent
                        source: card.player?.trackArtUrl ?? ""
                        sourceSize.width: 256
                        sourceSize.height: 256
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.base } }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: cover.status !== Image.Ready
                        text: "\uf001"
                        color: Theme.accent
                        font.family: Theme.icons
                        font.pixelSize: 34
                        rotation: -12
                    }
                    HoverHandler { id: artHover }
                }

                SequentialAnimation {
                    id: settle
                    ParallelAnimation {
                        NumberAnimation { target: art; property: "y"; to: -3; duration: Theme.quick }
                        NumberAnimation { target: art; property: "scale"; to: 0.96; duration: Theme.quick }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: art; property: "y"; to: 3; duration: Theme.unfold; easing.type: Easing.OutBack }
                        NumberAnimation { target: art; property: "scale"; to: 1; duration: Theme.unfold; easing.type: Easing.OutBack }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                Text {
                    Layout.fillWidth: true
                    text: card.player ? (card.player.trackTitle || "Untitled track") : "Ready when you are"
                    textFormat: Text.PlainText
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 4
                    font.bold: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: card.player ? (card.player.trackArtist || card.player.identity) : "Start something in your favorite player."
                    textFormat: Text.PlainText
                    color: Theme.secondary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                RowLayout {
                    Layout.topMargin: 3
                    spacing: 10
                    BarModule {
                        objectName: "previous"
                        text: "Previous track"
                        enabled: card.player?.canGoPrevious ?? false
                        onClicked: card.player.previous()
                        Text { text: "\uf048"; font.family: Theme.icons; font.pixelSize: 14; color: Theme.fg; Layout.alignment: Qt.AlignCenter }
                    }
                    BarModule {
                        id: playButton
                        objectName: "playPause"
                        text: card.playing ? "Pause" : "Play"
                        implicitWidth: 54
                        implicitHeight: 36
                        enabled: card.player?.canTogglePlaying ?? false
                        onClicked: card.player.togglePlaying()
                        background: Rectangle {
                            radius: card.playing ? 10 : 18
                            rotation: playButton.hovered ? -9 : 0
                            color: Theme.accent
                            border.width: playButton.visualFocus ? 2 : 0
                            border.color: Theme.fg
                            Behavior on radius { NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack } }
                            Behavior on rotation { NumberAnimation { duration: Theme.base; easing.type: Easing.OutBack } }
                        }
                        Text {
                            text: card.playing ? "\uf04c" : "\uf04b"
                            font.family: Theme.icons
                            font.pixelSize: 16
                            color: Theme.surface
                            Layout.alignment: Qt.AlignCenter
                        }
                    }
                    BarModule {
                        objectName: "next"
                        text: "Next track"
                        enabled: card.player?.canGoNext ?? false
                        onClicked: card.player.next()
                        Text { text: "\uf051"; font.family: Theme.icons; font.pixelSize: 14; color: Theme.fg; Layout.alignment: Qt.AlignCenter }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: card.player !== null
            Text {
                text: card.player?.positionSupported ? card.formatTime(card.position) : "--:--"
                color: Theme.secondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 3
            }
            MenuSlider {
                objectName: "seek"
                Layout.fillWidth: true
                label: "Seek position"
                value: card.canSeek ? Math.min(1, card.position / card.player.length) : 0
                enabled: card.canSeek
                opacity: enabled ? 1 : 0.35
                onMoved: v => {
                    if (!card.canSeek) return;
                    card.player.position = Math.max(0, Math.min(1, v)) * card.player.length;
                    card.refreshPosition();
                }
            }
            Text {
                text: card.player?.lengthSupported ? card.formatTime(card.player.length) : "--:--"
                color: Theme.secondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 3
            }
            BarModule {
                visible: Media.players.length > 1
                text: `${card.player?.identity ?? "Player"} · Switch player`
                implicitWidth: 26
                implicitHeight: 26
                padding: 2
                onClicked: Media.selectNext()
                Text { text: "↻"; font.family: Theme.font; font.pixelSize: 16; color: Theme.accent; Layout.alignment: Qt.AlignCenter }
            }
        }
    }
}
