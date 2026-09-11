import QtQuick
import qs.Commons

FocusScope {
    id: root
    property bool opened: false
    property string message: ""
    property string confirmText: "Confirm"
    property string cancelText: "Cancel"
    property color background: Color.menu.background
    property color foreground: Color.menu.text
    property color scrim: Color.menu.scrim
    property color selectedBackground: Color.menu.selectedBackground
    property color selectedText: Color.menu.selectedText
    property string fontFamily: Style.font.menuFamily
    property int cornerRadius: Style.cornerRadius
    property bool confirmSelected: false
    signal confirmed()
    signal canceled()
    visible: opened
    enabled: opened
    Accessible.role: Accessible.Dialog
    Accessible.name: message
    onOpenedChanged: if (opened) {
        confirmSelected = false
        Qt.callLater(function() { if (root.opened) cancelButton.forceActiveFocus() })
    }
    function handleKey(event) {
        if (!opened) return
        event.accepted = true
        if (event.isAutoRepeat) return
        if (event.key === Qt.Key_Escape) canceled()
        else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab || event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            confirmSelected = !confirmSelected
            if (confirmSelected) confirmButton.forceActiveFocus()
            else cancelButton.forceActiveFocus()
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (confirmSelected) confirmed()
            else canceled()
        }
    }
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: event => handleKey(event)
    Rectangle { anchors.fill: parent; color: root.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.canceled() }
    BorderSurface {
        anchors.centerIn: parent
        width: Math.max(0, Math.min(parent.width - Style.space(32), Style.space(440)))
        height: Math.min(parent.height, content.height + Style.space(40))
        color: root.background
        radius: root.cornerRadius
        borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
        MouseArea { anchors.fill: parent }
        Column {
            id: content
            x: Style.space(20)
            y: Style.space(20)
            width: parent.width - x * 2
            spacing: Style.space(20)
            Text {
                width: parent.width
                text: root.message
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
            }
            Row {
                anchors.right: parent.right
                spacing: Style.space(12)
                Button {
                    id: cancelButton
                    text: root.cancelText
                    focusable: true
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    onActiveFocusChanged: if (activeFocus) root.confirmSelected = false
                    onClicked: root.canceled()
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: event => root.handleKey(event)
                }
                Button {
                    id: confirmButton
                    text: root.confirmText
                    focusable: true
                    foreground: activeFocus ? root.selectedText : root.foreground
                    fontFamily: root.fontFamily
                    onActiveFocusChanged: if (activeFocus) root.confirmSelected = true
                    onClicked: root.confirmed()
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: event => root.handleKey(event)
                }
            }
        }
    }
}
