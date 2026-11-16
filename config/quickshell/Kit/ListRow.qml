import QtQuick
import QtQuick.Layouts
import qs

// ListRow.qml - one row of a list: icon (on a tile or bare), title and
// subtitle, then keycaps, a mono meta text and any extra trailing items.
//
// Defaults are the launcher's result row: 48 high, padding 0 10, gap 12,
// radius 10, a 30 px tile (radius 8) holding a 16 px icon, title 13 and
// subtitle 11 `inkDim`. Selected rows sit on `accentTint` with the tile on
// `fillHigh` and the icon in `accent`; others put the tile on `fillLow`.
// Notification rows: height 44, tileSize 28, iconSize 14, spacing 10,
// subtitleSize 12. Sheet rows: tile false, implicitHeight 46, spacing 10.
//
// The selection tint fades over Motion.effects (by opacity, so it never
// chases a theme change). Lists move the selection with arrow keys, so a row
// is not a Tab stop unless `activeFocusOnTab` is set.
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property bool tile: true
    property int tileSize: 30
    property int iconSize: 16
    property bool selected: false
    property var keys: []
    property string meta: ""
    property int padX: 10
    property int spacing: 12
    property int titleSize: 13
    property int subtitleSize: 11
    property int radius: 10
    property color tileColor: selected ? Tokens.fillHigh : Tokens.fillLow
    property color iconColor: selected ? Tokens.accent : Tokens.fg
    default property alias trailing: trailingRow.data

    readonly property bool hovered: mouse.containsMouse

    signal clicked()

    implicitHeight: 48
    implicitWidth: Math.ceil(row.implicitWidth) + 2 * padX

    Accessible.role: Accessible.ListItem
    Accessible.name: title
    Accessible.description: subtitle
    Accessible.selectable: true
    Accessible.selected: selected
    Accessible.onPressAction: root.clicked()

    Keys.onPressed: event => {
        if (event.isAutoRepeat) return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.clicked();
            event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Tokens.fg
        opacity: root.hovered && !root.selected ? 0.05 : 0
    }
    Rectangle {
        id: tint
        anchors.fill: parent
        radius: root.radius
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

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: root.padX
        anchors.rightMargin: root.padX
        spacing: root.spacing

        Rectangle {
            visible: root.icon !== "" && root.tile
            Layout.preferredWidth: root.tileSize
            Layout.preferredHeight: root.tileSize
            radius: 8
            color: root.tileColor
            Icon {
                anchors.centerIn: parent
                name: root.tile ? root.icon : ""
                size: root.iconSize
                color: root.iconColor
            }
        }
        Icon {
            visible: root.icon !== "" && !root.tile
            name: root.tile ? "" : root.icon
            size: root.iconSize
            color: root.iconColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: root.title
                color: Tokens.fg
                elide: Text.ElideRight
                maximumLineCount: 1
                font.family: "Adwaita Sans"
                font.pixelSize: root.titleSize
                Accessible.ignored: true
            }
            Text {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                color: Tokens.inkDim
                elide: Text.ElideRight
                maximumLineCount: 1
                font.family: "Adwaita Sans"
                font.pixelSize: root.subtitleSize
                Accessible.ignored: true
            }
        }

        Row {
            visible: root.keys.length > 0
            spacing: 4
            Repeater {
                model: root.keys
                Keycap { text: modelData }
            }
        }
        Text {
            visible: root.meta !== ""
            text: root.meta
            color: Tokens.inkDim
            font.family: "Monaspace Argon"
            font.pixelSize: 11
            Accessible.ignored: true
        }
        Row {
            id: trailingRow
            visible: children.length > 0
            spacing: 4
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    FocusRing {}
}
