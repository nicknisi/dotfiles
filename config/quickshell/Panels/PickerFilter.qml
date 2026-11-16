import QtQuick
import qs
import qs.Kit

// PickerFilter.qml - the pickers' filter pill (launcher-pickers 7.1): 200 x 30,
// radius 15, `fillLow` with a 1 px `hairline` ring, padding 0 12, gap 8, the
// search icon at 14 in `inkDim`, text at 12. Empty: "Type to filter" in
// `inkDim`. Typing: the filter in `fg` and the launcher's caret (a 2 px
// `accent` bar blinking in 500 ms steps, never a smooth loop, still while the
// motion profile is off). The keys go to the panel, not here: this only draws.
Rectangle {
    id: pill

    property string text: ""
    property bool active: false
    readonly property alias label: label

    implicitWidth: 200
    implicitHeight: 30
    radius: 15
    color: Tokens.fillLow
    border.width: 1
    border.color: Tokens.hairline
    Accessible.role: Accessible.EditableText
    Accessible.name: "Filter"
    Accessible.description: pill.text

    Icon {
        id: icon
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        name: "search"
        size: 14
        color: Tokens.inkDim
    }
    Text {
        id: label
        anchors.left: icon.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, pill.width - 12 - 14 - 8 - 12 - 4)
        text: pill.text !== "" ? pill.text : "Type to filter"
        textFormat: Text.PlainText
        elide: Text.ElideLeft
        color: pill.text !== "" ? Tokens.fg : Tokens.inkDim
        font.family: "Adwaita Sans"
        font.pixelSize: 12
    }
    Rectangle {
        id: caret
        property bool on: true
        x: label.x + label.width + 1
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 16
        color: Tokens.accent
        visible: pill.active && pill.text !== "" && on
        Timer {
            interval: 500
            repeat: true
            running: pill.active && pill.text !== "" && Motion.loops && pill.visible
            onTriggered: caret.on = !caret.on
            onRunningChanged: caret.on = true
        }
    }
    onTextChanged: caret.on = true
}
