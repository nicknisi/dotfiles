import QtQuick
import QtTest
import qs
import qs.Kit
import qs.Lock
import "../lib/LockMachine.js" as LockMachine

// The lock card (PLAN M8, control-lock 4.4 and 4.6): the board's sizes; keys
// as intents (no text field, so nothing to undo, select, copy or remember);
// the buffer driven through lib/LockMachine.js as Lock/LockAuth.qml does,
// with a fake PAM; read-only while checking; the failure ring and the shake.
Item {
    id: root
    width: 500
    height: 300

    // The host: LockMachine's record and a fake PAM that fails "nope" and
    // accepts "hunter2", answering synchronously.
    property var m: LockMachine.initial()
    QtObject {
        id: fakePam
        property bool active: false
        property var responses: []
        function start() {
            active = true;
            return true;
        }
        function respond(v) {
            responses = responses.concat([v]);
            active = false;
        }
        function abort() {
            active = false;
        }
    }
    property alias pam: fakePam
    function step(next) {
        root.m = LockMachine.perform(next, root.pam);
    }
    // PAM's side of a conversation, after Enter.
    function pamAnswers() {
        step(LockMachine.message(root.m, { text: "Password: ", responseRequired: true }));
        const last = root.pam.responses[root.pam.responses.length - 1];
        step(LockMachine.completed(root.m, last === "hunter2" ? LockMachine.SUCCESS : LockMachine.FAILED));
    }

    AuthCard {
        id: card
        x: 20
        y: 20
        name: "Nick Nisi"
        sub: "nicknisi on milhouse"
        length: LockMachine.bullets(root.m)
        phase: root.m.phase
        hint: LockMachine.hint(root.m)
        hintError: root.m.error && root.m.message !== ""
        prompt: root.m.prompt
        shakeSerial: root.m.shake
        onTyped: text => root.step(LockMachine.type(root.m, text))
        onErased: root.step(LockMachine.erase(root.m))
        onCleared: root.step(LockMachine.clear(root.m))
        onSubmitted: root.step(LockMachine.submit(root.m))
        onEscaped: root.step(LockMachine.clear(root.m))
    }

    SignalSpy {
        id: typed
        target: card
        signalName: "typed"
    }
    SignalSpy {
        id: submits
        target: card
        signalName: "submitted"
    }

    // A field whose window does not have the keyboard (offscreen every window
    // reports active, so the test sets windowActive the way Window.active
    // would read on a layer-shell window that lost it).
    Component {
        id: elsewhere
        SecretField {
            width: 300
            height: 44
        }
    }

    TestCase {
        name: "AuthCard"
        when: windowShown
        visible: true

        function init() {
            root.m = LockMachine.initial();
            root.pam.responses = [];
            card.shakeHold = -1;
            Prefs.reducedMotion = false;
            card.shakeAnimation.complete();
            card.focusField();
            typed.clear();
            submits.clear();
        }

        function test_layout() {
            compare(card.width, 380);
            compare(card.radius, 28);
            verify(Math.abs(card.height - 191) <= 3, "about 191 tall: " + card.height);
            compare(card.field.objectName, "lockField");
            compare(card.unlockButton.objectName, "lockUnlock");
            compare(card.field.height, 44);
            compare(card.field.radius, 12);
            compare(card.field.width, 340);
            compare(card.unlockButton.width, 32);
            compare(card.unlockButton.height, 32);
            compare(card.unlockButton.radius, 10);
            compare(String(card.unlockButton.color), String(Tokens.accent));
            compare(String(card.unlockButton.ink), String(Tokens.onAccent));
            const u = card.unlockButton.mapToItem(card.field, 0, 0);
            compare(u.x + 32, card.field.width - 6);
            compare(card.hintText.text, "Enter unlocks · Esc clears");
            compare(String(card.hintText.color), String(Tokens.inkDim));
            compare(card.initial, "N");
        }

        // The profile picture (Kit/FacePicture): the initial with no
        // picture, the picture with one, and the card the same size either way.
        function test_face() {
            const h = card.height;
            compare(card.face.size, 44);
            compare(card.face.width, 44);
            compare(card.face.initialText.text, "N");
            verify(card.face.initialText.visible && !card.face.pictureShown, "no picture: the initial, as the board draws it");
            card.faceSources = [Qt.resolvedUrl("text.png"), Qt.resolvedUrl("face.png")];
            tryCompare(card.face, "pictureShown", true, 3000);
            compare(card.face.tried, 1, "past the file that is not an image");
            compare(card.height, h, "the card keeps its height");
            compare(card.face.mapToItem(card, 0, 0).x, 20, "where the circle was");
            card.faceSources = [];
            verify(!card.face.pictureShown);
            tryCompare(card.face.initialText, "visible", true, 2000);
        }

        function test_field_holds_no_text() {
            verify(card.field.text === undefined, "SecretField has no text property");
            card.keyIntent(Qt.Key_H, "h", 0);
            card.keyIntent(Qt.Key_I, "i", 0);
            compare(root.m.buffer, "hi");
            compare(card.field.length, 2);
            compare(card.field.bullets.text, "••");
            verify(JSON.stringify(card.field.bullets.text).indexOf("hi") < 0);
        }

        function test_keys_are_intents() {
            keyClick(Qt.Key_A);
            keyClick(Qt.Key_B);
            compare(root.m.buffer, "ab", "real key events reach the buffer");
            keyClick(Qt.Key_Backspace);
            compare(root.m.buffer, "a");
            keyClick(Qt.Key_Space);
            compare(root.m.buffer, "a ", "space is part of a password");
            // Nothing to select, copy, cut, undo or redo.
            for (const k of [Qt.Key_A, Qt.Key_C, Qt.Key_X, Qt.Key_Z, Qt.Key_Y]) {
                verify(card.keyIntent(k, "", Qt.ControlModifier), "Ctrl+" + k + " is swallowed");
            }
            compare(root.m.buffer, "a ");
            verify(card.keyIntent(Qt.Key_U, "", Qt.ControlModifier));
            compare(root.m.buffer, "", "Ctrl+U clears");
            // No paste (M8 review): Ctrl+V and Shift+Insert are swallowed, and
            // there is no signal a host could turn into clipboard text.
            card.keyIntent(Qt.Key_K, "k", 0);
            verify(card.keyIntent(Qt.Key_V, "\u0016", Qt.ControlModifier), "Ctrl+V is swallowed");
            verify(card.keyIntent(Qt.Key_Insert, "", Qt.ShiftModifier), "Shift+Insert is swallowed");
            keyClick(Qt.Key_V, Qt.ControlModifier);
            keyClick(Qt.Key_Insert, Qt.ShiftModifier);
            compare(root.m.buffer, "k", "neither reaches the buffer");
            verify(card.pasteRequested === undefined && card.field.pasteRequested === undefined, "no paste signal on the card or the field");
            card.keyIntent(Qt.Key_U, "", Qt.ControlModifier);
            verify(!card.keyIntent(Qt.Key_Tab, "\t", 0), "Tab is left to the focus chain");
            verify(!card.keyIntent(Qt.Key_F5, "", 0), "F-keys are left alone");
            verify(card.keyIntent(Qt.Key_Left, "", 0) && card.keyIntent(Qt.Key_Home, "", 0), "no caret to move");
            compare(typed.count, 4, "only printable keys type (a, b, space, k)");
        }

        function test_undo_cannot_restore() {
            card.keyIntent(Qt.Key_S, "secret", 0);
            card.keyIntent(Qt.Key_Escape, "", 0);
            compare(root.m.buffer, "", "Esc clears");
            card.keyIntent(Qt.Key_Z, "", Qt.ControlModifier);
            card.keyIntent(Qt.Key_Z, "", Qt.ControlModifier | Qt.ShiftModifier);
            card.keyIntent(Qt.Key_Y, "", Qt.ControlModifier);
            keyClick(Qt.Key_Z, Qt.ControlModifier);
            compare(root.m.buffer, "", "Ctrl+Z, Ctrl+Shift+Z and Ctrl+Y bring nothing back");
            compare(card.field.length, 0);
        }

        function test_failure_and_success() {
            card.keyIntent(Qt.Key_N, "nope", 0);
            card.keyIntent(Qt.Key_Return, "\r", 0);
            compare(root.m.phase, "authenticating");
            compare(card.hintText.text, "Checking…");
            compare(card.unlockButton.opacity, 0.5);
            verify(card.field.readOnly);
            card.keyIntent(Qt.Key_X, "x", 0);
            compare(root.m.buffer, "nope", "read-only while checking: typing does nothing");
            root.step(LockMachine.message(root.m, { text: "Password: ", responseRequired: true }));
            compare(root.m.buffer, "", "the buffer went to PAM");
            compare(card.field.length, 4, "the bullets stay while PAM checks");
            root.step(LockMachine.completed(root.m, LockMachine.FAILED));
            compare(root.m.phase, "idle");
            compare(root.m.buffer, "", "a failure clears the buffer");
            compare(card.field.length, 0);
            compare(card.hintText.text, "Wrong password");
            compare(String(card.hintText.color), String(Tokens.bad));
            compare(String(card.field.border.color), String(Tokens.bad), "the ring turns bad");
            verify(card.shakeAnimation.running, "the card shakes");
            verify(!card.field.readOnly);
            // The message stays until the next keystroke.
            card.keyIntent(Qt.Key_H, "h", 0);
            compare(card.hintText.text, "Enter unlocks · Esc clears");
            verify(String(card.field.border.color) !== String(Tokens.bad));
            card.keyIntent(Qt.Key_U, "unter2", 0);
            card.keyIntent(Qt.Key_Enter, "\r", 0);
            root.pamAnswers();
            compare(root.m.phase, "unlocking");
            compare(root.m.buffer, "");
            compare(root.pam.responses.join(","), "nope,hunter2");
        }

        function test_focus_ring() {
            card.focusField();
            verify(card.field.activeFocus);
            verify(card.Window.active, "the test window has the keyboard");
            verify(card.field.keyboardHere);
            compare(String(card.field.border.color), String(Tokens.accent), "accent while focused");
            verify(card.field.caret.visible, "and the caret shows");
            card.forceActiveFocus();
            compare(String(card.field.border.color), String(Tokens.faint), "faint otherwise");
            card.keyIntent(Qt.Key_A, "a", 0);
            verify(card.field.activeFocus, "a key routed from elsewhere puts focus back on the field");
        }

        // M8 review: the island's polkit field kept Qt's activeFocus while the
        // compositor sent the keys to another window, and looked ready.
        function test_no_ring_without_the_keyboard() {
            const f = createTemporaryObject(elsewhere, root, { windowActive: false });
            f.forceActiveFocus();
            verify(f.activeFocus, "Qt focus");
            verify(!f.keyboardHere, "but not the keyboard");
            compare(String(f.border.color), String(Tokens.faint), "so no accent ring");
            verify(!f.caret.visible, "and no caret");
            f.windowActive = true;
            verify(f.keyboardHere);
            compare(String(f.border.color), String(Tokens.accent), "the ring shows once the window has the keyboard");
            verify(f.caret.visible);
            card.focusField();
        }

        function test_empty_enter_shakes() {
            card.keyIntent(Qt.Key_Return, "\r", 0);
            compare(root.m.phase, "idle");
            compare(root.m.shake, 1);
            compare(root.pam.responses.length, 0);
            verify(card.shakeAnimation.running);
        }

        function test_shake_frames() {
            compare(card.shakeFrames.join(" "), "0 -9 8 -6 4 -2 0");
            card.shakeHold = 1;
            compare(card.shakeOffset, -9, "held on the 15 % frame");
            card.shakeHold = 2;
            compare(card.shakeOffset, 8);
            card.shakeHold = -1;
            compare(card.shakeOffset, 0);
            root.step(LockMachine.submit(LockMachine.type(root.m, "x")));
            root.pamAnswers();
            verify(card.shakeAnimation.running);
            wait(500);
            verify(!card.shakeAnimation.running, "420 ms");
            compare(card.shakeOffset, 0);
        }

        function test_reduced_motion() {
            Prefs.reducedMotion = true;
            root.step(LockMachine.submit(LockMachine.type(root.m, "x")));
            root.pamAnswers();
            verify(!card.shakeAnimation.running, "no shake under reduced motion");
            compare(card.shakeOffset, 0);
            compare(card.hintText.text, "Wrong password", "the message still shows");
        }

        function test_second_prompt() {
            root.step(LockMachine.submit(LockMachine.type(root.m, "hunter2")));
            root.step(LockMachine.message(root.m, { text: "Password: ", responseRequired: true }));
            root.step(LockMachine.message(root.m, { text: "Verification code: ", responseRequired: true }));
            compare(root.m.phase, "answering");
            compare(card.field.placeholder, "Verification code");
            verify(!card.field.readOnly);
        }
    }
}
