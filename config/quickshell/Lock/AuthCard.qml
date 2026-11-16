import QtQuick
import qs
import qs.Kit

// AuthCard.qml - the lock screen's password card (PLAN M8, control-lock 4.4).
//
//   ┌──────────────────────────────────────┐   380 wide, radius 28, surface,
//   │ (N)  Nick Nisi                        │   hairline, the one shadow;
//   │      nicknisi on milhouse             │   padding 20, column gap 14
//   │ Password                              │   12 inkDim, gap 6
//   │ ┌──────────────────────────────┬──┐  │   field 44, radius 12, fillLow,
//   │ │ ••••••                        │→ │  │   1 px faint ring; Unlock 32 x 32,
//   │ └──────────────────────────────┴──┘  │   radius 10, accent, arrow onAccent
//   │      Enter unlocks · Esc clears       │   11 inkDim, centred
//   └──────────────────────────────────────┘   20+44+14+65+14+14+20 = 191
//
// It draws state and reports intents; it holds no secret. The buffer lives in
// lib/LockMachine.js (Lock/LockAuth.qml), and the field shows its length only
// (Kit/SecretField). Keys typed on the field come out as typed / erased /
// cleared / submitted / escaped; the lock surface routes keys typed while
// focus is elsewhere through keyIntent(). No paste (Kit/SecretField).
//
// While PAM checks (phase "authenticating") the field is read-only, the
// Unlock button sits at half opacity and the hint reads "Checking…". A failure
// shakes the card (shakeSerial bumps: Boot's 420 ms keyframes 0 / -9 / 8 / -6
// / 4 / -2 / 0, each step on cubic-bezier(0.36, 0.07, 0.19, 0.97); none under
// reduced motion) and turns the field's ring and the hint `bad` until the next
// keystroke. A second PAM question (a one-time code) shows as the field's
// label.
//
// (N) is Kit/FacePicture, 44: the profile picture (`faceSources`, lock.qml
// hands it Face.urls once the wallpaper has decoded) cropped to the circle,
// or the initial as the board draws it. It decodes off the UI thread and
// changes nothing else: no size, no focus, no timing.
//
// objectNames: lockField, lockUnlock.
//
// QtQuick only (qmltestrunner loads it).
Surface {
    id: card

    property string name: ""
    property string sub: ""
    property string initial: name.length > 0 ? name.charAt(0).toUpperCase() : "?"
    // The profile picture's file URLs, tried in order (Face.urls, through
    // lock.qml); empty: the initial, as the board draws it.
    property var faceSources: []
    // Characters in the buffer.
    property int length: 0
    // lib/LockMachine.js phase.
    property string phase: "idle"
    // The hint line (LockMachine.hint) and whether it is an error.
    property string hint: "Enter unlocks · Esc clears"
    property bool hintError: false
    // PAM's second question, "" for the plain password.
    property string prompt: ""
    // Bumps on every failure: the card shakes once per bump.
    property int shakeSerial: 0
    // Sandbox shots only (lock.qml): hold the shake still at this keyframe
    // (0..6), -1 to let it run. 1 is the board's 15 % frame, -9 px.
    property int shakeHold: -1

    readonly property bool checking: phase === "authenticating" || phase === "unlocking"
    readonly property alias field: field
    readonly property alias unlockButton: unlock
    readonly property alias hintText: hintText
    readonly property alias face: facePicture
    readonly property alias shakeAnimation: shake
    readonly property real shakeOffset: shift.x

    signal typed(string text)
    signal erased
    signal cleared
    signal submitted
    signal escaped

    // Boot board's shake keyframes (px) at 0 / 15 / 30 / 45 / 60 / 75 / 100 %.
    readonly property var shakeFrames: [0, -9, 8, -6, 4, -2, 0]
    readonly property var shakeTimes: [0, 0.15, 0.30, 0.45, 0.60, 0.75, 1]
    readonly property int shakeDuration: 420
    readonly property var shakeCurve: [0.36, 0.07, 0.19, 0.97, 1, 1]

    width: 380
    implicitHeight: column.implicitHeight + 40
    radius: 28
    transform: Translate {
        id: shift
    }

    Accessible.role: Accessible.Dialog
    Accessible.name: "Unlock " + card.name

    function focusField() {
        field.forceActiveFocus();
    }
    function keyIntent(key: int, text: string, modifiers: int): bool {
        const used = field.keyIntent(key, text, modifiers);
        if (used && !field.activeFocus) field.forceActiveFocus();
        return used;
    }

    onShakeSerialChanged: {
        if (shakeSerial <= 0 || shakeHold >= 0) return;
        if (Motion.reduced) {
            shake.stop();
            shift.x = 0;
            return;
        }
        shake.restart();
    }
    onShakeHoldChanged: {
        if (shakeHold < 0) {
            shift.x = 0;
            return;
        }
        shake.stop();
        shift.x = shakeFrames[Math.max(0, Math.min(shakeFrames.length - 1, shakeHold))];
    }

    SequentialAnimation {
        id: shake
        alwaysRunToEnd: false
        PropertyAction { target: shift; property: "x"; value: 0 }
        ShakeStep { index: 1 }
        ShakeStep { index: 2 }
        ShakeStep { index: 3 }
        ShakeStep { index: 4 }
        ShakeStep { index: 5 }
        ShakeStep { index: 6 }
    }
    component ShakeStep: NumberAnimation {
        required property int index
        target: shift
        property: "x"
        to: card.shakeFrames[index]
        duration: Math.round(card.shakeDuration * (card.shakeTimes[index] - card.shakeTimes[index - 1]))
        easing.type: Easing.BezierSpline
        easing.bezierCurve: card.shakeCurve
    }

    Column {
        id: column
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 14

        Row {
            id: identity
            spacing: 12
            FacePicture {
                id: facePicture
                size: 44
                fontSize: 16
                initial: card.initial
                sources: card.faceSources
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    width: Math.min(implicitWidth, column.width - 56)
                    text: card.name
                    color: Tokens.fg
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    font.family: "Adwaita Sans"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }
                Text {
                    width: Math.min(implicitWidth, column.width - 56)
                    text: card.sub
                    color: Tokens.inkDim
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                }
            }
        }

        Column {
            width: parent.width
            spacing: 6
            Text {
                id: label
                width: parent.width
                text: card.prompt !== "" ? card.prompt : "Password"
                color: Tokens.inkDim
                elide: Text.ElideRight
                textFormat: Text.PlainText
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
            SecretField {
                id: field
                objectName: "lockField"
                width: parent.width
                height: 44
                radius: 12
                padLeft: 14
                padRight: 6 + 32 + 8
                length: card.length
                readOnly: card.phase !== "idle" && card.phase !== "answering"
                failed: card.hintError && card.phase === "idle"
                placeholder: card.prompt !== "" ? card.prompt : "Enter your password"
                Accessible.name: label.text
                onTyped: text => card.typed(text)
                onErased: card.erased()
                onCleared: card.cleared()
                onSubmitted: card.submitted()
                onEscaped: card.escaped()

                LockButton {
                    id: unlock
                    objectName: "lockUnlock"
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    size: 32
                    radius: 10
                    iconName: "arrow"
                    iconSize: 16
                    fill: Tokens.accent
                    ink: Tokens.onAccent
                    label: "Unlock"
                    opacity: card.checking ? 0.5 : 1
                    onActivated: card.submitted()
                }
            }
        }

        Text {
            id: hintText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: card.hint
            color: card.hintError ? Tokens.bad : Tokens.inkDim
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 11
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }
    }
}
