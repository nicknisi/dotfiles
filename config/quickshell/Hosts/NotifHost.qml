import Quickshell
import Quickshell.Wayland
import QtQuick
import qs

// NotifHost.qml - notifications in the classic bar modes (pill, full, rail):
// the island's banner (Island/NotifLayer.qml, 520 x 92) on its own opaque
// surface, radius 28, one shadow, no blur (M10: it replaced the old toasts,
// Notifications.qml, once the old Theme went).
//
// What the toasts did, kept:
//   - one card per notification still up, oldest on top, all at once;
//   - the body wraps (four lines here, six on the toast's narrower card; the
//     markup goes, line breaks stay), and the card grows with it;
//   - a critical one stands out: its ring is `bad` (the toast's border was
//     red; low and normal no longer differ);
//   - top right, 8 in from the screen's edges and 8 under the bar when it is
//     along the top (the reserve, Theme.barExtent: y 64 under the pill, 48
//     under the full strip); along the bottom they stack up from 8 over it,
//     along the right they step in past it;
//   - Do not disturb hides all but critical ones, which still run out;
//   - each runs out after NotificationServer.timeoutFor (the sender's timeout,
//     else 4200 ms; never for a critical one) and then expires, staying in
//     the history;
//   - a click opens it (NotificationState.open: the sender's default action,
//     then its window, then dismissed), a right click dismisses, and every
//     other labelled action is a button (a pill in a row under the body).
// New with the banner: Open and the x, the countdown bar, and the pointer
// pauses a card's countdown; leaving gives it what it had left, at least
// IslandMachine.RESUME_MIN, as the island does.
//
// In island mode it holds nothing (the model is empty) and the islands show
// the banners; switching to a classic mode picks up what is still up for
// the rest of its time (NotificationServer.remainingFor), the whole timeout
// when that is unknown.
//
// The window is this file's; the cards are Hosts/NotifStack.qml, a plain
// Item, so tests/notif-host.sh drives them offscreen on a fake server.
Scope {
    id: root

    // The NotificationServer.qml instance (shell.qml).
    property var source: null
    readonly property bool active: Prefs.barMode !== "island"
    readonly property var model: root.active ? (root.source?.server?.trackedNotifications ?? null) : null
    readonly property alias window: popups
    readonly property alias cards: column

    // The gap to the screen's edge, and to the bar on the edge it holds.
    readonly property int gap: 8
    readonly property int topGap: Prefs.edge === "top" ? Theme.barExtent + root.gap : root.gap
    readonly property int bottomGap: Prefs.edge === "bottom" ? Theme.barExtent + root.gap : root.gap
    readonly property int rightGap: Prefs.edge === "right" ? Theme.barExtent + root.gap : root.gap
    // Room for the shadow (0 10 28): 28 to the left and above, 38 below.
    readonly property int shadowSide: 28
    readonly property int shadowBelow: 38

    // For `qs ipc call bar inspect`: whether the window shows, and each card
    // (Do not disturb's hidden ones too) in screen coordinates.
    function inspect(): var {
        const scr = popups.screen;
        const wx = (scr?.x ?? 0) + (scr ? scr.width - popups.width : 0);
        const wy = (scr?.y ?? 0) + (Prefs.edge === "bottom" && scr ? scr.height - popups.height : 0);
        return {
            active: root.active,
            visible: popups.visible,
            cards: column.cards.map(c => ({
                        id: c.notification?.id ?? null,
                        x: Math.round(wx + column.x + c.x),
                        y: Math.round(wy + column.y + c.y),
                        width: Math.round(c.width),
                        height: Math.round(c.height),
                        visible: c.visible,
                        critical: c.critical,
                        bodyLines: c.card.bodyText.visible ? c.card.bodyText.lineCount : 0,
                        bodyCut: c.card.bodyText.truncated,
                        actions: c.card.extraActions.map(a => String(a.text ?? ""))
                    }))
        };
    }

    PanelWindow {
        id: popups

        anchors {
            top: Prefs.edge !== "bottom"
            bottom: Prefs.edge === "bottom"
            right: true
        }
        implicitWidth: root.shadowSide + 520 + root.rightGap
        implicitHeight: Math.max(1, column.y + column.height + (Prefs.edge === "bottom" ? root.bottomGap : root.shadowBelow))
        mask: Region { item: column }
        color: "transparent"
        visible: root.active && column.visibleCount > 0

        // Over everything, reserving nothing; out of the shell-blur rule.
        WlrLayershell.namespace: "quickshell-notifications"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore

        NotifStack {
            id: column
            x: root.shadowSide
            y: Prefs.edge === "bottom" ? root.shadowSide : root.topGap
            source: root.source
            model: root.model
        }
    }
}
