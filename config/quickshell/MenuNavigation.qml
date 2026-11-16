import QtQuick

// Use Qt's focus chain, including native controls and dynamically created rows.
Item {
    id: navigation
    required property Item scope
    readonly property Item current: Window.activeFocusItem

    function contains(item) {
        for (let p = item; p; p = p.parent) if (p === scope) return true;
        return false;
    }
    function reveal(item) {
        if (!contains(item)) return;
        for (let p = item.parent; p && p !== scope; p = p.parent) {
            if (p.contentY === undefined || !p.contentItem) continue;
            const y = item.mapToItem(p.contentItem, 0, 0).y;
            if (y < p.contentY) p.contentY = Math.max(0, y);
            else if (y + item.height > p.contentY + p.height)
                p.contentY = Math.min(Math.max(0, p.contentHeight - p.height), y + item.height - p.height);
        }
    }
    function move(forward) {
        let origin = contains(current) ? current : scope;
        // ListView may focus its current delegate. Navigate the model, not only
        // the instantiated delegates, so offscreen results remain reachable.
        for (let list = origin; list && list !== scope; list = list.parent) {
            if (typeof list.incrementCurrentIndex !== "function") continue;
            const index = list.currentIndex + (forward ? 1 : -1);
            if (index >= 0 && index < list.count) {
                if (forward) list.incrementCurrentIndex(); else list.decrementCurrentIndex();
                list.positionViewAtIndex(index, ListView.Contain);
                return;
            }
            origin = list;
            break;
        }
        const first = origin.nextItemInFocusChain(forward);
        let item = first;
        do {
            if (!item) return;
            if (contains(item) && item.visible && item.enabled && item.activeFocusOnTab) {
                item.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
                reveal(item);
                return;
            }
            item = item.nextItemInFocusChain(forward);
        } while (item !== first);
    }
    onCurrentChanged: reveal(current)

    // Only while this item's own window shows. A hidden PopupWindow's items
    // keep `visible: true`, and Qt resolves a window shortcut through the
    // QObject parents, so the island's hidden old Hud (a PopupWindow child of
    // IslandView, gone in M10) took Up, Down, Ctrl+J and Ctrl+K from the
    // island window and the launcher's query field never saw them (M5 review).
    readonly property bool live: navigation.scope.visible && navigation.Window.window !== null && navigation.Window.window.visible

    Shortcut {
        sequences: ["Down", "Ctrl+J"]
        context: Qt.WindowShortcut
        enabled: navigation.live
        onActivated: navigation.move(true)
    }
    Shortcut {
        sequences: ["Up", "Ctrl+K"]
        context: Qt.WindowShortcut
        enabled: navigation.live
        onActivated: navigation.move(false)
    }
}
