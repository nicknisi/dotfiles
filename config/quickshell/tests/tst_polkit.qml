import QtQuick
import QtTest
import qs
import qs.Island

// The polkit prompt (PLAN M8, main-tokens 2.5.9) against a fake AuthFlow
// (Island/FixtureAuthFlow.qml): the board's parts, the label and the
// program path, keys (Enter authenticates, Esc cancels), the typed answer
// cleared on every way out, errors in `bad`, a visible answer when polkit
// asks for one.
Item {
    id: root
    width: 600
    height: 320

    Component {
        id: flowComponent
        FixtureAuthFlow {
            accept: "hunter2"
        }
    }

    // The path span rendered on its own: Monaspace is monospaced, Adwaita
    // Sans is not (M8 review: StyledText dropped the face, so a markup
    // check passed while the path drew proportional).
    Text {
        id: narrow
        visible: false
        textFormat: Text.RichText
        font.family: "Adwaita Sans"
        font.pixelSize: 12
        text: pk.styled("/iiiiiiii")
    }
    Text {
        id: wide
        visible: false
        textFormat: Text.RichText
        font.family: "Adwaita Sans"
        font.pixelSize: 12
        text: pk.styled("/MMMMMMMM")
    }

    PolkitLayer {
        id: pk
        x: 60
        y: 20
        current: true
        user: "nicknisi"
    }

    TestCase {
        name: "Polkit"
        when: windowShown
        visible: true

        property var flow: null

        function init() {
            flow = flowComponent.createObject(root);
            pk.flow = flow;
            pk.current = false;
            pk.current = true;
            wait(50);
            pk.focusField();
        }
        function cleanup() {
            pk.flow = null;
            flow.destroy();
            flow = null;
        }

        function test_layout() {
            compare(pk.width, 480);
            compare(pk.height, 272);
            compare(pk.field.objectName, "polkitField");
            compare(pk.field.height, 40);
            compare(pk.field.radius, 10);
            compare(pk.field.width, 440);
            compare(pk.field.placeholder, "Password");
            compare(pk.cancelButton.objectName, "polkitCancel");
            compare(pk.authButton.objectName, "polkitAuth");
            compare(pk.cancelButton.height, 34);
            compare(pk.cancelButton.tone, "quiet");
            compare(pk.authButton.tone, "accent");
            const f = pk.field.mapToItem(pk, 0, 0);
            compare(f.x, 20);
            compare(f.y, 114, "the field's top sits where the board's does, under a two-line message");
            const a = pk.authButton.mapToItem(pk, 0, 0);
            compare(a.x + pk.authButton.width, 460, "the footer ends at the padding");
            verify(a.y + 34 <= 272 - 20 + 0.5, "the footer fits inside the bottom padding: " + (a.y + 34));
        }

        function test_text() {
            compare(pk.label, "Password for nicknisi");
            const t = pk.messageText.text;
            verify(t.indexOf(">/usr/bin/pacman</span> as the super user.") > 0, "only the path is set apart: " + t);
            compare(pk.messageText.textFormat, Text.RichText);
            // What renders, not the markup.
            verify(narrow.implicitWidth > 40, "the probe rendered: " + narrow.implicitWidth);
            fuzzyCompare(narrow.implicitWidth, wide.implicitWidth, 0.01, "the path draws monospaced");
            compare(pk.messageLines, 2, "and the message wraps to two lines, as on the board");
            compare(pk.messageText.height, 36);
            flow.message = "Authentication is required to change <b>things</b> \"here\"";
            verify(pk.messageText.text.indexOf("&lt;b&gt;") >= 0 && pk.messageText.text.indexOf("<b>") < 0, "polkit's text is escaped, never markup");
            compare(pk.messageLines, 1);
            flow.message = "word ".repeat(200);
            compare(pk.messageLines, 3, "at most three lines");
            compare(pk.messageText.height, 54);
            // Past three lines it ends in an ellipsis (M10), on the last line.
            const cut = pk.messageText.text;
            verify(cut.endsWith("word…"), "cut after a word, then the ellipsis: " + cut.slice(-24));
            verify(pk.messageText.contentHeight <= 54.5, "the cut text fits in three lines: " + pk.messageText.contentHeight);
            verify(cut.length > 120 && cut.length < 1000, "about three lines of it: " + cut.length);
            // A cut inside the path keeps the shown part monospaced, the
            // ellipsis outside the span.
            flow.message = "Run " + "/usr/lib/" + "very-long-directory-name/".repeat(12) + "bin";
            const p = pk.messageText.text;
            verify(p.endsWith("</span>…"), "the ellipsis follows the path's span: " + p.slice(-24));
            verify(pk.messageText.contentHeight <= 54.5);
            // Three lines exactly: no ellipsis.
            flow.message = "Authentication is needed to run /usr/bin/pacman as the super user.";
            verify(!pk.messageText.text.endsWith("…"), "a message that fits is whole");
            // A narrower card refits.
            const was = pk.width;
            flow.message = "word ".repeat(60);
            const before = pk.messageText.text.length;
            pk.width = was - 120;
            wait(0);
            verify(pk.messageText.text.length < before && pk.messageText.text.endsWith("…"), "a narrower card cuts sooner: " + pk.messageText.text.length + " < " + before);
            verify(pk.messageText.contentHeight <= 54.5);
            pk.width = was;
            flow.message = "Authentication is needed to run /usr/bin/pacman as the super user.";
            flow.inputPrompt = "Fingerprint or PIN:";
            compare(pk.label, "Fingerprint or PIN", "a prompt other than Password: is the label");
            flow.inputPrompt = "Password:";
            compare(pk.label, "Password for nicknisi");
        }

        function test_wrong_then_right() {
            keyClick(Qt.Key_N);
            keyClick(Qt.Key_O);
            compare(pk.buffer, "no");
            compare(pk.field.bullets.text, "••");
            keyClick(Qt.Key_Return);
            compare(flow.submits, 1);
            verify(!flow.lastMatched);
            compare(pk.buffer, "", "the answer leaves the field when submitted");
            verify(pk.errorLine.visible);
            compare(String(pk.errorLine.color), String(Tokens.bad));
            verify(pk.field.failed);
            for (const ch of "hunter2")
                keyClick(ch);
            compare(pk.buffer, "hunter2");
            verify(!pk.field.failed, "typing again clears the ring");
            pk.authButton.clicked();
            verify(flow.isSuccessful && flow.isCompleted);
            compare(pk.buffer, "");
            verify(pk.field.readOnly, "a completed flow takes no more typing");
        }

        function test_escape_cancels() {
            keyClick(Qt.Key_X);
            keyClick(Qt.Key_Escape);
            verify(flow.isCancelled);
            compare(flow.cancels, 1);
            compare(pk.buffer, "");
            compare(flow.submits, 0, "nothing was submitted");
        }

        function test_cancel_button() {
            keyClick(Qt.Key_X);
            pk.cancelButton.clicked();
            verify(flow.isCancelled);
            compare(pk.buffer, "");
        }

        function test_cleared_on_every_exit() {
            keyClick(Qt.Key_S);
            pk.current = false;
            compare(pk.buffer, "", "leaving the state clears it");
            pk.current = true;
            pk.focusField();
            keyClick(Qt.Key_S);
            const other = flowComponent.createObject(root);
            pk.flow = other;
            compare(pk.buffer, "", "a new flow clears it");
            pk.flow = flow;
            pk.focusField();
            keyClick(Qt.Key_S);
            flow.cancelAuthenticationRequest();
            compare(pk.buffer, "", "the flow ending elsewhere clears it");
            other.destroy();
        }

        function test_empty_enter() {
            keyClick(Qt.Key_Return);
            compare(flow.submits, 0, "an empty answer is not sent");
            compare(pk.authButton.opacity, 1, "Authenticate stays full accent while the request waits, as on the board");
            flow.cancelAuthenticationRequest();
            compare(pk.authButton.opacity, 0.5, "and dims once it no longer waits");
        }

        function test_visible_answer() {
            flow.responseVisible = true;
            for (const ch of "nick")
                keyClick(ch);
            compare(pk.field.bullets.text, "nick", "polkit asked for a visible answer");
            flow.responseVisible = false;
            compare(pk.field.bullets.text, "••••");
        }

        function test_supplementary_message() {
            flow.supplementaryMessage = "Your account is locked";
            flow.supplementaryIsError = true;
            compare(pk.errorText, "Your account is locked");
            flow.supplementaryIsError = false;
            compare(pk.errorText, "", "an info message is not an error");
        }
    }
}
