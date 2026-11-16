import QtQuick
import "../lib/PickerNav.js" as PickerNav

// PickerModel.qml - the theme and wallpaper pickers' state and keys (PLAN M7,
// launcher-pickers 7.3 and 7.6), shared by both hosts: the island's `themes`
// and `wallpapers` states and ThemePicker.qml's free panel. ThemePicker.qml
// feeds it rows (`theme _rows`) and acts on what it asks for: applied(row,
// kind) runs bin/theme, closeRequested() closes, and `previewPalette` is what
// Tokens.previewPalette shows.
//
// QtQuick only, so tests/tst_picker_nav.qml drives it with real key events.
//
// Keys (handleKey, from whichever panel has the keyboard):
//   Left / Right      previous / next card, wrapping
//   Up / Down         same column, a row up / down
//   Home / End        first / last match
//   Enter             apply the focused card (an autorepeat does nothing)
//   Tab / Shift+Tab   the other panel, filter cleared, focus on its current card
//   printable         appended to the filter (no modifier, or Shift)
//   Backspace         the filter loses a character; Ctrl+Backspace a word;
//                     Ctrl+U all of it
//   Esc               clears the filter if any, else asks to close
//   Alt / Super       left for the compositor
QtObject {
    id: model

    // The IPC's kinds: "themes" or "backgrounds" (the island's `wallpapers`).
    property string kind: "themes"
    property bool opened: false
    property var themeRows: []
    property var wallRows: []
    property bool themesLoaded: false
    property bool wallsLoaded: false
    property string filter: ""
    property int themeIndex: -1
    property int wallIndex: -1
    // The user moved focus since the panel opened: rows that load late keep it.
    property bool themeTouched: false
    property bool wallTouched: false
    property int themeColumns: 8
    readonly property int wallColumns: 3
    // "Add from Pictures" and "Accent from wallpaper" have no backend yet
    // (launcher-pickers 7.2 [NEEDS CHECK]): drawn only once these turn on.
    readonly property bool canAdd: false
    readonly property bool canAccent: false

    readonly property bool themes: kind !== "backgrounds"
    readonly property var rows: themes ? themeRows : wallRows
    readonly property bool loaded: themes ? themesLoaded : wallsLoaded
    readonly property int index: themes ? themeIndex : wallIndex
    readonly property int columns: themes ? themeColumns : wallColumns
    // Row index -> position among the matches (-1: filtered out). The filter
    // belongs to the panel showing; the other panel is unfiltered.
    readonly property var themePositions: PickerNav.positions(themeRows, themes ? filter : "")
    readonly property var wallPositions: PickerNav.positions(wallRows, themes ? "" : filter)
    readonly property int themeMatches: PickerNav.count(themeRows, themes ? filter : "")
    readonly property int wallMatches: PickerNav.count(wallRows, themes ? "" : filter)
    readonly property int matchCount: themes ? themeMatches : wallMatches
    readonly property var focused: index >= 0 && index < rows.length && PickerNav.matches(rows[index], filter) ? rows[index] : null
    // The theme whose wallpapers these are (the wallpaper rows' tagline).
    readonly property string currentTheme: {
        if (wallRows.length > 0) return String(wallRows[0].tagline || "");
        const i = PickerNav.currentIndex(themeRows);
        return i >= 0 && themeRows[i].current ? String(themeRows[i].name || "") : "";
    }
    // Live preview (7.4): the focused theme while the themes panel is open,
    // unless it is the one applied. Wallpapers never preview.
    readonly property var previewRow: opened && themes && focused && focused.current !== true && focused.palette && focused.bg && focused.fg ? focused : null
    readonly property var previewPalette: previewRow ? Object.assign({}, previewRow.palette, {
            name: String(previewRow.name || ""),
            tagline: String(previewRow.tagline || "")
        }) : null

    signal applied(var row, string kind)
    signal closeRequested

    function open(k: string) {
        kind = k === "backgrounds" ? "backgrounds" : "themes";
        filter = "";
        themeTouched = false;
        wallTouched = false;
        themeIndex = PickerNav.currentIndex(themeRows);
        wallIndex = PickerNav.currentIndex(wallRows);
        opened = true;
    }
    function close() {
        opened = false;
        filter = "";
    }

    // Rows for `k` arrived (or changed): focus the applied card unless the
    // user has moved already, in which case the same index stays if it can.
    function setRows(k: string, list) {
        const r = Array.isArray(list) ? list : [];
        if (k === "backgrounds") {
            wallRows = r;
            wallsLoaded = true;
            wallIndex = wallTouched && wallIndex < r.length ? wallIndex : PickerNav.currentIndex(r);
        } else {
            themeRows = r;
            themesLoaded = true;
            themeIndex = themeTouched && themeIndex < r.length ? themeIndex : PickerNav.currentIndex(r);
        }
        refocus();
    }

    function setIndex(i: int) {
        if (themes) {
            themeIndex = i;
            themeTouched = true;
        } else {
            wallIndex = i;
            wallTouched = true;
        }
    }
    // The focused card left the matches: the first match takes focus.
    function refocus() {
        const i = PickerNav.fallback(rows, filter, index);
        if (i !== index && i >= 0) {
            if (themes) themeIndex = i;
            else wallIndex = i;
        }
    }

    function focusAt(i: int): bool {
        if (i < 0 || i >= rows.length || !PickerNav.matches(rows[i], filter)) return false;
        setIndex(i);
        return true;
    }
    // A card by its name (a theme's slug, a wallpaper's path or file name).
    function focusName(name: string): bool {
        for (let i = 0; i < rows.length; i++) {
            const n = String(rows[i].name || "");
            if (n === name || n.split("/").pop() === name) return focusAt(i);
        }
        return false;
    }
    function move(dir: int) {
        const i = PickerNav.step(rows, filter, index, dir);
        if (i >= 0) setIndex(i);
    }
    function moveRow(dir: int) {
        const i = PickerNav.vertical(rows, filter, index, columns, dir);
        if (i >= 0) setIndex(i);
    }
    function toEdge(last: bool) {
        const i = PickerNav.edge(rows, filter, last);
        if (i >= 0) setIndex(i);
    }
    function typeText(text: string) {
        filter = filter + text;
        refocus();
    }
    function edit(how: string) {
        filter = PickerNav.edited(filter, how);
        refocus();
    }
    // Esc: the filter first, then the panel. True when it cleared the filter.
    function clearOrClose(): bool {
        if (filter !== "") {
            filter = "";
            refocus();
            return true;
        }
        closeRequested();
        return false;
    }
    // Tab: the other panel, unfiltered, on its applied card unless moved there before.
    function switchKind() {
        filter = "";
        kind = themes ? "backgrounds" : "themes";
        refocus();
    }
    // Enter: the focused card. Nothing when no card matches (the filter
    // stays, so Backspace can fix it).
    function apply() {
        const r = focused;
        if (r) applied(r, kind);
    }

    function handleKey(event): bool {
        const mods = event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
        if (mods & (Qt.AltModifier | Qt.MetaModifier)) return false;
        const ctrl = (mods & Qt.ControlModifier) !== 0;
        switch (event.key) {
        case Qt.Key_Escape:
            clearOrClose();
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (!event.isAutoRepeat) apply();
            return true;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            switchKind();
            return true;
        case Qt.Key_Left:
            move(-1);
            return true;
        case Qt.Key_Right:
            move(1);
            return true;
        case Qt.Key_Up:
            moveRow(-1);
            return true;
        case Qt.Key_Down:
            moveRow(1);
            return true;
        case Qt.Key_Home:
            toEdge(false);
            return true;
        case Qt.Key_End:
            toEdge(true);
            return true;
        case Qt.Key_Backspace:
            if (filter !== "") edit(ctrl ? "word" : "char");
            return true;
        }
        if (ctrl && event.key === Qt.Key_U) {
            if (filter !== "") edit("all");
            return true;
        }
        const t = event.text;
        if (!ctrl && t && t.length === 1 && t.charCodeAt(0) >= 32 && t.charCodeAt(0) !== 127) {
            typeText(t);
            return true;
        }
        return false;
    }
}
