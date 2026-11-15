import QtQuick
import qs
import "../lib/PickerNav.js" as PickerNav

// ThemesPanel.qml - the theme picker (PLAN M7, launcher-pickers 7.1, Pickers
// board), content with a fixed implicit size and no background of its own:
// the island's `themes` state draws the material, and so does ThemePicker's
// free panel in the classic bar modes.
//
//   ← 20 → Themes  37 installed                      [ search  Type to filter ] ↑ 18, row 30
//          ┌ card ┐ ┌ card ┐ ... 8 columns, 139.5 wide, gap 12             ↑ 16
//          │      │ │      │     3 rows in view (154 + 12 + 154 + 12 + 154 = 486),
//          └──────┘ └──────┘     the grid scrolls by rows to keep focus in view
//          ←→ move   Enter applies   Tab switches to wallpapers   Esc ...   ↑ 16, row 14, 20 under
//
// 1240 x 600 on the 1920 screen. A screen narrower than 1272 drops columns
// (at least 4), as clamp(floor((width - 40 + 12) / 151.5), 4, 8).
//
// Every card is a PickerCard: the pack's thumbnail decoded at 1.5 times its
// 127.5 x 80 (191 x 120), its bg, fg and accent dots, its slug and a note
// (the mode; "Current" on the applied one; "Previewing" on the focused one).
// The filter drops cards that do not match and the rest reflow. The keys are
// PickerModel's (handleKey), taken while this has the keyboard; the pointer
// focuses a card it moves onto (once it has moved since the panel opened) and
// a click applies it.
//
// Until the first rows arrive the grid holds `fillLow` placeholders; later
// opens keep the last rows on screen while `theme _rows` runs again.
//
// QtQuick only, except PickerThumb (see there).
Item {
    id: panel

    property var picker: null
    // This panel is the one showing (the island's state, the free panel's kind).
    property bool active: false
    // The window's device pixel ratio: card edges land on whole device pixels.
    property real dpr: 1
    // The screen's logical width, for the column count.
    property real availableWidth: 1920

    readonly property int pad: 20
    readonly property real cardWidth: 139.5
    readonly property int cardHeight: 154
    readonly property int gap: 12
    readonly property int rowsInView: 3
    readonly property int columns: PickerNav.columnsFor(Math.min(1240, availableWidth - 32), cardWidth, 4, 8)
    readonly property real panelWidth: columns === 8 ? 1240 : 2 * pad + columns * cardWidth + (columns - 1) * gap
    readonly property int gridTop: 18 + 30 + 16
    readonly property int gridHeight: rowsInView * cardHeight + (rowsInView - 1) * gap

    readonly property var rows: picker ? picker.themeRows : []
    readonly property bool placeholders: rows.length === 0 && !(picker && picker.themesLoaded)
    readonly property int shownCount: picker ? picker.themeMatches : 0
    readonly property int totalRows: Math.ceil(shownCount / columns)

    readonly property alias grid: grid
    readonly property alias filterPill: filterPill
    readonly property alias cards: cards
    // The focused card, for inspect() and the shots.
    readonly property Item focusedCard: cards.count > 0 && picker && picker.themes && picker.themeIndex >= 0 ? cards.itemAt(picker.themeIndex) : null

    implicitWidth: panelWidth
    implicitHeight: gridTop + gridHeight + 16 + 14 + 20
    focus: true
    Accessible.role: Accessible.Pane
    Accessible.name: "Themes"

    Keys.onPressed: event => {
        if (panel.picker) event.accepted = panel.picker.handleKey(event);
    }

    Binding {
        target: panel.picker
        when: panel.picker !== null
        property: "themeColumns"
        value: panel.columns
    }

    // ---- the pointer gate ----------------------------------------------------
    // Hover focuses only after the pointer has moved since the panel opened.
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

    // On whole device pixels.
    function snap(v: real): real {
        return Math.round(v * panel.dpr) / panel.dpr;
    }

    // ---- header ----------------------------------------------------------------
    Text {
        id: title
        x: panel.pad
        y: 18 + (30 - height) / 2
        text: "Themes"
        color: Tokens.fg
        font.family: "Adwaita Sans"
        font.pixelSize: 15
        font.weight: Font.Medium
    }
    Text {
        anchors.left: title.right
        anchors.leftMargin: 12
        anchors.verticalCenter: title.verticalCenter
        text: panel.rows.length > 0 ? panel.rows.length + " installed" : ""
        color: Tokens.inkDim
        font.family: "Adwaita Sans"
        font.pixelSize: 12
    }
    PickerFilter {
        id: filterPill
        x: panel.panelWidth - panel.pad - width
        y: 18
        text: panel.picker && panel.picker.themes ? panel.picker.filter : ""
        active: panel.active && panel.activeFocus
    }

    // ---- the grid ----------------------------------------------------------------
    Flickable {
        id: grid
        x: panel.pad
        y: panel.gridTop
        width: panel.panelWidth - 2 * panel.pad
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
                id: card
                required property int index
                readonly property var row: panel.rows[index] ?? ({})
                readonly property int pos: panel.picker ? (panel.picker.themePositions[index] ?? -1) : -1
                readonly property int col: pos % panel.columns
                readonly property int line: Math.floor(pos / panel.columns)
                readonly property real cellX: col * (panel.cardWidth + panel.gap)
                objectName: "themeCard-" + (row.name ?? "")
                visible: pos >= 0
                x: panel.snap(cellX)
                y: line * (panel.cardHeight + panel.gap)
                width: panel.snap(cellX + panel.cardWidth) - x
                height: panel.cardHeight
                image: PickerNav.fileUrl(row.image ?? "")
                thumbSize: Qt.size(Math.round(127.5 * 1.5), Math.round(80 * 1.5))
                imageHeight: 80
                title: String(row.name ?? "")
                focused: !!panel.picker && panel.picker.themes && panel.picker.themeIndex === index
                current: row.current === true
                note: current ? "Current" : focused ? "Previewing" : String(row.mode ?? "")
                dots: [row.bg ?? "transparent", row.fg ?? "transparent", row.palette?.accent ?? (row.swatches ?? [])[0] ?? "transparent"]
                accessibleName: title + (current ? ", current theme" : "")
                armed: panel.pointerArmed
                onHovered: if (panel.picker) panel.picker.focusAt(index)
                onClicked: {
                    if (!panel.picker) return;
                    panel.picker.focusAt(index);
                    panel.picker.apply();
                }
            }
        }

        // Before the first rows: three rows of placeholders.
        Repeater {
            model: panel.placeholders ? panel.columns * panel.rowsInView : 0
            delegate: Rectangle {
                required property int index
                readonly property real cellX: (index % panel.columns) * (panel.cardWidth + panel.gap)
                x: panel.snap(cellX)
                y: Math.floor(index / panel.columns) * (panel.cardHeight + panel.gap)
                width: panel.snap(cellX + panel.cardWidth) - x
                height: panel.cardHeight
                radius: 16
                color: Tokens.fillLow
            }
        }
    }

    Text {
        anchors.centerIn: grid
        visible: !panel.placeholders && panel.shownCount === 0
        text: panel.rows.length === 0 ? "no themes found" : "no matches"
        color: Tokens.inkDim
        font.family: "Adwaita Sans"
        font.pixelSize: 13
    }

    // Keep the focused card in view: the grid moves a whole row at a time, on the spring.
    function keepInView(animated: bool) {
        if (!panel.picker) return;
        const step = panel.cardHeight + panel.gap;
        const row = PickerNav.gridRow(panel.rows, panel.picker.themes ? panel.picker.filter : "", panel.picker.themeIndex, panel.columns);
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
        function onThemeIndexChanged() { Qt.callLater(panel.keepInView, true) }
        function onFilterChanged() { Qt.callLater(panel.keepInView, true) }
        function onThemeRowsChanged() { Qt.callLater(panel.keepInView, false) }
    }
    onActiveChanged: {
        if (!active) return;
        resetPointer();
        Qt.callLater(panel.keepInView, false);
    }
    Component.onCompleted: Qt.callLater(panel.keepInView, false)

    // ---- hints -------------------------------------------------------------------
    Row {
        id: hints
        x: panel.pad
        y: panel.gridTop + panel.gridHeight + 16
        height: 14
        spacing: 18
        Repeater {
            model: ["←→ move", "Enter applies", "Tab switches to wallpapers", "Esc clears the filter, then closes"]
            delegate: Text {
                required property string modelData
                height: 14
                verticalAlignment: Text.AlignVCenter
                text: modelData
                color: Tokens.inkDim
                font.family: "Adwaita Sans"
                font.pixelSize: 11
            }
        }
    }
}
