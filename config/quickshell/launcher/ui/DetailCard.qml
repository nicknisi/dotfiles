import QtQuick
import Quickshell.Widgets
import qs
import qs.Kit
import "../core/Glyphs.js" as Glyphs

// DetailCard.qml - the selected result, beside the list (launcher-pickers
// 4.2, Main board): 306 x 352 in the 760 x 472 frame, radius 14, `raised`
// with a 1 px `hairline` ring, padding 18, gap 14.
//
//   [44 tile]
//   Screenshot Region                      title 15/500
//   Select an area, save it, and copy it   12/18 inkDim
//   Desktop › Capture                      11 inkDim
//   ───────────────────────────────────
//   Hotkey                 Super B [Change]   (bindable rows)
//   Runs                capture shot region   mono 11
//
//   [        Run   ↵        ] [ Actions ]
//
// Rows with something to look at (an image, a swatch, an emoji, file
// contents) show today's PreviewPane in the same card. Clipboard rows show
// 5.1's preview: the image cropped to 128 high, its kind and dimensions, or
// the decoded text in mono 12.
//
// Run is Enter. Actions opens a short list of the row's other actions, each
// with the key that runs it today (4.2 [GUESS]: the board draws only the
// button): the alternate (Ctrl+Enter), Assign or Change hotkey (Ctrl+B), the
// provider's settings (Ctrl+K), Uninstall for apps (Delete) and, in the
// clipboard scope, Clear history (Ctrl+Delete). While it is open the query
// field hands it Up, Down, Tab, Enter and Esc (LauncherContent).
Rectangle {
    id: card

    property var engine: null
    property var row: ({})

    // ---- the Actions list ----------------------------------------------------
    // Open for one row: it closes when the selection moves or the palette closes.
    property string menuFor: ""
    property int menuIndex: 0
    readonly property bool menuOpen: menuFor !== "" && menuFor === String(row && row.uid || "") && !!engine && engine.opened === true
    readonly property var menuItems: actionsFor(row)
    function altLabel(r) {
        const a = r.altAction || {};
        if (r.altLabel) return String(r.altLabel);
        if (a.type === "unbind-hotkey") return "Remove hotkey";
        if ((a.type === "dictation-copy" && a.paste) || (a.type === "exec" && (a.argv || [])[0] === "clipboard-paste")) return "Paste";
        if (a.type === "codex-external") return "Open a task in Codex";
        if (a.type === "url") return "Open link";
        return "Alternate action";
    }
    function actionsFor(r) {
        const e = card.engine;
        if (!e || !r || !r.uid || e.dmenuActive) return [];
        const items = [];
        if (r.altAction) items.push({ id: "alt", label: altLabel(r), keys: ["Ctrl", "↵"] });
        if (typeof e.bindable === "function" && e.bindable(r)) items.push({ id: "hotkey", label: r.accessory ? "Change hotkey" : "Assign hotkey", keys: ["Ctrl", "B"] });
        if (r.appId && e.appLibrary) items.push({ id: "uninstall", label: "Uninstall", keys: ["Del"] });
        if (e.scope === "clipboard") items.push({ id: "wipe", label: "Clear history", keys: ["Ctrl", "Del"] });
        if (r.providerKey && r.providerKey !== "dmenu") items.push({ id: "settings", label: r.providerKey === "settings" ? "Settings" : (r.providerName || "Provider") + " settings", keys: ["Ctrl", "K"] });
        return items;
    }
    function openMenu() {
        if (!menuItems.length) return;
        menuIndex = 0;
        menuFor = String(row.uid);
    }
    function closeMenu() {
        menuFor = "";
    }
    function moveMenu(delta) {
        if (menuOpen) menuIndex = (menuIndex + delta + menuItems.length) % menuItems.length;
    }
    function runMenu(index) {
        const item = menuItems[index === undefined ? menuIndex : index];
        const e = card.engine;
        closeMenu();
        if (!item || !e) return;
        if (item.id === "alt") e.activate(true);
        else if (item.id === "hotkey") e.beginCapture();
        else if (item.id === "uninstall") e.requestUninstall();
        else if (item.id === "wipe") e.requestClipboardWipe();
        else if (item.id === "settings") e.openProviderSettings();
        Qt.callLater(() => card.engine && card.engine.focusInput());
    }

    readonly property string kind: !row || !row.uid ? "empty" : row.providerKey === "clipboard" && row.clipboardId ? "clipboard"
        : engine && engine.usefulPreview(row) ? "preview" : "command"
    readonly property var clip: row && row.clipboardMeta ? row.clipboardMeta : ({})
    readonly property string glyph: Glyphs.forRow(row)

    radius: 14
    color: Tokens.raised
    border.width: 1
    border.color: Tokens.hairline

    function crumb(r) {
        const provider = String(r.providerName || ""), section = String(r.section || "");
        if (!provider) return section;
        if (!section || section === provider) return provider;
        return provider + " › " + section;
    }
    function runs(r) {
        const a = r.action || {};
        if (r.runsLabel) return String(r.runsLabel);
        if (a.type === "exec") return (a.argv || []).join(" ");
        if (a.type === "shell") return String(a.command || "");
        if (a.type === "url") return String(a.url || "");
        if (a.type === "copy") return "Copies to the clipboard";
        if (a.type === "app") return "Launches " + r.title;
        if (a.type === "navigate") return "Opens " + (a.title || r.title);
        if (a.type === "provider-view" || a.type === "system-view") return "Opens " + r.title;
        if (a.type === "dictate") return "Dictates to the clipboard";
        if (a.type === "setting") return "Changes this setting";
        if (a.type === "system-preference") return "Changes the bar";
        return "";
    }

    // ---- command rows ------------------------------------------------------
    Column {
        id: command
        visible: card.kind === "command"
        x: 18
        y: 18
        width: card.width - 36
        spacing: 14

        Rectangle {
            width: 44
            height: 44
            radius: 12
            color: Tokens.fillHigh
            Image {
                id: bigIcon
                anchors.centerIn: parent
                visible: status === Image.Ready
                width: 28
                height: 28
                source: card.row.iconSource || ""
                sourceSize.width: 56
                sourceSize.height: 56
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
            Icon {
                anchors.centerIn: parent
                visible: !bigIcon.visible && card.glyph !== ""
                name: card.glyph
                size: 22
                color: Tokens.fg
            }
            Text {
                anchors.centerIn: parent
                visible: !bigIcon.visible && card.glyph === ""
                text: card.row.icon || ""
                textFormat: Text.PlainText
                color: Tokens.fg
                font.family: card.row.iconFont || "Adwaita Sans"
                font.pixelSize: 22
            }
        }
        Column {
            width: parent.width
            spacing: 4
            Text {
                width: parent.width
                text: card.row.title || ""
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: Tokens.fg
                font.family: "Adwaita Sans"
                font.pixelSize: 15
                font.weight: Font.Medium
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: card.row.subtitle || ""
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                lineHeightMode: Text.FixedHeight
                lineHeight: 18
                color: Tokens.inkDim
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
        }
        Text {
            width: parent.width
            text: card.crumb(card.row)
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Tokens.inkDim
            font.family: "Adwaita Sans"
            font.pixelSize: 11
        }
        Rectangle {
            width: parent.width
            height: 1
            color: Tokens.hairline
        }
        Item {
            id: hotkeyRow
            readonly property bool bindable: !!card.engine && card.engine.bindable(card.row)
            readonly property var keys: card.row.accessory ? String(card.row.accessory).split(/\s*\+\s*/) : []
            visible: bindable || keys.length > 0
            width: parent.width
            height: 26
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Hotkey"
                color: Tokens.inkDim
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    model: hotkeyRow.keys
                    Keycap {
                        required property string modelData
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                    }
                }
                Text {
                    visible: hotkeyRow.keys.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: "None"
                    color: Tokens.inkDim
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                }
                Item {
                    visible: hotkeyRow.bindable
                    width: 6
                    height: 1
                }
                Rectangle {
                    visible: hotkeyRow.bindable
                    width: assign.implicitWidth + 20
                    height: 26
                    radius: 13
                    color: Tokens.fillHigh
                    Accessible.role: Accessible.Button
                    Accessible.name: assign.text + " hotkey"
                    Text {
                        id: assign
                        anchors.centerIn: parent
                        text: hotkeyRow.keys.length ? "Change" : "Assign"
                        color: Tokens.fg
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.engine.beginCapture()
                    }
                }
            }
        }
        Item {
            readonly property string value: card.runs(card.row)
            visible: value !== ""
            width: parent.width
            height: Math.max(runsLabel.implicitHeight, runsValue.implicitHeight)
            Text {
                id: runsLabel
                text: "Runs"
                color: Tokens.inkDim
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
            Text {
                id: runsValue
                anchors.right: parent.right
                anchors.verticalCenter: runsLabel.verticalCenter
                width: Math.min(implicitWidth, parent.width - runsLabel.implicitWidth - 12)
                horizontalAlignment: Text.AlignRight
                text: parent.value
                textFormat: Text.PlainText
                elide: Text.ElideMiddle
                color: Tokens.fg
                font.family: "Monaspace Argon"
                font.pixelSize: 11
            }
        }
    }

    // ---- previews (files, images, swatches, emoji, answers) ------------------
    PreviewPane {
        visible: card.kind === "preview"
        x: 18
        y: 4
        width: card.width - 36
        height: card.height - 4 - 58
        // Only its own rows: it loads row.previewImage whether shown or not,
        // and a clipboard row's decoded file is gone once the scope closes.
        row: card.kind === "preview" ? card.row : ({})
        compact: true
        accent: Tokens.accent
        foreground: Tokens.fg
    }

    // ---- clipboard (5.1) ---------------------------------------------------
    Column {
        visible: card.kind === "clipboard"
        x: 12
        y: 12
        width: card.width - 24
        height: card.height - 24 - 46
        spacing: 10
        ClippingRectangle {
            visible: card.clip.kind === "image" && (card.row.previewImage || "") !== ""
            width: parent.width
            height: 128
            radius: 10
            color: Tokens.fillLow
            Image {
                anchors.fill: parent
                // Only while the palette is open: the provider deletes the
                // decoded file as the scope closes, and the card is still
                // fading out then (M5 review: a "Cannot open" warning).
                source: card.row.previewImage && card.engine && card.engine.opened ? "file://" + card.row.previewImage : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width * 2
                asynchronous: true
                smooth: true
            }
        }
        Icon {
            visible: card.clip.kind === "video" || card.clip.kind === "binary" || (card.clip.kind === "image" && !card.row.previewImage)
            name: "image"
            size: 22
            color: Tokens.inkDim
        }
        Text {
            visible: card.clip.kind !== "text" && card.clip.kind !== "link"
            width: parent.width
            text: card.clip.label || ""
            color: Tokens.fg
            font.family: "Adwaita Sans"
            font.pixelSize: 12
        }
        Text {
            visible: text !== "" && card.clip.kind !== "text" && card.clip.kind !== "link"
            width: parent.width
            text: [card.clip.dims, card.clip.size].filter(s => !!s).join(" · ")
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Tokens.inkDim
            font.family: "Monaspace Argon"
            font.pixelSize: 11
        }
        Text {
            visible: card.clip.kind === "text" || card.clip.kind === "link"
            width: parent.width
            height: parent.height
            text: card.row.preview || ""
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            elide: Text.ElideRight
            clip: true
            color: Tokens.fg
            font.family: "Monaspace Argon"
            font.pixelSize: 12
        }
    }

    // ---- Run, Actions --------------------------------------------------------
    Row {
        visible: card.kind !== "empty"
        x: card.kind === "clipboard" ? 12 : 18
        width: card.width - 2 * x
        anchors.bottom: parent.bottom
        anchors.bottomMargin: x
        spacing: 8
        Rectangle {
            id: run
            width: parent.width - (actions.visible ? actions.width + parent.spacing : 0)
            height: 34
            radius: 17
            color: Tokens.fillHigh
            Accessible.role: Accessible.Button
            Accessible.name: runText.text
            Row {
                anchors.centerIn: parent
                spacing: 8
                Text {
                    id: runText
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.row.verb || "Run"
                    textFormat: Text.PlainText
                    color: Tokens.fg
                    font.family: "Adwaita Sans"
                    font.pixelSize: 13
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↵"
                    color: Tokens.inkDim
                    font.family: "Monaspace Argon"
                    font.pixelSize: 11
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: card.engine.activate()
            }
        }
        Rectangle {
            id: actions
            visible: card.menuItems.length > 0
            width: actionsText.implicitWidth + 28
            height: 34
            radius: 17
            color: card.menuOpen ? Tokens.fillLow : "transparent"
            border.width: 1
            border.color: Tokens.hairline
            Accessible.role: Accessible.Button
            Accessible.name: "Actions"
            Text {
                id: actionsText
                anchors.centerIn: parent
                text: "Actions"
                color: Tokens.fg
                font.family: "Adwaita Sans"
                font.pixelSize: 13
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: card.menuOpen ? card.closeMenu() : card.openMenu()
            }
        }
    }

    // The list, over the card above the buttons, right-aligned with Actions:
    // `surface` inside a 1 px hairline, radius 12, rows 32 (radius 8) with the
    // label left and its keys right, the selected one on `accentTint`.
    MouseArea {
        visible: card.menuOpen
        anchors.fill: parent
        onClicked: card.closeMenu()
    }
    Rectangle {
        id: menu
        objectName: "launcherActionsMenu"
        visible: card.menuOpen
        readonly property int pad: 4
        width: Math.min(card.width - 24, Math.max(200, menuColumn.implicitWidth + 2 * pad))
        height: menuColumn.implicitHeight + 2 * pad
        x: card.width - width - (card.kind === "clipboard" ? 12 : 18)
        y: card.height - (card.kind === "clipboard" ? 12 : 18) - 34 - 8 - height
        radius: 12
        color: Tokens.surface
        border.width: 1
        border.color: Tokens.hairline
        Accessible.role: Accessible.PopupMenu
        Accessible.name: "Actions"
        Column {
            id: menuColumn
            x: menu.pad
            y: menu.pad
            width: menu.width - 2 * menu.pad
            Repeater {
                model: card.menuOpen ? card.menuItems : []
                Rectangle {
                    id: entry
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === card.menuIndex
                    width: menuColumn.width
                    implicitWidth: itemLabel.implicitWidth + itemKeys.implicitWidth + 36
                    height: 32
                    radius: 8
                    color: selected ? Tokens.accentTint : "transparent"
                    Accessible.role: Accessible.MenuItem
                    Accessible.name: modelData.label
                    Accessible.selected: selected
                    Text {
                        id: itemLabel
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.label
                        textFormat: Text.PlainText
                        color: Tokens.fg
                        font.family: "Adwaita Sans"
                        font.pixelSize: 13
                    }
                    Row {
                        id: itemKeys
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Repeater {
                            model: entry.modelData.keys
                            Keycap {
                                required property string modelData
                                small: true
                                text: modelData
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: card.menuIndex = entry.index
                        onClicked: card.runMenu(entry.index)
                    }
                }
            }
        }
    }
}
