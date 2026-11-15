import QtQuick
import qs
import qs.Kit

// ResultRow.qml - one launcher result (launcher-pickers 4.2, Main board).
//
//   [tile] Title, matched letters 600 over a faint underline    [Super] [B]
//          subtitle 11 inkDim
//
// 48 high, radius 10, padding 0 10, gap 12; a 30 px tile (radius 8) with a
// 16 px icon. `dense` is the clipboard and voice geometry: 46, tile 28, icon
// 14. `compactText` is the clipboard's text on top of that: content 12 (sans
// or mono), gap 10, 1 between the lines; voice rows keep title 13 and gap 12
// (launcher-pickers 5.1, 5.4). Selected: `accentTint` behind it (fading over Motion.effects), the
// tile on `fillHigh`, the icon in `accent`; otherwise the tile is `fillLow`.
// Apps show their desktop icon in the tile; an emoji row shows its emoji.
// While Ctrl is held the first eight rows show their digit (Ctrl+1..8).
// A palette hotkey's chord trails as keycaps; the selected row shows its hint.
//
// Fixed roles only: the engine updates delegates in place while typing, so
// nothing here depends on object identity.
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string glyph: ""
    property string iconText: ""
    property string iconFont: ""
    property string iconSource: ""
    property string accessory: ""
    property string badge: ""
    property string hint: ""
    property string shortcut: ""
    property string ranges: "[]"
    property bool mono: false
    property bool dense: false
    property bool compactText: false
    property bool disabled: false
    property bool selected: false
    property int flashRise: 0
    property int flashFall: 0

    signal activated
    signal hovered(var item, var mouse)

    readonly property int tileSize: dense ? 28 : 30
    readonly property int iconSize: dense ? 14 : 16
    readonly property var keys: accessory ? accessory.split(/\s*\+\s*/).filter(k => k !== "") : []

    implicitHeight: dense ? 46 : 48
    opacity: disabled ? 0.62 : 1
    Accessible.role: Accessible.ListItem
    Accessible.name: title + (subtitle ? ". " + subtitle : "")
    Accessible.selectable: true
    Accessible.selected: selected
    Accessible.onPressAction: root.activated()

    function flash() {
        if (root.flashRise + root.flashFall <= 0) return;
        flashAnim.restart();
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Tokens.accentTint
        opacity: root.selected ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.effects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spring
            }
        }
    }
    Rectangle {
        id: flashLayer
        anchors.fill: parent
        radius: 10
        color: Tokens.fg
        opacity: 0
        SequentialAnimation {
            id: flashAnim
            NumberAnimation { target: flashLayer; property: "opacity"; to: 0.3; duration: root.flashRise; easing.type: Easing.OutQuad }
            NumberAnimation { target: flashLayer; property: "opacity"; to: 0; duration: root.flashFall; easing.type: Easing.InQuad }
        }
    }

    Rectangle {
        id: tile
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: root.tileSize
        height: root.tileSize
        radius: 8
        color: root.selected ? Tokens.fillHigh : Tokens.fillLow

        Text {
            anchors.centerIn: parent
            visible: root.shortcut !== ""
            text: root.shortcut
            color: Tokens.accent
            font.family: "Monaspace Argon"
            font.pixelSize: 13
            font.weight: Font.Medium
        }
        Image {
            id: appIcon
            anchors.centerIn: parent
            visible: root.shortcut === "" && root.iconSource !== "" && status === Image.Ready
            width: root.iconSize + 4
            height: width
            source: root.iconSource
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
        }
        Icon {
            anchors.centerIn: parent
            visible: root.shortcut === "" && !appIcon.visible && root.glyph !== ""
            name: root.glyph
            size: root.iconSize
            color: root.selected ? Tokens.accent : Tokens.fg
        }
        Text {
            anchors.centerIn: parent
            visible: root.shortcut === "" && !appIcon.visible && root.glyph === ""
            text: root.iconText
            textFormat: Text.PlainText
            color: root.selected ? Tokens.accent : Tokens.fg
            font.family: root.iconFont || "Adwaita Sans"
            font.pixelSize: root.iconSize
        }
    }

    Row {
        id: trailing
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Repeater {
            model: root.keys
            Keycap {
                required property string modelData
                text: modelData
            }
        }
        Text {
            visible: root.keys.length === 0 && root.hint !== "" && root.selected
            anchors.verticalCenter: parent.verticalCenter
            text: root.hint
            textFormat: Text.PlainText
            color: Tokens.inkDim
            font.family: "Monaspace Argon"
            font.pixelSize: 11
        }
    }

    Column {
        anchors.left: tile.right
        anchors.leftMargin: root.compactText ? 10 : 12
        anchors.right: trailing.left
        anchors.rightMargin: trailing.width > 0 ? 12 : 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.compactText ? 1 : 2
        Row {
            width: parent.width
            spacing: 6
            MatchText {
                width: Math.min(implicitWidth, parent.width - (badgeChip.visible ? badgeChip.width + 6 : 0))
                height: implicitHeight
                text: root.title
                ranges: {
                    try {
                        return JSON.parse(root.ranges);
                    } catch (e) {
                        return [];
                    }
                }
                mono: root.mono
                family: root.mono ? "Monaspace Argon" : "Adwaita Sans"
                pixelSize: root.mono || root.compactText ? 12 : 13
            }
            Rectangle {
                id: badgeChip
                visible: root.badge !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: badgeLabel.implicitWidth + 10
                height: badgeLabel.implicitHeight + 2
                radius: height / 2
                color: Tokens.fillLow
                Text {
                    id: badgeLabel
                    anchors.centerIn: parent
                    text: root.badge
                    textFormat: Text.PlainText
                    color: Tokens.inkDim
                    font.family: "Adwaita Sans"
                    font.pixelSize: 10
                }
            }
        }
        Text {
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            textFormat: Text.PlainText
            elide: Text.ElideRight
            maximumLineCount: 1
            color: Tokens.inkDim
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
        onPositionChanged: mouse => root.hovered(root, mouse)
        onClicked: root.activated()
    }
}
