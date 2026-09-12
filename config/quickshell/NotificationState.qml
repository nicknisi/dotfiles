pragma Singleton
// Session notification history shared by the popup server and HUD.
import Quickshell
import QtQuick

Singleton {
    id: root

    property bool dnd: false
    property bool centerOpen: false
    property var centerScreen: null
    property int unread: 0
    property Item centerAnchorItem: null
    property string centerEdge: "top"
    readonly property alias history: items
    readonly property int count: items.count
    signal clearRequested()
    signal anchorGeometryChanged()

    property var anchorsByScreen: ({})

    ListModel { id: items }

    function screenKey(screen): string {
        if (screen === null || screen === undefined) return "";
        if (screen.name !== undefined) return String(screen.name);
        return String(screen);
    }

    function sameScreen(a, b): bool {
        if (a === b) return true;
        const ak = screenKey(a);
        const bk = screenKey(b);
        return ak !== "" && ak === bk;
    }

    function validEntry(entry): bool {
        return entry && entry.item !== null && entry.item !== undefined;
    }

    function resolveAnchor(screen) {
        const key = screenKey(screen);
        const table = anchorsByScreen || ({});
        let entry = key !== "" ? table[key] : null;
        if (validEntry(entry)) return entry;
        if (key !== "") {
            if (entry) delete table[key];
            return null;
        }
        for (const candidateKey in table) {
            entry = table[candidateKey];
            if (validEntry(entry)) return entry;
            delete table[candidateKey];
        }
        anchorsByScreen = table;
        return null;
    }

    function updateCenterAnchor(screen, item, edge): void {
        const entry = item ? { item, edge: edge || "top", screen } : resolveAnchor(screen);
        centerAnchorItem = validEntry(entry) ? entry.item : null;
        if (!screen && validEntry(entry)) centerScreen = entry.screen;
        centerEdge = validEntry(entry) ? entry.edge : (edge || centerEdge || "top");
    }

    function registerAnchor(monitor, item, edge): void {
        if (!item) return;
        const key = screenKey(monitor);
        if (key === "") return;
        const table = anchorsByScreen || ({});
        table[key] = { item, edge: edge || "top", screen: monitor };
        anchorsByScreen = table;
        if (centerOpen && sameScreen(centerScreen, monitor)) {
            updateCenterAnchor(monitor, item, edge);
            anchorGeometryChanged();
        }
    }

    function unregisterAnchor(monitor, item): void {
        const key = screenKey(monitor);
        if (key === "") return;
        const table = anchorsByScreen || ({});
        const entry = table[key];
        if (!entry || (item && entry.item !== item)) return;
        delete table[key];
        anchorsByScreen = table;
        if (centerAnchorItem === entry.item) {
            centerAnchorItem = null;
            closeCenter();
        }
    }

    function remember(item): void {
        items.insert(0, {
            appName: String(item.appName || ""),
            summary: String(item.summary || "Notification"),
            body: String(item.body || ""),
            image: String(item.image || ""),
            appIcon: String(item.appIcon || ""),
            critical: Boolean(item.critical),
            created: Date.now()
        });
        if (items.count > 50) items.remove(50, items.count - 50);
        unread++;
    }

    function markRead(): void { unread = 0 }
    function openCenter(screen, item, edge): void {
        centerScreen = screen;
        updateCenterAnchor(screen, item, edge);
        centerOpen = true;
        markRead();
    }
    function closeCenter(): void { centerOpen = false }
    function toggleCenter(screen, item, edge): void {
        centerOpen && sameScreen(centerScreen, screen) ? closeCenter() : openCenter(screen, item, edge);
    }
    function toggleDnd(): void { dnd = !dnd }
    function clear(): void {
        items.clear();
        unread = 0;
        clearRequested();
    }
}
