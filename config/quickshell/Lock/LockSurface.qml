import QtQuick
import qs
import qs.Kit
import qs.Island
import "../lib/LockMachine.js" as LockMachine

// LockSurface.qml - what one screen shows while the session is locked (PLAN
// M8, control-lock 4.3, Lock board). lock.qml puts one in every
// WlSessionLockSurface, outputs added while locked included.
//
//   base `darker`, the wallpaper (PreserveAspectCrop) and the `scrim` over it
//   ┌───────────── ( 🔒 Locked ) ─────────────┐   capsule: top 8, centred
//   │                 10:45                    │   clock: bottom 120 above
//   │           Saturday, November 14          │   the card
//   │            ┌───────────────┐             │   card: top round(H/2) + 2
//   │            │   AuthCard    │             │
//   │            └───────────────┘             │
//   │ (MediaPill)                (StatusPill)  │   24 from the corners
//   └──────────────────────────────────────────┘
//
// No screenshot, ever: nothing of the session shows behind the lock, and a
// blurred grab would still leak the shape of what was on screen.
//
// `primary`: the full UI (card, pills, power menu). Other screens get the
// wallpaper, scrim, capsule and clock only. lock.qml picks the primary
// screen (the one with keyboard focus, else the cursor's, else eDP-1, else
// the first) and owns the one password buffer; every surface reports keys
// as intents (typed, erased, cleared, submitted, escaped) for it, so a key
// typed on any screen reaches the same buffer.
//
// Keys: the field holds focus; a key typed with focus elsewhere (a media
// button, nothing) goes to the field (control-lock 4.7). No paste: Ctrl+V
// and Shift+Insert do nothing (M8 review: a password left in the clipboard
// would unlock for anyone at the keyboard). Tab order: field,
// Unlock, media prev / play / next, Suspend, Power. Power opens the power
// menu (Suspend, Reboot, Shut down) in the capsule's place, as the island
// would: arrows move, Enter runs, Esc closes, a letter selects.
//
// Motion (control-lock 4.8): with `shown` the wallpaper and scrim fade in
// from `darker` over Motion.effects, the capsule springs 360 -> its width,
// and the clock, card and pills arrive on the enter rule (Kit/Layer). The
// host sets `shown` after the surface exists (lock.qml: once the lock is
// secure); a surface built with `shown` already true shows at once. Taking
// `shown` away runs the leave rule and springs the capsule back to 360, the
// island's rest width; lock.qml unlocks after that.
//
// That spring is a hand-over from the island's rest pill and back to it, so
// it runs only with `fromIsland` (lock.qml: the main shell is in island
// mode). In pill, full and rail there is no 360 pill there to spring from,
// so the capsule arrives at its own width on the enter rule's fade
// (Motion.effects on the spring, after Motion.stagger) and leaves on the
// leave rule's (Motion.exitFade, linear) instead (M10).
//
// Sleep (lock.qml's SleepWatch, `asleep`): a `night` layer over all of it
// fades in over 400 ms when logind announces sleep and out on wake. With
// `nightSnaps` (lock.qml: its watch has no reading yet) it follows `asleep`
// at once instead: a lock started during a sleep goes black the moment it
// learns, never fading in over its own lock-in motion. It only darkens: the
// card, the field, the keys and the unlock carry on under it.
//
// QtQuick only (qmltestrunner loads it).
Item {
    id: root

    property bool primary: true
    property url wallpaper: ""
    property date now: new Date()
    property string name: ""
    property string sub: ""
    // lib/LockMachine.js's record (lock.qml's), read for display only.
    property var auth: LockMachine.initial()
    // CcData.mediaCard() shape, or null.
    property var media: null
    // StatusPill's `status`.
    property var status: ({})
    property bool shown: false
    // The island's rest pill is where the capsule comes from and goes back to.
    property bool fromIsland: true
    // Sandbox shots only (lock.qml): hold the shake at this keyframe.
    property int shakeHold: -1
    // The profile picture's file URLs for the card (lock.qml: Face.urls once
    // the wallpaper has decoded); only the primary screen's card loads them.
    property var faceSources: []
    // The machine is about to sleep (lock.qml's SleepWatch): everything this
    // surface draws fades to `night` over the sleep fade's 400 ms, and back
    // up on wake. Darkening only: nothing else reads it.
    property bool asleep: false
    // `night` jumps to `asleep` with no fade (see the header).
    property bool nightSnaps: false
    readonly property int sleepFadeMs: Motion.reduced ? 0 : 400
    property bool powerOpen: false
    // The wallpaper has faded in (set by the first `shown`).
    property bool wallIn: false

    // This screen's window has keyboard focus.
    readonly property bool windowActive: Window.active
    readonly property int cardTop: Math.round(height / 2) + 2
    readonly property alias card: card
    readonly property alias mediaPill: mediaPill
    readonly property alias statusPill: statusPill
    readonly property alias capsule: capsule
    readonly property alias powerMenu: powerMenu
    readonly property alias clock: clockText
    readonly property alias wall: wall
    readonly property alias night: night
    // The wallpaper has decoded (or failed, or has no file): lock.qml lets
    // the profile picture load after it, so the two never queue behind each
    // other in the image reader.
    readonly property bool wallSettled: wallImage.status !== Image.Loading
    readonly property real capsuleRestWidth: Math.ceil(lockedRow.implicitWidth + 32)

    signal typed(string text)
    signal erased
    signal cleared
    signal submitted
    signal escaped
    // previous | toggle | next
    signal mediaAction(string name)
    signal suspendRequested
    // suspend | reboot | shutdown, from the power menu
    signal powerRun(string id)

    focus: true

    onShownChanged: {
        if (shown) wallIn = true;
        if (root.fromIsland) return;
        if (shown) {
            capsuleOut.stop();
            capsuleIn.restart();
        } else {
            capsuleIn.stop();
            capsuleOut.restart();
        }
    }
    onFromIslandChanged: {
        capsuleIn.stop();
        capsuleOut.stop();
        capsule.opacity = root.fromIsland || root.shown ? 1 : 0;
    }
    Component.onCompleted: {
        if (shown) wallIn = true;
        capsule.opacity = root.fromIsland || root.shown ? 1 : 0;
    }
    // The capsule's own fade outside island mode: the enter rule's (after the
    // stagger, Motion.effects on the spring) and the leave rule's.
    SequentialAnimation {
        id: capsuleIn
        PauseAnimation {
            duration: Motion.stagger
        }
        NumberAnimation {
            target: capsule
            property: "opacity"
            to: 1
            duration: Motion.effects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.spring
        }
    }
    NumberAnimation {
        id: capsuleOut
        target: capsule
        property: "opacity"
        to: 0
        duration: Motion.exitFade
    }

    // The card moving off this screen: the keys stay on the surface, which
    // still routes them to the one buffer.
    onPrimaryChanged: {
        if (!primary) {
            root.powerOpen = false;
            root.forceActiveFocus();
        } else {
            root.focusField();
        }
    }
    onPowerOpenChanged: powerOpen ? powerMenu.forceActiveFocus() : root.focusField()
    // After a failure the field takes focus back (control-lock 4.6).
    readonly property string phase: String(root.auth?.phase ?? "idle")
    onPhaseChanged: if (phase === "idle" || phase === "answering") root.focusField()

    function focusField() {
        if (root.primary && !root.powerOpen) card.focusField();
        else root.forceActiveFocus();
    }

    Keys.onPressed: event => {
        if (root.powerOpen) return;
        if (card.keyIntent(event.key, event.text, event.modifiers))
            event.accepted = true;
    }

    // ---- the picture ----------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: Tokens.darker
    }

    Item {
        id: wall
        anchors.fill: parent
        // In once, and kept on the way out: the desktop the unlock reveals
        // has the same wallpaper behind it.
        opacity: root.wallIn ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.effects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spring
            }
        }
        Image {
            id: wallImage
            anchors.fill: parent
            source: root.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            sourceSize.width: Math.max(1, root.width)
            sourceSize.height: Math.max(1, root.height)
        }
        Rectangle {
            anchors.fill: parent
            color: Tokens.scrim
        }
    }

    // A press anywhere puts the keyboard back on the field.
    MouseArea {
        anchors.fill: parent
        onPressed: root.powerOpen ? (root.powerOpen = false) : root.focusField()
    }

    // ---- clock --------------------------------------------------------------------

    Layer {
        id: clockLayer
        current: root.shown
        width: root.width
        height: clockColumn.implicitHeight
        // 120 above the card; on a short screen (a 1080p output at scale 2
        // is 540 logical) no higher than 24 under the capsule.
        y: Math.max(8 + 38 + 24, root.cardTop - 120 - height)
        Column {
            id: clockColumn
            width: parent.width
            spacing: 6
            Text {
                id: clockText
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.now, "HH:mm")
                color: Tokens.fg
                textFormat: Text.PlainText
                font.family: "Monaspace Argon"
                font.weight: Font.Medium
                font.pixelSize: 128
                font.letterSpacing: -2.56
                // The board's line box: 136 high whatever the font's own
                // metrics say (FixedHeight alone measured 147 here).
                height: 136
                lineHeightMode: Text.FixedHeight
                lineHeight: 136
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                id: dateText
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.now, "dddd, MMMM d")
                color: Tokens.fg
                textFormat: Text.PlainText
                font.family: "Adwaita Sans"
                font.pixelSize: 18
            }
        }
    }

    // ---- the card and the pills (primary only), in Tab order --------------------

    Layer {
        id: cardLayer
        current: root.shown && root.primary
        x: Math.round((root.width - card.width) / 2)
        y: root.cardTop
        width: card.width
        height: card.height
        AuthCard {
            id: card
            name: root.name
            sub: root.sub
            length: LockMachine.bullets(root.auth)
            phase: root.phase
            hint: LockMachine.hint(root.auth ?? LockMachine.initial())
            hintError: root.auth?.error === true && String(root.auth?.message ?? "") !== ""
            prompt: String(root.auth?.prompt ?? "")
            shakeSerial: Number(root.auth?.shake ?? 0)
            shakeHold: root.shakeHold
            faceSources: root.primary ? root.faceSources : []
            onTyped: text => root.typed(text)
            onErased: root.erased()
            onCleared: root.cleared()
            onSubmitted: root.submitted()
            onEscaped: root.escaped()
        }
    }

    Layer {
        id: mediaLayer
        current: root.shown && root.primary && mediaPill.present
        x: 24
        y: root.height - 24 - height
        width: mediaPill.width
        height: mediaPill.height
        MediaPill {
            id: mediaPill
            media: root.media
            animate: mediaLayer.current
            onPrevious: root.mediaAction("previous")
            onToggle: root.mediaAction("toggle")
            onNext: root.mediaAction("next")
        }
    }

    Layer {
        id: statusLayer
        current: root.shown && root.primary
        x: root.width - 24 - width
        y: root.height - 24 - height
        width: statusPill.width
        height: statusPill.height
        StatusPill {
            id: statusPill
            status: root.status
            onSuspend: root.suspendRequested()
            onPower: root.powerOpen = true
        }
    }

    // ---- the capsule, and the power menu in its place --------------------------------

    Surface {
        id: capsule
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        width: root.powerOpen ? powerMenu.width : root.shown || !root.fromIsland ? root.capsuleRestWidth : 360
        height: root.powerOpen ? 156 : 38
        // Without the island it fades in place (see the header): set at
        // creation, then capsuleIn and capsuleOut.
        opacity: 1
        radius: root.powerOpen ? 28 : 19
        Behavior on width {
            NumberAnimation {
                duration: Motion.spatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spring
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: Motion.spatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spring
            }
        }
        Behavior on radius {
            NumberAnimation {
                duration: Motion.spatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spring
            }
        }

        Item {
            anchors.fill: parent
            clip: true

            Layer {
                current: !root.powerOpen
                anchors.horizontalCenter: parent.horizontalCenter
                width: lockedRow.implicitWidth
                height: 38
                Row {
                    id: lockedRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "lock"
                        size: 14
                        color: Tokens.fg
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Locked"
                        color: Tokens.inkDim
                        textFormat: Text.PlainText
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                    }
                }
                Accessible.role: Accessible.StaticText
                Accessible.name: "Locked"
            }

            PowerLayer {
                id: powerMenu
                current: root.powerOpen && root.primary
                anchors.horizontalCenter: parent.horizontalCenter
                // 32 + 3 * 108 + 2 * 8 = 372: centred on a 1920 wide screen
                // the capsule sits at x 774, and at scale 1.5 its edges and
                // every item's land on whole device pixels, so the 1 px rings
                // stay sharp (M8 review: 107.2 left them at x 775.2).
                itemWidth: 108
                items: [
                    { id: "suspend", label: "Suspend", key: "S", icon: "moon" },
                    { id: "reboot", label: "Reboot", key: "R", icon: "restart" },
                    { id: "shutdown", label: "Shut down", key: "P", icon: "power" }
                ]
                onRun: id => {
                    root.powerOpen = false;
                    root.powerRun(id);
                }
                onCancel: root.powerOpen = false
            }
        }
    }

    // ---- the sleep fade --------------------------------------------------------------
    // Over everything above, input untouched (a Rectangle takes no events).
    // A surface built with `asleep` already true starts dark (no Behavior
    // runs on the first value); one that learns it later while `nightSnaps`
    // (lock.qml: before its watch's first reading) jumps to it.
    Rectangle {
        id: night
        objectName: "lockNight"
        anchors.fill: parent
        color: Tokens.night
        opacity: root.asleep ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            enabled: !root.nightSnaps
            NumberAnimation {
                duration: root.sleepFadeMs
                easing.type: Easing.InOutSine
            }
        }
    }
}
