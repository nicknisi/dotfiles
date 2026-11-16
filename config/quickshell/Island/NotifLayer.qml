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
// stripped; `bodyLines` below). "Open" (30 high, `fillHigh`) runs
// NotificationState.open: focus the sender, invoke its default action,
// dismiss. The x dismisses. Along the bottom (24 in, 7 up, 2 high) a `faint`
// bar on `fillLow` shrinks from full to empty over the timeout, linearly; a
// critical notification has none and stays until handled.
//
// The classic modes' cards (Hosts/NotifStack.qml, which replaced the old
// toasts in M10) ask for more than the board draws, as the toasts had it:
//   - `bodyLines` above 1: the body wraps to that many lines (the toasts
//     showed up to 6) and the card grows by the extra lines;
//   - `actionsShown`: every labelled action but "default" (Open and a click
//     run that one) as a pill (30 high, `fillLow`, 12, at most 120 wide,
//     eliding) in a row under the body, wrapping, each invoking its action
//     as the toast's buttons did; the card grows by the row.
// The tile, Open and the x stay where the board puts them, centred in the
// top 92, and the text column keeps its top. The island leaves both off and
// draws the board, 92 high.
//
// Data comes in as plain values (IslandView reads the server, or a fixture):
// { appName, summary, body, appIcon, image, critical, actions: [{ identifier,
// text, invoke() }] }. `timeout` is ms, 0 for none; `timeLeft` the ms its
// timer has to run each time it (re)starts; `running` is false while the
// card is paused under the pointer.
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
    // The sender's other actions as pills (the classic modes' cards).
    property bool actionsShown: false
    // How many lines the body may wrap to (the classic modes' cards).
    property int bodyLines: 1
    // The board's height: the tile, Open and the x are centred in it.
    readonly property int band: 92

    signal open
    signal dismiss
    // A non-default action ran (its pill was pressed).
    signal acted(string identifier)

    readonly property string appName: notification?.appName || "Notification"
    readonly property string summary: notification?.summary ?? ""
    readonly property string body: card.plain(notification?.body ?? "", card.bodyLines > 1)
    readonly property string iconSource: {
        const img = String(notification?.image ?? "");
        if (img !== "") return img;
        const icon = String(notification?.appIcon ?? "");
        if (icon === "") return "";
        return icon.startsWith("/") || icon.indexOf("://") > 0 ? icon : Quickshell.iconPath(icon, true);
    }
    readonly property bool agent: /^(claude|claude code|codex|pi|opencode)$/i.test(appName)
    // The non-default actions with a label, all of them (the row wraps).
    // Counted, not taken as an array, by the Repeater below (a fresh array
    // per read rebuilt it).
    readonly property var extraActions: {
        if (!card.actionsShown) return [];
        const list = notification?.actions ?? [];
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const a = list[i];
            if (a && a.identifier !== "default" && String(a.text ?? "") !== "") out.push(a);
        }
        return out;
    }
    readonly property alias actionsRow: actionsRow
    readonly property alias bodyText: bodyText
    readonly property alias progress: progress
    readonly property alias openButton: openButton
    readonly property alias dismissButton: dismissButton
    readonly property alias tile: tile

    // Notification bodies may carry a little markup (<b>, <i>, <a>) and
    // entities; the banner's one line is plain text. With `breaks` (a body
    // that wraps) a line break or <br> stays a break, and blank lines
    // collapse into it.
    function plain(s: string, breaks: bool): string {
        let t = String(s);
        if (breaks) t = t.replace(/<br\s*\/?>/gi, "\n");
        t = t.replace(/<[^>]*>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;|&apos;/g, "'").replace(/&amp;/g, "&");
        return (breaks ? t.replace(/[^\S\n]+/g, " ").replace(/ ?\n\s*/g, "\n") : t.replace(/\s+/g, " ")).trim();
    }

    // The body's lines past the first, and the actions' row, add to the 92.
    readonly property real bodyExtra: bodyText.visible && bodyText.lineCount > 1 ? bodyText.height - bodyText.height / bodyText.lineCount : 0
    width: 520
    height: Math.ceil(card.band + card.bodyExtra + (actionsRow.visible ? actionsRow.height + textColumn.spacing : 0))

    Accessible.role: Accessible.AlertMessage
    Accessible.name: appName + ": " + summary
    Accessible.description: body

    Rectangle {
        id: tile
        x: 14
        y: (card.band - height) / 2
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
        id: textColumn
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
            id: bodyText
            width: parent.width
            visible: text !== ""
            text: card.body
            color: Tokens.inkDim
            elide: Text.ElideRight
            // A long word (a URL, a path) breaks where the line fills.
            wrapMode: card.bodyLines > 1 ? Text.Wrap : Text.NoWrap
            maximumLineCount: Math.max(1, card.bodyLines)
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 12
        }
        // The sender's actions, under the body: 8 from it, 8 apart.
        Flow {
            id: actionsRow
            width: parent.width
            topPadding: 5
            spacing: 8
            visible: card.extraActions.length > 0
            Repeater {
                model: card.extraActions.length
                Rectangle {
                    id: actionPill
                    required property int index
                    readonly property var action: card.extraActions[index] ?? null
                    objectName: "notifAction-" + index
                    width: Math.min(120, Math.ceil(actionLabel.implicitWidth) + 28)
                    height: 30
                    radius: 15
                    color: actionArea.pressed ? Tokens.fillHigh : Tokens.fillLow
                    Accessible.role: Accessible.Button
                    Accessible.name: String(actionPill.action?.text ?? "")
                    Accessible.onPressAction: actionPill.run()
                    function run() {
                        const a = actionPill.action;
                        if (!a) return;
                        const id = String(a.identifier ?? "");
                        if (typeof a.invoke === "function") a.invoke();
                        card.acted(id);
                    }
                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, 120 - 28)
                        text: String(actionPill.action?.text ?? "")
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        color: Tokens.fg
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: actionArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: actionPill.run()
                    }
                }
            }
        }
    }

    Rectangle {
        id: openButton
        anchors.right: dismissButton.left
        anchors.rightMargin: 14
        y: (card.band - height) / 2
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
        y: (card.band - height) / 2
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
