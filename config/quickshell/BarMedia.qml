// Artwork and metadata in the bar; the full controls are the control
// center's media card (M4: a click opens the control center).
import QtQuick
import QtQuick.Layouts
import qs
import qs.Kit

BarChip {
    id: media
    property var player: Media.player
    property bool vertical: false
    property bool showDetails: !vertical
    property bool suppressClicks: false
    property var consumeClick: () => false
    property real wheelAccumulator: 0

    visible: player !== null
    implicitWidth: Math.max(32, Math.min(160, contentItem.implicitWidth + leftPadding + rightPadding))
    implicitHeight: 32
    padding: 2
    text: (player?.trackTitle || "Untitled track") + " · " + (player?.trackArtist || player?.identity || "Player")
    Accessible.description: "Click for media controls; middle-click to play or pause; scroll for next or previous track"
    onPlayerChanged: wheelAccumulator = 0
    onScrolled: delta => {
        if (suppressClicks || !player || delta === 0)
            return;
        if (wheelAccumulator * delta < 0)
            wheelAccumulator = 0;
        wheelAccumulator += delta;
        wheelReset.restart();
        if (Math.abs(wheelAccumulator) < 120)
            return;
        if (wheelAccumulator > 0 && player.canGoNext)
            player.next();
        else if (wheelAccumulator < 0 && player.canGoPrevious)
            player.previous();
        wheelAccumulator = 0;
    }
    Timer {
        id: wheelReset
        interval: 400
        onTriggered: media.wheelAccumulator = 0
    }
    Item {
        parent: media
        anchors.fill: parent
        TapHandler {
            acceptedButtons: Qt.MiddleButton
            onTapped: {
                if (!media.consumeClick() && media.player?.canTogglePlaying)
                    media.player.togglePlaying();
            }
        }
    }
    Rectangle {
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        Layout.alignment: Qt.AlignVCenter
        clip: true
        radius: 6
        color: Tokens.fillLow
        Image {
            id: cover
            objectName: "mediaArtwork"
            anchors.fill: parent
            source: media.player?.trackArtUrl ?? ""
            sourceSize.width: 64
            sourceSize.height: 64
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }
        Icon {
            objectName: "mediaArtworkFallback"
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            name: "music"
            size: 14
            color: Tokens.inkDim
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: media.showDetails && !media.vertical
        spacing: 0
        Text {
            objectName: "mediaTitle"
            Layout.fillWidth: true
            text: media.player?.trackTitle || "Untitled track"
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 11
            font.weight: Font.Medium
            color: Tokens.fg
            elide: Text.ElideRight
        }
        Text {
            objectName: "mediaArtist"
            Layout.fillWidth: true
            text: media.player?.trackArtist || media.player?.identity || "Player"
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 10
            color: Tokens.inkDim
            elide: Text.ElideRight
        }
    }
}
