import QtQuick
import qs
import qs.Kit
import qs.Island
import "../lib/IslandMachine.js" as IslandMachine

// NotifStack.qml - the classic modes' notification cards, oldest on top
// (Hosts/NotifHost.qml holds them in a window and says what they keep from
// the old toasts). Each is the island's banner, Island/NotifLayer.qml, with
// the body wrapping to `bodyLines` and the sender's other actions in a row
// under it, on an opaque Surface (radius 28, one shadow), 12 apart. A card
// is 92 high and grows with the body and the actions. A critical one's 1 px
// ring is `bad` (the toast's border was red for it).
//
// `source` has NotificationServer.qml's shape (timeoutFor, shows, critical,
// remainingFor); `model` is what lists the notifications, the server's
// trackedNotifications (an object model, so a new arrival leaves the other
// cards and their timers alone). Do not disturb hides a card and its timer
// still runs, as the toast's did.
Column {
    id: column

    property var source: null
    property var model: null
    // Lines a body may wrap to (the old toasts showed 6, on a narrower card).
    property int bodyLines: 4
    // Visible cards (Do not disturb hides some), for the window.
    property int visibleCount: 0
    // The cards, hidden ones included (tests).
    readonly property var cards: column.children.filter(c => c.notification !== undefined)

    objectName: "notifCards"
    width: 520
    spacing: 12

    function recount() {
        let n = 0;
        for (const c of column.children)
            if (c.visible && c.notification !== undefined) n++;
        column.visibleCount = n;
    }
    onChildrenChanged: Qt.callLater(column.recount)

    Repeater {
        model: column.model

        Item {
            id: slot
            required property var modelData
            readonly property var notification: slot.modelData
            readonly property int timeout: column.source ? column.source.timeoutFor(slot.notification) : 0
            readonly property bool critical: column.source?.critical ? column.source.critical(slot.notification) : false
            // ms the countdown has when it (re)starts.
            property int remaining: 0
            property real since: 0
            readonly property bool paused: hover.hovered
            property bool entered: false
            readonly property alias card: card
            readonly property alias surface: surface
            readonly property alias expiry: expiry

            objectName: "notifCard-" + (slot.notification?.id ?? "")
            width: 520
            height: card.height
            visible: column.source ? column.source.shows(slot.notification) : true
            onVisibleChanged: Qt.callLater(column.recount)

            function run() {
                if (slot.timeout <= 0) return;
                slot.since = Date.now();
                expiry.interval = Math.max(1, slot.remaining);
                expiry.restart();
                card.serial++;
            }
            // The pointer on the card: the countdown waits where it is.
            function pauseCountdown() {
                if (!expiry.running) return;
                expiry.stop();
                slot.remaining = Math.max(0, slot.remaining - (Date.now() - slot.since));
            }
            // The pointer gone: what it had left, at least RESUME_MIN.
            function resumeCountdown() {
                if (slot.timeout <= 0 || expiry.running) return;
                slot.remaining = Math.max(IslandMachine.RESUME_MIN, slot.remaining);
                slot.run();
            }
            onPausedChanged: slot.paused ? slot.pauseCountdown() : slot.resumeCountdown()
            Component.onCompleted: {
                const r = column.source?.remainingFor ? column.source.remainingFor(slot.notification) : 0;
                slot.remaining = r > 0 ? r : slot.timeout;
                slot.run();
                Qt.callLater(() => slot.entered = true);
            }

            Timer {
                id: expiry
                repeat: false
                onTriggered: slot.notification?.expire()
            }
            HoverHandler {
                id: hover
            }

            // The card arrives as the island's layers do.
            Layer {
                anchors.fill: parent
                current: slot.entered

                Surface {
                    id: surface
                    anchors.fill: parent
                    radius: IslandMachine.radiusFor(92)
                    border.color: slot.critical ? Tokens.bad : Tokens.hairline
                }
                // Under the card's buttons: a click opens, a right click
                // dismisses (the old toast's rule).
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) card.open();
                        else card.dismiss();
                    }
                }
                NotifLayer {
                    id: card
                    current: true
                    actionsShown: true
                    bodyLines: column.bodyLines
                    notification: slot.notification
                    timeout: slot.timeout
                    timeLeft: slot.remaining
                    running: !slot.paused
                    onOpen: NotificationState.open(slot.notification)
                    onDismiss: slot.notification?.dismiss()
                }
            }
        }
    }
}
