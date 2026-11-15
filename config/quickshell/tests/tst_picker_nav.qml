import QtQuick
import QtTest
import qs
import qs.Panels

// The theme and wallpaper pickers' keys and grid (PLAN M7, launcher-pickers
// 7.1 to 7.4): Left and Right wrap, Up and Down keep the column, the filter
// reflows the grid and moves focus to the first match when the focused card
// drops out, Tab switches panels with the filter cleared, Esc clears the
// filter before it closes, and only a theme other than the applied one
// previews. The real PickerModel, ThemesPanel and WallpapersPanel; tests/
// pickers.sh stands a plain Item in for PickerThumb (Quickshell.Widgets).
Item {
    id: root
    width: 1300
    height: 700

    // 37 themes, the applied one at 11 (as hackerman is in the real list);
    // "ocean" and "oceanic" for the filter, one light pack.
    function themeRows() {
        const names = [];
        for (let i = 0; i < 37; i++) names.push("pack-" + (i < 10 ? "0" : "") + i);
        names[5] = "ocean";
        names[6] = "oceanic";
        names[20] = "paper-light";
        return names.map((n, i) => ({
                    name: n,
                    label: n.replace(/-/g, " "),
                    image: "",
                    tagline: n + " tagline",
                    swatches: [],
                    current: i === 11,
                    mode: n === "paper-light" ? "light" : "dark",
                    bg: n === "paper-light" ? "#eff1f5" : "#101010",
                    fg: n === "paper-light" ? "#4c4f69" : "#f0f0f0",
                    palette: {
                        background: n === "paper-light" ? "#eff1f5" : "#101010",
                        foreground: n === "paper-light" ? "#4c4f69" : "#f0f0f0",
                        accent: "#3366ff",
                        mode: n === "paper-light" ? "light" : "dark"
                    }
                }));
    }
    function wallRows(n) {
        const out = [];
        for (let i = 0; i < n; i++)
            out.push({ name: "/themes/pack-11/backgrounds/" + i + "-wall.jpg", label: "Wall " + i, image: "", tagline: "pack-11", swatches: [], current: i === 1 });
        return out;
    }

    PickerModel {
        id: picker
    }
    // Scale 1.5: card edges land on whole device pixels (151.5 -> 151.33).
    ThemesPanel {
        id: themes
        picker: picker
        dpr: 1.5
        active: picker.opened && picker.themes
        visible: picker.themes
    }
    WallpapersPanel {
        id: walls
        picker: picker
        dpr: 1.5
        active: picker.opened && !picker.themes
        visible: !picker.themes
    }
    SignalSpy {
        id: applied
        target: picker
        signalName: "applied"
    }
    SignalSpy {
        id: closes
        target: picker
        signalName: "closeRequested"
    }

    TestCase {
        name: "PickerNav"
        when: windowShown
        visible: true

        function init() {
            picker.setRows("themes", root.themeRows());
            picker.setRows("backgrounds", root.wallRows(5));
            picker.open("themes");
            themes.forceActiveFocus();
            applied.clear();
            closes.clear();
        }
        function cleanup() {
            picker.close();
        }
        function name() {
            return picker.focused ? picker.focused.name : "";
        }
        function key(k, mods) {
            keyClick(k, mods === undefined ? Qt.NoModifier : mods);
        }

        function test_layout() {
            compare(themes.implicitWidth, 1240);
            compare(themes.implicitHeight, 600);
            compare(themes.columns, 8);
            compare(picker.themeColumns, 8);
            compare(themes.grid.x, 20);
            compare(themes.grid.y, 64);
            compare(themes.grid.width, 1200);
            compare(themes.grid.height, 486);
            compare(themes.filterPill.x, 1020);
            compare(themes.filterPill.width, 200);
            compare(themes.filterPill.height, 30);
            // Card 9: row 1, column 1.
            const c = themes.cards.itemAt(9);
            fuzzyCompare(c.x, 227 / 1.5, 0.01);
            compare(c.y, 166);
            fuzzyCompare(c.width, Math.round(291 * 1.5) / 1.5 - 227 / 1.5, 0.01);
            compare(c.height, 154);
            compare(c.thumb.sourceSize.width, 191);
            compare(c.thumb.sourceSize.height, 120);
            compare(c.thumb.height, 80);
            compare(c.dots.length, 3);
            compare(c.noteText.text, "dark");
            compare(themes.cards.itemAt(11).noteText.text, "Current");
            // Wallpapers: 780 wide, three columns, two rows in view for five.
            compare(walls.implicitWidth, 780);
            compare(walls.columns, 3);
            compare(walls.rowsInView, 2);
            compare(walls.implicitHeight, 444);
            compare(walls.grid.y, 52, "the header is the title's line, as the board draws it");
            const w = walls.cards.itemAt(4);
            fuzzyCompare(w.x, 250.67, 0.01);
            compare(w.y, 192);
            compare(w.thumb.sourceSize.width, 340);
            compare(w.thumb.sourceSize.height, 213);
            compare(w.titleText.text, "4-wall.jpg");
            picker.setRows("backgrounds", root.wallRows(2));
            compare(walls.implicitHeight, 252, "one row: 52 + 180 + 20, no hint row");
            picker.setRows("backgrounds", root.wallRows(18));
            compare(walls.implicitHeight, 444, "two rows in view, the rest scroll");
        }

        function test_open_focuses_the_applied_card() {
            compare(picker.themeIndex, 11);
            compare(name(), "pack-11");
            compare(picker.wallIndex, 1, "the wallpapers panel starts on the applied wallpaper");
            verify(picker.previewPalette === null, "the applied theme does not preview");
        }

        function test_wrap() {
            key(Qt.Key_Home);
            compare(picker.themeIndex, 0);
            key(Qt.Key_Left);
            compare(picker.themeIndex, 36, "Left from the first card wraps to the last");
            key(Qt.Key_Right);
            compare(picker.themeIndex, 0, "Right from the last wraps to the first");
            key(Qt.Key_Right);
            compare(picker.themeIndex, 1);
            key(Qt.Key_End);
            compare(picker.themeIndex, 36);
        }

        function test_columns() {
            key(Qt.Key_Home);
            key(Qt.Key_Down);
            compare(picker.themeIndex, 8, "Down keeps the column");
            key(Qt.Key_Up);
            compare(picker.themeIndex, 0);
            key(Qt.Key_Up);
            compare(picker.themeIndex, 0, "Up on the top row stays");
            verify(picker.focusName("pack-30"));
            key(Qt.Key_Down);
            compare(picker.themeIndex, 36, "Down onto the shorter last row lands on its last card");
            key(Qt.Key_Down);
            compare(picker.themeIndex, 36, "Down on the last row stays");
            key(Qt.Key_Up);
            compare(picker.themeIndex, 28);
            // The grid scrolls a row at a time to keep focus in view.
            key(Qt.Key_End);
            tryCompare(themes.grid, "contentY", 166 * 2, 2000);
            key(Qt.Key_Home);
            tryCompare(themes.grid, "contentY", 0, 2000);
        }

        function test_filter_fallback() {
            verify(picker.focusName("pack-09"));
            keyClick("o");
            keyClick("c");
            compare(picker.filter, "oc");
            compare(picker.themeMatches, 2);
            compare(name(), "ocean", "the focused card dropped out: the first match takes focus");
            // The matches reflow to the grid's start.
            compare(themes.cards.itemAt(5).x, 0);
            fuzzyCompare(themes.cards.itemAt(6).x, 227 / 1.5, 0.01);
            verify(!themes.cards.itemAt(9).visible);
            key(Qt.Key_Right);
            compare(name(), "oceanic");
            key(Qt.Key_Right);
            compare(name(), "ocean", "wrapping counts matches only");
            keyClick("e");
            keyClick("a");
            keyClick("n");
            keyClick("i");
            compare(name(), "oceanic", "the first match left");
            keyClick("x");
            compare(picker.themeMatches, 0);
            verify(picker.focused === null);
            key(Qt.Key_Return);
            compare(applied.count, 0, "Enter with no match applies nothing");
            compare(closes.count, 0, "and does not close");
            key(Qt.Key_Backspace);
            compare(picker.filter, "oceani");
            compare(name(), "oceanic");
            key(Qt.Key_Backspace, Qt.ControlModifier);
            compare(picker.filter, "", "Ctrl+Backspace drops the word");
            keyClick("p");
            keyClick(" ");
            keyClick("l");
            key(Qt.Key_U, Qt.ControlModifier);
            compare(picker.filter, "", "Ctrl+U clears it");
            // A label matches too ("paper light" for paper-light).
            keyClick("r");
            keyClick(" ");
            keyClick("l");
            compare(name(), "paper-light");
        }

        function test_tab() {
            keyClick("o");
            key(Qt.Key_Tab);
            compare(picker.kind, "backgrounds");
            compare(picker.filter, "", "Tab clears the filter");
            compare(picker.wallIndex, 1, "and lands on the applied wallpaper");
            verify(picker.previewPalette === null, "wallpapers never preview");
            walls.forceActiveFocus();
            key(Qt.Key_Right);
            compare(picker.wallIndex, 2);
            key(Qt.Key_Down);
            compare(picker.wallIndex, 4, "Down onto the shorter row: its last card");
            key(Qt.Key_Backtab, Qt.ShiftModifier);
            compare(picker.kind, "themes", "Shift+Tab goes back");
            compare(name(), "ocean", "the themes panel keeps where it was");
            themes.forceActiveFocus();
            key(Qt.Key_Tab);
            compare(picker.wallIndex, 4, "and the wallpapers panel too");
        }

        function test_esc_order() {
            keyClick("p");
            key(Qt.Key_Escape);
            compare(picker.filter, "", "the first Esc clears the filter");
            compare(closes.count, 0);
            verify(picker.opened);
            key(Qt.Key_Escape);
            compare(closes.count, 1, "the second asks to close");
        }

        function test_preview_and_apply() {
            key(Qt.Key_Right);
            compare(name(), "pack-12");
            verify(picker.previewPalette !== null);
            compare(picker.previewPalette.name, "pack-12");
            compare(picker.previewPalette.background, "#101010");
            compare(themes.cards.itemAt(12).noteText.text, "Previewing");
            key(Qt.Key_Left);
            verify(picker.previewPalette === null, "back on the applied card: no preview");
            key(Qt.Key_Right);
            keyPress(Qt.Key_Return, Qt.NoModifier, -1);
            compare(applied.count, 1, "Enter applies");
            compare(applied.signalArguments[0][0].name, "pack-12");
            compare(applied.signalArguments[0][1], "themes");
            picker.close();
            verify(picker.previewPalette === null, "closing ends the preview");
        }

        function test_modifiers_pass() {
            keyClick("x", Qt.AltModifier);
            compare(picker.filter, "", "Alt chords are left for the compositor");
            keyClick("x", Qt.MetaModifier);
            compare(picker.filter, "");
            keyClick("X", Qt.ShiftModifier);
            compare(picker.filter, "X", "Shift types");
        }

        function test_rows_reload_keeps_focus() {
            key(Qt.Key_Right);
            key(Qt.Key_Right);
            compare(picker.themeIndex, 13);
            picker.setRows("themes", root.themeRows());
            compare(picker.themeIndex, 13, "rows that arrive late keep a moved focus");
            picker.close();
            picker.open("themes");
            compare(picker.themeIndex, 11, "a new open starts on the applied card");
        }

        function test_pointer_gate() {
            const card = themes.cards.itemAt(14);
            const p = card.mapToItem(root, card.width / 2, card.height / 2);
            mouseMove(root, p.x, p.y);
            compare(picker.themeIndex, 11, "a pointer that has not moved since the open does not take focus");
            mouseMove(root, p.x + 10, p.y + 4);
            mouseMove(root, p.x + 12, p.y + 4);
            compare(picker.themeIndex, 14, "once it moves, hover focuses");
            mouseClick(root, p.x + 10, p.y + 4);
            compare(applied.count, 1, "a click applies");
            compare(applied.signalArguments[0][0].name, "pack-14");
        }
    }
}
