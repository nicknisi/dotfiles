import QtQuick
import Quickshell
import qs
import qs.Kit
import qs.Ui as Ui
import "../core/UserHotkeys.js" as UserHotkeys

// LauncherContent.qml - the launcher's view (PLAN M5, launcher-pickers 4-5,
// Launcher and Main boards). launcher/Keystroke.qml is the engine; this draws
// it and hands it the keys.
//
//   ┌ [search] query|                               All sources ┐  header 56
//   │ ┌ list 440 ──────────────────┐ ┌ detail card 306 x 352 ┐ │
//   │ │ [tile] Screenshot Region   │ │                       │ │  body 378
//   │ │ ...rows 48, gap 2          │ │                       │ │
//   │ └────────────────────────────┘ └───────────────────────┘ │
//   └ Apps · Files · Clipboard · ...        Hold [Super Space] ┘  footer 38
//
// 760 x 472, a fixed implicit size and no background of its own, so either
// host can hold it (PLAN 1.6): the island's `launcher` state (the body is the
// material) or Launcher.qml's free panel in pill, full and rail. A picker
// (`launcher select`/`input`) is its requested width and only as tall as its
// rows, with no card and no footer.
//
// Modes swap the body: the clipboard scope's denser rows and preview (5.1),
// a colour answer (5.3), the voice meter and transcript (5.4); a provider
// view (Codex, the device menus, Settings screens) covers everything (5.2).
// The hotkey recorder and the confirm dialog cover it while they run.
//
// Exactly one content is `active` at a time: it registers its query field,
// list and provider-view item with the engine (Keystroke.attach), which
// drives them from then on. Behaviour per DECISION 2: Tab and Shift+Tab move
// the selection, Enter copies a clipboard entry and Ctrl+Enter pastes it, a
// transcript waits for Enter.
Item {
    id: content

    property var engine: null
    property bool active: true

    readonly property bool attached: engine !== null && engine.attachedView === content
    readonly property var rows: engine ? engine.rows : []
    readonly property var current: engine ? engine.current : ({})
    readonly property bool dmenu: !!engine && engine.dmenuActive
    readonly property bool inputOnly: !!engine && engine.mode === "input"
    readonly property bool viewShown: !!engine && engine.providerViewActive
    readonly property bool scoped: !!engine && engine.scope !== "" && !dmenu
    readonly property bool clipboard: !!engine && engine.scope === "clipboard"
    readonly property bool colorAnswer: rows.length > 0 && rows[0].answerKind === "color"
    readonly property var answerRow: rows.length > 0 && rows[0].tier === "answer" ? rows[0] : null
    // For inspect() and the shots: the list, the card and the selected row.
    readonly property alias listItem: list
    readonly property alias cardItem: card
    readonly property alias fieldItem: field
    readonly property Item selectedRow: list.currentItem ? list.currentItem.row : null

    // The sandbox's voice fixture (launcherVoice: phase, trigger, level,
    // history, text) stands in for the voice session, which needs voxtype.
    readonly property var fixtureVoice: {
        const f = Fixture.data.launcherVoice;
        if (!f) return null;
        const phase = f.phase ?? "listening";
        return { phase: phase, active: phase !== "idle", level: Number(f.level) || 0, history: f.history ?? [], liveText: f.text ?? "", trigger: f.trigger ?? "hold" };
    }
    readonly property var voice: fixtureVoice ?? (engine ? engine.voice : null)
    readonly property bool voiceActive: !!voice && voice.active === true
    readonly property string voiceTrigger: fixtureVoice ? fixtureVoice.trigger : (engine ? engine.voiceTrigger : "tap")

    readonly property bool cardShown: !dmenu && !colorAnswer && !voiceActive && rows.length > 0 && !!engine && engine.paletteSettings.showPreview !== false
    readonly property bool dense: clipboard || voiceActive
    readonly property int rowHeight: dense ? 46 : 48
    readonly property int listWidth: cardShown ? 440 : width
    // Sections get headers only when a query or scope mixes them (4.2).
    readonly property bool sectioned: {
        if (dmenu || voiceActive || !engine || (!engine.matchQuery && !scoped)) return false;
        const seen = {};
        let n = 0;
        for (const r of rows) {
            if (!seen[r.section]) {
                seen[r.section] = true;
                n++;
            }
            if (n > 1) return true;
        }
        return false;
    }

    // A picker: the requested width, as tall as its rows (up to its maxHeight).
    readonly property int dmenuCap: engine && engine.dmenuMaxHeight > 0 ? Math.max(1, Math.floor((engine.dmenuMaxHeight - 72) / 50)) : 8
    readonly property int dmenuHeight: 56 + (inputOnly ? 0 : Math.min(dmenuCap, Math.max(1, list.count)) * 50 - 2 + 16)
    implicitWidth: dmenu ? Math.max(300, engine.dmenuWidth) : 760
    implicitHeight: dmenu ? dmenuHeight : 472

    // ---- the engine's hold on this view ------------------------------------
    function sync() {
        if (!engine) return;
        if (active) engine.attach(content, field, list);
        else engine.detach(content);
    }
    function detached() {}
    // The detail card's Actions list (the sandbox's `launcher actions`).
    function openActions() {
        if (card.visible) card.openMenu();
        return card.menuOpen;
    }
    onActiveChanged: sync()
    onEngineChanged: sync()
    Component.onCompleted: {
        sync();
        if (active && engine && engine.opened) Qt.callLater(() => content.engine && content.engine.focusInput());
    }
    Component.onDestruction: if (engine) engine.detach(content)

    Translate {
        id: levelShift
        x: content.engine ? content.engine.levelTransform.x : 0
    }
    readonly property real levelOpacity: engine ? engine.levelOpacity : 1

    Connections {
        target: content.engine
        ignoreUnknownSignals: true
        function onFlashed(uid) {
            for (let i = 0; i < list.count; i++) {
                const d = list.itemAtIndex(i);
                if (d && d.uid === uid) d.flash();
            }
        }
    }

    // ---- header (56) ---------------------------------------------------------
    Item {
        id: header
        visible: !content.viewShown
        width: parent.width
        height: 56

        Rectangle {
            y: parent.height - 1
            width: parent.width
            height: 1
            color: Tokens.hairline
        }

        Icon {
            id: lead
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            name: content.voiceActive ? "mic" : "search"
            size: content.voiceActive ? 16 : 18
            color: content.voiceActive ? Tokens.accent : Tokens.inkDim
        }

        // Inside a scope: "Clipboard History ×", left of the query.
        Rectangle {
            id: scopeChip
            visible: content.scoped && !content.voiceActive
            anchors.left: lead.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? scopeLabel.implicitWidth + 10 + 6 + 14 + 6 : 0
            height: 24
            radius: 12
            color: Tokens.fillHigh
            Accessible.role: Accessible.Button
            Accessible.name: "Leave " + scopeLabel.text
            Text {
                id: scopeLabel
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                text: content.engine ? content.engine.scopeTitle : ""
                textFormat: Text.PlainText
                color: Tokens.fg
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
            Icon {
                anchors.left: scopeLabel.right
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                name: "x"
                size: 14
                color: Tokens.inkDim
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: content.engine.goBack()
            }
        }

        // Right: the source chip, or Esc inside a scope, or the voice label.
        Row {
            id: right
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Text {
                visible: content.voiceActive
                anchors.verticalCenter: parent.verticalCenter
                text: !content.voice ? "" : content.voice.phase === "starting" ? "Starting voxtype…" : content.voice.phase === "transcribing" ? "Finishing transcript…"
                    : content.voiceTrigger === "hold" ? "Release to finish" : "↵ to finish"
                color: Tokens.inkDim
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
            Rectangle {
                visible: !content.voiceActive && !content.scoped && !content.dmenu
                anchors.verticalCenter: parent.verticalCenter
                width: sourceLabel.implicitWidth + 20
                height: sourceLabel.implicitHeight + 8
                radius: height / 2
                color: Tokens.fillLow
                Text {
                    id: sourceLabel
                    anchors.centerIn: parent
                    text: content.answerRow ? content.answerRow.providerName : "All sources"
                    textFormat: Text.PlainText
                    color: Tokens.inkDim
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                }
            }
            Keycap {
                visible: !content.voiceActive && (content.scoped || content.dmenu)
                anchors.verticalCenter: parent.verticalCenter
                text: "Esc"
            }
        }

        VoiceMeter {
            visible: content.voiceActive
            anchors.left: lead.right
            anchors.leftMargin: 12
            anchors.right: right.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            bars: Math.max(4, Math.min(28, Math.floor((width + 3) / 6)))
            history: content.voice ? content.voice.history : []
        }

        TextInput {
            id: field
            anchors.left: scopeChip.visible ? scopeChip.right : lead.right
            anchors.leftMargin: 12
            anchors.right: right.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 24
            verticalAlignment: TextInput.AlignVCenter
            // The string takes the header while speaking; focus and keys stay here.
            opacity: content.voiceActive ? 0 : 1
            text: content.engine ? content.engine.searchProxy.text : ""
            color: Tokens.fg
            selectionColor: Tokens.accentA35
            selectedTextColor: Tokens.fg
            font.family: content.colorAnswer ? "Monaspace Argon" : "Adwaita Sans"
            font.pixelSize: 16
            selectByMouse: true
            clip: true
            focus: true
            Accessible.name: content.dmenu ? content.engine.dmenuPrompt : "Search apps, files and commands"

            property bool caretOn: true
            cursorDelegate: Rectangle {
                width: 2
                height: 20
                color: Tokens.accent
                visible: field.caretOn && field.activeFocus
            }
            // The caret blinks in 500 ms steps (2.7): one frame per change,
            // never a smooth loop, and still while the motion profile is off.
            Timer {
                interval: 500
                repeat: true
                running: field.activeFocus && Motion.loops && content.visible
                onTriggered: field.caretOn = !field.caretOn
                onRunningChanged: field.caretOn = true
            }
            onCursorPositionChanged: {
                field.caretOn = true;
                if (content.attached && content.engine.searchProxy.cursorPosition !== cursorPosition) content.engine.searchProxy.cursorPosition = cursorPosition;
            }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: !field.text && !field.preeditText && !content.voiceActive
                text: !content.engine ? "" : content.engine.dictationMode ? "Speak…" : content.dmenu ? content.engine.dmenuPrompt + "…"
                    : content.scoped ? "Search " + content.engine.scopeTitle.toLowerCase() : "Search apps, files and commands"
                textFormat: Text.PlainText
                color: Tokens.inkDim
                font: field.font
                elide: Text.ElideRight
            }

            onTextEdited: if (content.engine) content.engine.typed(text)
            Keys.priority: Keys.BeforeItem
            Keys.onReleased: event => {
                const e = content.engine;
                if (!e) return;
                // Hold mode ends when the modifier comes up (Hyprland swallows the
                // hotkey's own release, and its release bind only fires while the
                // modifier is still down). A tap's release must not end anything.
                if (e.voice.active && e.voiceTrigger === "hold" && e.isSuperKey(event.key)) {
                    e.voiceStop();
                    event.accepted = true;
                }
                if (event.key === Qt.Key_Control) e.ctrlHeld = false;
                if (e.capturing && !e.captureChord && e.isModifierKey(event.key)) e.capturePartial = "";
            }
            Keys.onPressed: event => {
                const e = content.engine;
                if (!e) return;
                // Ctrl's own press carries no modifier flag yet; a chord pressed
                // with Ctrl already down (before the palette opened) does.
                e.ctrlHeld = event.key === Qt.Key_Control || !!(event.modifiers & Qt.ControlModifier);
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && event.isAutoRepeat) {
                    event.accepted = true;
                    return;
                }
                if (e.confirmPending) {
                    confirmDialog.handleKey(event);
                    event.accepted = true;
                    return;
                }
                if (e.capturing) {
                    e.captureKey(event);
                    event.accepted = true;
                    return;
                }
                if (e.voice.active) {
                    if (event.key === Qt.Key_Escape) {
                        e.cancel();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (e.dictationMode) e.dictationAccept(!!(event.modifiers & Qt.ControlModifier));
                        else e.voiceStop();
                        event.accepted = true;
                        return;
                    }
                    if (e.isModifierKey(event.key)) {
                        event.accepted = true;
                        return;
                    }
                    e.voiceCancel(); // typing and navigation supersede speech immediately
                }
                const ctrl = event.modifiers & Qt.ControlModifier;
                const atEnd = cursorPosition === text.length;
                // The detail card's Actions list, while open, takes the
                // movement keys, Enter and Esc; any other key closes it.
                if (card.menuOpen) {
                    if (event.key === Qt.Key_Escape) {
                        card.closeMenu();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Up || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab
                        || (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_P))) {
                        card.moveMenu(event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || event.key === Qt.Key_P || (event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                        event.accepted = true;
                        return;
                    }
                    if (!ctrl && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                        card.runMenu();
                        event.accepted = true;
                        return;
                    }
                    if (!e.isModifierKey(event.key)) card.closeMenu();
                }
                if (event.key === Qt.Key_Escape) {
                    e.cancel();
                    event.accepted = true;
                } else if (ctrl && event.key === Qt.Key_U) {
                    e.searchProxy.text = "";
                    e.edited();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_N)) {
                    e.select(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_P)) {
                    e.select(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageDown) {
                    e.selectPage(6);
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageUp) {
                    e.selectPage(-6);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                    e.select(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                    event.accepted = true;
                } else if (ctrl && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                    e.activate(true);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    e.activate();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right && (atEnd || !text) && !e.dmenuActive && e.rows.length) {
                    e.activate();
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Backspace) && !text && !preeditText && (e.scope || e.history.length)) {
                    e.goBack();
                    event.accepted = true;
                } else if (ctrl && event.key === Qt.Key_Delete && content.clipboard) {
                    // The old Super+V picker's wipe, now behind a confirm.
                    e.requestClipboardWipe();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Delete && !text && e.current.appId) {
                    e.requestUninstall();
                    event.accepted = true;
                } else if (ctrl && event.key >= Qt.Key_1 && event.key <= Qt.Key_8) {
                    e.activateAt(event.key - Qt.Key_1);
                    event.accepted = true;
                } else if (ctrl && event.key === Qt.Key_Comma && !e.dmenuActive) {
                    e.navigate("settings", "Settings");
                    event.accepted = true;
                } else if (ctrl && event.key === Qt.Key_B && !e.dmenuActive) {
                    e.beginCapture();
                    event.accepted = true;
                } else if (ctrl && event.key === Qt.Key_K && !e.dmenuActive) {
                    e.openProviderSettings();
                    event.accepted = true;
                }
            }
        }
    }

    // ---- body ------------------------------------------------------------------
    Item {
        id: body
        visible: !content.viewShown
        y: 56
        width: parent.width
        height: parent.height - y - (footer.visible ? footer.height : 0)
        transform: levelShift
        opacity: content.levelOpacity

        // Voice: the transcript is the query (5.4). Settled words in fg, the
        // last one, which can still change, in inkDim.
        Text {
            id: transcript
            visible: content.voiceActive
            x: 20
            y: 16
            width: parent.width - 40
            // Its own height: one or two 26 px lines (the list sits under it).
            readonly property real shownHeight: visible ? Math.max(26, implicitHeight) : 0
            readonly property string said: {
                const live = content.voice ? String(content.voice.liveText || "") : "";
                return (live || field.text).replace(/\s+/g, " ").trim();
            }
            function escaped(s) {
                return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
            }
            text: {
                if (!said) return "<font color=\"" + Tokens.hex(Tokens.inkDim) + "\">Listening…</font>";
                const cut = said.lastIndexOf(" ");
                const head = cut >= 0 ? said.slice(0, cut + 1) : "";
                const tail = cut >= 0 ? said.slice(cut + 1) : said;
                return escaped(head) + "<font color=\"" + Tokens.hex(Tokens.inkDim) + "\">" + escaped(tail) + "</font>";
            }
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            maximumLineCount: 2
            lineHeightMode: Text.FixedHeight
            lineHeight: 26
            color: Tokens.fg
            font.family: "Adwaita Sans"
            font.pixelSize: 20
        }

        ListView {
            id: list
            visible: !content.colorAnswer
            x: 10
            y: content.voiceActive ? transcript.y + transcript.shownHeight + 8 : 8
            width: content.listWidth - 20
            height: Math.max(0, parent.height - y - 8)
            model: content.engine ? content.engine.results : null
            spacing: 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: content.rowHeight * 4
            highlightFollowsCurrentItem: false
            currentIndex: -1

            delegate: Column {
                id: delegateRoot
                required property int index
                required property string uid
                required property string providerKey
                required property string title
                required property string subtitle
                required property string icon
                required property string iconFont
                required property string iconSource
                required property string section
                required property bool sectionStart
                required property string accessory
                required property bool disabled
                required property string badge
                required property string hint
                required property string ranges
                required property string glyph
                required property string meta
                required property bool mono
                readonly property bool showHeader: content.sectioned && sectionStart
                readonly property alias row: rowItem
                function flash() {
                    rowItem.flash();
                }
                width: list.width

                Item {
                    visible: delegateRoot.showHeader
                    width: parent.width
                    height: visible ? (delegateRoot.index === 0 ? 8 : 10) + headerLabel.implicitHeight + 4 : 0
                    Text {
                        id: headerLabel
                        x: 10
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        text: delegateRoot.section.toUpperCase()
                        textFormat: Text.PlainText
                        color: Tokens.inkDim
                        font.family: "Adwaita Sans"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        font.letterSpacing: 0.66
                    }
                }
                ResultRow {
                    id: rowItem
                    width: parent.width
                    height: implicitHeight
                    dense: content.dense
                    compactText: content.clipboard
                    title: delegateRoot.title
                    // Voice rows lead with their crumb (5.4: "Desktop › Pair
                    // and manage Bluetooth devices").
                    subtitle: {
                        const sub = delegateRoot.meta !== "" ? delegateRoot.meta : delegateRoot.providerKey === "applications" ? "" : delegateRoot.subtitle;
                        if (!content.voiceActive || !delegateRoot.section) return sub;
                        return sub ? delegateRoot.section + " › " + sub : delegateRoot.section;
                    }
                    glyph: delegateRoot.glyph
                    iconText: delegateRoot.icon
                    iconFont: delegateRoot.iconFont
                    iconSource: delegateRoot.iconSource
                    accessory: delegateRoot.accessory
                    badge: delegateRoot.badge
                    // The clipboard footer already says Ctrl ↵ pastes.
                    hint: delegateRoot.providerKey === "applications" || content.clipboard ? "" : delegateRoot.hint
                    ranges: delegateRoot.ranges
                    mono: delegateRoot.mono
                    disabled: delegateRoot.disabled
                    selected: !!content.engine && content.engine.selected === delegateRoot.index
                    shortcut: content.engine && content.engine.ctrlHeld && !content.dmenu && delegateRoot.index < content.engine.shortcutRows ? String(delegateRoot.index + 1) : ""
                    flashRise: content.engine ? content.engine.motion.flashRise : 0
                    flashFall: content.engine ? content.engine.motion.flashFall : 0
                    onHovered: (item, mouse) => content.engine.selectFromPointer(delegateRoot.index, item, mouse)
                    onActivated: {
                        content.engine.selectionTouched = true;
                        content.engine.selected = delegateRoot.index;
                        content.engine.activate();
                    }
                }
            }
        }

        // Nothing to show (4.4): today's copy under the sparkle.
        Column {
            visible: !!content.engine && content.rows.length === 0 && !content.inputOnly && !content.voiceActive
                && (!content.engine.pending || content.engine.showLoading)
            x: Math.round((content.listWidth - width) / 2)
            y: Math.round((parent.height - height) / 2)
            width: Math.min(content.listWidth - 40, 400)
            spacing: 10
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "sparkle"
                size: 32
                color: Tokens.accent
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: !content.engine ? "" : content.engine.pending ? "Finding your next move…" : field.text ? "No matches for “" + field.text + "”"
                    : content.clipboard ? "Your clipboard is empty" : content.engine.scope === "files" ? "Type to search your home folder" : "Nothing here yet"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Tokens.fg
                opacity: 0.8
                font.family: "Adwaita Sans"
                font.pixelSize: 13
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: text !== ""
                text: !content.engine ? "" : content.engine.scope === "converter" ? "Try 2m in feet or 10 am in London" : content.dmenu ? "" : "Search by name. Follow your curiosity."
                textFormat: Text.PlainText
                color: Tokens.inkDim
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
        }

        DetailCard {
            id: card
            visible: content.cardShown
            x: content.listWidth
            y: content.clipboard ? 10 : 12
            width: parent.width - x - (content.clipboard ? 12 : 14)
            height: parent.height - y - (content.clipboard ? 10 : 14)
            engine: content.engine
            row: content.current
        }

        ColorsAnswer {
            visible: content.colorAnswer && !content.voiceActive
            anchors.fill: parent
            engine: content.engine
        }
    }

    // ---- footer (38) -------------------------------------------------------------
    Item {
        id: footer
        visible: !content.dmenu && !content.viewShown
        y: parent.height - height
        width: parent.width
        height: 38

        Rectangle {
            width: parent.width
            height: 1
            color: Tokens.hairline
        }
        readonly property string status: {
            const e = content.engine;
            if (!e) return "";
            const v = content.voice;
            if (v && v.phase === "listening") return content.voiceTrigger === "hold" ? "Listening… release to finish" : "Listening… tap the hotkey again or press ↵ to finish";
            if (v && v.phase === "transcribing") return "Finishing transcript…";
            if (v && v.phase === "starting") return "Starting voxtype…";
            if (e.pending && e.showLoading) return "Searching…";
            if (e.errorMessage) return "Needs attention: " + e.errorMessage;
            return e.statusMessage;
        }
        // Per mode: hint lists in place of the sources, gap 16 (5.1, 5.3).
        // Ctrl Del is the old picker's wipe, clickable as it was there.
        readonly property string wipeHint: "Ctrl Del Clear history"
        readonly property var hints: content.clipboard ? ["↵ Copy", "Ctrl ↵ Paste", wipeHint]
            : content.engine && content.engine.clipboardChoice ? ["↵ Copy", "Ctrl ↵ Paste"]
            : content.colorAnswer ? ["↵ Copy", "↑↓ Format", "Try 1800 / 1.5, 3 mi in km, timer 25m"] : []

        Row {
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16
            Text {
                visible: footer.status !== "" || footer.hints.length === 0
                width: Math.min(implicitWidth, footer.width * 0.62)
                text: footer.status || "Apps · Files · Clipboard · Emoji · Codex · Calc · Timer · Colors"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: content.engine && content.engine.errorMessage && footer.status.indexOf("Needs attention") === 0 ? Tokens.bad : Tokens.inkDim
                font.family: "Adwaita Sans"
                font.pixelSize: 11
            }
            Repeater {
                model: footer.status === "" ? footer.hints : []
                Text {
                    required property string modelData
                    readonly property bool wipe: modelData === footer.wipeHint
                    text: modelData
                    color: wipe && wipeArea.containsMouse ? Tokens.bad : Tokens.inkDim
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11
                    Accessible.role: wipe ? Accessible.Button : Accessible.StaticText
                    Accessible.name: text
                    MouseArea {
                        id: wipeArea
                        visible: parent.wipe
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (content.engine) content.engine.requestClipboardWipe()
                    }
                }
            }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            // "Hold Super Space to dictate", on the palette's own footer only.
            readonly property bool dictateHint: !content.colorAnswer && !content.voiceActive && !content.clipboard
            Text {
                visible: parent.dictateHint
                anchors.verticalCenter: parent.verticalCenter
                text: "Hold"
                color: Tokens.inkDim
                font.family: "Adwaita Sans"
                font.pixelSize: 11
            }
            Keycap {
                visible: parent.dictateHint
                anchors.verticalCenter: parent.verticalCenter
                small: true
                text: "Super Space"
            }
            Text {
                visible: parent.dictateHint
                anchors.verticalCenter: parent.verticalCenter
                text: "to dictate"
                color: Tokens.inkDim
                font.family: "Adwaita Sans"
                font.pixelSize: 11
            }
        }
    }

    // ---- a provider view (Codex, device menus, Settings screens) ---------------
    Loader {
        id: providerLoader
        anchors.fill: parent
        z: 5
        transform: levelShift
        opacity: content.levelOpacity
        sourceComponent: content.attached ? content.engine.viewProxy.sourceComponent : null
        onLoaded: {
            item.host = content.engine;
            content.engine.viewProxy.item = item;
            Qt.callLater(content.engine.focusInput);
        }
        onItemChanged: if (!item && content.attached) content.engine.viewProxy.item = null
    }

    // ---- the hotkey recorder: covers the content while a chord is captured -----
    Rectangle {
        id: recorder
        visible: !!content.engine && content.engine.capturing
        z: 9
        anchors.fill: parent
        color: Tokens.surface
        MouseArea {
            anchors.fill: parent
        }
        Column {
            anchors.centerIn: parent
            width: parent.width - 80
            spacing: 14
            readonly property var e: content.engine
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.e && parent.e.captureCurrent ? "Change the hotkey for" : "Set a hotkey for"
                color: Tokens.inkDim
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: parent.e && parent.e.captureRow ? parent.e.captureRow.title : ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Tokens.fg
                font.family: "Adwaita Sans"
                font.pixelSize: 15
                font.weight: Font.Medium
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                readonly property var e: parent.e
                text: !e ? "" : e.captureChord ? UserHotkeys.display(e.captureChord) : e.capturePartial ? UserHotkeys.displayPartial(e.capturePartial)
                    : e.captureCurrent ? UserHotkeys.display(e.captureCurrent.combo) : "Press keys…"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: e && e.captureChord ? Tokens.fg : Tokens.inkDim
                font.family: "Monaspace Argon"
                font.pixelSize: 28
                font.weight: Font.Medium
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                readonly property var e: parent.e
                text: !e ? "" : e.captureChord ? e.captureCheck.message : e.captureCurrent ? "Press a new combination, or ⌫ to remove it" : "Hold a modifier, then press a key"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: !e || !e.captureChord ? Tokens.inkDim : e.captureReady ? (e.captureCheck.state === "available" ? Tokens.inkDim : Tokens.accent) : Tokens.bad
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                readonly property var e: parent.e
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Bind"
                    color: parent.e && parent.e.captureReady ? Tokens.fg : Tokens.inkDim
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11
                }
                Keycap {
                    small: true
                    text: "↵"
                }
                Item {
                    width: 10
                    height: 1
                }
                Text {
                    visible: !!parent.e && !!parent.e.captureCurrent
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.e && parent.e.captureChord ? "Clear" : "Remove"
                    color: Tokens.inkDim
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11
                }
                Keycap {
                    visible: !!parent.e && !!parent.e.captureCurrent
                    small: true
                    text: "⌫"
                }
                Item {
                    width: 10
                    height: 1
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Cancel"
                    color: Tokens.inkDim
                    font.family: "Adwaita Sans"
                    font.pixelSize: 11
                }
                Keycap {
                    small: true
                    text: "Esc"
                }
            }
        }
    }

    Ui.ConfirmDialog {
        id: confirmDialog
        anchors.fill: parent
        z: 10
        opened: !!content.engine && content.engine.confirmPending !== null
        message: content.engine && content.engine.confirmPending ? content.engine.confirmPending.message : ""
        confirmText: content.engine && content.engine.confirmPending ? content.engine.confirmPending.confirmText : "Confirm"
        background: Tokens.raised
        foreground: Tokens.fg
        scrim: Tokens.scrim
        selectedBackground: Tokens.accentTint
        selectedText: Tokens.fg
        fontFamily: "Adwaita Sans"
        cornerRadius: 14
        onCanceled: {
            content.engine.confirmPending = null;
            Qt.callLater(content.engine.focusInput);
        }
        onConfirmed: {
            const run = content.engine.confirmPending ? content.engine.confirmPending.run : null;
            content.engine.confirmPending = null;
            if (run) run();
            Qt.callLater(content.engine.focusInput);
        }
    }
}
