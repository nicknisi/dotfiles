// MenuHint.qml - the small explanatory line inside a bar menu.
import QtQuick
import QtQuick.Layouts

Text {
    font.family: Theme.font
    font.pixelSize: Theme.fontSize - 3
    color: Theme.muted
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
}
