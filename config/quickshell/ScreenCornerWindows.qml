import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Kit

// ScreenCornerWindows.qml - ScreenCorners.qml's windows: per screen, an
// Overlay layer surface along the top edge holding the two top corners and
// one along the bottom for the other two, each as tall as the radius. That
// file says why two strips; this one is only built where Wayland is.
Scope {
    id: root

    // ScreenCorners.qml, set as soon as this loads: on, shown, span, frames.
    property var corners: null

    component Strip: PanelWindow {
        id: strip
        required property var modelData
        // Not `top`: Strip is a PanelWindow, whose anchors have one.
        property bool atTop: true
        readonly property string edge: atTop ? "top" : "bottom"

        screen: modelData
        visible: root.corners?.on === true
        anchors {
            top: strip.atTop
            bottom: !strip.atTop
            left: true
            right: true
        }
        implicitHeight: Math.max(1, Math.ceil(root.corners?.span ?? 1))
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "screen-corners"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // An empty input region: every click goes through.
        mask: Region {}

        ScreenCorner {
            id: start
            anchors.left: parent.left
            y: strip.atTop ? 0 : parent.height - height
            corner: strip.atTop ? "topLeft" : "bottomLeft"
            radius: root.corners?.shown ?? 0
        }
        ScreenCorner {
            anchors.right: parent.right
            y: strip.atTop ? 0 : parent.height - height
            corner: strip.atTop ? "topRight" : "bottomRight"
            radius: root.corners?.shown ?? 0
        }
        Connections {
            target: start.Window.window
            function onFrameSwapped() { if (root.corners) root.corners.frames++; }
        }

        function inspect() {
            return {
                screen: strip.screen?.name ?? "",
                edge: strip.edge,
                visible: strip.visible,
                width: strip.width,
                height: strip.height,
                layer: strip.WlrLayershell.layer === WlrLayer.Overlay ? "overlay" : String(strip.WlrLayershell.layer),
                namespace: strip.WlrLayershell.namespace,
                keyboard: strip.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None ? "none" : String(strip.WlrLayershell.keyboardFocus),
                exclusive: strip.exclusionMode === ExclusionMode.Ignore ? "ignore" : String(strip.exclusionMode),
                mask: { width: strip.mask.width, height: strip.mask.height, item: strip.mask.item !== null }
            };
        }
    }

    Variants {
        id: screens
        model: Quickshell.screens
        delegate: Scope {
            id: pair
            required property var modelData
            readonly property var strips: [topStrip, bottomStrip]
            Strip {
                id: topStrip
                modelData: pair.modelData
                atTop: true
            }
            Strip {
                id: bottomStrip
                modelData: pair.modelData
                atTop: false
            }
        }
    }

    // Every strip's inspect(), screen by screen, top then bottom.
    function inspect() {
        const out = [];
        for (const pair of screens.instances)
            for (const s of pair.strips)
                out.push(s.inspect());
        return out;
    }
}
