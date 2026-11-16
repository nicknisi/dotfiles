import Quickshell
import Quickshell.Io
import QtQuick
import qs.Kit

// ScreenCorners.qml - rounded screen corners: the four corner wedges of every
// screen painted in Tokens.bezel (black), as if the panel were physically
// rounded (Kit/ScreenCorner.qml draws one). Prefs.screenCorners turns them on
// (the default) and off; Prefs.screenCornerRadius is their radius, 14 by
// default (Prefs says why). The control center's Display sheet, the
// launcher's Bar Preferences and `qs ipc call corners ...` change them.
//
// Each screen gets two Overlay layer surfaces, a strip along the top edge
// holding the two top corners and one along the bottom for the other two,
// each as tall as the radius. Overlay is drawn above fullscreen windows. They
// take no input (an empty mask), hold no exclusive zone (ExclusionMode.Ignore
// sits them on the screen's own edges whatever reserves space) and never take
// the keyboard. Nothing in them animates at rest: they render when they map
// and when the radius changes, and not again (`frames` counts every frame
// they swap, for the sandbox check).
//
// Hyprland stacks a layer's surfaces in map order, so a full-screen Overlay
// surface that maps later sits above the strips. The ones that fill with the
// scrim would grey the corners (keys review): the window switcher, the polkit
// window and a bar's power menu. Each paints its own over its scrim
// (Kit/ScreenCornerSet at `drawn`, handed this from shell.qml), and
// tests/corner-cover.py keeps every scrim surface doing so. The session lock
// covers the corners with everything else.
//
// Why two strips and not one full-screen surface: measured in the sandbox at
// 2880x1800, a full-screen transparent surface cost the qs process 65 MB of
// GPU memory (two colour buffers and a depth-stencil buffer at full size) and
// added about 12% to the compositor's render time under full-screen damage
// (a video, a scroll), since Hyprland blends every damaged pixel of it. The
// two strips cost 27 MB in all and no measurable render time; four corner
// surfaces cost 47 MB (about 11 MB of fixed overhead per window).
//
// A radius change animates once over Motion.spatial (snaps under reduced
// motion). The strips take the larger of the two radii while it runs and
// settle on the new one when it ends, so a window resizes at most twice per
// change and never per frame.
//
//   qs ipc call corners on | off | toggle
//   qs ipc call corners radius N   N a whole number from 4 to 48
//   qs ipc call corners inspect    JSON: the prefs, the radius drawn, the
//                                  strips per screen, the frames swapped
Scope {
    id: root

    // Build the windows (ScreenCornerWindows.qml). tests/shortcuts.sh drives
    // the IPC offscreen, where a PanelWindow has no backend.
    property bool windows: true
    readonly property bool on: Prefs.screenCorners
    readonly property int radius: Prefs.screenCornerRadius
    // The radius drawn, and the strips' height while a change runs.
    property real shown: Prefs.screenCornerRadius
    property real span: Prefs.screenCornerRadius
    property int frames: 0
    // What a full-screen Overlay surface with a scrim paints in its own
    // corners (Kit/ScreenCornerSet): Hyprland stacks a layer's surfaces in
    // map order, so the window switcher, the polkit window and a bar's power
    // menu, mapped after the strips, would grey them. 0 while they are off.
    readonly property real drawn: root.on ? root.shown : 0

    onRadiusChanged: {
        motion.stop();
        // The stored radius arriving at start (Prefs.loaded), reduced motion
        // and hidden corners snap.
        if (Motion.spatial <= 0 || !root.on || !Prefs.loaded) {
            root.shown = root.radius;
            root.span = root.radius;
            return;
        }
        root.span = Math.max(root.shown, root.radius);
        motion.from = root.shown;
        motion.to = root.radius;
        motion.start();
    }
    NumberAnimation {
        id: motion
        target: root
        property: "shown"
        duration: Motion.spatial
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.spring
        onStopped: root.span = root.shown
    }

    // The windows, from their own file: a PanelWindow type needs a Wayland
    // backend to compile, and tests/shortcuts.sh runs this offscreen.
    LazyLoader {
        id: windowsLoader
        active: root.windows
        source: root.windows ? "ScreenCornerWindows.qml" : ""
        onItemChanged: if (item) item.corners = root
    }

    function inspect(): string {
        const strips = windowsLoader.item?.inspect() ?? [];
        return JSON.stringify({
            on: root.on,
            radius: root.radius,
            shown: root.shown,
            animating: motion.running,
            range: Prefs.screenCornerRadii,
            strips: strips,
            frames: root.frames
        });
    }

    // The IPC's verbs, for tests/shortcuts.sh (offscreen, no IPC socket).
    readonly property alias ipc: handler
    IpcHandler {
        id: handler
        target: "corners"

        function on(): string {
            Prefs.setScreenCorners(true);
            return "ok";
        }
        function off(): string {
            Prefs.setScreenCorners(false);
            return "ok";
        }
        function toggle(): string {
            Prefs.toggleScreenCorners();
            return "ok: " + (Prefs.screenCorners ? "on" : "off");
        }
        function radius(value: string): string {
            const text = String(value).trim();
            const r = /^\d+$/.test(text) ? Number(text) : NaN;
            if (!Prefs.setScreenCornerRadius(r))
                return "error: the radius is a whole number from " + Prefs.screenCornerRadii[0] + " to " + Prefs.screenCornerRadii[1] + " (logical px), not \"" + text + "\"";
            return "ok";
        }
        function inspect(): string {
            return root.inspect();
        }
    }
}
