pragma Singleton
// Session notification history shared by the popup server and HUD.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
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
            desktopEntry: String(item.desktopEntry || ""),
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

    // The window behind a notification: Slack's toast means the Slack window,
    // whatever workspace it is on. desktopEntry is the sender's own id when it
    // sends one ("slack", "brave-origin"); appName is the fallback. A window
    // already marked urgent wins, since that is the one that pinged.
    function sourceWindow(appName, desktopEntry) { return windowFor([desktopEntry, appName]) }
    // The same lookup for whatever names a tray item offers: its title, its
    // tooltip and its id ("1Password_status_icon_1", "chrome_status_icon_1").
    function windowFor(names) {
        const wanted = names
            .map(s => String(s || "").toLowerCase().replace(/\.desktop$/, "").trim())
            .filter(s => s.length > 0);
        if (!wanted.length) return null;
        const matches = ToplevelManager.toplevels.values.filter(t => {
            const id = String(t.appId || "").toLowerCase();
            return id !== "" && wanted.some(w => id === w || id.endsWith("." + w) || (w.length >= 4 && (id.includes(w) || w.includes(id))));
        });
        if (!matches.length) return null;
        const pinged = matches.find(t => Hyprland.toplevels.values.some(h => h.wayland === t && h.urgent));
        return pinged || matches.find(t => t.activated) || matches[0];
    }
    // Focus that window, switching workspace as needed. False when the app has
    // no window, so the caller can leave its own surface alone.
    function focusSource(appName, desktopEntry): bool { return focusApp([desktopEntry, appName]) }
    function focusApp(names): bool {
        const win = windowFor(names);
        if (!win) return false;
        win.activate();
        return true;
    }
    // The popup server, set by Notifications.qml, for the toasts still up.
    property var server: null

    // What a click on a toast does: the window first, so it is on screen,
    // then the sender's default action (Slack jumps to the message), then the
    // toast goes. The window comes first because invoking the action may
    // close the notification, and with it the toast whose handler is running.
    function open(notification): bool {
        if (!notification) return false;
        const appName = String(notification.appName || ""), desktopEntry = String(notification.desktopEntry || "");
        const focused = focusSource(appName, desktopEntry);
        const actions = notification.actions || [];
        for (let i = 0; i < actions.length; i++) {
            if (actions[i].identifier === "default") { actions[i].invoke(); break; }
        }
        // The sender usually closes it itself on the action; only dismiss
        // what is still up, a destroyed one logs an error rather than throwing.
        if (server && server.trackedNotifications.values.includes(notification))
            notification.dismiss();
        return focused;
    }
    function openLatest(): bool {
        const list = server ? server.trackedNotifications.values : [];
        return list.length > 0 ? open(list[list.length - 1]) : false;
    }

    // `qs ipc call notifications open` acts on the newest toast as a click
    // would (a bind can do it without reaching for the mouse); `focus slack`
    // is the window jump alone, and the way to check the matching.
    IpcHandler {
        target: "notifications"
        function open(): string { return root.openLatest() ? "ok" : "nothing to open" }
        function focus(app: string): string {
            const win = root.sourceWindow(app, app);
            if (!win) return "no window for " + app;
            win.activate();
            return "activated " + win.appId + " · " + win.title;
        }
    }
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
