import QtQuick
import qs

// PillButton.qml - a fully round text button.
//
// tone     fill        ring       ink        mock use
// strong   fillHigh    none       fg         Run, Open, Change/Assign (default)
// quiet    fillLow     hairline   fg         Cancel
// outline  none        hairline   fg         Actions
// accent   accent      none       onAccent   Authenticate (13/500)
//
// Heights 34 (13 px text), 30 and 26 (12 px). `hint` is the dim mono suffix in
// "Run ↵". Hover and press tint the fill with the ink colour; the mocks do not
// draw either state.
//
// Enter, Return or Space press it when it has focus. A click never gives it
// focus, so the focus ring only answers the keyboard.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property string hint: ""
    property string tone: "strong"
    property int size: 34
    property int fontSize: size >= 34 ? 13 : 12
    property int fontWeight: tone === "accent" ? Font.Medium : Font.Normal
    property int padX: 14
    property color ink: tone === "accent" ? Tokens.onAccent : Tokens.fg

    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    signal clicked()

    implicitHeight: size
    implicitWidth: Math.ceil(content.implicitWidth) + 2 * padX
    radius: height / 2
    color: tone === "accent" ? Tokens.accent
         : tone === "quiet" ? Tokens.fillLow
         : tone === "outline" ? "transparent"
         : Tokens.fillHigh
    border.color: Tokens.hairline
    border.width: tone === "quiet" || tone === "outline" ? 1 : 0
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: enabled

    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.focusable: true
    Accessible.onPressAction: root.clicked()

    Keys.onPressed: event => {
        if (event.isAutoRepeat) return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.clicked();
            event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.ink
        opacity: root.pressed ? 0.12 : root.hovered ? 0.07 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.effects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spring
            }
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 8

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            size: 16
            color: root.ink
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: root.text
            color: root.ink
            font.family: "Adwaita Sans"
            font.pixelSize: root.fontSize
            font.weight: root.fontWeight
            Accessible.ignored: true
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: root.hint
            color: root.tone === "accent" ? root.ink : Tokens.inkDim
            font.family: "Monaspace Argon"
            font.pixelSize: 11
            Accessible.ignored: true
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    FocusRing {}
}
