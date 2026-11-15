import QtQuick
import qs
import qs.Kit

// LevelsCard.qml - the control center's volume and brightness rows
// (control-lock 2.5, Main board `cc`).
//
//   ←12→ 🔊 ←12→ [========------] ←12→  62 ←12→      Speakers ›  ←12→
//
// `raised`, radius 14, hairline, padding 6 12; each row 40 high, 12 apart
// across: the icon (16 `fg`; pressing the volume one mutes, as the old HUD
// did [GUESS]), a Kit Slider filling the rest (its whole 40 px row is the
// drag target, no thumb [GUESS]), the value (26 wide, Monaspace 12, 0 to
// 100, no %) and the device button (112 wide, right-aligned: 12 `inkDim`
// then `chev` 14) that opens the row's sheet. Muted: the fill in `inkDim`,
// the value still the stored level [GUESS].
//
// rows: [{ key, icon, label, value, muted, device, enabled }] (CcData.levels).
// The Repeater counts them rather than take the array, so a level changing
// under a drag updates the row in place and the drag holds (M6 review). The
// sliders take Left and Right; Up and Down move focus (ControlCenter).
// device(key, byKey): byKey when a key asked, not the pointer.
Rectangle {
    id: card

    property var rows: []

    signal moved(string key, real value)
    signal iconClicked(string key)
    signal device(string key, bool byKey)

    readonly property alias repeater: repeater

    implicitWidth: 728
    implicitHeight: 92
    radius: 14
    color: Tokens.raised
    border.width: 1
    border.color: Tokens.hairline

    Column {
        x: 12
        y: 6
        width: parent.width - 24
        Repeater {
            id: repeater
            model: card.rows.length
            Item {
                id: row
                required property int index
                readonly property var entry: card.rows[index] ?? ({})
                readonly property alias slider: slider
                readonly property alias valueText: valueText
                objectName: "ccLevel-" + (entry.key ?? "")
                width: parent.width
                height: 40
                enabled: row.entry.enabled !== false

                Item {
                    id: iconBox
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    Icon {
                        anchors.fill: parent
                        name: row.entry.icon ?? ""
                        size: 16
                        color: Tokens.fg
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.iconClicked(row.entry.key)
                    }
                }
                Slider {
                    id: slider
                    x: iconBox.width + 12
                    width: valueText.x - 12 - x
                    height: 40
                    anchors.verticalCenter: parent.verticalCenter
                    value: Number(row.entry.value) || 0
                    label: row.entry.label ?? ""
                    verticalKeys: false
                    fillColor: row.entry.muted ? Tokens.inkDim : Tokens.accent
                    onMoved: v => card.moved(row.entry.key, v)
                }
                Text {
                    id: valueText
                    x: deviceButton.x - 12 - width
                    width: 26
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: String(Math.round(100 * (slider.dragging ? slider.shown : (Number(row.entry.value) || 0))))
                    color: Tokens.fg
                    textFormat: Text.PlainText
                    font.family: "Monaspace Argon"
                    font.pixelSize: 12
                }
                Item {
                    id: deviceButton
                    x: parent.width - width
                    width: 112
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter
                    activeFocusOnTab: true
                    readonly property real radius: 8
                    Accessible.role: Accessible.Button
                    Accessible.name: (row.entry.label ?? "") + " device, " + (row.entry.device ?? "")
                    Accessible.onPressAction: card.device(row.entry.key, true)
                    Keys.onPressed: event => {
                        if (event.isAutoRepeat) return;
                        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            card.device(row.entry.key, true);
                            event.accepted = true;
                        }
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, 112 - 18)
                            elide: Text.ElideRight
                            text: row.entry.device ?? ""
                            color: Tokens.inkDim
                            textFormat: Text.PlainText
                            font.family: "Adwaita Sans"
                            font.pixelSize: 12
                        }
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "chev"
                            size: 14
                            color: Tokens.inkDim
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.device(row.entry.key, false)
                    }
                    FocusRing {}
                }
            }
        }
    }
}
