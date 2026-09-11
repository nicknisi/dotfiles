import QtQuick
import QtQuick.Controls as Controls
import qs.Commons

Controls.Button {
    id: root
    property color foreground: Color.menu.text
    property color accent: Color.accent
    property string fontFamily: Style.font.menuFamily
    property int fontSize: Style.font.bodySmall
    property bool focusable: false
    property string tooltipText: ""
    focusPolicy: focusable ? Qt.StrongFocus : Qt.NoFocus
    font.family: fontFamily
    font.pixelSize: fontSize
    padding: Style.space(8)
    horizontalPadding: Style.space(12)
    implicitHeight: Math.max(Style.space(30), contentItem.implicitHeight + topPadding + bottomPadding)
    contentItem: Text {
        text: root.text
        textFormat: Text.PlainText
        color: root.foreground
        font: root.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: BorderSurface {
        radius: Style.cornerRadius
        color: Style.controlFill(root.activeFocus || root.down, root.hovered, root.foreground, root.accent)
        borderSpec: Border.controlSpec(root.activeFocus ? "focus" : "normal", root.foreground, root.accent)
    }
    Controls.ToolTip.visible: hovered && tooltipText.length > 0
    Controls.ToolTip.text: tooltipText
    Controls.ToolTip.delay: 600
    Accessible.name: text
}
