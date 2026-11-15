import QtQuick
import qs

// PickerPreview.qml - the theme picker's live preview (PLAN M7,
// launcher-pickers 7.4): Tokens.previewPalette follows the model's
// previewPalette (the focused theme card, unless it is the applied one), so
// the island, the free panel, the launcher and everything else drawn from
// Tokens retints on the effects spring. Nothing is written to disk.
//
// When Enter applies a theme the preview is pinned to it (pin) until
// colors.json names it (Theme.name) or 15 s pass, so the shell does not
// flash back to the old theme while bin/theme runs. Closing without Enter
// (Esc, an outside click, Tab to the wallpapers) drops it at once.
//
// ThemePicker.qml owns one; check.qml drives one against the real Tokens.
QtObject {
    id: preview

    property var model: null
    property var pinned: null
    property string pinnedName: ""
    readonly property var palette: (model ? model.previewPalette : null) ?? pinned

    onPaletteChanged: Tokens.previewPalette = preview.palette

    // The theme Enter applied: its palette stays on screen until Theme catches up.
    function pin(row) {
        if (!row || row.current === true || !row.palette) return;
        preview.pinned = Object.assign({}, row.palette, {
            name: String(row.name || ""),
            tagline: String(row.tagline || "")
        });
        preview.pinnedName = String(row.name || "");
        pinTimer.restart();
    }
    function unpin() {
        pinTimer.stop();
        preview.pinned = null;
        preview.pinnedName = "";
    }

    property Timer pinTimer: Timer {
        id: pinTimer
        interval: 15000
        onTriggered: preview.unpin()
    }
    property Connections themeWatch: Connections {
        target: Theme
        function onPaletteChanged() {
            if (preview.pinnedName !== "" && Theme.name === preview.pinnedName) preview.unpin();
        }
    }
}
