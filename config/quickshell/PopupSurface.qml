import QtQuick

ShellSurface {
    id: surface
    required property bool shown
    required property string edge
    property real reveal: 0

    onShownChanged: {
        entrance.stop();
        reveal = 0;
        if (shown) entrance.restart();
    }

    // Move the drawing, never the popup anchor or its layout geometry.
    opacity: reveal
    transform: Translate {
        x: (surface.edge === "left" ? -6 : surface.edge === "right" ? 6 : 0) * (1 - surface.reveal)
        y: (surface.edge === "top" ? -6 : surface.edge === "bottom" ? 6 : 0) * (1 - surface.reveal)
    }
    NumberAnimation {
        id: entrance
        target: surface
        property: "reveal"
        from: 0; to: 1
        duration: Theme.base
        easing.type: Easing.OutCubic
    }
}
