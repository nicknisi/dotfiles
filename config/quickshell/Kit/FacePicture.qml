import QtQuick
import QtQuick.Effects
import qs

// FacePicture.qml - the user's circle: the profile picture cropped to it, or
// the initial on `fillHigh` exactly as the boards draw it (the lock card's
// 44 / 16, the control center footer's 28 / 12, the polkit prompt's 18 / 10).
//
//   sources   file URLs to try in order (Face.urls: ~/.face, then the
//             AccountsService icon). Each is decoded asynchronously at twice
//             the drawn size, so the UI thread never waits on a file and a
//             50 MP photo decodes to 88 px; one that fails (empty, not an
//             image, too big for the reader) moves on to the next, and with
//             none left the initial stays.
//   initial   the letter drawn until a picture is ready, and when none is.
//
// The picture fills the circle (PreserveAspectCrop, centred) through a
// MultiEffect mask, as CcMedia crops its cover, and fades in over
// Motion.effects on top of the initial. With a picture the circle gets the
// Surface ring: 1 px `hairline` inside its edge. The mask's circle is 1 px
// inside the ring's outer edge, so the picture ends under the ring's fully
// covered pixels and never tints its outer antialiased ones (at scale 1.5
// the mask's soft edge reached under them). The initial has no ring, as
// before.
//
// QtQuick only (qmltestrunner loads it, Lock/AuthCard.qml uses it).
Item {
    id: root

    property real size: 44
    property var sources: []
    property string initial: "?"
    property real fontSize: 16
    // Which of `sources` is being tried; sources.length once none is left.
    property int tried: 0

    readonly property bool pictureShown: image.status === Image.Ready && String(image.source) !== ""
    readonly property string shownSource: pictureShown ? String(image.source) : ""
    readonly property bool loading: image.status === Image.Loading
    readonly property alias image: image
    readonly property alias initialText: initialText
    readonly property alias ring: ring

    width: size
    height: size
    Accessible.ignored: true

    // A new list starts again from its first file; the same list rebuilt (the
    // control center's footer recomputes on every volume step) changes nothing.
    readonly property string sourcesKey: JSON.stringify(root.sources ?? [])
    onSourcesKeyChanged: root.tried = 0

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Tokens.fillHigh
    }
    Text {
        id: initialText
        anchors.centerIn: parent
        text: root.initial
        visible: !root.pictureShown || cover.opacity < 1
        color: Tokens.fg
        textFormat: Text.PlainText
        font.family: "Adwaita Sans"
        font.pixelSize: root.fontSize
        font.weight: Font.Medium
    }

    Image {
        id: image
        anchors.fill: parent
        visible: false
        source: root.tried < (root.sources?.length ?? 0) ? root.sources[root.tried] : ""
        sourceSize: Qt.size(Math.ceil(root.size * 2), Math.ceil(root.size * 2))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        onStatusChanged: if (status === Image.Error) root.tried++
    }
    // The mask's texture is the whole circle's box (MultiEffect stretches it
    // over its own), with the disc 1 px in from the edge.
    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            objectName: "faceMaskDisc"
            anchors.fill: parent
            anchors.margins: 1
            radius: width / 2
        }
    }
    MultiEffect {
        id: cover
        objectName: "facePicture"
        anchors.fill: parent
        source: image
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
        opacity: root.pictureShown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.effects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spring
            }
        }
    }
    Rectangle {
        id: ring
        objectName: "faceRing"
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Tokens.hairline
        visible: cover.visible
        opacity: cover.opacity
    }
}
