pragma Singleton
// Prefs.qml - the handful of choices the capsule remembers across restarts.
//
// Which edge it lives on, its size and whether it is see-through. All three
// are changed on the bar rather than by editing a file, so they have to be
// written back somewhere or every reload would undo them.
//
// JsonAdapter does the serialising: each property below is a key in the file,
// the file's contents land in the properties on load, and any change writes
// the whole object back out. Quickshell.statePath keeps it under
// $XDG_STATE_HOME/quickshell alongside its own state.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // "top" | "bottom" | "left" | "right"
    readonly property string edge: ["top", "bottom", "left", "right"].includes(store.edge) ? store.edge : "top"
    readonly property string barMode: ["pill", "full", "rail"].includes(store.barMode) ? store.barMode : "pill"
    readonly property bool translucent: store.translucent

    readonly property bool vertical: root.edge === "left" || root.edge === "right"

    function setEdge(edge: string): void {
        if (["top", "bottom", "left", "right"].indexOf(edge) < 0) return;
        store.edge = edge;
    }

    function setBarMode(mode: string): void {
        if (!["pill", "full", "rail"].includes(mode)) return;
        store.barMode = mode;
    }

    function nextBarMode(mode: string): string {
        if (mode === "pill") return "full";
        if (mode === "full") return "rail";
        return "pill";
    }

    function cycleBarMode(): void { store.barMode = nextBarMode(store.barMode) }
    function toggleTranslucent(): void { store.translucent = !store.translucent }

    FileView {
        id: file
        path: Quickshell.statePath("capsule.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        // First run on a machine: nothing saved yet. Writing the defaults out
        // is what makes every later load quiet.
        onLoadFailed: writeAdapter()

        adapter: JsonAdapter {
            id: store
            property string edge: "top"
            property string barMode: "pill"
            property bool translucent: false
        }
    }
}
