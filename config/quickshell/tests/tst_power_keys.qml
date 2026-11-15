import QtQuick
import QtTest
import qs
import qs.Island

// The power menu's keys and layout (control-lock 5, PLAN M6): today's rule,
// letters select and Enter runs; arrows wrap; Esc cancels; Lock is selected
// on open; 600 x 156 with the board's parts.
Item {
    id: root
    width: 700
    height: 200

    PowerLayer {
        id: power
        current: true
    }

    SignalSpy {
        id: runs
        target: power
        signalName: "run"
    }
    SignalSpy {
        id: cancels
        target: power
        signalName: "cancel"
    }

    TestCase {
        name: "PowerKeys"
        when: windowShown
        visible: true

        function init() {
            power.current = false;
            power.current = true;
            power.forceActiveFocus();
            runs.clear();
            cancels.clear();
        }

        function test_layout() {
            compare(power.width, 600);
            compare(power.height, 156);
            compare(power.grid.x, 16);
            compare(power.grid.y, 16);
            const ids = [];
            for (let i = 0; i < 5; i++) {
                const item = power.repeater.itemAt(i);
                ids.push(item.objectName);
                compare(item.height, 98);
                fuzzyCompare(item.width, (568 - 32) / 5, 0.01);
                compare(item.radius, 14);
            }
            compare(ids.join(" "), "powerItem-lock powerItem-suspend powerItem-logout powerItem-reboot powerItem-shutdown");
            compare(power.hint.y, 16 + 98 + 10);
            verify(power.hint.y + power.hint.height <= 156 - 12 + 0.5, "the hint ends inside the 12 px bottom padding");
        }

        function test_selected_style() {
            compare(power.selectedId, "lock", "Lock is selected when it opens");
            const lock = power.repeater.itemAt(0);
            const suspend = power.repeater.itemAt(1);
            compare(String(lock.color), String(Tokens.accentTint));
            compare(String(lock.border.color), String(Tokens.accent));
            compare(String(suspend.color), String(Tokens.raised));
            compare(String(suspend.border.color), String(Tokens.hairline));
        }

        function test_letters_select_enter_runs() {
            keyClick(Qt.Key_S);
            compare(power.selectedId, "suspend");
            keyClick(Qt.Key_E);
            compare(power.selectedId, "logout");
            keyClick(Qt.Key_R);
            compare(power.selectedId, "reboot");
            keyClick(Qt.Key_P);
            compare(power.selectedId, "shutdown");
            keyClick(Qt.Key_L);
            compare(power.selectedId, "lock");
            compare(runs.count, 0, "a letter never runs anything");
            keyClick(Qt.Key_R);
            keyClick(Qt.Key_Return);
            compare(runs.count, 1);
            compare(runs.signalArguments[0][0], "reboot");
            keyClick(Qt.Key_S);
            keyClick(Qt.Key_Enter);
            compare(runs.signalArguments[1][0], "suspend");
        }

        function test_arrows_wrap() {
            keyClick(Qt.Key_Left);
            compare(power.selectedId, "shutdown", "Left from Lock wraps to Shut down");
            keyClick(Qt.Key_Right);
            compare(power.selectedId, "lock", "Right from Shut down wraps to Lock");
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Down);
            compare(power.selectedId, "logout");
            keyClick(Qt.Key_Up);
            compare(power.selectedId, "suspend");
            keyClick(Qt.Key_End);
            compare(power.selectedId, "shutdown");
            keyClick(Qt.Key_Home);
            compare(power.selectedId, "lock");
            compare(runs.count, 0);
        }

        function test_escape_cancels() {
            keyClick(Qt.Key_P);
            keyClick(Qt.Key_Escape);
            compare(cancels.count, 1);
            compare(runs.count, 0, "Esc runs nothing");
        }

        function test_reopen_selects_lock() {
            keyClick(Qt.Key_P);
            power.current = false;
            power.current = true;
            compare(power.selectedId, "lock");
        }

        function test_modifiers_are_not_letters() {
            keyClick(Qt.Key_S, Qt.ControlModifier);
            compare(power.selectedId, "lock", "Ctrl+S is not S");
        }

        function test_click_runs() {
            mouseClick(power.repeater.itemAt(3));
            compare(power.selectedId, "reboot");
            compare(runs.count, 1);
            compare(runs.signalArguments[0][0], "reboot");
        }
    }
}
