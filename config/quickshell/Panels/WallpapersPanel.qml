import QtQuick
import qs
import qs.Kit
import "../lib/PickerNav.js" as PickerNav

// WallpapersPanel.qml - the wallpaper picker for the applied theme (PLAN M7,
// launcher-pickers 7.2, Pickers board), content with a fixed implicit size and
// no background, like ThemesPanel.
//
//   ← 20 → Wallpapers  themes/hackerman/backgrounds        [ filter, while typing ] ↑ 18, row 20
//          ┌ card ┐ ┌ card ┐ ┌ card ┐  3 columns, 238.7 wide, gap 12               ↑ 14
//          └──────┘ └──────┘ └──────┘  180 high; 1 or 2 rows in view, then it scrolls
//                                                                                 ↓ 20
//
// As the board draws it: the header is the title's line (19, rounded to 20
// so the grid starts on a whole device pixel at 1.5), with no hint row (the
// themes panel's says what Tab does). The filter pill, 30 high, shows over
// the header's right end, centred on it, only while there is filter text.
//
// 780 wide; 252 high for up to three wallpapers, 444 for more (the island's
// body follows on the spatial spring). Capped at two rows, not the themes
// panel's three [GUESS, launcher-pickers 7.2 says three]: three rows of 180
// make 636 and more, taller than any other state, and packs hold 1 to 18
// images. Cards are 180 high (270 device px at 1.5, as the theme cards' 154
// make 231): 179 put every edge below the first row on a half pixel.
//
// A card is the image (226.7 x 142, decoded at 340 x 213), its file name, and
// rings as ThemesPanel's but with a 1 px `hairline` when idle, as the board
// draws it. No live preview: a wallpaper only changes once Enter runs
// `theme bg <path>`.
//
// "Add from Pictures" (the last cell) and the "Accent from wallpaper" switch
// row are drawn only when PickerModel's canAdd and canAccent turn on: neither
// has a backend yet (PLAN M7: they ship hidden).
Item {
    id: panel

    property var picker: null
    property bool active: false
    property real dpr: 1

    readonly property int pad: 20
    readonly property real cardWidth: (780 - 2 * pad - 2 * gap) / 3
    readonly property int cardHeight: 180
    readonly property int gap: 12
    readonly property int columns: 3
    readonly property int gridTop: 18 + 20 + 14

    readonly property var rows: picker ? picker.wallRows : []
    readonly property bool canAdd: !!picker && picker.canAdd
    readonly property bool canAccent: !!picker && picker.canAccent
    readonly property bool placeholders: rows.length === 0 && !(picker && picker.wallsLoaded)
    readonly property int shownCount: picker ? picker.wallMatches : 0
    readonly property int cells: shownCount + (canAdd ? 1 : 0)
    // From every wallpaper, not just the matches, so typing never resizes it.
    readonly property int rowsInView: Math.max(1, Math.min(2, Math.ceil((rows.length + (canAdd ? 1 : 0)) / columns)))
    readonly property int totalRows: Math.ceil(cells / columns)
    readonly property int gridHeight: rowsInView * cardHeight + (rowsInView - 1) * gap

    readonly property alias grid: grid
    readonly property alias cards: cards
    readonly property Item focusedCard: cards.count > 0 && picker && !picker.themes && picker.wallIndex >= 0 ? cards.itemAt(picker.wallIndex) : null

    implicitWidth: 780
    implicitHeight: gridTop + gridHeight + (canAccent ? 14 + 44 : 0) + 20
    focus: true
    Accessible.role: Accessible.Pane
    Accessible.name: "Wallpapers"

    Keys.onPressed: event => {
        if (panel.picker) event.accepted = panel.picker.handleKey(event);
    }

    property bool pointerArmed: false
    property point pointerStart: Qt.point(-1, -1)
    function resetPointer() {
        pointerArmed = false;
        pointerStart = Qt.point(-1, -1);
    }
    HoverHandler {
        id: gate
        onPointChanged: {
            if (panel.pointerArmed || !gate.hovered) return;
            const p = gate.point.position;
            if (panel.pointerStart.x < 0) panel.pointerStart = p;
            else if (Math.abs(p.x - panel.pointerStart.x) + Math.abs(p.y - panel.pointerStart.y) > 3) panel.pointerArmed = true;
        }
    }

    function snap(v: real): real {
        return Math.round(v * panel.dpr) / panel.dpr;
    }

    // ---- header ----------------------------------------------------------------
    Text {
        id: title
        x: panel.pad
        y: 18 + (20 - height) / 2
        text: "Wallpapers"
        color: Tokens.fg
        font.family: "Adwaita Sans"
        font.pixelSize: 15
        font.weight: Font.Medium
    }
    Text {
        anchors.left: title.right
        anchors.leftMargin: 12
        anchors.verticalCenter: title.verticalCenter
        text: panel.picker && panel.picker.currentTheme !== "" ? "themes/" + panel.picker.currentTheme + "/backgrounds" : ""
        textFormat: Text.PlainText
        color: Tokens.inkDim
        font.family: "Adwaita Sans"
        font.pixelSize: 12
    }
    PickerFilter {
        x: 780 - panel.pad - width
        y: panel.snap(18 + 10 - height / 2)
        visible: text !== ""
        text: panel.picker && !panel.picker.themes ? panel.picker.filter : ""
        active: panel.active && panel.activeFocus
    }

    // ---- the grid ----------------------------------------------------------------
    Flickable {
        id: grid
        x: panel.pad
        y: panel.gridTop
        width: 780 - 2 * panel.pad
        height: panel.gridHeight
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, panel.totalRows * (panel.cardHeight + panel.gap) - panel.gap)
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        NumberAnimation {
            id: scroll
            target: grid
            property: "contentY"
            duration: Motion.spatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spring
        }

        Repeater {
            id: cards
            model: panel.rows.length
            delegate: PickerCard {
                required property int index
                readonly property var row: panel.rows[index] ?? ({})
                readonly property int pos: panel.picker ? (panel.picker.wallPositions[index] ?? -1) : -1
                readonly property real cellX: (pos % panel.columns) * (panel.cardWidth + panel.gap)
                objectName: "wallpaperCard-" + title
                visible: pos >= 0
                x: panel.snap(cellX)
                y: Math.floor(pos / panel.columns) * (panel.cardHeight + panel.gap)
                width: panel.snap(cellX + panel.cardWidth) - x
                height: panel.cardHeight
                image: PickerNav.fileUrl(row.image ?? "")
                thumbSize: Qt.size(340, 213)
                imageHeight: 142
                title: String(row.name ?? "").split("/").pop()
                titleWeight: Font.Normal
                focused: !!panel.picker && !panel.picker.themes && panel.picker.wallIndex === index
                current: row.current === true
                idleRing: true
                accessibleName: title + (current ? ", current wallpaper" : "")
                armed: panel.pointerArmed
                onHovered: if (panel.picker) panel.picker.focusAt(index)
                onClicked: {
                    if (!panel.picker) return;
                    panel.picker.focusAt(index);
                    panel.picker.apply();
                }
            }
        }

        // The last cell, once it has a backend.
        Rectangle {
            readonly property int pos: panel.shownCount
            readonly property real cellX: (pos % panel.columns) * (panel.cardWidth + panel.gap)
            visible: panel.canAdd
            x: panel.snap(cellX)
            y: Math.floor(pos / panel.columns) * (panel.cardHeight + panel.gap)
            width: panel.snap(cellX + panel.cardWidth) - x
            height: panel.cardHeight
            radius: 16
            color: "transparent"
            border.width: 1
            border.color: Tokens.hairline
            Accessible.role: Accessible.Button
            Accessible.name: "Add from Pictures"
            Column {
                anchors.centerIn: parent
                spacing: 8
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "plus"
                    size: 20
                    color: Tokens.inkDim
                }
                Text {
                    text: "Add from Pictures"
                    color: Tokens.inkDim
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                }
            }
        }

        Repeater {
            model: panel.placeholders ? panel.columns : 0
            delegate: Rectangle {
                required property int index
                readonly property real cellX: index * (panel.cardWidth + panel.gap)
                x: panel.snap(cellX)
                width: panel.snap(cellX + panel.cardWidth) - x
                height: panel.cardHeight
                radius: 16
                color: Tokens.fillLow
            }
        }
    }

    Text {
        anchors.centerIn: grid
        visible: !panel.placeholders && panel.shownCount === 0 && !panel.canAdd
        text: panel.rows.length === 0 ? "this theme has no wallpapers" : "no matches"
        color: Tokens.inkDim
        font.family: "Adwaita Sans"
        font.pixelSize: 13
    }

    // ---- the accent switch row, once it has a backend ------------------------------
    Rectangle {
        visible: panel.canAccent
        x: panel.pad
        y: panel.gridTop + panel.gridHeight + 14
        width: 780 - 2 * panel.pad
        height: 44
        radius: 12
        color: Tokens.raised
        border.width: 1
        border.color: Tokens.hairline
        Column {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 12 - 12 - 40 - 12
            spacing: 1
            Text {
                text: "Accent from wallpaper"
                color: Tokens.fg
                font.family: "Adwaita Sans"
                font.pixelSize: 13
            }
            Text {
                text: "Sample the dominant hue and override the theme's accent"
                color: Tokens.inkDim
                font.family: "Adwaita Sans"
                font.pixelSize: 11
            }
        }
        Switch {
            x: parent.width - 12 - width
            anchors.verticalCenter: parent.verticalCenter
            label: "Accent from wallpaper"
            checked: false
        }
    }

    function keepInView(animated: bool) {
        if (!panel.picker) return;
        const step = panel.cardHeight + panel.gap;
        const row = PickerNav.gridRow(panel.rows, panel.picker.themes ? "" : panel.picker.filter, panel.picker.wallIndex, panel.columns);
        const top = PickerNav.scrollTop(Math.round(grid.contentY / step), row, panel.rowsInView, panel.totalRows);
        const y = top * step;
        scroll.stop();
        if (Math.abs(grid.contentY - y) < 0.5) return;
        if (animated && panel.visible) {
            scroll.to = y;
            scroll.start();
        } else {
            grid.contentY = y;
        }
    }
    Connections {
        target: panel.picker
        ignoreUnknownSignals: true
        function onWallIndexChanged() { Qt.callLater(panel.keepInView, true) }
        function onFilterChanged() { Qt.callLater(panel.keepInView, true) }
        function onWallRowsChanged() { Qt.callLater(panel.keepInView, false) }
    }
    onActiveChanged: {
        if (!active) return;
        resetPointer();
        Qt.callLater(panel.keepInView, false);
    }
    Component.onCompleted: Qt.callLater(panel.keepInView, false)
}
