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
    readonly property alias history: items
    readonly property int count: items.count
    signal clearRequested()

    ListModel { id: items }

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
    function openCenter(screen): void {
        centerScreen = screen;
        centerOpen = true;
        markRead();
    }
    function closeCenter(): void { centerOpen = false }
    function toggleCenter(screen): void {
        centerOpen && centerScreen === screen ? closeCenter() : openCenter(screen);
    }
    function toggleDnd(): void { dnd = !dnd }
    function clear(): void {
        items.clear();
        unread = 0;
        clearRequested();
    }
}
