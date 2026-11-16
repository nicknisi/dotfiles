import QtQuick
import qs
import qs.Kit

// PolkitLayer.qml - a polkit authentication request, as the island itself
// (PLAN M8, main-tokens 2.5.9, Main board `polkit`, 480 x 272 over the scrim).
//
//   ┌──────────────────────────────────────────────┐  padding 20, column gap 14
//   │ [🛡]  Authentication required                 │  tile 44, radius 12,
//   │       Authentication is needed to run         │  `raised` + hairline,
//   │       /usr/bin/pacman as the super user.      │  shield 18; text gap 4
//   │ Password for nicknisi                         │  12 inkDim, gap 6
//   │ ┌──────────────────────────────────────────┐ │  40 high, radius 10,
//   │ │ ••••••                                    │ │  fillLow, 1 px faint
//   │ └──────────────────────────────────────────┘ │
//   │ org.freedesktop.policykit.exec  (Cancel) (Authenticate) │  gap 8
//   └──────────────────────────────────────────────┘
//
// `flow` is Quickshell's AuthFlow (ShellServices' PolkitAgent) or
// Island/FixtureAuthFlow.qml; this reads it and calls submit(value) and
// cancelAuthenticationRequest(), nothing else. The typed answer lives here
// only, in `buffer` (the field draws its length), and is cleared when it is
// submitted, on cancel, when the flow changes or ends, and when the layer
// stops being current.
//
// The message: polkit's free text, with its first absolute path in
// Monaspace `fg` [GUESS, main-tokens 2.5.9], as RichText: StyledText drops
// a <font face>, so the path came out in Adwaita Sans and the message fit on
// one line where the board wraps it to two (M8 review). RichText ignores
// maximumLineCount and elide, so a message past three 18 px lines is cut by
// hand: the longest start of it that fits in three with a trailing "…",
// at a word's end when one is near (`fitMessage`, a binary search on a
// hidden probe laid out the same way, M10). The label: the flow's own
// prompt when it is more than "Password:", else "Password for <user>".
// Errors: supplementaryMessage in `bad` when supplementaryIsError, else
// "Wrong password" after a failure.
//
// Keys: Enter authenticates, Esc cancels (main-tokens 2.5.9); a key typed
// with focus on a button goes to the field.
//
// objectNames: polkitField, polkitCancel, polkitAuth.
//
// QtQuick only (qmltestrunner loads it).
Layer {
    id: polkit

    property var flow: null
    // The user the request is for, when the flow does not name one.
    property string user: ""
    // The typed answer. Only here.
    property string buffer: ""

    readonly property bool waiting: polkit.flow !== null && polkit.flow.isCompleted !== true && polkit.flow.isResponseRequired === true
    readonly property string errorText: {
        if (!polkit.flow) return "";
        if (polkit.flow.supplementaryIsError && String(polkit.flow.supplementaryMessage ?? "") !== "") return String(polkit.flow.supplementaryMessage);
        return polkit.flow.failed === true ? "Wrong password" : "";
    }
    readonly property string identityName: {
        const id = polkit.flow?.selectedIdentity ?? null;
        if (!id) return polkit.user;
        for (const k of ["displayName", "name", "userName", "user"]) {
            const v = id[k];
            if (typeof v === "string" && v !== "") return v;
        }
        return polkit.user;
    }
    readonly property string label: {
        const p = String(polkit.flow?.inputPrompt ?? "").trim().replace(/:$/, "");
        if (p !== "" && p.toLowerCase() !== "password") return p;
        return polkit.identityName !== "" ? "Password for " + polkit.identityName : "Password";
    }
    readonly property alias field: field
    readonly property alias cancelButton: cancel
    readonly property alias authButton: auth
    readonly property alias messageText: messageText
    readonly property alias errorLine: errorLine

    width: 480
    height: 272

    Accessible.role: Accessible.Dialog
    Accessible.name: "Authentication required"

    onFlowChanged: polkit.buffer = ""
    onCurrentChanged: {
        polkit.buffer = "";
        if (current) Qt.callLater(polkit.focusField);
    }
    onWaitingChanged: if (!waiting) polkit.buffer = ""

    Connections {
        target: polkit.flow
        ignoreUnknownSignals: true
        function onAuthenticationFailed() {
            polkit.buffer = "";
            polkit.focusField();
        }
        function onAuthenticationSucceeded() {
            polkit.buffer = "";
        }
        function onAuthenticationRequestCancelled() {
            polkit.buffer = "";
        }
    }

    function focusField() {
        field.forceActiveFocus();
    }
    function submit() {
        if (!polkit.waiting || polkit.buffer === "") return;
        const answer = polkit.buffer;
        polkit.buffer = "";
        polkit.flow.submit(answer);
    }
    function cancel() {
        polkit.buffer = "";
        if (polkit.flow && polkit.flow.isCompleted !== true) polkit.flow.cancelAuthenticationRequest();
    }

    // polkit's message as RichText, the first absolute path in Monaspace
    // `fg`. Everything else is escaped: polkit's text is never markup.
    function htmlEscape(s: string): string {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
    }
    function styled(text: string): string {
        return polkit.styledCut(text, text.length);
    }
    // Only text's first `cut` characters (trailing spaces dropped) and a
    // "…". The path is found in the whole text, so a cut inside it keeps the
    // part shown in Monaspace and the "…" in Adwaita.
    function styledCut(text: string, cut: int): string {
        const n = Math.max(0, Math.min(cut, text.length));
        const tail = n < text.length ? "…" : "";
        const shown = tail ? text.slice(0, n).replace(/\s+$/, "") : text;
        const m = /(^|\s)(\/[^\s'"]+?)(?=[\s'".,;:!?)]*(\s|$))/.exec(text);
        if (!m || m.index + m[1].length >= shown.length) return polkit.htmlEscape(shown) + tail;
        const start = m.index + m[1].length;
        const end = Math.min(shown.length, start + m[2].length);
        return polkit.htmlEscape(shown.slice(0, start)) + "<span style=\"font-family: 'Monaspace Argon'; color: " + Tokens.fg + "\">" + polkit.htmlEscape(shown.slice(start, end)) + "</span>" + polkit.htmlEscape(shown.slice(end)) + tail;
    }
    // The whole message, or its longest start that fits in three lines with
    // a "…": the probe lays each try out (Text lays out as its text is set).
    function fitMessage(text: string): string {
        messageProbe.width = messageText.width;
        messageProbe.text = polkit.styled(text);
        if (messageProbe.contentHeight <= 3 * 18 + 0.5) return messageProbe.text;
        let lo = 0, hi = text.length;
        while (lo < hi) {
            const mid = Math.ceil((lo + hi) / 2);
            messageProbe.text = polkit.styledCut(text, mid);
            if (messageProbe.contentHeight <= 3 * 18 + 0.5)
                lo = mid;
            else
                hi = mid - 1;
        }
        // At a word's end when one is near (a long path has none, so it is
        // cut where it fills the line).
        if (lo < text.length && !/\s/.test(text[lo])) {
            const space = text.slice(0, lo).search(/\s\S*$/);
            if (space > 0 && lo - space <= 24) lo = space;
        }
        return polkit.styledCut(text, lo);
    }
    readonly property string message: String(polkit.flow?.message ?? "")
    property string shownMessage: ""
    function refit() {
        polkit.shownMessage = polkit.fitMessage(polkit.message);
    }
    onMessageChanged: polkit.refit()
    Component.onCompleted: polkit.refit()
    // The path's colour is in the markup.
    Connections {
        target: Tokens
        function onFgChanged() {
            polkit.refit();
        }
    }
    // messageText's twin, never drawn: fitMessage's trial layouts.
    Text {
        id: messageProbe
        visible: false
        wrapMode: Text.Wrap
        textFormat: Text.RichText
        font.family: "Adwaita Sans"
        font.pixelSize: 12
        lineHeightMode: Text.FixedHeight
        lineHeight: 18
    }
    // The message's lines, at most three (RichText reports no lineCount).
    readonly property int messageLines: Math.max(1, Math.min(3, Math.round(messageText.contentHeight / 18)))

    Keys.onPressed: event => {
        if (field.keyIntent(event.key, event.text, event.modifiers)) {
            field.forceActiveFocus();
            event.accepted = true;
        }
    }

    Column {
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 14

        Row {
            width: parent.width
            spacing: 14
            Rectangle {
                width: 44
                height: 44
                radius: 12
                color: Tokens.raised
                border.width: 1
                border.color: Tokens.hairline
                Icon {
                    anchors.centerIn: parent
                    name: "shield"
                    size: 18
                    color: Tokens.fg
                }
            }
            Column {
                width: parent.width - 44 - 14
                spacing: 4
                Text {
                    width: parent.width
                    text: "Authentication required"
                    color: Tokens.fg
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    font.family: "Adwaita Sans"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }
                Text {
                    id: messageText
                    width: parent.width
                    // The board's 18 px line boxes, whole lines only.
                    height: polkit.messageLines * 18
                    clip: true
                    text: polkit.shownMessage
                    onWidthChanged: polkit.refit()
                    color: Tokens.inkDim
                    wrapMode: Text.Wrap
                    textFormat: Text.RichText
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 18
                }
            }
        }

        Column {
            width: parent.width
            spacing: 6
            Text {
                id: labelText
                width: parent.width
                text: polkit.label
                color: Tokens.inkDim
                elide: Text.ElideRight
                textFormat: Text.PlainText
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
            SecretField {
                id: field
                objectName: "polkitField"
                width: parent.width
                height: 40
                radius: 10
                padLeft: 12
                padRight: 12
                placeholder: "Password"
                length: polkit.buffer.length
                echo: polkit.flow?.responseVisible === true ? polkit.buffer : ""
                failed: polkit.errorText !== "" && polkit.buffer === ""
                readOnly: !polkit.waiting
                Accessible.name: labelText.text
                onTyped: text => polkit.buffer += text
                onErased: polkit.buffer = polkit.buffer.slice(0, -1)
                onCleared: polkit.buffer = ""
                onSubmitted: polkit.submit()
                onEscaped: polkit.cancel()
            }
            Text {
                id: errorLine
                width: parent.width
                visible: polkit.errorText !== ""
                text: polkit.errorText
                color: Tokens.bad
                elide: Text.ElideRight
                textFormat: Text.PlainText
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
        }

        Row {
            width: parent.width
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - cancel.width - auth.width - 16
                text: String(polkit.flow?.actionId ?? "")
                color: Tokens.inkDim
                elide: Text.ElideMiddle
                textFormat: Text.PlainText
                font.family: "Monaspace Argon"
                font.pixelSize: 11
            }
            PillButton {
                id: cancel
                objectName: "polkitCancel"
                text: "Cancel"
                tone: "quiet"
                padX: 16
                onClicked: polkit.cancel()
            }
            PillButton {
                id: auth
                objectName: "polkitAuth"
                text: "Authenticate"
                tone: "accent"
                padX: 16
                // Full `accent` while the request waits, empty field included
                // (the board's first look; submit() ignores an empty answer).
                opacity: polkit.waiting ? 1 : 0.5
                onClicked: polkit.submit()
            }
        }
    }
}
