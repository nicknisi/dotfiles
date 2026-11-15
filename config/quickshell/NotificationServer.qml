// NotificationServer.qml - the session's org.freedesktop.Notifications server
// (PLAN M3: split out of Notifications.qml, which keeps only the toasts).
//
// Nothing else on this machine owns that bus name, so without it every
// notification is dropped, batsignal's low-battery warnings included. One
// instance for the session, in shell.qml, whatever the bar mode: the island
// shows its banners from `arrived`, the classic modes' toasts read
// `server.trackedNotifications`, and NotificationState keeps the history,
// DND and the `notifications` IPC target, unchanged.
//
// A notification is discarded the moment the callback returns unless
// something marks it `tracked`, which onNotification does below. It stays
// tracked until it expires (timeoutFor: the sender's timeout, else 4200 ms,
// never for a critical one), is dismissed or opened, or the sender closes it.
//
// Who expires it (M3 review):
//   - the classic modes: its toast's timer (Notifications.qml);
//   - island mode: the islands. Each IslandView tells hold() every id its
//     machine refers to (shown, interrupted, queued). One shows the banner
//     on every screen, each with its own timer, and it expires once the last
//     island holding it lets go, so a card paused under the pointer on one
//     screen outlives the others' timers;
//   - island mode, held by no island (Do not disturb kept it off, it arrived
//     in a classic mode before a switch, or while the islands were being
//     rebuilt): its deadline, arrival + timeoutFor, checked every 500 ms
//     while one is pending. A new island adopts what is still up
//     (remainingFor), so such a notification can show for the rest of its time.
//
// The Quickshell type is imported under a name (Dbus) because this file
// shares its own: unqualified, `NotificationServer` here would be this file.
import Quickshell
import Quickshell.Services.Notifications as Dbus
import QtQuick
import "lib/IslandMachine.js" as IslandMachine

Scope {
    id: root

    readonly property alias server: server
    // Every notification still up, oldest first.
    readonly property var tracked: server.trackedNotifications.values

    // A new notification, already in NotificationState's history.
    signal arrived(var notification)

    function find(id: int): var {
        return root.tracked.find(n => n.id === id) ?? null;
    }
    function critical(notification): bool {
        return notification?.urgency === Dbus.NotificationUrgency.Critical;
    }
    // ms on the island or a toast; 0 is never (critical).
    function timeoutFor(notification): int {
        return IslandMachine.notifTimeout(notification?.expireTimeout ?? -1, root.critical(notification));
    }
    // Whether it may interrupt: Do not disturb holds back everything but critical.
    function shows(notification): bool {
        return !NotificationState.dnd || root.critical(notification);
    }

    // ---- island mode: who holds what, and the deadlines ---------------------

    // [{ owner, ids }]: what each island's machine refers to.
    property var holders: []
    // id -> how many islands hold it.
    readonly property var heldCount: {
        const c = {};
        for (const h of root.holders)
            for (const id of h.ids)
                c[id] = (c[id] ?? 0) + 1;
        return c;
    }
    function held(id: int): bool {
        return (root.heldCount[id] ?? 0) > 0;
    }
    // `owner` (an IslandView) now refers to exactly `ids`. One it let go of
    // that no island holds any more has run its course on the islands and
    // expires (it stays in the history), unless its sender or the user
    // closed it already.
    function hold(owner, ids): void {
        const r = IslandMachine.holdIds(root.holders, owner, ids);
        root.holders = r.holders;
        for (const id of r.released)
            root.find(id)?.expire();
    }
    // An island going away (a mode switch, a screen unplugged) lets go
    // without expiring anything: the classic toasts, or the deadline, take over.
    function forget(owner): void {
        root.holders = root.holders.filter(h => h.owner !== owner);
    }

    // id -> when it times out (ms since the epoch), 0 for never.
    property var deadlines: ({})
    // ms it has left, 0 for none or never (see deadlines).
    function remainingFor(notification): int {
        const at = root.deadlines[notification?.id] ?? 0;
        return at > 0 ? Math.max(0, at - Date.now()) : 0;
    }
    readonly property bool sweeping: Prefs.barMode === "island" && root.tracked.some(n => (root.deadlines[n.id] ?? 0) > 0 && !root.held(n.id))
    function sweep(): void {
        const now = Date.now();
        for (const n of root.tracked.slice()) {
            const at = root.deadlines[n.id] ?? 0;
            if (at > 0 && at <= now && !root.held(n.id)) n.expire();
        }
    }
    Timer {
        interval: 500
        repeat: true
        running: root.sweeping
        onTriggered: root.sweep()
    }
    // Deadlines go with their notifications.
    onTrackedChanged: {
        const ids = root.tracked.map(n => n.id);
        const keep = {};
        let dropped = false;
        for (const id in root.deadlines) {
            if (ids.indexOf(Number(id)) >= 0) keep[id] = root.deadlines[id];
            else dropped = true;
        }
        if (dropped) root.deadlines = keep;
    }

    Dbus.NotificationServer {
        id: server
        Component.onCompleted: NotificationState.server = server

        // Advertised capabilities. Senders check these, so only claim what the
        // toasts and the island banner render.
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: false
        inlineReplySupported: false

        onNotification: notification => {
            notification.tracked = true;
            NotificationState.remember({
                appName: notification.appName,
                desktopEntry: notification.desktopEntry,
                summary: notification.summary,
                body: notification.body,
                image: notification.image,
                appIcon: notification.appIcon,
                critical: root.critical(notification)
            });
            const t = root.timeoutFor(notification);
            const next = Object.assign({}, root.deadlines);
            next[notification.id] = t > 0 ? Date.now() + t : 0;
            root.deadlines = next;
            root.arrived(notification);
        }
    }

    Connections {
        target: NotificationState
        function onClearRequested() {
            for (const notification of server.trackedNotifications.values)
                notification.dismiss();
        }
    }
}
