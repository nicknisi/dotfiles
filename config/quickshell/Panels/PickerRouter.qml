import QtQuick

// PickerRouter.qml - which island shows the theme picker (PLAN M7): the
// placement half of ThemePicker.qml, apart from its windows, so
// tests/check.qml drives the real thing with two IslandViews.
//
// The host calls place(island) each time the model opens, changes kind
// (Tab) or closes, with the island that should show it (an Island.qml, or
// anything with its `view`; null for the host's free panel). The island that
// showed it before is released (IslandView.releasePicker: back to rest).
//
// An island leaving its picker states any other way (an outside click on
// its focus grab, `island close`, the palette, cc or the calendar opening
// over it) emits pickerLeft, and that closes the model. Not while place()
// itself moves the picker: reopening on a second screen releases the
// first, and that release is not a close (M7 review: the model closed, the
// second island stayed in the themes state with nothing to close it).
QtObject {
    id: router

    // Panels/PickerModel.qml.
    property var model: null
    // The island showing the picker, or null while the free panel does.
    // Chosen on every open, kept through the close.
    property var shownIsland: null
    readonly property bool islandHosting: shownIsland !== null
    // True while place() runs.
    property bool placing: false

    // From `kind`, not the `themes` binding: onKindChanged can run before it updates.
    function stateName(): string {
        return router.model && router.model.kind === "backgrounds" ? "wallpapers" : "themes";
    }
    function place(island) {
        if (!router.model) return;
        router.placing = true;
        try {
            if (!router.model.opened) {
                if (router.shownIsland) router.shownIsland.view.releasePicker();
                return;
            }
            const old = router.shownIsland;
            const next = island ?? null;
            // The new host first: the old island's pickerLeft is not a close.
            router.shownIsland = next;
            if (old && old !== next) old.view.releasePicker();
            if (next) next.view.showPicker(router.model, router.stateName());
        } finally {
            router.placing = false;
        }
    }
    // The islands changed (a bar mode change, a screen unplugged): one that
    // went cannot host. True when the shown island was one of them.
    function forget(islands): bool {
        if (!router.shownIsland || (islands || []).indexOf(router.shownIsland) >= 0) return false;
        router.shownIsland = null;
        return true;
    }

    property Connections leaveWatch: Connections {
        target: router.shownIsland ? router.shownIsland.view : null
        ignoreUnknownSignals: true
        function onPickerLeft() {
            if (!router.placing && router.model && router.model.opened) router.model.close();
        }
    }
}
