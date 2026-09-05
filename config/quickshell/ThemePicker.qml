// ThemePicker.qml - the theme (and wallpaper) switcher overlay: a carousel of
// wallpaper cards, the chosen one expanded in the middle and the rest as skewed
// slices to either side, dimmed. Left/Right/Tab move, typing filters, Enter
// applies, Esc clears the filter and then closes, a click outside closes.
//
// Drawn with this bar's Theme tokens. Each card is a wallpaper, with the pack's
// palette swatches and its tagline under the label.
//
// Opened over IPC, which is what `theme picker [themes|backgrounds]` does
// (and what the "Theme" / "Wallpaper" entries in wofi run):
//     qs ipc call picker open themes
// Rows come from `theme _rows <kind>` as JSON; images are the thumbnails
// `theme thumbs` caches under ~/.cache/theme/thumbs, or the originals until
// that has run once.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Scope {
    id: root

    // ~/.config/quickshell is a symlink into the dotfiles checkout; .. walks the
    // real parent, so this lands on dotfiles/bin/theme without hard-coding it.
    readonly property string themeBin: Quickshell.shellDir + "/../../bin/theme"

    property string kind: "themes"
    property var rows: []
    property int selectedIndex: 0
    property string filterText: ""
    property bool opened: false
    property bool loaded: false

    // Logical pixels; the panel is 1800 wide at scale 1.6.
    readonly property int expandedWidth: 720
    readonly property int expandedHeight: 450
    readonly property int sliceWidth: 96
    readonly property int sliceHeight: 405
    readonly property int sliceSpacing: -26
    readonly property int skew: 26
    readonly property int chromeHeight: 120

    IpcHandler {
        target: "picker"
        function open(kind: string): void { root.open(kind) }
        function close(): void { root.close() }
        function toggle(kind: string): void { if (root.opened) root.close(); else root.open(kind) }
    }

    function open(kind) {
        root.kind = kind === "backgrounds" ? "backgrounds" : "themes"
        root.filterText = ""
        root.loaded = false
        root.rows = []
        root.opened = true
        rowsProc.running = false
        rowsProc.command = [root.themeBin, "_rows", root.kind]
        rowsProc.running = true
    }

    function close() {
        root.opened = false
        root.filterText = ""
    }

    Process {
        id: rowsProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (!root.opened) return
                let parsed = []
                try { parsed = JSON.parse(text) } catch (e) { console.log("picker: bad rows: " + e) }
                root.rows = Array.isArray(parsed) ? parsed : []
                root.selectedIndex = 0
                for (let i = 0; i < root.rows.length; i++) {
                    if (root.rows[i].current) { root.selectedIndex = i; break }
                }
                root.loaded = true
                Qt.callLater(() => carousel.forceActiveFocus())
            }
        }
    }

    // ── Model helpers ──────────────────────────────────────────────────

    function matches(i) {
        if (i < 0 || i >= rows.length) return false
        const needle = filterText.toLowerCase()
        if (!needle) return true
        const r = rows[i]
        return String(r.name || "").toLowerCase().includes(needle)
            || String(r.label || "").toLowerCase().includes(needle)
    }

    function filteredPosition(i) {
        if (!filterText) return i
        let p = 0
        for (let k = 0; k < i; k++) if (matches(k)) p++
        return p
    }

    function selectedFilteredPosition() {
        if (!filterText) return selectedIndex
        return matches(selectedIndex) ? filteredPosition(selectedIndex) : 0
    }

    function matchCount() {
        if (!filterText) return rows.length
        let n = 0
        for (let i = 0; i < rows.length; i++) if (matches(i)) n++
        return n
    }

    function select(i) {
        if (i >= 0 && i < rows.length && matches(i)) selectedIndex = i
    }

    function selectAdjacent(direction) {
        const n = rows.length
        let i = selectedIndex
        for (let k = 0; k < n; k++) {
            i = (i + direction + n) % n
            if (matches(i)) { selectedIndex = i; return }
        }
    }

    function selectEnd(fromStart) {
        if (fromStart) { for (let i = 0; i < rows.length; i++) if (matches(i)) { selectedIndex = i; return } }
        else { for (let i = rows.length - 1; i >= 0; i--) if (matches(i)) { selectedIndex = i; return } }
    }

    function updateFilter(text) {
        filterText = text
        if (!matches(selectedIndex)) selectEnd(true)
    }

    function current() {
        return (rows.length > 0 && matches(selectedIndex)) ? rows[selectedIndex] : null
    }

    function apply() {
        const r = current()
        if (!r) { close(); return }
        const cmd = root.kind === "backgrounds" ? [root.themeBin, "bg", r.name] : [root.themeBin, r.name]
        Quickshell.execDetached(cmd)
        close()
    }

    function fileUrl(path) {
        if (!path) return ""
        return "file://" + String(path).split("/").map(encodeURIComponent).join("/")
    }

    // Backspace / Ctrl+Backspace / Ctrl+U edit the filter; anything with Alt or
    // Meta belongs to the compositor and is left alone.
    function editsFilter(event) {
        if (!filterText) return false
        if (event.modifiers & (Qt.AltModifier | Qt.MetaModifier)) return false
        if (event.key === Qt.Key_U) return event.modifiers === Qt.ControlModifier
        return event.key === Qt.Key_Backspace
    }

    function editedFilter(event) {
        if (event.key === Qt.Key_U) return ""
        if (event.modifiers & Qt.ControlModifier) return filterText.replace(/\s+$/, "").replace(/\S+$/, "")
        return filterText.slice(0, -1)
    }

    // ── The overlay ─────────────────────────────────────────────────────

    PanelWindow {
        id: panel

        visible: root.opened
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: "theme-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.bg, 0.72)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Text {
            anchors.centerIn: parent
            visible: root.opened && root.loaded && root.rows.length === 0
            text: root.kind === "backgrounds" ? "this theme has no wallpapers" : "no themes found"
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 18
        }

        Item {
            id: card
            visible: root.loaded && root.rows.length > 0
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, root.expandedWidth + 14 * (root.sliceWidth + root.sliceSpacing) + 40)
            height: root.expandedHeight + 30 + root.chromeHeight

            // A click on the card is not a click outside it.
            MouseArea { anchors.fill: parent; onClicked: {} }

            Item {
                id: carousel
                anchors.top: parent.top
                anchors.topMargin: 30
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 40
                height: root.expandedHeight
                clip: false
                focus: true

                readonly property real step: root.sliceWidth + root.sliceSpacing
                readonly property real previewX: (width - root.expandedWidth) / 2

                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                        if (root.filterText) root.updateFilter("")
                        else root.close()
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.apply()
                    } else if (root.editsFilter(event)) {
                        root.updateFilter(root.editedFilter(event))
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab
                               || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                        root.selectAdjacent(-1)
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                        root.selectAdjacent(1)
                    } else if (event.key === Qt.Key_Home) {
                        root.selectEnd(true)
                    } else if (event.key === Qt.Key_End) {
                        root.selectEnd(false)
                    } else if (event.text && event.text.length === 1
                               && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127
                               && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
                        root.updateFilter(root.filterText + event.text)
                    } else {
                        return
                    }
                    event.accepted = true
                }

                Repeater {
                    model: root.rows.length

                    delegate: Item {
                        id: item
                        required property int index

                        readonly property var row: root.rows[index] || ({})
                        readonly property bool matched: root.matches(index)
                        readonly property int rel: root.filteredPosition(index) - root.selectedFilteredPosition()
                        readonly property bool selected: matched && index === root.selectedIndex
                        readonly property bool nearby: matched && Math.abs(rel) <= 16
                        // Load images as they come near, and keep them loaded so
                        // moving back and forth does not tear textures down.
                        property bool activated: nearby
                        onNearbyChanged: if (nearby) activated = true

                        visible: nearby
                        x: selected ? carousel.previewX
                         : (rel < 0 ? carousel.previewX + rel * carousel.step
                                    : carousel.previewX + root.expandedWidth + root.sliceSpacing + (rel - 1) * carousel.step)
                        width: selected ? root.expandedWidth : root.sliceWidth
                        height: selected ? root.expandedHeight : root.sliceHeight
                        y: selected ? 0 : (root.expandedHeight - root.sliceHeight) / 2
                        z: selected ? 100 : 50 - Math.min(Math.abs(rel), 40)

                        // A parallelogram: the top edge sits `skew` px to the right of the bottom.
                        readonly property real topLeft: root.skew
                        readonly property real topRight: width
                        readonly property real bottomRight: width - root.skew
                        readonly property real bottomLeft: 0

                        Item {
                            id: maskShape
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true

                            Shape {
                                anchors.fill: parent
                                antialiasing: true
                                preferredRendererType: Shape.CurveRenderer
                                ShapePath {
                                    fillColor: "white"
                                    strokeColor: "transparent"
                                    startX: item.topLeft; startY: 0
                                    PathLine { x: item.topRight; y: 0 }
                                    PathLine { x: item.bottomRight; y: item.height }
                                    PathLine { x: item.bottomLeft; y: item.height }
                                    PathLine { x: item.topLeft; y: 0 }
                                }
                            }
                        }

                        Item {
                            anchors.fill: parent
                            layer.enabled: true
                            layer.smooth: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: maskShape
                                maskThresholdMin: 0.3
                                maskSpreadAtMin: 0.3
                            }

                            Image {
                                anchors.fill: parent
                                source: item.activated ? root.fileUrl(item.row.image) : ""
                                // Bounds the decode when the row still points at a 4K original.
                                sourceSize: Qt.size(1440, 900)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.alpha(Theme.bg, item.selected ? 0 : 0.42)
                            }
                        }

                        Shape {
                            anchors.fill: parent
                            antialiasing: true
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: item.selected ? Theme.accent : Theme.alpha(Theme.fg, 0.28)
                                strokeWidth: item.selected ? 3 : 1
                                startX: item.topLeft; startY: 0
                                PathLine { x: item.topRight; y: 0 }
                                PathLine { x: item.bottomRight; y: item.height }
                                PathLine { x: item.bottomLeft; y: item.height }
                                PathLine { x: item.topLeft; y: 0 }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: item.selected ? root.apply() : root.select(item.index)
                        }
                    }
                }
            }

            Column {
                id: chrome
                anchors.top: carousel.bottom
                anchors.topMargin: 16
                anchors.horizontalCenter: carousel.horizontalCenter
                width: root.expandedWidth
                spacing: 6

                readonly property var cur: root.current()

                Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: chrome.cur ? chrome.cur.label : (root.filterText ? "no matches" : "")
                    color: Theme.fg
                    style: Text.Outline
                    styleColor: Theme.alpha(Theme.bg, 0.7)
                    font.family: Theme.font
                    font.pixelSize: 26
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    visible: chrome.cur !== null

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Repeater {
                            model: chrome.cur ? (chrome.cur.swatches || []) : []
                            delegate: Rectangle {
                                required property var modelData
                                width: 14; height: 14; radius: 3
                                color: modelData
                                border.width: 1
                                border.color: Theme.alpha(Theme.bg, 0.5)
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: {
                            const c = chrome.cur
                            if (!c) return ""
                            if (root.kind === "backgrounds")
                                return (root.selectedFilteredPosition() + 1) + " / " + root.matchCount() + "  ·  " + c.tagline
                            return c.tagline || ""
                        }
                        color: Theme.alpha(Theme.fg, 0.85)
                        style: Text.Outline
                        styleColor: Theme.alpha(Theme.bg, 0.7)
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.italic: true
                    }
                }

                Text {
                    width: parent.width
                    visible: root.filterText !== ""
                    textFormat: Text.PlainText
                    text: "› " + root.filterText
                    color: Theme.fg
                    opacity: 0.85
                    style: Text.Outline
                    styleColor: Theme.alpha(Theme.bg, 0.7)
                    font.family: Theme.font
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }
        }
    }
}
