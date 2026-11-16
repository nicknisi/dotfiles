import QtQuick
import Quickshell.Widgets
import qs

// PickerThumb.qml - a picker card's image (PLAN M7, launcher-pickers 7.1 and
// 7.2): cropped to fill, radius 10, decoded at `sourceSize` (the display size
// times the device pixel ratio, so 37 thumbnails decode small; the old
// carousel decoded every one at 1440 x 900). A `fillLow` placeholder shows
// until it has loaded, or when it cannot.
//
// The one picker file that imports Quickshell (Widgets' ClippingRectangle,
// for the rounded crop): tests/pickers.sh stands a plain Image in for it. The
// clip's own colour is transparent and never changes, so a theme preview
// retinting the panel does not redraw 37 clip textures; the placeholder that
// does retint sits outside it.
Item {
    id: thumb

    property string source: ""
    property size sourceSize: Qt.size(0, 0)
    property real radius: 10
    readonly property alias status: image.status

    Rectangle {
        anchors.fill: parent
        radius: thumb.radius
        color: Tokens.fillLow
        visible: image.status !== Image.Ready
    }
    ClippingRectangle {
        anchors.fill: parent
        radius: thumb.radius
        color: "transparent"
        visible: image.status === Image.Ready
        Image {
            id: image
            anchors.fill: parent
            source: thumb.source
            sourceSize: thumb.sourceSize
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
        }
    }
}
