import QtQuick
import qs
import qs.Kit

// QuickTile.qml - one of the control center's four toggles (control-lock
// 2.3, Main board `cc`): Wi-Fi, Bluetooth, Tailscale, Do not disturb.
//
//   ←11→ (◉) ←10→ Wi-Fi           ←10→ [›] ←6→      174 x 70, radius 14
//               home-5g
//
// The disc is 36 round: `accent` with the icon in `onAccent` when on,
// `fillHigh` with `fg` when off, cross-faded over Motion.effects; at half
// opacity while `busy`. The text column is what is left, 75 px, and the sub
// elides there. The label (13 / 500) runs on to the chevron's glyph (91 px,
// into the chevron's box but clear of its stroke), so "Do not disturb"
// (88 px) reads whole, as the Main board draws it running under the chevron;
// a longer label still elides there. It draws above the chevron, so the
// chevron's hover fill never covers its last letter.
// The chevron (26 square, radius 8, `chev` 14 `inkDim`) opens the tile's sheet.
//
// Controlled: the disc asks with toggled(on) and leaves `checked` alone.
// Keys on the disc: Space or Enter toggles (the arrows move between tiles,
// ControlCenter); on the chevron, Space, Enter or Right opens the sheet.
// more(byKey) says whether a key (not the pointer) asked, so the sheet knows
// whether to draw its focus ring.
Rectangle {
    id: tile

    property string key: ""
    property string label: ""
    property string sub: ""
    property string icon: ""
    property bool checked: false
    property bool busy: false

    signal toggled(bool on)
    signal more(bool byKey)

    readonly property alias disc: disc
    readonly property alias chevron: chevron
    readonly property alias labelText: labelText
    readonly property alias subText: subText

    objectName: "ccTile-" + key
    implicitWidth: 174
    implicitHeight: 70
    radius: 14
    color: Tokens.raised
    border.width: 1
    border.color: Tokens.hairline

    Accessible.role: Accessible.Grouping
    Accessible.name: label + ", " + sub

    component Fade: NumberAnimation {
        duration: Motion.effects
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.spring
    }

    Item {
        id: disc
        x: 11
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36
        readonly property real radius: 18
        opacity: tile.busy ? 0.5 : tile.enabled ? 1 : 0.45
        activeFocusOnTab: tile.enabled
        Accessible.role: Accessible.Button
        Accessible.name: (tile.checked ? "Turn off " : "Turn on ") + tile.label
        Accessible.checkable: true
        Accessible.checked: tile.checked
        Accessible.onPressAction: tile.toggled(!tile.checked)
        Keys.onPressed: event => {
            if (event.isAutoRepeat) return;
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                tile.toggled(!tile.checked);
                event.accepted = true;
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: Tokens.fillHigh
        }
        Rectangle {
            id: onFill
            anchors.fill: parent
            radius: 18
            color: Tokens.accent
            opacity: tile.checked ? 1 : 0
            Behavior on opacity { Fade {} }
        }
        Icon {
            anchors.centerIn: parent
            name: tile.icon
            size: 16
            color: Tokens.fg
            opacity: 1 - onFill.opacity
        }
        Icon {
            anchors.centerIn: parent
            name: tile.icon
            size: 16
            color: Tokens.onAccent
            opacity: onFill.opacity
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggled(!tile.checked)
        }
        FocusRing { targetRadius: 18 }
    }

    Column {
        id: textColumn
        x: disc.x + disc.width + 10
        z: 1
        anchors.verticalCenter: parent.verticalCenter
        width: chevron.x - 10 - x
        spacing: 2
        Text {
            id: labelText
            // To the chevron glyph's box (14 centred in 26).
            width: chevron.x + (chevron.width - 14) / 2 - textColumn.x
            text: tile.label
            color: Tokens.fg
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 13
            font.weight: Font.Medium
            Accessible.ignored: true
        }
        Text {
            id: subText
            width: parent.width
            text: tile.sub
            color: Tokens.inkDim
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 12
            Accessible.ignored: true
        }
    }

    Rectangle {
        id: chevron
        x: tile.width - 6 - width
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26
        radius: 8
        color: chevArea.containsMouse || activeFocus ? Tokens.fillLow : "transparent"
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: tile.label + " settings"
        Accessible.onPressAction: tile.more(true)
        Keys.onPressed: event => {
            if (event.isAutoRepeat || event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) return;
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Right) {
                tile.more(true);
                event.accepted = true;
            }
        }
        Icon {
            anchors.centerIn: parent
            name: "chev"
            size: 14
            color: Tokens.inkDim
        }
        MouseArea {
            id: chevArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.more(false)
        }
        FocusRing {}
    }
}
