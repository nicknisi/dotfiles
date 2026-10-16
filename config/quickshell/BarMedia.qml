// Artwork and metadata in the bar; full controls live in the media popup.
import QtQuick
import QtQuick.Layouts

BarModule {
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
        color: Theme.raised
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
        Text {
            objectName: "mediaArtworkFallback"
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: "\uf001"
            font.family: Theme.icons
            font.pixelSize: 14
            color: Theme.secondary
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
            font.family: Theme.font
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: Theme.fg
            elide: Text.ElideRight
        }
        Text {
            objectName: "mediaArtist"
            Layout.fillWidth: true
            text: media.player?.trackArtist || media.player?.identity || "Player"
            textFormat: Text.PlainText
            font.family: Theme.font
            font.pixelSize: 9
            color: Theme.secondary
            elide: Text.ElideRight
        }
    }
}
