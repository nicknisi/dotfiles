import QtQuick
import qs
import qs.Kit

// MiniTile.qml - one of the control center's six small buttons (control-lock
// 2.6, Main board `cc`): Keep awake, Power mode, Display, Theme, Record,
// Clipboard.
//
//   ←12→ ☕                    a column, centred, 4 apart, the sub 3 closer
//        Keep awake            12 / 500
//        1 hour                11 `inkDim`
//
// `raised`, radius 12, a 1 px ring: `accent` when on, `hairline` otherwise
// (cross-faded over Motion.effects); the icon is `accent` when on. Both text
// lines elide inside the 90.7 px the box leaves (theme names run to 89).
//
// clicked(byKey) on a press, Enter or Space; more(byKey) on a right click, a
// long press or Alt+Right (Keep awake's durations sheet, control-lock 3.6).
// byKey: a key asked, not the pointer (a sheet it opens draws its ring).
Rectangle {
    id: mini

    property string key: ""
    property string label: ""
    property string sub: ""
    property string icon: ""
    property bool checked: false

    signal clicked(bool byKey)
    signal more(bool byKey)

    readonly property alias labelText: labelText
    readonly property alias subText: subText

    objectName: "ccMini-" + key
    implicitWidth: 114
    implicitHeight: 64
    radius: 12
    color: area.containsMouse ? Qt.tint(Tokens.raised, Qt.rgba(Tokens.fg.r, Tokens.fg.g, Tokens.fg.b, 0.04)) : Tokens.raised
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: label + ", " + sub
    Accessible.onPressAction: mini.clicked(true)

    Keys.onPressed: event => {
        if (event.isAutoRepeat) return;
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            mini.clicked(true);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right && event.modifiers & Qt.AltModifier) {
            mini.more(true);
            event.accepted = true;
        }
    }

    component Fade: NumberAnimation {
        duration: Motion.effects
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.spring
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: 1
        border.color: Tokens.hairline
    }
    Rectangle {
        id: onRing
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: 1
        border.color: Tokens.accent
        opacity: mini.checked ? 1 : 0
        Behavior on opacity { Fade {} }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Item {
            width: 16
            height: 16
            Icon {
                anchors.fill: parent
                name: mini.icon
                size: 16
                color: Tokens.fg
                opacity: 1 - onRing.opacity
            }
            Icon {
                anchors.fill: parent
                name: mini.icon
                size: 16
                color: Tokens.accent
                opacity: onRing.opacity
            }
        }
        Text {
            id: labelText
            width: parent.width
            text: mini.label
            color: Tokens.fg
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 12
            font.weight: Font.Medium
            Accessible.ignored: true
        }
        Text {
            id: subText
            width: parent.width
            // margin-top -3 (the board), as a negative gap.
            topPadding: -3
            height: implicitHeight - 3
            text: mini.sub
            color: Tokens.inkDim
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 11
            Accessible.ignored: true
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => mouse.button === Qt.RightButton ? mini.more(false) : mini.clicked(false)
        onPressAndHold: mini.more(false)
    }
    FocusRing {}
}
