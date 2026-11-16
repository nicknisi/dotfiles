import QtQuick
import qs
import qs.Kit

// ControlCenter.qml - the control center's content, 760 x 560, with no
// background and no idea of its host (PLAN 1.6, control-lock 2, Main board
// `cc`). The island hosts it in its `cc` state (Island/CcLayer.qml); M4's
// AnchoredHost will host the same component in the classic modes.
//
// Padding 16, a column 12 apart, 728 wide:
//   tiles (356, a 2 x 2 grid of QuickTiles 8 apart) | media (the rest)   148
//   levels (volume, brightness)                                           92
//   six MiniTiles, 8 apart                                                64
//   notifications                                                        132
//   footer: letter, user, battery, the tray, Lock, Power                  36
// 16 + 148 + 12 + 92 + 12 + 64 + 12 + 132 + 12 + 36 + 16 = 552: the last 8 of
// the 560 stay empty, so the sheet area is the same size as home [GUESS,
// control-lock 2.2].
//
// Sheets: a tile's chevron, a level's device button or a mini opens its
// sheet, which slides in from +760 over Motion.spatial while home fades out
// (Motion.exitFade, linear) and moves 24 left; back reverses it (control-lock
// 3.1). The sheet fills the padded area, 728 x 528. `sheetUrl(name)` gives the
// component for a name (the host passes the live sheets; tests pass
// stand-ins); a sheet has `shown`, `monitor` and back(), dismissed() and
// navigate(page) (Panels/Sheets/SheetFrame.qml).
//
// Nothing here runs anything: every press is action(name, arg), and the host
// (Panels/CcModel.qml) does it. closeRequested() asks the host to close.
//
// Keys (control-lock 2.9 [GUESS]): focus starts on the Wi-Fi disc; Tab walks
// tiles, media, levels, minis, notifications, the footer. The arrows move
// spatially inside the tile grid (disc to disc, chevron to chevron) and along
// the mini row; Up and Down (and Ctrl+J / Ctrl+K anywhere) follow the focus
// chain elsewhere, so the level sliders take Left and Right only. Right on a
// tile's chevron opens its sheet. Esc steps back out of a sheet, then asks to
// close.
//
// The Repeaters count the model's rows rather than take its arrays: the host
// rebuilds `model` on every service change, and a delegate rebuilt under a
// drag or a key press would drop the drag and the focus (M6 review).
FocusScope {
    id: cc

    property var model: ({ tiles: [], media: null, levels: [], minis: [], notes: { count: 0, rows: [] }, footer: { user: "", letter: "", battery: { visible: false }, tray: [] } })
    property var sheetUrl: function (name) {
        return "";
    }
    property var monitor: null
    // The host is showing it (the island's cc state is current).
    property bool shown: true
    // Ambient loops (the eq bars) may run.
    property bool animated: true

    // The sheet showing or sliding in, "" for home.
    property string sheet: ""
    // 760 when the sheet is off to the right, 0 when it is in.
    property real sheetOffset: 760
    readonly property bool sliding: sheetIn.running || sheetOut.running
    readonly property var sheetItem: sheetLoader.item

    signal action(string name, var arg)
    signal closeRequested

    readonly property alias home: home
    readonly property alias tiles: tileRepeater
    readonly property alias media: mediaCard
    readonly property alias levels: levelsCard
    readonly property alias minis: miniRepeater
    readonly property alias notes: notesCard
    readonly property alias footer: footer
    readonly property alias tray: trayRepeater
    readonly property alias lockButton: lockButton
    readonly property alias powerButton: powerButton
    readonly property alias sheetLoader: sheetLoader
    readonly property alias sheetArea: sheetArea

    // Which sheet each tile's chevron opens.
    readonly property var tileSheets: ({ wifi: "wifi", bt: "bt", ts: "tailscale", dnd: "notifications" })

    implicitWidth: 760
    implicitHeight: 560

    Accessible.role: Accessible.Pane
    Accessible.name: "Control center"

    onShownChanged: {
        if (shown) {
            if (sheet === "") focusHome();
        } else if (sheet !== "") {
            // Closed with a sheet open: it is gone by the next open.
            closeSheet(true);
        }
    }

    // Opened by key (or `island open cc`), the Wi-Fi disc takes focus and its
    // ring shows (control-lock 2.9); opened by the pointer (the status pill),
    // the control center holds the keys (Esc, Tab) with no ring drawn: Kit
    // controls take focus only from the keyboard (Kit/FocusRing.qml).
    // With a sheet showing, the keys go to the sheet instead (home is
    // disabled under it).
    function focusHome(byKey) {
        if (cc.sheet !== "" && sheetLoader.item) {
            if (byKey !== false) sheetLoader.item.keyboard = true;
            sheetLoader.item.forceActiveFocus();
            return;
        }
        const first = tileRepeater.itemAt(0);
        if (first && byKey !== false) first.disc.forceActiveFocus();
        else homeKeys.forceActiveFocus();
    }

    // Opens the sheet `name`, with `props` set on it as it is made (the Tray
    // sheet's item); false when there is none by that name. `byKey`: opened
    // from the keyboard (or IPC), so the first row draws its focus ring; from
    // the pointer it waits for a key (main-tokens 2.6).
    function openSheet(name: string, props, byKey): bool {
        const url = name !== "" ? cc.sheetUrl(name) : "";
        if (!url) return false;
        if (cc.sheet === name && !sheetOut.running && !props) {
            if (sheetLoader.item && byKey === true) sheetLoader.item.keyboard = true;
            return true;
        }
        // A back still running (home fading in, the last sheet sliding out)
        // gives way to this one.
        sheetOut.stop();
        homeIn.stop();
        cc.sheet = name;
        // A fresh sheet each time (setSource skips one already loaded).
        sheetLoader.source = "";
        sheetLoader.setSource(url, Object.assign({ monitor: cc.monitor, shown: false, keyboard: byKey === true }, props || {}));
        if (sheetLoader.item) {
            sheetLoader.item.shown = Qt.binding(() => cc.shown && cc.sheet === name && !sheetOut.running);
            sheetLoader.item.forceActiveFocus();
        }
        homeOut.restart();
        sheetIn.restart();
        return true;
    }
    // Back to home (the sheet's back, Esc). `now` skips the slide.
    function closeSheet(now: bool) {
        if (cc.sheet === "") return;
        const from = cc.sheet;
        const keys = sheetLoader.item?.keyboard === true;
        cc.sheet = "";
        sheetIn.stop();
        homeOut.stop();
        if (now || Motion.spatial === 0) {
            cc.sheetOffset = 760;
            sheetLoader.source = "";
            home.opacity = 1;
            homeShift.x = 0;
        } else {
            sheetOut.restart();
            homeIn.restart();
        }
        if (!now) {
            // Back to the chevron that opened it when the keys drove the
            // sheet; after the pointer, to the ring-less holder.
            const opener = cc.openerFor(from);
            if (!keys) homeKeys.forceActiveFocus();
            else if (opener) opener.forceActiveFocus();
            else cc.focusHome();
        }
    }
    function back() {
        closeSheet(false);
    }
    // Where focus goes back to when a sheet closes [GUESS, control-lock 3.2].
    function openerFor(name) {
        for (let i = 0; i < tileRepeater.count; i++) {
            const t = tileRepeater.itemAt(i);
            if (t && cc.tileSheets[t.key] === name) return t.chevron;
        }
        return null;
    }

    Keys.onEscapePressed: cc.sheet !== "" ? cc.back() : cc.closeRequested()

    // ---- arrow keys (control-lock 2.9) ----------------------------------------

    // Moves focus along the window's focus chain (what Tab does).
    function chain(item, forward: bool) {
        const next = item ? item.nextItemInFocusChain(forward) : null;
        if (next && next !== item) next.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
    }
    // { index, part: "disc" | "chevron" } for a tile's focus stop, or null.
    function tileStop(item) {
        for (let i = 0; i < tileRepeater.count; i++) {
            const t = tileRepeater.itemAt(i);
            if (t && t.disc === item) return { index: i, part: "disc" };
            if (t && t.chevron === item) return { index: i, part: "chevron" };
        }
        return null;
    }
    function miniStop(item): int {
        for (let i = 0; i < miniRepeater.count; i++)
            if (miniRepeater.itemAt(i) === item) return i;
        return -1;
    }
    // A key no control took, from home's focused item: true when it moved focus.
    function arrow(event): bool {
        const item = cc.Window.activeFocusItem;
        if (!item) return false;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if ((event.modifiers & Qt.AltModifier) !== 0) return false;
        const next = ctrl && event.key === Qt.Key_J;
        const prev = ctrl && event.key === Qt.Key_K;
        const key = ctrl ? 0 : event.key;
        const left = key === Qt.Key_Left, right = key === Qt.Key_Right;
        const up = key === Qt.Key_Up, down = key === Qt.Key_Down;
        if (!(left || right || up || down || next || prev)) return false;
        // The ring-less holder (opened by the pointer): any of them shows the
        // ring on the Wi-Fi disc.
        if (item === homeKeys) {
            const first = tileRepeater.itemAt(0);
            if (first) first.disc.forceActiveFocus(Qt.TabFocusReason);
            return true;
        }
        if (next || prev) {
            cc.chain(item, next);
            return true;
        }
        const t = cc.tileStop(item);
        if (t) {
            const cols = tileGrid.columns;
            let to = -1;
            if (left && t.index % cols > 0) to = t.index - 1;
            else if (right && t.index % cols < cols - 1 && t.index + 1 < tileRepeater.count) to = t.index + 1;
            else if (up && t.index >= cols) to = t.index - cols;
            else if (down && t.index + cols < tileRepeater.count) to = t.index + cols;
            if (to >= 0) {
                tileRepeater.itemAt(to)[t.part].forceActiveFocus(Qt.TabFocusReason);
            } else if (down) {
                // Out of the grid: on from its last stop, back from its first.
                cc.chain(tileRepeater.itemAt(tileRepeater.count - 1).chevron, true);
            } else if (up) {
                cc.chain(tileRepeater.itemAt(0).disc, false);
            }
            return true;
        }
        const m = cc.miniStop(item);
        if (m >= 0 && (left || right)) {
            const to = m + (right ? 1 : -1);
            if (to >= 0 && to < miniRepeater.count) miniRepeater.itemAt(to).forceActiveFocus(Qt.TabFocusReason);
            return true;
        }
        if (up || down) {
            cc.chain(item, down);
            return true;
        }
        return false;
    }

    component Spatial: NumberAnimation {
        duration: Motion.spatial
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.spring
    }

    ParallelAnimation {
        id: sheetIn
        Spatial {
            target: cc
            property: "sheetOffset"
            from: 760
            to: 0
        }
    }
    SequentialAnimation {
        id: sheetOut
        Spatial {
            target: cc
            property: "sheetOffset"
            to: 760
        }
        ScriptAction {
            script: if (cc.sheet === "") sheetLoader.source = ""
        }
    }
    ParallelAnimation {
        id: homeOut
        NumberAnimation {
            target: home
            property: "opacity"
            to: 0
            duration: Motion.exitFade
            easing.type: Easing.Linear
        }
        Spatial {
            target: homeShift
            property: "x"
            to: -24
        }
    }
    ParallelAnimation {
        id: homeIn
        SequentialAnimation {
            PauseAnimation { duration: Motion.stagger }
            NumberAnimation {
                target: home
                property: "opacity"
                to: 1
                duration: Motion.effects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spring
            }
        }
        Spatial {
            target: homeShift
            property: "x"
            to: 0
        }
    }

    // ---- home ---------------------------------------------------------------

    Item {
        id: home
        x: 16
        y: 16
        width: 728
        height: 528
        visible: opacity > 0
        enabled: cc.sheet === ""
        transform: Translate {
            id: homeShift
        }
        Keys.onPressed: event => {
            if (cc.arrow(event)) event.accepted = true;
        }

        // Holds the keys when the pointer opened the control center: no ring,
        // Esc closes (the root's handler), Tab moves on to the Wi-Fi disc.
        Item {
            id: homeKeys
            objectName: "ccHomeKeys"
        }

        Item {
            id: topRow
            width: parent.width
            height: 148

            Grid {
                id: tileGrid
                width: 356
                columns: 2
                rowSpacing: 8
                columnSpacing: 8
                Repeater {
                    id: tileRepeater
                    model: (cc.model?.tiles ?? []).length
                    QuickTile {
                        required property int index
                        readonly property var entry: cc.model?.tiles?.[index] ?? ({})
                        width: (tileGrid.width - tileGrid.columnSpacing) / 2
                        key: entry.key ?? ""
                        label: entry.label ?? ""
                        sub: entry.sub ?? ""
                        icon: entry.icon ?? ""
                        checked: entry.on === true
                        busy: entry.busy === true
                        enabled: entry.enabled !== false
                        onToggled: on => cc.action("tile", { key: key, on: on })
                        onMore: byKey => cc.openSheet(cc.tileSheets[key] ?? "", null, byKey)
                    }
                }
            }
            CcMedia {
                id: mediaCard
                x: tileGrid.width + 12
                width: parent.width - x
                height: 148
                media: cc.model?.media ?? undefined
                animated: cc.shown && cc.animated
                onPrevious: cc.action("media", "previous")
                onTogglePlaying: cc.action("media", "toggle")
                onNext: cc.action("media", "next")
                onSeek: fraction => cc.action("seek", fraction)
                onCycle: cc.action("cycle", null)
            }
        }

        LevelsCard {
            id: levelsCard
            y: topRow.height + 12
            width: parent.width
            rows: cc.model?.levels ?? []
            onMoved: (key, value) => cc.action("level", { key: key, value: value })
            onIconClicked: key => cc.action("mute", key)
            onDevice: (key, byKey) => cc.openSheet(key === "volume" ? "sound" : "display", null, byKey)
        }

        Row {
            id: miniRow
            y: levelsCard.y + levelsCard.height + 12
            width: parent.width
            height: 64
            spacing: 8
            Repeater {
                id: miniRepeater
                model: (cc.model?.minis ?? []).length
                MiniTile {
                    required property int index
                    readonly property var entry: cc.model?.minis?.[index] ?? ({})
                    width: (miniRow.width - 5 * miniRow.spacing) / 6
                    height: 64
                    key: entry.key ?? ""
                    label: entry.label ?? ""
                    sub: entry.sub ?? ""
                    icon: entry.icon ?? ""
                    checked: entry.on === true
                    hasSheet: (entry.sheet ?? "") !== ""
                    // `opens`: the press opens the sheet instead (the night
                    // light while hyprsunset is not answering).
                    onClicked: byKey => {
                        if (key === "display" || key === "power") cc.openSheet("display", null, byKey);
                        else if (entry.opens === true && hasSheet) cc.openSheet(entry.sheet, null, byKey);
                        else cc.action("mini", key);
                    }
                    onMore: byKey => {
                        if (hasSheet) cc.openSheet(entry.sheet, null, byKey);
                    }
                }
            }
        }

        NotifCard {
            id: notesCard
            y: miniRow.y + miniRow.height + 12
            width: parent.width
            notes: cc.model?.notes ?? ({ count: 0, rows: [] })
            onClearAll: cc.action("clearNotes", null)
            onOpen: index => cc.action("openNote", index)
            onMore: cc.openSheet("notifications", null, false)
        }

        Item {
            id: footer
            y: notesCard.y + notesCard.height + 12
            width: parent.width
            height: 36

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 14
                    color: Tokens.fillHigh
                    Text {
                        anchors.centerIn: parent
                        text: cc.model?.footer?.letter ?? ""
                        color: Tokens.fg
                        textFormat: Text.PlainText
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: cc.model?.footer?.user ?? ""
                    color: Tokens.fg
                    textFormat: Text.PlainText
                    font.family: "Adwaita Sans"
                    font.pixelSize: 13
                }
                Item {
                    id: battery
                    objectName: "ccBattery"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: cc.model?.footer?.battery?.visible === true
                    width: batteryRow.implicitWidth
                    height: 28
                    activeFocusOnTab: visible
                    readonly property real radius: 8
                    Accessible.role: Accessible.Button
                    Accessible.name: "Battery, " + (cc.model?.footer?.battery?.text ?? "")
                    Accessible.onPressAction: cc.action("battery", null)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            cc.action("battery", null);
                            event.accepted = true;
                        }
                    }
                    Row {
                        id: batteryRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: cc.model?.footer?.battery?.icon ?? "battery"
                            size: 14
                            color: cc.model?.footer?.battery?.low ? Tokens.bad : Tokens.inkDim
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: cc.model?.footer?.battery?.text ?? ""
                            color: cc.model?.footer?.battery?.low ? Tokens.bad : Tokens.inkDim
                            textFormat: Text.PlainText
                            font.family: "Adwaita Sans"
                            font.pixelSize: 12
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cc.action("battery", null)
                    }
                    FocusRing {}
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                // The tray (DECISION 5: between the battery and Lock). Left
                // click activates (or opens the menu of a menu-only item),
                // right click opens its menu, middle click its secondary
                // action, the wheel scrolls it; the host does each.
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Repeater {
                        id: trayRepeater
                        model: (cc.model?.footer?.tray ?? []).length
                        Rectangle {
                            id: trayButton
                            required property int index
                            readonly property var entry: cc.model?.footer?.tray?.[index] ?? ({})
                            objectName: "ccTray-" + index
                            width: 28
                            height: 28
                            radius: 8
                            color: trayArea.containsMouse || activeFocus ? Tokens.fillLow : "transparent"
                            opacity: entry.passive ? 0.55 : 1
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: entry.title ?? ""
                            Accessible.onPressAction: cc.action("tray", { index: index, button: "left" })
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    cc.action("tray", { index: trayButton.index, button: "left" });
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Menu) {
                                    cc.action("tray", { index: trayButton.index, button: "right" });
                                    event.accepted = true;
                                }
                            }
                            Image {
                                anchors.centerIn: parent
                                visible: (trayButton.entry.icon ?? "") !== ""
                                width: 16
                                height: 16
                                source: visible ? trayButton.entry.icon : ""
                                sourceSize.width: 16
                                sourceSize.height: 16
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: (trayButton.entry.icon ?? "") === "" && (trayButton.entry.glyph ?? "") !== ""
                                name: trayButton.entry.glyph ?? ""
                                size: 16
                                color: Tokens.fg
                            }
                            MouseArea {
                                id: trayArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => cc.action("tray", {
                                        index: trayButton.index,
                                        button: mouse.button === Qt.RightButton ? "right" : mouse.button === Qt.MiddleButton ? "middle" : "left"
                                    })
                                onWheel: wheel => cc.action("trayScroll", { index: trayButton.index, delta: wheel.angleDelta.y })
                            }
                            FocusRing {}
                        }
                    }
                }
                FooterButton {
                    id: lockButton
                    objectName: "ccLock"
                    iconName: "lock"
                    label: "Lock"
                    onActivated: cc.action("lock", null)
                }
                FooterButton {
                    id: powerButton
                    objectName: "ccPower"
                    iconName: "power"
                    label: "Power menu"
                    onActivated: cc.action("power", null)
                }
            }
        }
    }

    // ---- the sheet ----------------------------------------------------------

    Item {
        id: sheetArea
        x: 16
        y: 16
        width: 728
        height: 528
        visible: sheetLoader.item !== null
        Loader {
            id: sheetLoader
            x: cc.sheetOffset
            width: parent.width
            height: parent.height
            onLoaded: {
                item.width = Qt.binding(() => sheetLoader.width);
                item.height = Qt.binding(() => sheetLoader.height);
            }
        }
        Connections {
            target: sheetLoader.item
            ignoreUnknownSignals: true
            function onBack() {
                cc.back();
            }
            function onDismissed() {
                cc.closeRequested();
            }
            function onNavigate(page) {
                cc.openSheet(page, null, sheetLoader.item?.keyboard === true);
            }
        }
    }

    component FooterButton: Rectangle {
        id: button
        property string iconName: ""
        property string label: ""
        signal activated
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 34
        height: 34
        radius: 10
        color: buttonArea.containsMouse ? Tokens.fillHigh : Tokens.fillLow
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.onPressAction: button.activated()
        Keys.onPressed: event => {
            if (event.isAutoRepeat) return;
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                button.activated();
                event.accepted = true;
            }
        }
        Icon {
            anchors.centerIn: parent
            name: button.iconName
            size: 16
            color: Tokens.fg
        }
        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
        FocusRing {}
    }
}
