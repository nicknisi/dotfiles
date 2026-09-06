// One HUD page. The single popup in Hud.qml owns focus and dismissal, so
// changing pages never releases the Wayland popup grab between controls.
import QtQuick
import QtQuick.Layouts

Item {
    id: menu

    property int menuWidth: 320
    property string title: ""
    property string subtitle: ""
    property Component accessory: null
    property bool shown: false
    default property alias menuContent: content.data
    signal dismissed()

    implicitWidth: menuWidth
    implicitHeight: body.implicitHeight

    ColumnLayout {
        id: body
        width: parent.width
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: menu.title !== ""

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: menu.title
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 5
                    font.bold: true
                    color: Theme.fg
                }
                Text {
                    Layout.fillWidth: true
                    text: menu.subtitle
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    color: Theme.secondary
                    elide: Text.ElideRight
                    visible: text !== ""
                }
            }

            Loader {
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: menu.accessory
            }
        }

        ColumnLayout {
            id: content
            Layout.fillWidth: true
            spacing: 6
        }
    }
}
