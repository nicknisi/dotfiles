// BarModule.qml - one clickable thing in the bar.
//
// Everything in the bar that reacts to a pointer is one of these, so hover, the
// open-menu state and the expanding label behave identically everywhere.
//
// The label is the trim-hard compromise: the bar carries glyphs, and the words
// behind them slide out only when you point at one. It animates its own width
// from zero rather than toggling visible, so the modules beside it slide over
// instead of jumping.
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: mod

    // Text that expands on hover. Empty means the module is glyph-only.
    property string reveal: ""

    // Held open while this module's menu is showing.
    property bool highlighted: false

    // 0..1 draws a dim hairline along the bottom edge, under the hover accent.
    // Negative means the module has nothing to report, which is most of them.
    property real progress: -1

    default property alias content: inner.data

    readonly property bool lit: mod.containsMouse || mod.highlighted

    // Driven as a property rather than bound straight onto Layout.preferredWidth,
    // because a Behavior cannot be attached to an attached property.
    property real revealWidth: (mod.containsMouse && mod.reveal !== "") ? label.implicitWidth : 0
    Behavior on revealWidth {
        NumberAnimation { duration: Theme.base; easing.type: Easing.OutCubic }
    }

    Layout.alignment: Qt.AlignVCenter
    implicitWidth: outer.implicitWidth + 14
    implicitHeight: Theme.barHeight - Theme.borderWidth * 2 - 6
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        color: Theme.raised
        radius: Theme.radius
        opacity: mod.lit ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        height: 1
        width: parent.width * Math.max(0, mod.progress)
        visible: mod.progress >= 0
        color: Theme.muted
        opacity: 0.7
    }

    // The same accent the window manager paints on a focused border, opening
    // from the middle. It is how a module says "this one, and its menu".
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        height: Theme.borderWidth
        width: mod.lit ? parent.width : 0
        color: Theme.borderActive
        Behavior on width {
            NumberAnimation { duration: Theme.base; easing.type: Easing.OutCubic }
        }
    }

    RowLayout {
        id: outer
        anchors.fill: parent
        anchors.leftMargin: 7
        anchors.rightMargin: 7
        spacing: 0

        // Nested so the label always lands after the module's own children;
        // anything aliased into a layout is appended, and the label has to sit
        // on the right of the glyph it explains.
        RowLayout {
            id: inner
            Layout.alignment: Qt.AlignVCenter
            spacing: 6
        }

        Text {
            id: label
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: mod.revealWidth
            Layout.leftMargin: Math.min(6, mod.revealWidth)
            clip: true
            text: mod.reveal
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
            color: Theme.muted
        }
    }
}
