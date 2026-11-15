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
// maximumLineCount and elide, so the item is cut to three 18 px lines
// (`messageLines`). The label: the flow's own
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
        const m = /(^|\s)(\/[^\s'"]+?)(?=[\s'".,;:!?)]*(\s|$))/.exec(text);
        if (!m) return polkit.htmlEscape(text);
        const start = m.index + m[1].length;
        const end = start + m[2].length;
        return polkit.htmlEscape(text.slice(0, start)) + "<span style=\"font-family: 'Monaspace Argon'; color: " + Tokens.fg + "\">" + polkit.htmlEscape(text.slice(start, end)) + "</span>" + polkit.htmlEscape(text.slice(end));
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
                    text: polkit.styled(String(polkit.flow?.message ?? ""))
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
