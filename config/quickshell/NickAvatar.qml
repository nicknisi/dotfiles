// Nick's beef artwork, cropped into atlases. Portraits are 32x32:
// normal, blink, engineer, astronaut, wizard, explorer. Body frames are 32x52.
import QtQuick

Item {
    id: avatar

    property string page: ""
    property bool hovered: false
    property bool pressed: false
    property bool moving: false
    readonly property bool fullBody: moving || (hovered && page === "")
    readonly property int costume: {
        switch (page) {
        case "home": case "audio": return 2;
        case "net": case "bt": case "display": case "tailscale": return 3;
        case "theme": return 4;
        case "clock": return 5;
        default: return 0;
        }
    }

    implicitWidth: 30
    implicitHeight: 30
    transform: [
        Translate {
            y: avatar.hovered && avatar.page === "" ? -1 : 0
            Behavior on y { NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack } }
        },
        Scale {
            origin.x: avatar.width / 2
            origin.y: avatar.height
            xScale: avatar.pressed ? 1.08 : 1
            yScale: avatar.pressed ? 0.78 : 1
            Behavior on xScale { NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack } }
            Behavior on yScale { NumberAnimation { duration: Theme.unfold; easing.type: Easing.OutBack; easing.overshoot: 2 } }
        }
    ]

    SpriteSequence {
        objectName: "nickFace"
        anchors.centerIn: parent
        width: 32
        height: 32
        visible: !avatar.fullBody && avatar.costume === 0
        running: visible
        smooth: false
        interpolate: false
        Sprite {
            name: "idle"
            source: "assets/nick/portraits.png"
            frameWidth: 32; frameHeight: 32; frameCount: 1
            frameDuration: 6000
            to: ({ blink: 1 })
        }
        Sprite {
            name: "blink"
            source: "assets/nick/portraits.png"
            frameX: 32
            frameWidth: 32; frameHeight: 32; frameCount: 1
            frameDuration: 120
            to: ({ idle: 1 })
        }
    }

    Image {
        objectName: "nickCostume"
        anchors.centerIn: parent
        width: 32
        height: 32
        visible: !avatar.fullBody && avatar.costume !== 0
        source: "assets/nick/portraits.png"
        sourceClipRect: Qt.rect(avatar.costume * 32, 0, 32, 32)
        smooth: false
    }

    // A slow idle loop while hovered. Never play the blank source frame.
    AnimatedSprite {
        objectName: "nickGreeting"
        anchors.centerIn: parent
        width: 16
        height: 26
        visible: avatar.fullBody && !avatar.moving
        source: "assets/nick/greet.png"
        frameWidth: 32; frameHeight: 52; frameCount: 8
        frameRate: 4
        running: visible
        smooth: false
        interpolate: false
    }

    AnimatedSprite {
        objectName: "nickRunning"
        anchors.centerIn: parent
        width: 16
        height: 26
        visible: avatar.moving
        source: "assets/nick/run.png"
        frameWidth: 32; frameHeight: 52; frameCount: 2
        frameRate: 10
        running: visible
        smooth: false
        interpolate: false
    }
}
