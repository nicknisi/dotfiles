// BarMenu.qml - the base of the one old page left, AppearanceMenu (the
// classic bars' anchored host shows it on its page frame, Hosts/AnchoredView).
// The other pages went in M10: their content lives on in the control
// center's sheets (Panels/Sheets).
//
// A column of controls under an optional header (the title 15 / 500, the
// subtitle 12 `inkDim`, the island's type). On the host's frame (`framed`)
// the frame's header carries the title and the subtitle, so this one hides.
import QtQuick
import QtQuick.Layouts

Item {
    id: menu

    property int menuWidth: 320
    property string title: ""
    property string subtitle: ""
    property Component accessory: null
    property bool shown: false
    property bool framed: false
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
            visible: menu.title !== "" && !menu.framed

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: menu.title
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.family: "Adwaita Sans"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    color: Tokens.fg
                }
                Text {
                    Layout.fillWidth: true
                    text: menu.subtitle
                    textFormat: Text.PlainText
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                    color: Tokens.inkDim
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
