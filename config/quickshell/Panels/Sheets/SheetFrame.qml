import QtQuick
import qs
import qs.Kit

// SheetFrame.qml - the frame every control center sheet shares
// (control-lock 3.2, Control board).
//
//   [‹] Wi-Fi                                     On  [==●]      h36
//   CONNECTED                                                    11 / 500, uppercase
//   ┌──────────────────────────────────────────────────────┐
//   │ ◉  home-5g                                           │     rows min 46
//   │    Secured                                           │
//   └──────────────────────────────────────────────────────┘
//   ...                                                          14 apart
//   [            Network settings  ›                       ]    h38
//
// The header: back (32 square, radius 10, `fillLow`, chevL 16; "Back to the
// control center"), the title (15 / 500), the state (12 `inkDim`), a Kit
// Switch. Groups: a label (11 / 500, uppercase, 0.66 spacing, `inkDim`,
// padding 0 4) over a card (`raised`, radius 14, hairline, padding 4).
// Rows: at least 46 high (the text column's own 6 px padding top and bottom
// counts once), padding 0 10, 10 apart, radius 10; `accentTint` when on,
// `fillLow` on hover; the icon `accent` when on, `inkDim` when dim; title 13,
// sub 11 `inkDim` (in `bad` for an error row; for a `wrap` row up to
// `lines` lines, four when it names none, else one); an optional 110 x 6
// slider;
// the trail (Monaspace 11 `inkDim`, at least 18 wide). A `stepper` row puts
// a minus and a plus (26 square, radius 8, the trash button's look, `minus`
// and `plus` 14 `inkDim`) either side of its trail: stepped(row, -1 | 1). A
// slider's key step is the row's `step` (5 % when it names none). A row that can be
// forgotten shows a trash button on hover or keyboard focus [GUESS]. The
// footer button is 38 high, radius 12, hairline, no fill, 13 `fg` then chev
// 14 `inkDim`.
//
// The keyboard's row draws Kit's focus ring (2 px `accent`, 2 px outside the
// row) only while the keys are in use (main-tokens 2.6): the sheet opened by
// key (`keyboard`, which the host sets), or a key walked the rows since. A
// pointer press on a row hides it again.
//
// The groups scroll between the header and the footer when they do not fit
// (StopAtBounds) [GUESS]. In the control center the frame is 728 x 528; in
// the launcher's System view it takes its implicit height and the launcher
// scrolls.
//
// Keys [GUESS, control-lock 3.2]: focus lands on the first row; Up and Down
// (or Ctrl+K / Ctrl+J) walk the rows, Enter runs the current one, Delete forgets it, Esc, Backspace and
// Alt+Left go back. Left and Right step a `stepper` row, and move a slider
// row that names its `step` (the night light's warmth) by it. One row at a time can ask for a passphrase
// (`expandedKey`): it grows 52 for a 40 px field; Enter submits, Esc folds it.
// The field is cleared whenever the sheet hides, so a typed secret never
// outlives it.
//
// The interface the launcher's System provider and the control center both
// use: `shown`, `monitor`, dismissed() (close whatever hosts the sheet),
// navigate(page) (another sheet) and back(). `backHandler`, when set, gets
// the first say on back (a nested page steps out of itself first).
//
// sheetData: what lib/CcData.js's sheet functions return: { status,
// switchOn, switchEnabled, hasSwitch, groups: [{ label, rows }], footer,
// footerEnabled }. `content`, when set, is a component drawn under the
// groups in the same scroll (the Profile picture sheet's grid), and
// `keyHandler(event)`, when set, gets the first say on a key the frame
// itself holds (true: taken). The group and row Repeaters count rows rather than take
// the arrays, so a service changing (a volume step, a rescan) updates the rows
// in place: a slider being dragged or a row holding focus is never rebuilt.
FocusScope {
    id: frame

    property bool shown: false
    property var monitor: null
    property string title: ""
    property string switchLabel: title
    property var sheetData: ({ status: "", switchOn: false, switchEnabled: true, hasSwitch: false, groups: [], footer: "", footerEnabled: true })
    property var backHandler: null
    // Drawn under the groups, in their scroll; its item is `contentItem`.
    property Component content: null
    property var keyHandler: null
    readonly property alias contentItem: contentLoader.item
    // The row (by key) showing the passphrase field, "" for none.
    property string expandedKey: ""
    property string fieldPlaceholder: "Password"
    // The keyboard's row, an index into `rows`.
    property int current: 0
    // The keys are in use: the keyboard's row draws its ring and trash.
    property bool keyboard: false
    // The frame itself holds the keys (not the back button, the switch, the
    // footer or a passphrase field).
    readonly property bool rowsFocused: frame.activeFocus && frame.Window.activeFocusItem === frame

    signal dismissed
    signal navigate(string page)
    signal back
    signal switchToggled(bool on)
    signal activated(var row)
    signal slid(var row, real value)
    signal forgot(var row)
    signal footerClicked
    signal submitted(var row, string text)
    signal stepped(var row, int delta)

    // Every row that does something, in order.
    readonly property var rows: {
        const out = [];
        for (const g of sheetData?.groups ?? [])
            for (const r of g.rows ?? [])
                if (!r.inert) out.push(r);
        return out;
    }
    readonly property var currentRow: rows[Math.max(0, Math.min(current, rows.length - 1))] ?? null
    readonly property alias backButton: backButton
    readonly property alias toggle: toggle
    readonly property alias body: body
    readonly property alias footerButton: footerButton
    readonly property bool hasFooter: (sheetData?.footer ?? "") !== ""

    implicitWidth: 728
    implicitHeight: 36 + 14 + groups.implicitHeight + (hasFooter ? 14 + 38 : 0)

    Accessible.role: Accessible.Pane
    Accessible.name: title

    // A row's field clears itself whenever it folds (SheetRow).
    onShownChanged: {
        expandedKey = "";
        if (shown) current = 0;
        else keyboard = false;
    }
    onRowsChanged: current = Math.max(0, Math.min(current, rows.length - 1))
    onExpandedKeyChanged: if (expandedKey === "") frame.forceActiveFocus()

    function goBack() {
        if (frame.expandedKey !== "") {
            frame.expandedKey = "";
            return;
        }
        if (typeof frame.backHandler === "function" && frame.backHandler()) return;
        frame.back();
    }
    function move(step) {
        if (!rows.length) return;
        current = (current + step + rows.length) % rows.length;
        const item = rowItem(rows[current].key);
        if (item) body.ensureVisible(item);
    }
    function activate(row) {
        if (!row || row.inert) return;
        current = Math.max(0, rows.findIndex(r => r.key === row.key));
        frame.activated(row);
    }
    // A pointer press: the ring and the trash wait for the keys again.
    function press(row) {
        frame.keyboard = false;
        frame.activate(row);
    }
    // Left and Right reach this row: a stepper, or a slider with its own step.
    function steps(row): bool {
        return !!row && !row.inert && (row.stepper === true || (typeof row.slider === "number" && row.step > 0));
    }
    function step(row, delta: int) {
        if (!frame.steps(row)) return;
        if (row.stepper === true) frame.stepped(row, delta);
        else frame.slid(row, Math.max(0, Math.min(1, row.slider + delta * row.step)));
    }
    // The row item with this key, or null.
    function rowItem(key) {
        for (let g = 0; g < groupRepeater.count; g++) {
            const group = groupRepeater.itemAt(g);
            const rep = group ? group.rowRepeater : null;
            for (let i = 0; rep && i < rep.count; i++) {
                const item = rep.itemAt(i);
                if (item && item.row.key === key) return item;
            }
        }
        return null;
    }

    Keys.onPressed: event => {
        const ctrl = event.modifiers & Qt.ControlModifier;
        // Tab leaves for the header and the footer (the focus chain), and the
        // keys are in use from then on.
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            frame.keyboard = true;
            return;
        }
        if (typeof frame.keyHandler === "function" && frame.keyHandler(event)) {
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || (event.key === Qt.Key_Left && event.modifiers & Qt.AltModifier)) {
            frame.goBack();
        } else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_J)) {
            // Opened by the pointer, the first press shows the ring where the
            // keys are (the first row) and the next ones move it.
            if (frame.keyboard) frame.move(1);
            frame.keyboard = true;
        } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_K)) {
            if (frame.keyboard) frame.move(-1);
            frame.keyboard = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (event.isAutoRepeat) return;
            frame.keyboard = true;
            frame.activate(frame.currentRow);
        } else if (event.key === Qt.Key_Delete) {
            frame.keyboard = true;
            if (frame.currentRow?.forget) frame.forgot(frame.currentRow);
        } else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right) && !(event.modifiers & (Qt.AltModifier | Qt.ControlModifier)) && frame.steps(frame.currentRow)) {
            frame.keyboard = true;
            frame.step(frame.currentRow, event.key === Qt.Key_Right ? 1 : -1);
        } else {
            return;
        }
        event.accepted = true;
    }

    // ---- header -------------------------------------------------------------

    Item {
        id: header
        width: parent.width
        height: 36

        Rectangle {
            id: backButton
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 10
            color: backArea.containsMouse ? Tokens.fillHigh : Tokens.fillLow
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: "Back to the control center"
            Accessible.onPressAction: frame.goBack()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    frame.goBack();
                    event.accepted = true;
                }
            }
            Icon {
                anchors.centerIn: parent
                name: "chevL"
                size: 16
                color: Tokens.fg
            }
            MouseArea {
                id: backArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: frame.goBack()
            }
            FocusRing {}
        }
        Text {
            id: titleText
            x: backButton.width + 8
            anchors.verticalCenter: parent.verticalCenter
            width: statusText.x - 8 - x
            text: frame.title
            color: Tokens.fg
            elide: Text.ElideRight
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 15
            font.weight: Font.Medium
        }
        Text {
            id: statusText
            x: (toggle.visible ? toggle.x - 8 : parent.width) - width
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width / 2)
            elide: Text.ElideRight
            text: frame.sheetData?.status ?? ""
            color: Tokens.inkDim
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 12
        }
        Switch {
            id: toggle
            objectName: "sheetSwitch"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: frame.sheetData?.hasSwitch !== false
            enabled: frame.sheetData?.switchEnabled !== false
            checked: frame.sheetData?.switchOn === true
            label: frame.switchLabel
            onToggled: on => frame.switchToggled(on)
        }
    }

    // ---- groups -------------------------------------------------------------

    Flickable {
        id: body
        y: header.height + 14
        width: parent.width
        height: Math.max(0, frame.height - y - (frame.hasFooter ? 14 + 38 : 0))
        contentWidth: width
        contentHeight: groups.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        clip: contentHeight > height

        function ensureVisible(item) {
            const p = item.mapToItem(groups, 0, 0);
            if (p.y < contentY) contentY = p.y;
            else if (p.y + item.height > contentY + height) contentY = p.y + item.height - height;
        }

        Column {
            id: groups
            width: parent.width
            spacing: 14
            Repeater {
                id: groupRepeater
                model: (frame.sheetData?.groups ?? []).length
                Column {
                    id: group
                    required property int index
                    readonly property var entry: frame.sheetData?.groups?.[index] ?? ({})
                    readonly property alias rowRepeater: rowRepeater
                    width: groups.width
                    spacing: 6
                    Text {
                        visible: (group.entry.label ?? "") !== ""
                        leftPadding: 4
                        rightPadding: 4
                        text: String(group.entry.label ?? "").toUpperCase()
                        color: Tokens.inkDim
                        textFormat: Text.PlainText
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        font.letterSpacing: 0.66
                    }
                    Rectangle {
                        width: parent.width
                        height: cardRows.implicitHeight + 8
                        radius: 14
                        color: Tokens.raised
                        border.width: 1
                        border.color: Tokens.hairline
                        Column {
                            id: cardRows
                            x: 4
                            y: 4
                            width: parent.width - 8
                            Repeater {
                                id: rowRepeater
                                model: (group.entry.rows ?? []).length
                                SheetRow {
                                    required property int index
                                    width: cardRows.width
                                    row: group.entry.rows?.[index] ?? ({})
                                }
                            }
                        }
                    }
                }
            }
            Loader {
                id: contentLoader
                width: groups.width
                active: frame.content !== null
                visible: active
                sourceComponent: frame.content
            }
        }
    }

    // ---- footer -------------------------------------------------------------

    Rectangle {
        id: footerButton
        objectName: "sheetFooter"
        visible: frame.hasFooter
        y: frame.height - height
        width: parent.width
        height: 38
        radius: 12
        color: footerArea.containsMouse ? Tokens.fillLow : "transparent"
        border.width: 1
        border.color: Tokens.hairline
        enabled: frame.sheetData?.footerEnabled !== false
        opacity: enabled ? 1 : 0.45
        activeFocusOnTab: visible && enabled
        Accessible.role: Accessible.Button
        Accessible.name: frame.sheetData?.footer ?? ""
        Accessible.onPressAction: frame.footerClicked()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                frame.footerClicked();
                event.accepted = true;
            }
        }
        Row {
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: frame.sheetData?.footer ?? ""
                color: Tokens.fg
                textFormat: Text.PlainText
                font.family: "Adwaita Sans"
                font.pixelSize: 13
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "chev"
                size: 14
                color: Tokens.inkDim
            }
        }
        MouseArea {
            id: footerArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: frame.footerClicked()
        }
        FocusRing {}
    }

    // Enter in a row's passphrase field.
    function submit(item, text) {
        frame.expandedKey = "";
        if (item && text !== "") frame.submitted(item.row, text);
    }

    // ---- one row ------------------------------------------------------------

    // A stepper row's minus or plus, beside its trail (the night light's From
    // and To: earlier and later).
    component StepButton: Rectangle {
        id: stepButton
        property int delta: 1
        property var row: ({})
        anchors.verticalCenter: parent.verticalCenter
        visible: row.stepper === true
        width: 26
        height: 26
        radius: 8
        color: stepArea.containsMouse ? Tokens.fillHigh : "transparent"
        Accessible.role: Accessible.Button
        Accessible.name: (delta < 0 ? "Earlier " : "Later ") + (row.title ?? "")
        Accessible.onPressAction: frame.step(row, delta)
        Icon {
            anchors.centerIn: parent
            name: stepButton.delta < 0 ? "minus" : "plus"
            size: 14
            color: stepArea.containsMouse ? Tokens.fg : Tokens.inkDim
        }
        MouseArea {
            id: stepArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                frame.keyboard = false;
                frame.step(stepButton.row, stepButton.delta);
            }
        }
    }

    component SheetRow: Item {
        id: rowItem
        property var row: ({})
        readonly property bool on: row.on === true
        readonly property bool isCurrent: frame.rowsFocused && frame.currentRow !== null && frame.currentRow.key === row.key
        // The ring and the trash: only while the keys are in use.
        readonly property bool keyFocus: isCurrent && frame.keyboard
        readonly property bool expanded: frame.expandedKey !== "" && frame.expandedKey === row.key
        readonly property alias field: rowField
        readonly property alias subText: subText
        objectName: "sheetRow-" + (row.key ?? "")
        implicitHeight: main.height + (expanded ? 52 : 0)
        height: implicitHeight
        Accessible.role: Accessible.ListItem
        Accessible.name: (row.title ?? "") + (row.sub ? ", " + row.sub : "")
        Accessible.selected: on
        Accessible.onPressAction: frame.activate(row)

        Item {
            id: main
            width: parent.width
            // textCol's implicitHeight already holds its 6 + 6 padding.
            height: Math.max(46, textCol.implicitHeight)

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: rowItem.on ? Tokens.accentTint : area.containsMouse && !rowItem.row.inert ? Tokens.fillLow : "transparent"
            }
            FocusRing {
                objectName: "sheetRowRing"
                targetRadius: 10
                show: rowItem.keyFocus
            }
            Item {
                id: iconBox
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: (rowItem.row.icon ?? "") !== "" || (rowItem.row.image ?? "") !== "" ? 16 : 0
                height: 16
                Icon {
                    anchors.fill: parent
                    visible: (rowItem.row.icon ?? "") !== ""
                    name: rowItem.row.icon ?? ""
                    size: 16
                    color: rowItem.on ? Tokens.accent : rowItem.row.dim ? Tokens.inkDim : Tokens.fg
                }
                Image {
                    anchors.fill: parent
                    visible: (rowItem.row.image ?? "") !== "" && (rowItem.row.icon ?? "") === ""
                    source: visible ? rowItem.row.image : ""
                    sourceSize.width: 16
                    sourceSize.height: 16
                }
            }
            Column {
                id: textCol
                x: iconBox.width > 0 ? iconBox.x + iconBox.width + 10 : 10
                anchors.verticalCenter: parent.verticalCenter
                width: trailRow.x - 10 - x
                topPadding: 6
                bottomPadding: 6
                spacing: 1
                Text {
                    width: parent.width
                    text: rowItem.row.title ?? ""
                    color: rowItem.row.inert && rowItem.row.dim ? Tokens.inkDim : Tokens.fg
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    textFormat: Text.PlainText
                    font.family: "Adwaita Sans"
                    font.pixelSize: 13
                }
                Text {
                    id: subText
                    width: parent.width
                    visible: (rowItem.row.sub ?? "") !== ""
                    text: rowItem.row.sub ?? ""
                    color: rowItem.row.bad ? Tokens.bad : Tokens.inkDim
                    // `wrap` (the battery sheet's hints, a notification's
                    // body): up to `lines`, else four.
                    wrapMode: rowItem.row.wrap === true ? Text.Wrap : Text.NoWrap
                    elide: Text.ElideRight
                    maximumLineCount: rowItem.row.wrap === true ? (rowItem.row.lines > 0 ? rowItem.row.lines : 4) : 1
                    textFormat: Text.PlainText
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11
                }
            }
            Row {
                id: trailRow
                x: parent.width - 10 - width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Slider {
                    objectName: "sheetRowSlider"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: typeof rowItem.row.slider === "number"
                    width: 110
                    height: 24
                    value: typeof rowItem.row.slider === "number" ? rowItem.row.slider : 0
                    stepSize: rowItem.row.step > 0 ? rowItem.row.step : 0.05
                    label: rowItem.row.title ?? ""
                    onMoved: v => frame.slid(rowItem.row, v)
                }
                Rectangle {
                    id: forgetButton
                    objectName: "sheetForget"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rowItem.row.forget === true && (area.containsMouse || forgetArea.containsMouse || rowItem.keyFocus)
                    width: 26
                    height: 26
                    radius: 8
                    color: forgetArea.containsMouse ? Tokens.fillHigh : "transparent"
                    Accessible.role: Accessible.Button
                    Accessible.name: "Forget " + (rowItem.row.title ?? "")
                    Accessible.onPressAction: frame.forgot(rowItem.row)
                    Icon {
                        anchors.centerIn: parent
                        name: "trash"
                        size: 14
                        color: forgetArea.containsMouse ? Tokens.bad : Tokens.inkDim
                    }
                    MouseArea {
                        id: forgetArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: frame.forgot(rowItem.row)
                    }
                }
                StepButton {
                    objectName: "sheetStepDown"
                    row: rowItem.row
                    delta: -1
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: (rowItem.row.trail ?? "") !== ""
                    width: Math.max(18, implicitWidth)
                    horizontalAlignment: rowItem.row.stepper === true ? Text.AlignHCenter : Text.AlignRight
                    text: rowItem.row.trail ?? ""
                    color: Tokens.inkDim
                    textFormat: Text.PlainText
                    font.family: "Monaspace Argon"
                    font.pixelSize: 11
                }
                StepButton {
                    objectName: "sheetStepUp"
                    row: rowItem.row
                    delta: 1
                }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                // Below the trail's own controls.
                z: -1
                hoverEnabled: true
                enabled: !rowItem.row.inert
                cursorShape: rowItem.row.inert ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: frame.press(rowItem.row)
            }
        }
        onExpandedChanged: {
            rowField.text = "";
            if (expanded) Qt.callLater(() => rowField.forceActiveFocus());
        }
        Rectangle {
            visible: rowItem.expanded
            x: 10
            y: main.height + 6
            width: parent.width - 20
            height: 40
            radius: 10
            color: Tokens.fillLow
            border.width: 1
            border.color: Tokens.faint
            TextInput {
                id: rowField
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                enabled: rowItem.expanded
                echoMode: TextInput.Password
                color: Tokens.fg
                selectionColor: Tokens.accentTint
                selectedTextColor: Tokens.fg
                font.family: "Adwaita Sans"
                font.pixelSize: 13
                clip: true
                Accessible.role: Accessible.EditableText
                Accessible.name: frame.fieldPlaceholder
                Keys.onReturnPressed: frame.submit(rowItem, rowField.text)
                Keys.onEnterPressed: frame.submit(rowItem, rowField.text)
                Keys.onEscapePressed: frame.expandedKey = ""
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rowField.text === ""
                    text: frame.fieldPlaceholder
                    color: Tokens.inkMid
                    font: rowField.font
                }
            }
        }
    }
}
