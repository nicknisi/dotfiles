import Quickshell
import Quickshell.Widgets
import QtQuick
import qs
import qs.Kit

// NotifLayer.qml - one notification as the island itself (island-modes 9.1,
// main-tokens 2.5.6, Main board `notif`, 520 x 92).
//
//   ←14→ [tile] ←14→ Claude Code  now                    [ Open ] (x) ←14→
//                    Island mocks are ready
//                    Open the canvas to review them.
//          ─────────────────── progress ───────────────────
//
// Tile 44, radius 12, `raised` with a `hairline` ring, holding the app's icon
// (18) or the notification's image; agents get the sparkle and anything
// without an icon the bell, both `accent` [GUESS]. Meta 11 `inkDim` (app,
// "now"), the summary 14 / 500, the body 12 `inkDim` on one line (markup
// stripped). "Open" (30 high, `fillHigh`) runs NotificationState.open: focus
// the sender, invoke its default action, dismiss. The x dismisses. Along the
// bottom (24 in, 7 up, 2 high) a `faint` bar on `fillLow` shrinks from full
// to empty over the timeout, linearly; a critical notification has none and
// stays until handled.
//
// Data comes in as plain values (IslandView reads the server, or a fixture):
// { appName, summary, body, appIcon, image, critical }. `timeout` is ms, 0
// for none; `timeLeft` the ms its timer has to run each time it (re)starts;
// `running` is false while the card is paused under the pointer.
Layer {
    id: card

    property var notification: null
    property int timeout: 0
    // What the timer has to run when the bar (re)starts: the timeout for a
    // new card, what it had left when the pointer paused it, 0 for timeout.
    property int timeLeft: 0
    // The countdown runs while this holds; the view clears it while the
    // pointer rests on the card (the machine pauses it there).
    property bool running: true
    // Bumped by the view for each notification shown, so the bar restarts.
    property int serial: 0

    signal open
    signal dismiss

    readonly property string appName: notification?.appName || "Notification"
    readonly property string summary: notification?.summary ?? ""
    readonly property string body: card.plain(notification?.body ?? "")
    readonly property string iconSource: {
        const img = String(notification?.image ?? "");
        if (img !== "") return img;
        const icon = String(notification?.appIcon ?? "");
        if (icon === "") return "";
        return icon.startsWith("/") || icon.indexOf("://") > 0 ? icon : Quickshell.iconPath(icon, true);
    }
    readonly property bool agent: /^(claude|claude code|codex|pi|opencode)$/i.test(appName)
    readonly property alias progress: progress
    readonly property alias openButton: openButton
    readonly property alias dismissButton: dismissButton
    readonly property alias tile: tile

    // Notification bodies may carry a little markup (<b>, <i>, <a>) and
    // entities; the banner's one line is plain text.
    function plain(s: string): string {
        return String(s).replace(/<[^>]*>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;|&apos;/g, "'").replace(/&amp;/g, "&").replace(/\s+/g, " ").trim();
    }

    width: 520
    height: 92

    Accessible.role: Accessible.AlertMessage
    Accessible.name: appName + ": " + summary
    Accessible.description: body

    Rectangle {
        id: tile
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 44
        radius: 12
        color: Tokens.raised
        border.width: 1
        border.color: Tokens.hairline
        Icon {
            anchors.centerIn: parent
            visible: card.iconSource === "" || image.status === Image.Error
            name: card.agent ? "sparkle" : "bell"
            size: 18
            color: Tokens.accent
        }
        ClippingRectangle {
            anchors.centerIn: parent
            visible: card.iconSource !== "" && image.status !== Image.Error
            // An image (a screenshot, an avatar) fills the tile; an app icon is 18.
            readonly property bool photo: String(card.notification?.image ?? "") !== ""
            width: photo ? 42 : 18
            height: photo ? 42 : 18
            radius: photo ? 11 : 0
            color: "transparent"
            Image {
                id: image
                anchors.fill: parent
                source: card.iconSource
                sourceSize: Qt.size(84, 84)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
        }
    }

    Column {
        anchors.left: tile.right
        anchors.leftMargin: 14
        anchors.right: openButton.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Row {
            spacing: 6
            width: parent.width
            Text {
                width: Math.min(implicitWidth, parent.width - 30)
                text: card.appName
                color: Tokens.inkDim
                elide: Text.ElideRight
                textFormat: Text.PlainText
                font.family: "Adwaita Sans"
                font.pixelSize: 11
            }
            Text {
                text: "now"
                color: Tokens.inkDim
                font.family: "Adwaita Sans"
                font.pixelSize: 11
            }
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: card.summary
            color: Tokens.fg
            elide: Text.ElideRight
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 14
            font.weight: Font.Medium
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: card.body
            color: Tokens.inkDim
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 12
        }
    }

    Rectangle {
        id: openButton
        anchors.right: dismissButton.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: Math.ceil(openLabel.implicitWidth) + 28
        height: 30
        radius: 15
        color: openArea.pressed ? Tokens.fillLow : Tokens.fillHigh
        Accessible.role: Accessible.Button
        Accessible.name: "Open"
        Accessible.onPressAction: card.open()
        Text {
            id: openLabel
            anchors.centerIn: parent
            text: "Open"
            color: Tokens.fg
            font.family: "Adwaita Sans"
            font.pixelSize: 12
        }
        MouseArea {
            id: openArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: card.open()
        }
    }

    Rectangle {
        id: dismissButton
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        radius: 15
        color: dismissArea.containsMouse ? Tokens.fillLow : "transparent"
        Accessible.role: Accessible.Button
        Accessible.name: "Dismiss"
        Accessible.onPressAction: card.dismiss()
        Icon {
            anchors.centerIn: parent
            name: "x"
            size: 14
            color: Tokens.inkDim
        }
        MouseArea {
            id: dismissArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.dismiss()
        }
    }

    // The timeout, shrinking linearly. Paused under the pointer it waits
    // where it is; leaving restarts it from there over what was left.
    Rectangle {
        id: progressTrack
        visible: card.timeout > 0
        x: 24
        width: parent.width - 48
        y: parent.height - 7 - height
        height: 2
        radius: 1
        color: Tokens.fillLow
        Rectangle {
            id: progress
            height: 2
            radius: 1
            color: Tokens.faint
            property real remaining: 1
            width: Math.round(progressTrack.width * remaining)
        }
    }
    NumberAnimation {
        id: countdown
        target: progress
        property: "remaining"
        to: 0
        easing.type: Easing.Linear
    }
    function restartCountdown() {
        countdown.stop();
        const ms = card.timeLeft > 0 ? card.timeLeft : card.timeout;
        const from = card.timeout > 0 ? Math.min(1, ms / card.timeout) : 1;
        progress.remaining = from;
        countdown.from = from;
        countdown.duration = Math.max(1, ms);
        if (card.current && card.timeout > 0 && card.running) countdown.start();
    }
    // After the view's change has settled: `current` and `running` follow
    // the same record and may not have caught up when the serial moves.
    onSerialChanged: Qt.callLater(card.restartCountdown)
    onCurrentChanged: Qt.callLater(card.restartCountdown)
    onRunningChanged: if (!running && countdown.running) countdown.pause()
}
