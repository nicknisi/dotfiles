import QtQuick
import QtTest
import qs
import "../BarGeometry.js" as BarGeometry

// The classic bar's layout, material and drags (PLAN M4, island-modes 12.3).
// BarView is the real one; tests/bar-drag.sh builds the stand-in services.
TestCase {
    id: test
    name: "BarDrag"
    when: windowShown
    visible: true
    width: 1920
    height: 1080

    BarView {
        id: bar
        screen: ({ width: 1920, height: 1080 })
        workspaces: [{ name: "W", urgent: false, activate: () => {} }, { name: "D", urgent: false, activate: () => {} }]
        focusedName: "D"
    }
    SignalSpy {
        id: toggles
        target: bar
        signalName: "toggled"
    }

    // Every valid mode and edge: the pill on any edge, the full strip on the
    // top and the bottom, the rail on the left and the right.
    readonly property var placements: [["pill", "top"], ["pill", "bottom"], ["pill", "left"], ["pill", "right"], ["full", "top"], ["full", "bottom"], ["rail", "left"], ["rail", "right"]]

    function init() {
        Media.player = null;
        Prefs.translucent = false;
        bar.suppressClicks = false;
        bar.openMenu = "";
        bar.seamFrom = 0;
        bar.seamTo = 0;
        bar.seamStartLine = false;
        bar.seamEndLine = false;
        bar.dpr = 1;
        toggles.clear();
    }
    function place(mode, edge) {
        Prefs.barMode = mode;
        Prefs.storedEdge = edge;
        waitForRendering(bar);
    }

    // ---- where it sits ------------------------------------------------------
    function test_layout_data() {
        const cases = [];
        for (const mode of ["pill", "full", "rail"])
            for (const edge of ["top", "bottom", "left", "right"])
                cases.push({ tag: mode + "/" + edge, mode, edge });
        return cases;
    }
    // Any remembered edge: full reads top or bottom, the rail left or right,
    // the pill keeps it; the window is 56 deep for the pill, 40 for the strips.
    function test_layout(data) {
        place(data.mode, data.edge);
        const edge = BarGeometry.edgeFor(data.mode, data.edge);
        compare(Prefs.edge, edge, "the mode's edge");
        compare(Prefs.storedEdge, data.edge, "the remembered edge is kept");
        const vertical = edge === "left" || edge === "right";
        const along = vertical ? 1080 : 1920;
        const length = data.mode === "pill" ? 518 : along;
        compare(vertical ? bar.body.height : bar.body.width, length);
        compare(vertical ? bar.body.width : bar.body.height, 40);
        compare(vertical ? bar.width : bar.height, data.mode === "pill" ? 56 : 40);
        compare(vertical ? bar.body.y : bar.body.x, Math.round((along - length) / 2), "centred, on a whole pixel");
        compare(vertical ? bar.body.x : bar.body.y, data.mode === "pill" ? 8 : 0, "8 in for the pill, flush for the strips");
    }

    function test_mediaExpansion_data() {
        return test_layout_data();
    }
    function test_mediaExpansion(data) {
        place(data.mode, data.edge);
        const idleLength = bar.vertical ? bar.body.height : bar.body.width;
        Media.player = { isPlaying: false, trackTitle: "A very long track title ".repeat(20) };
        const extra = data.mode === "pill" && !bar.vertical ? 128 : 0;
        tryCompare(bar, "bodyLength", idleLength + extra, 1000, "the pill makes room for artwork and metadata");
        if (extra) {
            Media.player = { isPlaying: false, trackTitle: "Hi", trackArtist: "AB" };
            tryVerify(() => bar.bodyLength < idleLength + extra, 1000, "short tracks shrink it too");
        }
        Media.player = null;
        compare(bar.vertical ? bar.body.height : bar.body.width, idleLength, "it shrinks when the player closes");
    }

    // ---- the material (island-modes 12.3) ------------------------------------
    function test_material_data() {
        return placements.map(p => ({ tag: p[0] + "/" + p[1], mode: p[0], edge: p[1] }));
    }
    function test_material(data) {
        place(data.mode, data.edge);
        const pill = data.mode === "pill";
        compare(String(bar.surface.color), String(Tokens.surface), "opaque surface");
        compare(bar.surface.radius, pill ? 20 : 0, "the pill's radius is h/2; the strips are square");
        compare(bar.surface.border.width, pill ? 1 : 0, "the pill's hairline ring");
        compare(String(bar.surface.border.color), String(Tokens.hairline));
        compare(bar.innerLine.visible, !pill, "the strips draw the inner edge only");
        if (!pill) {
            const line = bar.innerLine;
            const vertical = data.edge === "left" || data.edge === "right";
            compare(vertical ? line.width : line.height, 1, "1 px");
            compare(vertical ? line.height : line.width, vertical ? bar.body.height : bar.body.width, "the whole strip");
            const inner = { top: [0, bar.body.height - 1], bottom: [0, 0], left: [bar.body.width - 1, 0], right: [0, 0] }[data.edge];
            compare([line.x, line.y], inner, "on the side facing the screen");
            compare(String(findChild(line, "barLineBefore").color), String(Tokens.hairline));
        }
        // The one shadow, on the pill only.
        const shadow = bar.body.children.find(c => c.blur !== undefined);
        verify(shadow, "a shadow item");
        compare(shadow.visible, pill, "the pill has the one shadow, the strips none");
        compare(shadow.blur, 28);
        compare(shadow.offset.y, 10);
        Prefs.translucent = true;
        tryVerify(() => Math.abs(bar.surface.color.a - 0.62) < 0.01, 1000, "translucent: 0.62");
        Prefs.translucent = false;
        tryVerify(() => bar.surface.color.a > 0.99, 1000);
    }

    // The strips leave their hairline out where a panel joins.
    function test_seam_data() {
        return [
            { tag: "full/top end", mode: "full", edge: "top", from: 1160, to: 1920 },
            { tag: "full/top middle", mode: "full", edge: "top", from: 580, to: 1340 },
            { tag: "full/bottom start", mode: "full", edge: "bottom", from: 0, to: 760 },
            { tag: "rail/left end", mode: "rail", edge: "left", from: 520, to: 1080 },
            { tag: "rail/right middle", mode: "rail", edge: "right", from: 300, to: 668 },
            { tag: "rail/left start", mode: "rail", edge: "left", from: 0, to: 560 }
        ];
    }
    function test_seam(data) {
        place(data.mode, data.edge);
        const vertical = data.edge === "left" || data.edge === "right";
        const before = findChild(bar.innerLine, "barLineBefore");
        const after = findChild(bar.innerLine, "barLineAfter");
        verify(!after.visible, "no seam, one line");
        bar.seamFrom = data.from;
        bar.seamTo = data.to;
        const len = vertical ? bar.body.height : bar.body.width;
        compare(vertical ? before.height : before.width, data.from, "the line runs up to the panel");
        compare(after.visible, data.to < len, "and resumes after it, unless the panel reaches the end");
        if (data.to < len) {
            compare(vertical ? after.y : after.x, data.to);
            compare(vertical ? after.height : after.width, len - data.to);
        }
        bar.seamFrom = 0;
        bar.seamTo = 0;
        compare(vertical ? before.height : before.width, len, "closed: the whole edge again");
    }

    // Where the panel draws a hairline on a side that meets the strip, the
    // strip's line keeps covering that side's width, so the two meet in one
    // closed corner (the Modes board) instead of touching only diagonally.
    function test_seamCorner_data() {
        const cases = [];
        for (const dpr of [1, 1.5])
            for (const d of [
                    { tag: "full/top end", mode: "full", edge: "top", from: 1160, to: 1920, start: true, end: false },
                    { tag: "full/top middle", mode: "full", edge: "top", from: 760, to: 1160, start: true, end: true },
                    { tag: "rail/right middle", mode: "rail", edge: "right", from: 300, to: 668, start: true, end: true },
                    { tag: "rail/left end", mode: "rail", edge: "left", from: 520, to: 1080, start: true, end: false }
                ])
                cases.push(Object.assign({}, d, { tag: d.tag + " @" + dpr, dpr }));
        return cases;
    }
    function test_seamCorner(data) {
        bar.dpr = data.dpr;
        place(data.mode, data.edge);
        const vertical = data.edge === "left" || data.edge === "right";
        const before = findChild(bar.innerLine, "barLineBefore");
        const after = findChild(bar.innerLine, "barLineAfter");
        const line = bar.innerLine.thickness;
        bar.seamFrom = data.from;
        bar.seamTo = data.to;
        bar.seamStartLine = data.start;
        bar.seamEndLine = data.end;
        const len = vertical ? bar.body.height : bar.body.width;
        compare(vertical ? before.height : before.width, data.from + line, "over the panel's start side too");
        if (data.to < len) {
            verify(after.visible);
            compare(vertical ? after.y : after.x, data.to - (data.end ? line : 0), "and from its end side on");
        }
        bar.seamStartLine = false;
        compare(vertical ? before.height : before.width, data.from, "no hairline on that side: the gap starts at the panel");
    }

    // At scale 1.5 (PLAN risk 13) a 1 px ring on a half device pixel smears
    // over three device columns: the pill's ends, every module with a ring
    // and the strip's line sit on whole device pixels, and the line is two
    // device pixels thick, as a 1 px ring draws.
    function onDevice(v, dpr) {
        return Math.abs(v * dpr - Math.round(v * dpr)) < 0.001;
    }
    function test_devicePixels_data() {
        return placements.map(p => ({ tag: p[0] + "/" + p[1], mode: p[0], edge: p[1] }));
    }
    function test_devicePixels(data) {
        bar.dpr = 1.5;
        Media.player = { isPlaying: true, trackTitle: "Neon Grid", trackArtist: "Night Rider" };
        place(data.mode, data.edge);
        const dpr = 1.5;
        const r = bar.surfaceRect();
        verify(onDevice(r.x, dpr) && onDevice(r.y, dpr) && onDevice(r.x + r.width, dpr) && onDevice(r.y + r.height, dpr), "the bar's edges on device pixels: " + JSON.stringify(r));
        for (const m of [bar.systemButton, bar.networkButton, bar.notificationsButton, bar.audioButton, bar.mediaButton, bar.clockButton]) {
            const q = bar.rectOf(m);
            verify(onDevice(q.x, dpr) && onDevice(q.y, dpr) && onDevice(q.x + q.width, dpr) && onDevice(q.y + q.height, dpr), m.objectName + " on device pixels: " + JSON.stringify(q));
        }
        if (data.mode !== "pill") {
            const line = bar.innerLine;
            compare(Math.round(bar.innerLine.thickness * dpr), 2, "the strip's line: 2 device px, as the panel's 1 px sides draw");
            verify(onDevice(line.x, dpr) && onDevice(line.y, dpr), "on whole device pixels: " + line.x + "," + line.y);
        }
        Media.player = null;
    }

    // Every module is a capsule (radius h/2) in every mode, as the board
    // draws the status group and the workspace marks; only the pill adds the
    // accent ring.
    function test_chipRadius_data() {
        return placements.map(p => ({ tag: p[0] + "/" + p[1], mode: p[0], edge: p[1] }));
    }
    function test_chipRadius(data) {
        place(data.mode, data.edge);
        for (const m of [bar.systemButton, bar.networkButton, bar.audioButton, bar.notificationsButton, bar.clockButton])
            compare(m.background.radius, Math.min(m.width, m.height) / 2, m.objectName + " is round");
        const chip = bar.workspaceList.itemAtIndex(0);
        verify(chip, "a workspace chip");
        compare(chip.cornerRadius, chip.height / 2, "the workspace marks are round");
        compare(bar.systemButton.ringed, data.mode === "pill", "the ring is the pill's alone");
    }

    // ---- picking it up ---------------------------------------------------------
    function test_dragReaction_data() {
        return test_material_data();
    }
    function test_dragReaction(data) {
        place(data.mode, data.edge);
        tryCompare(bar.surface, "expansion", 0, 500);
        const width = bar.width, height = bar.height;
        const origin = bar.clockButton.mapToItem(test, 0, 0);
        bar.openMenu = "home";
        wait(60);
        compare(bar.surface.expansion, 0, "an open panel does not grow the bar (the module's highlight says it)");
        bar.openMenu = "";
        const px = bar.vertical ? 16 : 100, py = bar.vertical ? 100 : 16;
        mousePress(bar.body, px, py, Qt.LeftButton);
        mouseMove(bar.body, px + 10, py + 10, 20);
        mouseMove(bar.body, px + 12, py + 12, 20);
        tryVerify(() => bar.handler.active, 500);
        const grown = data.mode === "pill" ? 3 : 0;
        if (grown) {
            wait(40);
            verify(bar.surface.expansion > 0 && bar.surface.expansion < 3, "it grows rather than jumping");
        }
        tryCompare(bar.surface, "expansion", grown, 1000, "picking up the pill grows its surface; the strips stay");
        compare(bar.width, width, "the window stays put");
        compare(bar.height, height);
        compare(bar.clockButton.mapToItem(test, 0, 0), origin, "hit targets do not move with the surface");
        compare(String(bar.surface.border.color), String(Tokens.accent), "an accent ring while held");
        compare(bar.surface.border.width, 1);
        mouseRelease(bar.body, px + 12, py + 12, Qt.LeftButton);
        tryCompare(bar.surface, "expansion", 0, 1000);
        tryVerify(() => !bar.suppressClicks, 500);
        wait(250);
        compare(bar.surface.expansion, 0, "no idle bounce");
    }

    function test_doubleTapTransparency_data() {
        return test_material_data();
    }
    function test_doubleTapTransparency(data) {
        place(data.mode, data.edge);
        Prefs.translucent = data.mode !== "pill";
        const before = Prefs.translucent;
        const x = bar.vertical ? 16 : 100;
        const y = bar.vertical ? 100 : 16;
        wait(Qt.styleHints.mouseDoubleClickInterval + 20);
        // QtTest inserts 500ms between mouse clicks, past the platform's 400ms
        // threshold. Touch events reach the same TapHandler without it.
        const touch = touchEvent(bar.body);
        touch.press(0, bar.body, x, y).commit();
        touch.release(0, bar.body, x, y).commit();
        touch.press(0, bar.body, x, y).commit();
        touch.release(0, bar.body, x, y).commit();
        tryCompare(Prefs, "translucent", !before, 500, "double-tap toggles the background's translucency");
        tryVerify(() => Math.abs(bar.surface.color.a - (Prefs.translucent ? 0.62 : 1)) < 0.01, 1000);
        mouseDoubleClickSequence(bar.clockButton, 16, 16, Qt.LeftButton, Qt.NoModifier, 10);
        compare(Prefs.translucent, !before, "module double-clicks do not change it");
        compare(toggles.count, 2, "module clicks keep their own action");
    }
    function test_dragAfterTap() {
        place("pill", "top");
        wait(Qt.styleHints.mouseDoubleClickInterval + 20);
        const touch = touchEvent(bar.body);
        touch.press(0, bar.body, 100, 16).commit();
        touch.release(0, bar.body, 100, 16).commit();
        touch.press(0, bar.body, 100, 16).commit();
        touch.move(0, bar.body, 160, 16).commit();
        touch.move(0, bar.body, 180, 16).commit();
        tryVerify(() => bar.handler.active, 500);
        touch.release(0, bar.body, 180, 16).commit();
        verify(!Prefs.translucent, "a drag cancels a possible double-tap");
        tryVerify(() => !bar.suppressClicks, 500);
    }

    // Drops: every valid start, every edge, from the background and from a
    // module. The full strip dropped on a side becomes the rail, the rail
    // dropped on the top or the bottom becomes the full strip
    // (island-modes 12.5); the pill keeps its mode.
    function test_drag_data() {
        const cases = [];
        for (const p of placements)
            for (const to of ["top", "bottom", "left", "right"])
                for (const button of [false, true])
                    cases.push({ tag: p[0] + "/" + p[1] + "->" + to + "/" + (button ? "module" : "bar"), mode: p[0], from: p[1], to, button });
        return cases;
    }
    function test_drag(data) {
        place(data.mode, data.from);
        compare(Prefs.edge, data.from);
        const originX = data.from === "right" ? bar.screen.width - bar.width : 0;
        const originY = data.from === "bottom" ? bar.screen.height - bar.height : 0;
        const targets = { top: [960, 5], bottom: [960, 1075], left: [5, 540], right: [1915, 540] };
        const target = targets[data.to];
        const subject = data.button ? bar.clockButton : bar.body;
        const px = data.button || bar.vertical ? 16 : 100;
        const py = data.button || !bar.vertical ? 16 : 100;
        mousePress(subject, px, py, Qt.LeftButton);
        mouseMove(subject, px + 30, py + 30, 20);
        tryVerify(() => bar.handler.active, 500, "a drag starts over the " + (data.button ? "module" : "background"));
        mouseMove(test, target[0] - originX, target[1] - originY, 20);
        compare(bar.dragEdge, data.to, "the drop target follows the pointer");
        mouseRelease(test, target[0] - originX, target[1] - originY, Qt.LeftButton);
        compare(Prefs.edge, data.to, "the drop picks the edge");
        const side = data.to === "left" || data.to === "right";
        const mode = data.mode === "pill" ? "pill" : side ? "rail" : "full";
        compare(Prefs.barMode, mode, "full and rail trade places across orientations");
        verify(!bar.handler.active);
        compare(toggles.count, 0, "a drag never presses a module");
        verify(!Prefs.translucent, "a drag never toggles translucency");
        tryVerify(() => !bar.suppressClicks, 500, "the release guard expires");
        mouseClick(bar.clockButton, 16, 16);
        compare(toggles.count, 1, "ordinary clicks work after dragging");
    }

    function test_clickAndWheel() {
        place("pill", "top");
        mousePress(bar.clockButton, 16, 16);
        mouseMove(bar.clockButton, 18, 18, 20);
        verify(!bar.handler.active, "small pointer jitter stays a click");
        mouseRelease(bar.clockButton, 18, 18);
        compare(toggles.count, 1);
        compare(bar.openMenu, "clock");
        verify(!bar.handler.active);
        bar.suppressClicks = true;
        mouseClick(bar.clockButton, 16, 16);
        compare(toggles.count, 1, "the release guard eats a stray click");
        compare(bar.openMenu, "clock");
        const volume = Audio.volume;
        mouseWheel(bar.audioButton, 16, 16, 0, 120);
        verify(Audio.volume > volume, "the wheel reaches the module");
        compare(Prefs.edge, "top", "the wheel does not move the bar");
        mouseClick(bar.body, 100, 16);
        verify(!Prefs.translucent, "a single background click does not toggle translucency");
    }
}
