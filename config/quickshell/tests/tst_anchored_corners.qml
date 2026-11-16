import QtQuick
import QtTest
import qs
import qs.Hosts
import "../lib/Anchored.js" as Anchored
import "../BarGeometry.js" as BarGeometry

// The classic bars' anchored panels (PLAN M4, island-modes 12.4): where
// lib/Anchored.js puts a panel for every mode, edge and module position, its
// round corners and hairline sides ("round only corners that touch neither
// the bar nor a screen edge"; the hairline only on sides that touch
// neither), its motion, the free panel the launcher and the power menu share,
// the menu table, the edge rules (BarGeometry.js), and Hosts/AnchoredFrame
// drawing those corners and sides in pixels, clipped at the seam.
TestCase {
    id: test
    name: "AnchoredCorners"
    when: windowShown
    visible: true
    width: 480
    height: 320

    readonly property var screen: ({ width: 1920, height: 1200 })
    // The bar's surface on a 1920 x 1200 screen, per mode and edge.
    readonly property var bars: ({
            "pill/top": { x: 701, y: 8, width: 518, height: 40 },
            "pill/bottom": { x: 701, y: 1152, width: 518, height: 40 },
            "pill/left": { x: 8, y: 341, width: 40, height: 518 },
            "pill/right": { x: 1872, y: 341, width: 40, height: 518 },
            "full/top": { x: 0, y: 0, width: 1920, height: 40 },
            "full/bottom": { x: 0, y: 1160, width: 1920, height: 40 },
            "rail/left": { x: 0, y: 0, width: 40, height: 1200 },
            "rail/right": { x: 1880, y: 0, width: 40, height: 1200 }
        })
    readonly property var sizes: [{ width: 760, height: 560 }, { width: 400, height: 368 }]

    function side(edge) {
        return edge === "left" || edge === "right";
    }
    // A 52 x 32 module 8 from the bar's start, in its middle, or 8 from its end.
    function moduleAt(bar, edge, where) {
        const v = side(edge);
        const along = v ? bar.height : bar.width;
        const start = v ? bar.y : bar.x;
        const a = where === "start" ? start + 8 : where === "middle" ? start + (along - 52) / 2 : start + along - 8 - 52;
        return v ? { x: bar.x + 4, y: a, width: 32, height: 52 } : { x: a, y: bar.y + 4, width: 52, height: 32 };
    }

    function test_place_data() {
        const cases = [];
        for (const key in bars)
            for (const where of ["start", "middle", "end"])
                for (const align of ["start", "center", "end"])
                    for (let s = 0; s < sizes.length; s++)
                        cases.push({ tag: key + " " + where + "/" + align + " " + sizes[s].width, mode: key.split("/")[0], edge: key.split("/")[1], where, align, size: sizes[s] });
        return cases;
    }
    function test_place(data) {
        const bar = bars[data.mode + "/" + data.edge];
        const module = moduleAt(bar, data.edge, data.where);
        const p = Anchored.place({ mode: data.mode, edge: data.edge, screen, bar, module, align: data.align, size: data.size });
        const flush = data.mode !== "pill";
        const v = side(data.edge);
        compare([p.width, p.height], [data.size.width, data.size.height], "the content's size");

        // Across: 8 from the pill, flush against a strip.
        const gap = flush ? 0 : 8;
        compare(p.gap, gap);
        if (data.edge === "top") compare(p.y, bar.y + bar.height + gap);
        if (data.edge === "bottom") compare(p.y + p.height, bar.y - gap);
        if (data.edge === "left") compare(p.x, bar.x + bar.width + gap);
        if (data.edge === "right") compare(p.x + p.width, bar.x - gap);

        // Along: aligned to the module, then kept on the screen (8 in for the
        // pill; a strip's panel may touch the screen edge, and does within 16).
        const room = v ? screen.height : screen.width;
        const size = v ? p.height : p.width;
        const mStart = v ? module.y : module.x;
        const mSize = v ? module.height : module.width;
        let want = data.align === "start" ? mStart : data.align === "center" ? Math.round(mStart + (mSize - size) / 2) : mStart + mSize - size;
        if (flush) {
            want = Math.max(0, Math.min(room - size, want));
            if (want < 16) want = 0;
            if (room - (want + size) < 16) want = room - size;
        } else {
            want = Math.max(8, Math.min(room - 8 - size, want));
        }
        compare(v ? p.y : p.x, want, "aligned to the module, clamped");
        verify(p.x >= 0 && p.y >= 0 && p.x + p.width <= screen.width && p.y + p.height <= screen.height, "on the screen");

        // Corners and hairlines: attached sides are the seam and the screen's edges.
        const attached = {
            top: (flush && data.edge === "top") || p.y <= 0.5,
            bottom: (flush && data.edge === "bottom") || p.y + p.height >= screen.height - 0.5,
            left: (flush && data.edge === "left") || p.x <= 0.5,
            right: (flush && data.edge === "right") || p.x + p.width >= screen.width - 0.5
        };
        const round = (a, b) => !(attached[a] || attached[b]) ? 28 : 0;
        compare(p.radii, { topLeft: round("top", "left"), topRight: round("top", "right"), bottomRight: round("bottom", "right"), bottomLeft: round("bottom", "left") }, "round only corners touching neither the bar nor a screen edge");
        compare(p.hairline, { top: !attached.top, right: !attached.right, bottom: !attached.bottom, left: !attached.left }, "hairline only on free sides");
        compare(p.seam, flush ? data.edge : "", "the seam is the side against the strip");
        if (!flush) {
            compare(p.radii, { topLeft: 28, topRight: 28, bottomRight: 28, bottomLeft: 28 }, "the pill's panel: all four round");
            compare(p.hairline, { top: true, right: true, bottom: true, left: true }, "and the hairline all round");
        }
        // The stretch of the strip it covers.
        if (flush) {
            compare(p.seamFrom, v ? p.y : p.x);
            compare(p.seamTo, (v ? p.y : p.x) + size);
        }

        // Motion: grow (pill), drop (full), slide (rail).
        compare(p.motion, flush ? (v ? "slide" : "drop") : "grow");
        if (p.motion === "drop") {
            compare([p.from.x, p.from.width, p.from.height], [p.x, p.width, p.height], "drops as one piece");
            compare(data.edge === "top" ? p.from.y + p.from.height : p.from.y, data.edge === "top" ? bar.y + bar.height : bar.y, "from behind the strip");
        } else if (p.motion === "slide") {
            compare([p.from.y, p.from.width, p.from.height], [p.y, p.width, p.height], "slides as one piece");
            compare(data.edge === "left" ? p.from.x + p.from.width : p.from.x, data.edge === "left" ? bar.x + bar.width : bar.x, "from behind the rail");
        } else {
            compare([p.from.width, p.from.height], [Math.min(p.width, module.width), Math.min(p.height, module.height)], "grows from the module's size");
            const o = p.origin;
            const pinX = o.indexOf("Left") > 0 || o === "left" ? p.from.x === p.x : o.indexOf("Right") > 0 || o === "right" ? p.from.x + p.from.width === p.x + p.width : Math.abs(p.from.x + p.from.width / 2 - (p.x + p.width / 2)) < 0.01;
            const pinY = o.indexOf("top") === 0 ? p.from.y === p.y : o.indexOf("bottom") === 0 ? p.from.y + p.from.height === p.y + p.height : Math.abs(p.from.y + p.from.height / 2 - (p.y + p.height / 2)) < 0.01;
            verify(pinX && pinY, "pinned at the " + o + " corner");
            const near = { top: "top", bottom: "bottom", left: "Left", right: "Right" }[data.edge];
            verify(o.indexOf(near) >= 0 || o === data.edge, "the corner on the bar's side: " + o);
        }
    }

    // The board's thumbnails (island-modes 12.2 and 12.4), at real size.
    function test_board_data() {
        return [
            { tag: "pill, status module", mode: "pill", edge: "top", where: "end", align: "end", radii: [28, 28, 28, 28], hairline: [true, true, true, true] },
            { tag: "full, right module", mode: "full", edge: "top", where: "end", align: "end", radii: [0, 0, 0, 28], hairline: [false, false, true, true] },
            { tag: "full, centre module", mode: "full", edge: "top", where: "middle", align: "center", radii: [0, 0, 28, 28], hairline: [false, true, true, true] },
            { tag: "rail, bottom module", mode: "rail", edge: "left", where: "end", align: "end", radii: [0, 28, 0, 0], hairline: [true, true, false, false] }
        ];
    }
    function test_board(data) {
        const bar = bars[data.mode + "/" + data.edge];
        const p = Anchored.place({ mode: data.mode, edge: data.edge, screen, bar, module: moduleAt(bar, data.edge, data.where), align: data.align, size: { width: 760, height: 560 } });
        compare([p.radii.topLeft, p.radii.topRight, p.radii.bottomRight, p.radii.bottomLeft], data.radii, "radii top-left, top-right, bottom-right, bottom-left");
        compare([p.hairline.top, p.hairline.right, p.hairline.bottom, p.hairline.left], data.hairline, "hairline top, right, bottom, left");
        if (data.mode === "full" && data.where === "end") compare(p.x + p.width, 1920, "the right module's panel reaches the screen's edge");
        if (data.mode === "rail") compare(p.y + p.height, 1200, "the bottom module's panel reaches the screen's bottom");
        if (data.mode === "pill") compare(p.y, 56, "8 under the pill");
    }

    // The launcher's free panel (PLAN 1.6): top centre, 8 under the reserved
    // zone when the bar is on the top (56 for the pill, 40 for the strips),
    // else 8 down.
    function test_free_data() {
        return [
            { tag: "pill/top", mode: "pill", edge: "top", y: 64 },
            { tag: "full/top", mode: "full", edge: "top", y: 48 },
            { tag: "pill/bottom", mode: "pill", edge: "bottom", y: 8 },
            { tag: "full/bottom", mode: "full", edge: "bottom", y: 8 },
            { tag: "rail/left", mode: "rail", edge: "left", y: 8 },
            { tag: "pill/right", mode: "pill", edge: "right", y: 8 },
            { tag: "island", mode: "island", edge: "top", y: 8 }
        ];
    }
    function test_free(data) {
        // Theme.barExtent: the bar's thickness and its inset on both sides.
        const reserve = data.mode === "island" ? 46 : 40 + 2 * BarGeometry.inset(data.mode);
        const f = Anchored.free({ mode: data.mode, edge: data.edge, screen, reserve, size: { width: 760, height: 472 } });
        compare(f.y, data.y);
        compare(f.x, (1920 - 760) / 2, "centred");
        compare(f.radii, { topLeft: 28, topRight: 28, bottomRight: 28, bottomLeft: 28 }, "never docked: all round");
        compare(f.seam, "");
        const tall = Anchored.free({ mode: data.mode, edge: data.edge, screen, reserve, size: { width: 3000, height: 3000 } });
        verify(tall.width <= 1904 && tall.y + tall.height <= 1200 - 16, "kept on the screen");
    }

    // At scale 1.5 every panel lands on whole device pixels (PLAN risk 13),
    // whatever the module's edge: the cc under a status module ending at
    // 1235 (device 1852.5) moved to 475.33, not 475, and a strip's panel
    // still touches the screen edge it was clamped to.
    function onDevice(v, dpr) {
        return Math.abs(v * dpr - Math.round(v * dpr)) < 0.001;
    }
    function test_devicePixels_data() {
        const cases = [];
        for (const key in bars)
            for (const where of ["start", "middle", "end"])
                for (const align of ["start", "center", "end"])
                    cases.push({ tag: key + " " + where + "/" + align, mode: key.split("/")[0], edge: key.split("/")[1], where, align });
        return cases;
    }
    function test_devicePixels(data) {
        const dpr = 1.5;
        const bar = bars[data.mode + "/" + data.edge];
        const m = moduleAt(bar, data.edge, data.where);
        // A module whose far edge sits on a half device pixel (61.33 px wide).
        const module = side(data.edge) ? Object.assign({}, m, { y: m.y + 0.5, height: 61 + 1 / 3 }) : Object.assign({}, m, { x: m.x + 0.5, width: 61 + 1 / 3 });
        for (const size of sizes.concat([{ width: 600, height: 156 }, { width: 392, height: 301 }])) {
            const p = Anchored.place({ mode: data.mode, edge: data.edge, screen, bar, module, align: data.align, size, dpr });
            verify(onDevice(p.x, dpr) && onDevice(p.y, dpr) && onDevice(p.x + p.width, dpr) && onDevice(p.y + p.height, dpr), "on device pixels: " + JSON.stringify([p.x, p.y, p.width, p.height]));
            const plain = Anchored.place({ mode: data.mode, edge: data.edge, screen, bar, module, align: data.align, size });
            // Each is within half a pixel of the unrounded place (dpr 1 rounds
            // to whole logical pixels).
            verify(Math.abs(p.x - plain.x) <= 1 && Math.abs(p.y - plain.y) <= 1, "moved by under a pixel");
            if (data.mode !== "pill") {
                compare(p.x + p.width >= 1920 - 0.001, plain.x + plain.width >= 1920 - 0.5, "a panel at the right edge stays on it");
                compare(p.y + p.height >= 1200 - 0.001, plain.y + plain.height >= 1200 - 0.5, "a panel at the bottom stays on it");
                compare(p.radii, plain.radii, "the same corners");
            }
        }
        const f = Anchored.free({ mode: data.mode, edge: data.edge, screen, reserve: 56, size: { width: 761, height: 471 }, dpr });
        verify(onDevice(f.x, dpr) && onDevice(f.y, dpr) && onDevice(f.width, dpr) && onDevice(f.height, dpr), "the free panel too: " + JSON.stringify([f.x, f.y, f.width, f.height]));
    }

    function test_menus() {
        const want = { home: ["cc", ""], media: ["cc", ""], net: ["cc", "wifi"], audio: ["cc", "sound"], caffeine: ["cc", "awake"], notifications: ["cc", "notifications"], tray: ["cc", "tray"], clock: ["cal", ""], power: ["power", ""], battery: ["cc", "battery"], appearance: ["page", ""], theme: ["page", ""] };
        for (const name in want) {
            const t = Anchored.target(name);
            verify(t, name);
            compare([t.panel, t.sheet], want[name], name);
        }
        compare(Anchored.target("appearance").page, "appearance");
        compare(Anchored.menuFor("battery"), { menu: "battery", sheet: "" }, "bar open battery: the Battery sheet (M10)");
        compare(Anchored.target(""), null, "nothing open");
        compare(Anchored.target("nope"), null);
        compare(Anchored.menuFor("cc"), { menu: "home", sheet: "" });
        compare(Anchored.menuFor("cc/wifi"), { menu: "home", sheet: "wifi" });
        compare(Anchored.menuFor("cal"), { menu: "clock", sheet: "" });
        compare(Anchored.menuFor("power"), { menu: "power", sheet: "" });
        compare(Anchored.menuFor("appearance"), { menu: "appearance", sheet: "" });
        compare(Anchored.menuFor("power/x"), null);
        compare(Anchored.menuFor("hover"), null, "island-only states are not the bar's");
        compare(Anchored.SIZES.cc, { width: 760, height: 560 });
        compare(Anchored.SIZES.cal, { width: 400, height: 368 });
        compare(Anchored.SIZES.power, { width: 600, height: 156 });
    }

    // Each mode's edges (island-modes 12.3): the pill any, full top or bottom,
    // the rail left or right, the island the top; and moving between them.
    function test_edges_data() {
        const cases = [];
        for (const mode of ["pill", "full", "rail", "island"])
            for (const edge of ["top", "bottom", "left", "right"])
                cases.push({ tag: mode + "/" + edge, mode, edge });
        return cases;
    }
    function test_edges(data) {
        const shown = BarGeometry.edgeFor(data.mode, data.edge);
        const v = side(data.edge);
        const expect = data.mode === "island" ? "top" : data.mode === "full" ? (v ? "top" : data.edge) : data.mode === "rail" ? (v ? data.edge : "left") : data.edge;
        compare(shown, expect);
        const moved = BarGeometry.moveTo(data.mode, data.edge);
        const mode = data.mode === "full" && v ? "rail" : data.mode === "rail" && !v ? "full" : data.mode;
        compare(moved, { mode, edge: data.edge }, "a move lands on the edge asked for");
        compare(BarGeometry.edgeFor(moved.mode, moved.edge), data.mode === "island" ? "top" : data.edge);
        compare(BarGeometry.moveTo(data.mode, "middle"), null);
        compare(BarGeometry.inset(data.mode), data.mode === "full" || data.mode === "rail" ? 0 : 8);
    }

    // ---- the frame, in pixels -------------------------------------------------
    // A 480 x 320 "screen" with the bar on it, so the corners land on whole
    // pixels at scale 1. Magenta behind: anything not drawn reads magenta.
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "#ff00ff"
    }
    AnchoredFrame {
        id: frame
        anchors.fill: parent
        shadowed: false
    }
    readonly property var small: ({ width: 480, height: 320 })
    readonly property var smallBars: ({
            "pill/top": { x: 120, y: 8, width: 240, height: 40 },
            "full/top": { x: 0, y: 0, width: 480, height: 40 },
            "full/bottom": { x: 0, y: 280, width: 480, height: 40 },
            "rail/left": { x: 0, y: 0, width: 40, height: 320 },
            "rail/right": { x: 440, y: 0, width: 40, height: 320 }
        })
    function sameColor(pixel, expected) {
        const want = Qt.color(expected);
        return Math.abs(pixel.r - want.r) * 255 <= 3 && Math.abs(pixel.g - want.g) * 255 <= 3 && Math.abs(pixel.b - want.b) * 255 <= 3;
    }
    function hex(c) {
        return "#" + [c.r, c.g, c.b].map(v => ("0" + Math.round(v * 255).toString(16)).slice(-2)).join("");
    }
    function show(p, seamAt) {
        frame.shape = p;
        frame.panelX = p.x;
        frame.panelY = p.y;
        frame.panelWidth = p.width;
        frame.panelHeight = p.height;
        frame.contentX = p.x;
        frame.contentY = p.y;
        frame.contentWidth = p.width;
        frame.contentHeight = p.height;
        frame.seamAt = seamAt;
        waitForRendering(frame);
    }
    function test_frame_data() {
        return [
            { tag: "pill/top end", key: "pill/top", where: "end", align: "end" },
            { tag: "pill/top start", key: "pill/top", where: "start", align: "start" },
            { tag: "full/top end", key: "full/top", where: "end", align: "end" },
            { tag: "full/top middle", key: "full/top", where: "middle", align: "center" },
            { tag: "full/bottom start", key: "full/bottom", where: "start", align: "start" },
            { tag: "rail/left end", key: "rail/left", where: "end", align: "end" },
            { tag: "rail/right middle", key: "rail/right", where: "middle", align: "center" }
        ];
    }
    function test_frame(data) {
        const mode = data.key.split("/")[0], edge = data.key.split("/")[1];
        const bar = smallBars[data.key];
        const module = moduleAt(bar, edge, data.where);
        const p = Anchored.place({ mode, edge, screen: small, bar, module, align: data.align, size: { width: 200, height: 150 } });
        const seamAt = edge === "top" ? bar.y + bar.height : edge === "bottom" ? bar.y : edge === "left" ? bar.x + bar.width : bar.x;
        show(p, seamAt);
        compare(frame.drawn.radii, p.radii, "the frame draws the corners it was given");
        compare(frame.drawn.hairline, p.hairline, "and the sides");
        const img = grabImage(test);
        const at = (x, y) => img.pixel(Math.round(x), Math.round(y));
        const x0 = p.x, y0 = p.y, x1 = p.x + p.width - 1, y1 = p.y + p.height - 1;
        // Corners: a round one leaves its corner pixel undrawn; a square one fills it.
        const corners = { topLeft: [x0, y0], topRight: [x1, y0], bottomRight: [x1, y1], bottomLeft: [x0, y1] };
        for (const c in corners) {
            const px = at(corners[c][0], corners[c][1]);
            if (p.radii[c] > 0)
                verify(sameColor(px, "#ff00ff"), c + " is round: " + hex(px));
            else
                verify(!sameColor(px, "#ff00ff"), c + " is square: " + hex(px));
        }
        // Sides: the outermost pixel row or column, at the middle.
        const sides = { top: [(x0 + x1) / 2, y0], bottom: [(x0 + x1) / 2, y1], left: [x0, (y0 + y1) / 2], right: [x1, (y0 + y1) / 2] };
        for (const s in sides) {
            const px = at(sides[s][0], sides[s][1]);
            verify(sameColor(px, p.hairline[s] ? Tokens.hairline : Tokens.surface), s + (p.hairline[s] ? " has" : " has no") + " hairline: " + hex(px));
        }
        // One pixel in, the surface.
        verify(sameColor(at((x0 + x1) / 2, (y0 + y1) / 2), Tokens.surface), "surface inside");
    }
    // A strip's panel halfway out: nothing is drawn on the bar's side of the seam.
    function test_seamClip_data() {
        return [{ tag: "drop", key: "full/top" }, { tag: "slide", key: "rail/left" }, { tag: "drop up", key: "full/bottom" }];
    }
    function test_seamClip(data) {
        const mode = data.key.split("/")[0], edge = data.key.split("/")[1];
        const bar = smallBars[data.key];
        const p = Anchored.place({ mode, edge, screen: small, bar, module: moduleAt(bar, edge, "middle"), align: "center", size: { width: 200, height: 150 } });
        const seamAt = edge === "top" ? bar.y + bar.height : edge === "bottom" ? bar.y : bar.x + bar.width;
        show(p, seamAt);
        // Halfway: from + (place - from) / 2.
        frame.panelX = (p.from.x + p.x) / 2;
        frame.panelY = (p.from.y + p.y) / 2;
        waitForRendering(frame);
        const img = grabImage(test);
        const v = side(edge);
        const mid = v ? (p.y + p.height / 2) : (p.x + p.width / 2);
        const behind = edge === "top" ? [mid, seamAt - 4] : edge === "bottom" ? [mid, seamAt + 4] : [seamAt - 4, mid];
        const out = edge === "top" ? [mid, seamAt + 4] : edge === "bottom" ? [mid, seamAt - 4] : [seamAt + 4, mid];
        verify(sameColor(img.pixel(behind[0], behind[1]), "#ff00ff"), "clipped at the strip's inner edge: " + hex(img.pixel(behind[0], behind[1])));
        verify(sameColor(img.pixel(out[0], out[1]), Tokens.surface), "drawn past it: " + hex(img.pixel(out[0], out[1])));
    }
    // While the pill's panel grows from a 52 x 32 module, a corner is never
    // rounder than half the panel.
    function test_growRadius() {
        const bar = smallBars["pill/top"];
        const p = Anchored.place({ mode: "pill", edge: "top", screen: small, bar, module: moduleAt(bar, "top", "end"), align: "end", size: { width: 200, height: 150 } });
        show(p, 0);
        frame.panelX = p.from.x;
        frame.panelY = p.from.y;
        frame.panelWidth = p.from.width;
        frame.panelHeight = p.from.height;
        compare(frame.drawn.radii.topLeft, 16, "half of 32");
        frame.panelWidth = p.width;
        frame.panelHeight = p.height;
        compare(frame.drawn.radii.topLeft, 28);
    }
}
