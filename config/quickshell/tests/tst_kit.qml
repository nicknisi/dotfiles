import QtQuick
import QtTest
import qs
import qs.Kit
import "../Kit/IconPaths.js" as IconPaths

// The Kit leaf components. Runs under tests/kit.sh: real Kit/, Motion.qml and
// lib/Spring.js, a stub Tokens with hackerman's values and a stub Prefs.
//
// qmltestrunner renders with Qt's software backend, so pixel checks here cover
// geometry (stroke width, ring placement). RectangularShadow and the curve
// renderer only draw on the GPU; the gallery shot (tests/gallery/shell.qml)
// covers those.
TestCase {
    id: test
    name: "Kit"
    when: windowShown
    visible: true
    width: 760
    height: 560

    function init() {
        Prefs.motion = "spring";
        Prefs.reducedMotion = false;
    }

    function near(a, b, tolerance) {
        return Math.abs(a - b) <= tolerance;
    }
    // Rendered colour vs a token, within d per channel (0..255).
    function sameColor(pixel, expected, d) {
        const want = Qt.color(expected);
        return near(pixel.r * 255, want.r * 255, d) && near(pixel.g * 255, want.g * 255, d) && near(pixel.b * 255, want.b * 255, d);
    }
    function hex(c) {
        return "#" + [c.r, c.g, c.b].map(v => ("0" + Math.round(v * 255).toString(16)).slice(-2)).join("");
    }
    function find(item, test) {
        for (let i = 0; i < item.children.length; i++) {
            const c = item.children[i];
            if (test(c)) return c;
        }
        return null;
    }
    function ringOf(item) {
        return find(item, c => c.thickness !== undefined && c.gap !== undefined && c.show !== undefined);
    }

    // ---- Icon ----------------------------------------------------------------

    Rectangle {
        id: strokeStage
        x: 0; y: 0; width: 220; height: 100
        color: "black"
        Icon { id: plus14; x: 0; y: 0; name: "plus"; size: 14; color: "white" }
        Icon { id: plus16; x: 20; y: 0; name: "plus"; size: 16; color: "white" }
        Icon { id: plus96; x: 100; y: 0; name: "plus"; size: 96; color: "white" }
    }
    Icon { id: plainIcon; x: 700; y: 0; name: "wifi" }

    // Light summed down one pixel column: the stroke's width in px. The column
    // at 7/24 of the icon crosses only plus's horizontal bar (y = 12).
    function strokeAt(img, icon) {
        const x = Math.floor(icon.x + icon.size * 7 / 24);
        let sum = 0;
        for (let y = 0; y < icon.size; y++) {
            const c = img.pixel(x, y);
            sum += Math.max(c.r, c.g, c.b);
        }
        return sum;
    }

    function test_icon_stroke_width() {
        compare(IconPaths.STROKE, 1.8);
        compare(plus14.strokeWidth, 1.8 * 14 / 24);
        compare(plus16.strokeWidth, 1.8 * 16 / 24);
        waitForRendering(strokeStage);
        const img = grabImage(strokeStage);
        const at14 = strokeAt(img, plus14), at16 = strokeAt(img, plus16), at96 = strokeAt(img, plus96);
        verify(near(at14, 1.05, 0.2), "14 px icon draws a 1.05 px stroke, got " + at14);
        verify(near(at16, 1.2, 0.2), "16 px icon draws a 1.2 px stroke, got " + at16);
        // ShapePath.scale scaled only the coordinates: a scaled stroke would be 28.8
        verify(near(at96, 7.2, 0.4), "96 px icon draws a 7.2 px stroke, got " + at96);
    }

    Rectangle {
        id: allIcons
        x: 0; y: 100; width: 12 * 28; height: Math.ceil(IconPaths.NAMES.length / 12) * 28
        color: "black"
        Repeater {
            model: IconPaths.NAMES
            Icon {
                x: (index % 12) * 28 + 2
                y: Math.floor(index / 12) * 28 + 2
                name: modelData
                size: 24
                color: "white"
            }
        }
    }

    function test_every_icon_draws() {
        verify(IconPaths.NAMES.length >= 55, IconPaths.NAMES.length + " icons");
        waitForRendering(allIcons);
        const img = grabImage(allIcons);
        for (let i = 0; i < IconPaths.NAMES.length; i++) {
            const name = IconPaths.NAMES[i];
            verify(IconPaths.path(name).length > 0, name + " has a path");
            let ink = 0;
            const x0 = (i % 12) * 28, y0 = Math.floor(i / 12) * 28;
            for (let y = y0; y < y0 + 28; y++)
                for (let x = x0; x < x0 + 28; x++)
                    ink += img.pixel(x, y).r;
            verify(ink > 8, name + " drew " + ink.toFixed(1) + " px of ink");
        }
    }

    function test_icon_names() {
        compare(IconPaths.path("ts"), IconPaths.path("tailscale"));
        compare(IconPaths.path("exit"), IconPaths.path("logout"));
        compare(IconPaths.path("no-such-icon"), "");
        compare(IconPaths.has("constructor"), false);
        verify(IconPaths.isSolid("play") && IconPaths.isSolid("pause") && IconPaths.isSolid("prev") && IconPaths.isSolid("next"));
        verify(!IconPaths.isSolid("wifi"));
        compare(plainIcon.color, Tokens.fg, "ink defaults to fg");
        compare(plainIcon.implicitWidth, 16, "16 px unless sized");
    }

    // ---- Surface -------------------------------------------------------------

    Rectangle {
        id: surfaceStage
        x: 340; y: 0; width: 300; height: 140
        color: "#ff00ff"
        Surface { id: flat; x: 10; y: 10; width: 120; height: 40; floating: false }
        Surface { id: pill; x: 150; y: 10; width: 120; height: 38; radius: 19; floating: false }
        Surface { id: card; x: 10; y: 70; width: 120; height: 40; radius: 14; floating: false; color: Tokens.raised }
        Surface { id: floater; x: 150; y: 70; width: 120; height: 38; radius: 19 }
    }

    function test_surface_ring_inside_bounds() {
        waitForRendering(surfaceStage);
        const img = grabImage(surfaceStage);
        const at = (x, y) => img.pixel(x, y);
        // flat: 1 px ring on the innermost pixel of every edge, fill one in
        verify(sameColor(at(10, 30), Tokens.hairline, 2), "left edge " + hex(at(10, 30)));
        verify(sameColor(at(129, 30), Tokens.hairline, 2), "right edge " + hex(at(129, 30)));
        verify(sameColor(at(70, 10), Tokens.hairline, 2), "top edge " + hex(at(70, 10)));
        verify(sameColor(at(70, 49), Tokens.hairline, 2), "bottom edge " + hex(at(70, 49)));
        verify(sameColor(at(11, 30), Tokens.surface, 2), "fill inside the ring " + hex(at(11, 30)));
        verify(sameColor(at(70, 30), Tokens.surface, 2), "fill " + hex(at(70, 30)));
        // nothing outside the bounds
        verify(sameColor(at(9, 30), "#ff00ff", 2), "left of the edge " + hex(at(9, 30)));
        verify(sameColor(at(130, 30), "#ff00ff", 2), "right of the edge " + hex(at(130, 30)));
        verify(sameColor(at(70, 50), "#ff00ff", 2), "below the edge " + hex(at(70, 50)));
        // the rest pill: ring at its round ends (antialiased, so looser) and its top
        verify(sameColor(at(150, 29), Tokens.hairline, 16), "pill left " + hex(at(150, 29)));
        verify(sameColor(at(269, 29), Tokens.hairline, 16), "pill right " + hex(at(269, 29)));
        verify(sameColor(at(149, 29), "#ff00ff", 2), "nothing left of the pill " + hex(at(149, 29)));
        verify(sameColor(at(210, 10), Tokens.hairline, 3), "pill top " + hex(at(210, 10)));
        verify(sameColor(at(210, 29), Tokens.surface, 2), "pill fill " + hex(at(210, 29)));
        // cards: same ring, raised fill
        verify(sameColor(at(70, 90), Tokens.raised, 2), "card fill " + hex(at(70, 90)));
        verify(sameColor(at(10, 90), Tokens.hairline, 2), "card ring " + hex(at(10, 90)));
    }

    function test_surface_shadow() {
        const shadowOf = s => find(s, c => c.blur !== undefined && c.offset !== undefined);
        const s = shadowOf(floater);
        verify(s !== null);
        verify(s.visible, "floating surfaces cast the shadow");
        compare(s.offset.y, 10);
        compare(s.offset.x, 0);
        compare(s.blur, 28);
        compare(s.radius, 19);
        compare(s.color, Tokens.shadow);
        verify(s.z < 0, "drawn under the fill");
        verify(!shadowOf(card).visible, "cards are grounded");
    }

    // ---- type ----------------------------------------------------------------

    TextMetrics { id: clock500; font.family: "Monaspace Argon"; font.pixelSize: 13; font.weight: Font.Medium; text: "10:45" }
    TextMetrics { id: clock400; font.family: "Monaspace Argon"; font.pixelSize: 13; font.weight: Font.Normal; text: "10:45" }

    // PLAN risk 14: Monaspace Argon ships SemiWide and Wide faces under the same
    // family. Weight 500 must still pick the width-100 face.
    function test_mono_medium_is_not_wide() {
        verify(clock500.advanceWidth > 0);
        compare(clock500.advanceWidth, clock400.advanceWidth);
        // width 100 advances 0.62 em; SemiWide is 113 %, Wide 125 %
        verify(clock500.advanceWidth < 13 * 5 * 0.66, "10:45 at 13/500 is " + clock500.advanceWidth + " px");
    }

    // ---- Layer ---------------------------------------------------------------

    Layer { id: layer; x: 0; y: 300; width: 100; height: 40 }
    Component { id: currentLayer; Layer { current: true; width: 10; height: 10 } }

    function test_layer_enter_and_leave() {
        layer.current = false;
        tryCompare(layer, "visible", false, 1000);
        tryCompare(layer, "offset", -6, 1000);
        compare(layer.opacity, 0);
        compare(layer.enabled, false);
        compare(layer.Accessible.ignored, true);

        let start = Date.now();
        layer.current = true;
        compare(layer.visible, true, "visible at once");
        compare(layer.enabled, true);
        compare(layer.Accessible.ignored, false, "exposed at once");
        wait(40);
        compare(layer.opacity, 0, "still waiting out the 80 ms stagger");
        verify(layer.offset > -6 && layer.offset < 0, "already sliding: " + layer.offset);
        tryVerify(() => layer.opacity === 1 && layer.offset === 0, 1500);
        verify(Date.now() - start >= 80 + 245 - 20, "fade took " + (Date.now() - start) + " ms");

        start = Date.now();
        layer.current = false;
        compare(layer.enabled, false, "input off at once");
        compare(layer.Accessible.ignored, true, "hidden from accessibility at once");
        compare(layer.visible, true, "still fading");
        wait(40);
        verify(layer.opacity > 0 && layer.opacity < 1, "fading linearly: " + layer.opacity);
        tryCompare(layer, "visible", false, 1000);
        const gone = Date.now() - start;
        verify(gone >= 123 - 20 && gone < 400, "invisible after " + gone + " ms");
        compare(layer.opacity, 0);
        tryCompare(layer, "offset", -6, 1000);
    }

    function test_layer_reverses_mid_flight() {
        layer.current = true;
        tryVerify(() => layer.opacity === 1, 1500);
        layer.current = false;
        wait(50);
        const mid = layer.opacity;
        verify(mid > 0 && mid < 1);
        layer.current = true;
        compare(layer.visible, true);
        wait(20);
        verify(Math.abs(layer.opacity - mid) < 0.05, "holds its opacity through the stagger");
        tryVerify(() => layer.opacity === 1 && layer.offset === 0 && !layer.animating, 1500);
        layer.current = false;
        tryCompare(layer, "visible", false, 1000);
    }

    function test_layer_without_motion() {
        Prefs.motion = "off";
        layer.current = true;
        tryVerify(() => layer.opacity === 1 && layer.offset === 0, 50);
        layer.current = false;
        tryVerify(() => !layer.visible && layer.opacity === 0, 50);
        Prefs.motion = "spring";
        Prefs.reducedMotion = true;
        layer.current = true;
        tryVerify(() => layer.opacity === 1 && layer.offset === 0, 50);
        layer.current = false;
        tryVerify(() => !layer.visible, 50);
    }

    function test_layer_current_at_creation_shows_at_once() {
        const l = createTemporaryObject(currentLayer, test);
        compare(l.visible, true);
        compare(l.opacity, 1);
        compare(l.offset, 0);
        compare(l.animating, false);
    }

    // ---- Keycap and Chip -----------------------------------------------------

    Keycap { id: key; x: 0; y: 360; text: "Tab" }
    Keycap { id: smallKey; x: 60; y: 360; text: "Tab"; small: true }
    Chip { id: quiet; x: 120; y: 360; text: "All sources" }
    Chip { id: accentChip; x: 240; y: 360; text: "On"; tone: "accent" }
    Chip { id: strongChip; x: 320; y: 360; text: "12"; tone: "strong"; mono: true; fontSize: 11; padX: 6; padY: 1 }
    Chip { id: tintChip; x: 380; y: 360; text: "Tint"; tone: "tint"; icon: "sparkle" }

    function test_keycap() {
        compare(key.color, Tokens.fillHigh);
        compare(key.radius, 5);
        compare(smallKey.radius, 4);
        compare(key.padX, 6);
        compare(key.padY, 2);
        compare(key.implicitWidth - smallKey.implicitWidth, 2, "padding 6 vs 5 each side");
        compare(key.implicitHeight - smallKey.implicitHeight, 2, "padding 2 vs 1 each side");
        compare(key.ink, Tokens.fg);
        compare(key.Accessible.name, "Tab");
    }

    function test_chip_tones() {
        compare(quiet.color, Tokens.fillLow);
        compare(quiet.ink, Tokens.inkDim);
        compare(accentChip.color, Tokens.accent);
        compare(accentChip.ink, Tokens.onAccent);
        compare(strongChip.color, Tokens.fillHigh);
        compare(strongChip.ink, Tokens.fg);
        compare(tintChip.color, Tokens.accentTint);
        for (const chip of [quiet, accentChip, strongChip, tintChip])
            compare(chip.radius, chip.height / 2, "fully round");
        compare(quiet.padX, 10, "All sources: padding 4 10");
        compare(quiet.padY, 4);
        compare(quiet.fontSize, 12);
        verify(tintChip.implicitWidth > 14 + 6 + 2 * 10, "room for the icon, the gap and the label");
    }

    // ---- PillButton ----------------------------------------------------------

    PillButton { id: run; x: 0; y: 400; text: "Run"; hint: "↵"; onClicked: test.clicks++ }
    PillButton { id: cancel; x: 120; y: 400; text: "Cancel"; tone: "quiet"; padX: 16 }
    PillButton { id: actions; x: 240; y: 400; text: "Actions"; tone: "outline" }
    PillButton { id: auth; x: 360; y: 400; text: "Authenticate"; tone: "accent"; padX: 16 }
    PillButton { id: open; x: 520; y: 400; text: "Open"; size: 30 }
    property int clicks: 0

    function test_pill_tones() {
        compare(run.color, Tokens.fillHigh);
        compare(run.border.width, 0);
        compare(cancel.color, Tokens.fillLow);
        compare(cancel.border.width, 1);
        compare(cancel.border.color, Tokens.hairline);
        compare(actions.color, Qt.rgba(0, 0, 0, 0));
        compare(actions.border.width, 1);
        compare(auth.color, Tokens.accent);
        compare(auth.ink, Tokens.onAccent);
        compare(auth.fontWeight, Font.Medium);
        compare(run.height, 34);
        compare(run.radius, 17);
        compare(run.fontSize, 13);
        compare(open.height, 30);
        compare(open.radius, 15);
        compare(open.fontSize, 12);
    }

    function test_pill_click_and_keys() {
        clicks = 0;
        mouseClick(run);
        compare(clicks, 1);
        verify(!run.activeFocus, "a click does not take focus");
        verify(!ringOf(run).visible, "so no focus ring under the pointer");
        run.forceActiveFocus(Qt.TabFocusReason);
        verify(ringOf(run).visible, "keyboard focus shows the ring");
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_Return);
        compare(clicks, 3);
        run.focus = false;
        verify(!ringOf(run).visible);
    }

    function test_focus_ring_geometry() {
        const ring = ringOf(run);
        run.forceActiveFocus(Qt.TabFocusReason);
        compare(ring.border.width, 2);
        compare(ring.border.color, Tokens.accent);
        compare(ring.width, run.width + 8, "2 px gap and 2 px ring on each side");
        compare(ring.height, run.height + 8);
        compare(ring.x, -4);
        compare(ring.radius, run.radius + 4, "follows the corner");
        run.focus = false;
    }

    // ---- Switch --------------------------------------------------------------

    Switch { id: sw; x: 0; y: 450; label: "Accent from wallpaper"; onToggled: on => test.asked = on }
    property var asked: null

    function knobOf(s) {
        return find(s, c => c.width === 18 && c.height === 18);
    }

    function test_switch() {
        sw.checked = false;
        tryCompare(knobOf(sw), "x", 3, 1000);
        asked = null;
        mouseClick(sw);
        compare(asked, true, "asks to turn on");
        compare(sw.checked, false, "controlled: checked waits for the owner");
        sw.checked = true;
        tryCompare(knobOf(sw), "x", 40 - 18 - 3, 1000);
        sw.forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Space);
        compare(asked, false, "asks to turn off");
        compare(sw.Accessible.role, Accessible.Switch);
        compare(sw.Accessible.checked, true);
        sw.focus = false;
        compare(sw.width, 40);
        compare(sw.height, 24);
    }

    // ---- Slider --------------------------------------------------------------

    Slider { id: slider; x: 100; y: 450; width: 200; value: 0.5; onMoved: v => test.slid = v }
    property real slid: -1

    function test_slider() {
        slider.interactive = true;
        slider.value = 0.5;
        tryCompare(slider, "fillWidth", 100, 1000);
        mouseClick(slider, 50, slider.height / 2);
        verify(near(slid, 0.25, 0.01), "click asks for 0.25, got " + slid);
        compare(slider.value, 0.5, "controlled: value waits for the owner");
        slider.forceActiveFocus(Qt.TabFocusReason);
        keyClick(Qt.Key_Right);
        verify(near(slid, 0.55, 1e-9), "Right steps 5 %: " + slid);
        keyClick(Qt.Key_Down);
        verify(near(slid, 0.45, 1e-9), "Down steps back: " + slid);
        keyClick(Qt.Key_End);
        compare(slid, 1);
        keyClick(Qt.Key_Home);
        compare(slid, 0);
        slider.focus = false;
        mouseWheel(slider, 100, 12, 0, 120);
        verify(near(slid, 0.55, 1e-9), "a wheel notch steps 5 %: " + slid);
        // the fill follows the held pointer, not the service
        mousePress(slider, 150, 12);
        compare(slider.fillWidth, 150);
        mouseMove(slider, 30, 12);
        compare(slider.fillWidth, 30);
        mouseRelease(slider, 30, 12);
        tryCompare(slider, "fillWidth", 100, 1000);
        // read-only (the OSD)
        slider.interactive = false;
        slid = -1;
        mouseClick(slider, 20, 12);
        compare(slid, -1);
        slider.interactive = true;
    }

    // ---- ScreenCorner ----------------------------------------------------------

    // A 60 px white screen with the four 14 px corners, and a 28 px one.
    Rectangle {
        id: cornerStage
        x: 460; y: 490; width: 60; height: 60
        color: "white"
        ScreenCorner { id: cornerTL; corner: "topLeft"; radius: 14 }
        ScreenCorner { id: cornerTR; corner: "topRight"; radius: 14; x: 60 - 14 }
        ScreenCorner { id: cornerBL; corner: "bottomLeft"; radius: 14; y: 60 - 14 }
        ScreenCorner { id: cornerBR; corner: "bottomRight"; radius: 14; x: 60 - 14; y: 60 - 14 }
    }
    Rectangle {
        id: cornerStage28
        x: 530; y: 490; width: 40; height: 40
        color: "white"
        ScreenCorner { id: corner28; corner: "topLeft"; radius: 28 }
    }

    // Black, white or in between (the antialiased edge), by luminance.
    function shade(pixel) {
        const l = (pixel.r + pixel.g + pixel.b) / 3;
        return l < 0.1 ? "black" : l > 0.6 ? "white" : "edge";
    }

    function test_screen_corner() {
        compare(cornerTL.width, 14);
        compare(cornerTL.height, 14);
        compare(String(cornerTL.color), String(Tokens.bezel));
        const img = grabImage(cornerStage);
        // Each corner, mirrored: [x, y] in the top-left corner's frame. The
        // arc is the circle of radius 14 centred 14 in from both edges: it
        // leaves the edge row (y 0 to 1) between x 8.9 and 12, and crosses
        // the diagonal at 4.1. Pixels wholly on one side read black or white.
        const at = (c, x, y) => {
            const px = c.atRight ? 59 - x : x, py = c.atBottom ? 59 - y : y;
            return shade(img.pixel(px, py));
        };
        for (const c of [cornerTL, cornerTR, cornerBL, cornerBR]) {
            compare(at(c, 0, 0), "black", c.corner + ": the screen's corner is black");
            compare(at(c, 2, 2), "black", c.corner + ": inside the arc on the diagonal");
            compare(at(c, 8, 0), "black", c.corner + ": the edge row up to the arc");
            compare(at(c, 0, 8), "black", c.corner + ": the edge column up to the arc");
            compare(at(c, 5, 5), "white", c.corner + ": past the arc on the diagonal");
            compare(at(c, 12, 0), "white", c.corner + ": the edge row past the arc");
            compare(at(c, 0, 12), "white", c.corner + ": the edge column past the arc");
            compare(at(c, 20, 20), "white", c.corner + ": the screen beyond the corner is untouched");
        }
        // The edge pixel the arc crosses is antialiased, not stepped.
        compare(shade(img.pixel(10, 0)), "edge", "the arc's crossing on the edge row is antialiased");
        const big = grabImage(cornerStage28);
        compare(shade(big.pixel(6, 6)), "black", "radius 28: black on the diagonal at 6");
        compare(shade(big.pixel(10, 10)), "white", "radius 28: white on the diagonal at 10");
        compare(shade(big.pixel(19, 0)), "black", "radius 28: the edge row is black to x 19");
        compare(shade(big.pixel(25, 0)), "white", "radius 28: and white from 25");
        // Radius 0 draws nothing.
        corner28.radius = 0;
        verify(!corner28.visible);
        corner28.radius = 28;
    }

    // ---- ScreenCornerSet -----------------------------------------------------

    // A 64 x 48 "screen" under a full-size scrim (rgba(bg, .56) over white),
    // the set over both, as on the window switcher's and the power menu's
    // full-screen Overlay surfaces.
    Rectangle {
        id: setStage
        x: 600; y: 490; width: 64; height: 48
        color: "white"
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.04, 0.05, 0.09, 0.56)
        }
        ScreenCornerSet {
            id: cornerSet
            anchors.fill: parent
            radius: 14
        }
    }

    function test_screen_corner_set() {
        compare(cornerSet.width, 64);
        compare(cornerSet.height, 48);
        const grey = p => {
            const l = (p.r + p.g + p.b) / 3;
            return l > 0.35 && l < 0.6;
        };
        let img = grabImage(setStage);
        // The four corners of the item it fills are the bezel's black, over
        // the scrim; past the arc and in the middle, the scrim shows.
        for (const [x, y] of [[0, 0], [63, 0], [0, 47], [63, 47], [2, 2], [61, 2], [2, 45], [61, 45], [8, 0], [55, 47]])
            compare(shade(img.pixel(x, y)), "black", "black at " + x + "," + y);
        for (const [x, y] of [[5, 5], [58, 5], [5, 42], [58, 42], [12, 0], [32, 24], [0, 24], [63, 24]])
            verify(grey(img.pixel(x, y)), "the scrim at " + x + "," + y + ": " + img.pixel(x, y));
        // ScreenCorners.drawn is 0 with the corners off: nothing drawn.
        cornerSet.radius = 0;
        verify(!cornerSet.visible);
        img = grabImage(setStage);
        verify(grey(img.pixel(0, 0)), "no corners at radius 0: " + img.pixel(0, 0));
        // A radius change moves all four.
        cornerSet.radius = 20;
        img = grabImage(setStage);
        compare(shade(img.pixel(12, 0)), "black", "radius 20: the edge row is black at 12");
        compare(shade(img.pixel(51, 47)), "black", "radius 20: bottom right too");
        cornerSet.radius = 14;
        // skipEdge leaves out one edge's two corners (where a flush strip's
        // own wedges show, the scrim stopping short of them).
        for (const [edge, gone, kept] of [["top", [[0, 0], [63, 0]], [[0, 47], [63, 47]]],
                                          ["right", [[63, 0], [63, 47]], [[0, 0], [0, 47]]],
                                          ["bottom", [[0, 47], [63, 47]], [[0, 0], [63, 0]]],
                                          ["left", [[0, 0], [0, 47]], [[63, 0], [63, 47]]]]) {
            cornerSet.skipEdge = edge;
            img = grabImage(setStage);
            for (const [x, y] of gone)
                verify(grey(img.pixel(x, y)), "skipEdge " + edge + ": no corner at " + x + "," + y);
            for (const [x, y] of kept)
                compare(shade(img.pixel(x, y)), "black", "skipEdge " + edge + ": the corner at " + x + "," + y);
        }
        cornerSet.skipEdge = "";
    }

    // ---- ListRow -------------------------------------------------------------

    ListRow {
        id: row
        x: 0; y: 490; width: 440
        icon: "crop"
        title: "Screenshot region"
        subtitle: "capture shot region"
        keys: ["Print"]
        onClicked: test.rowClicks++
    }
    property int rowClicks: 0

    function tintOf(r) {
        return find(r, c => c.color !== undefined && hex(c.color) === hex(Tokens.accentTint) && c.radius === 10);
    }

    function test_list_row() {
        compare(row.height, 48);
        row.selected = false;
        tryCompare(tintOf(row), "opacity", 0, 1000);
        compare(row.tileColor, Tokens.fillLow);
        compare(row.iconColor, Tokens.fg);
        row.selected = true;
        compare(row.tileColor, Tokens.fillHigh);
        compare(row.iconColor, Tokens.accent);
        tryCompare(tintOf(row), "opacity", 1, 1000);
        rowClicks = 0;
        mouseClick(row);
        compare(rowClicks, 1);
        compare(row.Accessible.selected, true);
        compare(row.Accessible.name, "Screenshot region");
        row.selected = false;
    }
}
