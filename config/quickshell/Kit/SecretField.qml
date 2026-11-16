import QtQuick
import qs

// SecretField.qml - a password field that never holds the password (PLAN M8).
//
// The lock card and the polkit prompt keep the typed secret in one place of
// their own (lib/LockMachine.js's buffer, PolkitLayer's), and this draws only
// its length: a bullet per character, a placeholder when empty, a still caret
// while it has focus. No TextInput, so there is no second copy of the
// secret, no undo history to bring it back, no selection to copy and nothing
// for an input method to remember.
//
// Keys become intents the owner applies to its buffer (keyIntent() below,
// also called by a surface that routes keys typed while focus is elsewhere):
//
//   printable text            typed(text)     (no Ctrl or Meta held)
//   Backspace                 erased()
//   Ctrl+Backspace, Ctrl+U    cleared()       (no words to delete in a secret)
//   Enter                     submitted()
//   Esc                       escaped()
//   Ctrl+V, Shift+Insert      swallowed: no paste (M8 review). A password
//                             left in the clipboard would otherwise unlock
//                             the lock for anyone at the keyboard.
//   Ctrl+A/C/X/Z/Y, arrows,
//   Home, End, Delete         swallowed: nothing to select, copy or undo
//   Tab                       left to the focus chain
//
// While readOnly (PAM is checking) typing and erasing are swallowed; Esc and
// Enter still reach the owner, which decides.
//
// The box: `fillLow`, a 1 px ring in `faint` (stronger than hairline on
// purpose, control-lock 4.4), `accent` while it has the keyboard [GUESS],
// `bad` after a failure. Sizes default to the lock card's field (44 high,
// radius 12, 14 px text, padding 14 left); the polkit prompt's is 40, 10 and
// 12.
//
// "Has the keyboard" is Qt's focus and the window's (`keyboardHere`): a
// layer-shell window can keep Qt's activeFocus while the compositor sends
// the keys to another window (the island's polkit prompt after an unlock,
// M8 review). Without the window's keyboard the field draws no accent ring
// and no caret, so it never looks ready for typing it will not get.
//
// QtQuick only (qmltestrunner loads it).
Rectangle {
    id: root

    // Characters typed: what the bullets show.
    property int length: 0
    property string placeholder: "Enter your password"
    property bool failed: false
    property bool readOnly: false
    property int fontSize: 14
    property real padLeft: 14
    // Room kept free on the right, for a button the owner puts there.
    property real padRight: 14
    // Drawn in place of the bullets when set: a visible answer (polkit's
    // responseVisible, e.g. a user name). Never the password.
    property string echo: ""

    signal typed(string text)
    signal erased
    signal cleared
    signal submitted
    signal escaped

    readonly property alias bullets: bullets
    readonly property alias caret: caret
    // The window has the compositor's keyboard (a test can stand in for it:
    // offscreen, every window reports active).
    property bool windowActive: root.Window.active
    readonly property bool keyboardHere: root.activeFocus && root.windowActive

    implicitHeight: 44
    implicitWidth: 240
    radius: 12
    color: Tokens.fillLow
    border.width: 1
    border.color: root.failed ? Tokens.bad : root.keyboardHere ? Tokens.accent : Tokens.faint
    activeFocusOnTab: true

    Accessible.role: Accessible.EditableText
    Accessible.passwordEdit: true
    Accessible.name: root.placeholder
    Accessible.focusable: true
    Accessible.readOnly: root.readOnly

    Keys.onPressed: event => {
        if (root.keyIntent(event.key, event.text, event.modifiers))
            event.accepted = true;
    }

    // Classifies one key and emits its intent. True when the key was used
    // (or swallowed); false for keys the field leaves alone (Tab, F-keys,
    // modifiers on their own).
    function keyIntent(key: int, text: string, modifiers: int): bool {
        const ctrl = (modifiers & Qt.ControlModifier) !== 0;
        const meta = (modifiers & Qt.MetaModifier) !== 0;
        switch (key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.submitted();
            return true;
        case Qt.Key_Escape:
            root.escaped();
            return true;
        case Qt.Key_Backspace:
            if (!root.readOnly) ctrl ? root.cleared() : root.erased();
            return true;
        case Qt.Key_Insert:
        case Qt.Key_Delete:
        case Qt.Key_Left:
        case Qt.Key_Right:
        case Qt.Key_Home:
        case Qt.Key_End:
        case Qt.Key_Up:
        case Qt.Key_Down:
            return true;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            return false;
        }
        if (ctrl || meta) {
            if (key === Qt.Key_U) {
                if (!root.readOnly) root.cleared();
                return true;
            }
            // Select all, copy, cut, paste, undo, redo: nothing to act on.
            return [Qt.Key_A, Qt.Key_C, Qt.Key_X, Qt.Key_V, Qt.Key_Z, Qt.Key_Y].indexOf(key) >= 0;
        }
        if (!root.printable(text)) return false;
        if (!root.readOnly) root.typed(text);
        return true;
    }

    // Text with no control characters.
    function printable(text: string): bool {
        if (text.length === 0) return false;
        for (let i = 0; i < text.length; i++) {
            const c = text.charCodeAt(i);
            if (c < 0x20 || c === 0x7f) return false;
        }
        return true;
    }

    Text {
        id: placeholderText
        anchors.left: parent.left
        anchors.leftMargin: root.padLeft
        anchors.right: parent.right
        anchors.rightMargin: root.padRight
        anchors.verticalCenter: parent.verticalCenter
        visible: root.length === 0
        text: root.placeholder
        color: Tokens.inkDim
        elide: Text.ElideRight
        textFormat: Text.PlainText
        font.family: "Adwaita Sans"
        font.pixelSize: root.fontSize
        Accessible.ignored: true
    }

    // The newest bullets win when there are more than fit (elided on the left).
    Text {
        id: bullets
        anchors.left: parent.left
        anchors.leftMargin: root.padLeft
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, parent.width - root.padLeft - root.padRight - 4)
        visible: root.length > 0
        text: root.echo !== "" ? root.echo : "•".repeat(Math.max(0, Math.min(root.length, 256)))
        color: Tokens.fg
        elide: Text.ElideLeft
        textFormat: Text.PlainText
        font.family: "Adwaita Sans"
        font.pixelSize: root.fontSize
        font.letterSpacing: root.echo !== "" ? 0 : 2
        Accessible.ignored: true
    }

    // Still, not blinking: a lock screen can sit for hours, and a blink is a
    // frame every half second for nothing.
    Rectangle {
        id: caret
        x: root.padLeft + (root.length > 0 ? bullets.width + 1 : 0)
        anchors.verticalCenter: parent.verticalCenter
        width: 1.5
        height: root.fontSize + 4
        radius: 0.75
        color: Tokens.fg
        visible: root.keyboardHere && !root.readOnly
    }

    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: root.padRight
        cursorShape: Qt.IBeamCursor
        onPressed: root.forceActiveFocus()
    }
}
