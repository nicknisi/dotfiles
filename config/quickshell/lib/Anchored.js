.pragma library
// Anchored.js - where a panel sits against the classic bar (PLAN M4,
// island-modes 12.4, the Modes board), as pure functions: Hosts/AnchoredHost
// places the control center, its sheets, the power menu and the calendar
// with place(), and Launcher.qml's free panel with free().
//
// place(o) -> the panel's rectangle and how it is drawn, for
//   o = { mode, edge, screen: { width, height }, bar: { x, y, width, height },
//         module: { x, y, width, height }, align: "start" | "center" | "end",
//         size: { width, height }, dpr }
// every rectangle in screen coordinates (logical px). `dpr` is the window's
// devicePixelRatio (1 when left out): the rectangle lands on whole device
// pixels, so its 1 px ring stays crisp at scale 1.5 (PLAN risk 13: a panel
// at logical 475 sat on device 712.5 and smeared both side hairlines over
// three device columns).
//
//   pill  "The panel opens under the module you clicked, right edges aligned,
//         and grows from that corner": GAP (8) from the bar, aligned to the
//         module (its far edge for the trailing group, its centre for the
//         clock), kept MARGIN (8) inside the screen; all four corners round,
//         the hairline all round. Motion "grow": from the module's size at
//         the aligned corner to the panel's size.
//   full  "Panels drop out of the strip as one piece, square where they join
//         and rounded on the free corner": flush with the strip (gap 0),
//         aligned to the module and clamped to the screen; a panel that ends
//         within SNAP (16) of the screen edge touches it (the trailing
//         group's 8 px end padding). Motion "drop": in from behind the strip.
//   rail  "Panels slide out sideways beside the module, flush with the
//         rail": the same, across. Motion "slide".
//
// A corner is round only when it touches neither the bar nor a screen edge,
// and the hairline is drawn only on the sides that touch neither: the seam
// (the side against a flush strip) and any side on a screen edge stay open,
// so strip and panel read as one piece. The bar leaves its own inner-edge
// hairline out along the seam (`seamFrom`/`seamTo`, BarView.qml), except
// over a panel side that draws its hairline, so the strip's line and the
// panel's side meet in one corner.
//
// Radius: 28, the island's, on every free corner. The thumbnails draw 14 on
// panels a third the real size [NEEDS CHECK] in island-modes 12.4; the
// island thumbnail's 16 stands for its real 28, so 14 there reads as about
// 24, and the control center's 14 px cards sit 16 in, concentric with 28.

// What each of the bar's menus opens (BarView.openMenu): the control center
// (on a sheet, "" for home), the calendar, the power menu (anchored like the
// others, island-modes 3.2: to the module the control center hangs from), or
// one of the old Hud pages that has no sheet yet (the battery hand-off,
// Appearance and its Theme page; M10 retires them).
var MENUS = {
    home: { panel: "cc", sheet: "" },
    media: { panel: "cc", sheet: "" },
    net: { panel: "cc", sheet: "wifi" },
    audio: { panel: "cc", sheet: "sound" },
    caffeine: { panel: "cc", sheet: "awake" },
    notifications: { panel: "cc", sheet: "notifications" },
    tray: { panel: "cc", sheet: "tray" },
    clock: { panel: "cal", sheet: "" },
    power: { panel: "power", sheet: "" },
    battery: { panel: "page", sheet: "", page: "battery" },
    appearance: { panel: "page", sheet: "", page: "appearance" },
    theme: { panel: "page", sheet: "", page: "theme" }
};
// Each panel's size (island-modes 3.4); a page's height is its content's.
var SIZES = { cc: { width: 760, height: 560 }, cal: { width: 400, height: 368 }, power: { width: 600, height: 156 }, page: { width: 392, height: 0 } };

function target(menu) {
    return MENUS[menu] || null;
}

// The menu an IPC state names: cc, cc/<sheet>, cal, power, battery,
// appearance, theme. Returns { menu, sheet } or null.
function menuFor(state) {
    var s = String(state || "");
    var slash = s.indexOf("/");
    var head = slash >= 0 ? s.slice(0, slash) : s;
    var sheet = slash >= 0 ? s.slice(slash + 1) : "";
    if (head === "cc") return { menu: "home", sheet: sheet };
    if (head === "cal" || head === "clock") return sheet === "" ? { menu: "clock", sheet: "" } : null;
    if (sheet !== "") return null;
    if (head === "power" || head === "battery" || head === "appearance" || head === "theme") return { menu: head, sheet: "" };
    return null;
}

var GAP = 8;
var MARGIN = 8;
var SNAP = 16;
var RADIUS = 28;
var EPS = 0.5;

function side(edge) {
    return edge === "left" || edge === "right";
}

function flush(mode) {
    return mode === "full" || mode === "rail";
}

function clamp(v, lo, hi) {
    return hi < lo ? lo : Math.max(lo, Math.min(hi, v));
}

// `v` on the nearest whole device pixel.
function snap(v, dpr) {
    var k = Number(dpr) > 0 ? Number(dpr) : 1;
    return Math.round(v * k) / k;
}

// "drop" for a flush strip on the top or the bottom, "slide" on a side, "grow"
// for the pill.
function motionFor(mode, edge) {
    if (!flush(mode)) return "grow";
    return side(edge) ? "slide" : "drop";
}

// The sides of `r` that touch a screen edge.
function onScreenEdges(r, screen) {
    return {
        top: r.y <= EPS,
        left: r.x <= EPS,
        bottom: r.y + r.height >= screen.height - EPS,
        right: r.x + r.width >= screen.width - EPS
    };
}

// The rounded corners and hairline sides for a rectangle with `seam` ("" for
// none) and the screen edges it touches.
function shape(seam, screenSides) {
    var attached = {
        top: seam === "top" || screenSides.top,
        right: seam === "right" || screenSides.right,
        bottom: seam === "bottom" || screenSides.bottom,
        left: seam === "left" || screenSides.left
    };
    var corners = {
        topLeft: !(attached.top || attached.left),
        topRight: !(attached.top || attached.right),
        bottomRight: !(attached.bottom || attached.right),
        bottomLeft: !(attached.bottom || attached.left)
    };
    var hairline = { top: !attached.top, right: !attached.right, bottom: !attached.bottom, left: !attached.left };
    return {
        corners: corners,
        radii: {
            topLeft: corners.topLeft ? RADIUS : 0,
            topRight: corners.topRight ? RADIUS : 0,
            bottomRight: corners.bottomRight ? RADIUS : 0,
            bottomLeft: corners.bottomLeft ? RADIUS : 0
        },
        hairline: hairline
    };
}

// The corner (or side centre) a pill panel grows from: on the bar's side,
// at the aligned end.
var ORIGINS = {
    top: { start: "topLeft", center: "top", end: "topRight" },
    bottom: { start: "bottomLeft", center: "bottom", end: "bottomRight" },
    left: { start: "topLeft", center: "left", end: "bottomLeft" },
    right: { start: "topRight", center: "right", end: "bottomRight" }
};
function originFor(edge, align) {
    return (ORIGINS[edge] || ORIGINS.top)[align] || "topRight";
}
// A rectangle `fw` x `fh` pinned at `origin` inside r.
function pinned(r, origin, fw, fh) {
    var left = origin === "left" || origin.indexOf("Left") > 0;
    var right = origin === "right" || origin.indexOf("Right") > 0;
    var top = origin.indexOf("top") === 0;
    var bottom = origin.indexOf("bottom") === 0;
    return {
        x: left ? r.x : right ? r.x + r.width - fw : r.x + (r.width - fw) / 2,
        y: top ? r.y : bottom ? r.y + r.height - fh : r.y + (r.height - fh) / 2,
        width: fw,
        height: fh
    };
}

function place(o) {
    var mode = o.mode || "pill";
    var edge = o.edge || "top";
    var screen = o.screen || { width: 1920, height: 1200 };
    var bar = o.bar || { x: 0, y: 0, width: 0, height: 0 };
    var module = o.module || bar;
    var align = o.align === "start" || o.align === "center" ? o.align : "end";
    var dpr = o.dpr;
    var w = snap(Math.max(0, Number(o.size && o.size.width) || 0), dpr);
    var h = snap(Math.max(0, Number(o.size && o.size.height) || 0), dpr);
    var docked = flush(mode);
    var gap = docked ? 0 : GAP;
    var vertical = side(edge);

    // Across the bar: beside it, `gap` away.
    var x, y;
    if (edge === "top") y = bar.y + bar.height + gap;
    else if (edge === "bottom") y = bar.y - gap - h;
    else if (edge === "left") x = bar.x + bar.width + gap;
    else x = bar.x - gap - w;

    // Along the bar: aligned to the module, then kept on the screen.
    var mStart = vertical ? module.y : module.x;
    var mSize = vertical ? module.height : module.width;
    var size = vertical ? h : w;
    var room = vertical ? screen.height : screen.width;
    // Centred on a whole pixel, so the frame's 1 px ring stays crisp.
    var a = align === "start" ? mStart : align === "center" ? Math.round(mStart + (mSize - size) / 2) : mStart + mSize - size;
    if (docked) {
        a = clamp(a, 0, room - size);
        if (a < SNAP) a = 0;
        if (room - (a + size) < SNAP) a = room - size;
    } else {
        a = clamp(a, MARGIN, room - MARGIN - size);
    }
    if (vertical) y = a;
    else x = a;
    // On whole device pixels. A strip's panel clamped to the screen edge
    // stays on it: the room and the size are whole device pixels already.
    x = snap(x, dpr);
    y = snap(y, dpr);

    var rect = { x: x, y: y, width: w, height: h };
    var seam = docked ? edge : "";
    var s = shape(seam, onScreenEdges(rect, screen));
    var motion = motionFor(mode, edge);
    var origin = originFor(edge, align);

    // Where the motion starts.
    var from;
    if (motion === "drop") from = { x: x, y: edge === "top" ? y - h : y + h, width: w, height: h };
    else if (motion === "slide") from = { x: edge === "left" ? x - w : x + w, y: y, width: w, height: h };
    else from = pinned(rect, origin, Math.min(w, Math.max(1, module.width)), Math.min(h, Math.max(1, module.height)));

    // The stretch of the bar the panel covers, along it, for the seam gap.
    var seamFrom = docked ? (vertical ? y : x) : 0;
    var seamTo = docked ? seamFrom + (vertical ? h : w) : 0;

    return {
        x: x, y: y, width: w, height: h,
        mode: mode, edge: edge, align: align, gap: gap,
        seam: seam, seamFrom: seamFrom, seamTo: seamTo,
        corners: s.corners, radii: s.radii, hairline: s.hairline,
        motion: motion, origin: origin, from: from
    };
}

// A panel that belongs to no module (the launcher and the pickers in pill,
// full and rail), PLAN 1.6: "a free panel, top centre, 8 px under the
// reserved zone". o.reserve is the exclusive zone the bar keeps on its edge
// (Theme.barExtent: 56 for the pill, 40 for the strips), so the panel sits
// GAP under it when the bar is on the top (y 64 under the pill, 48 under the
// full strip), else GAP under the screen's top (in island mode too, over a
// fullscreen window, where the island would be). Never docked, so every
// corner is round and the hairline goes all the way round. Its height is
// kept GAP + 8 clear of the bottom; o.dpr as for place().
function free(o) {
    var mode = o.mode || "pill";
    var edge = o.edge || "top";
    var screen = o.screen || { width: 1920, height: 1200 };
    var dpr = o.dpr;
    var reserve = Math.max(0, Number(o.reserve) || 0);
    var w = snap(Math.min(Math.max(0, Number(o.size && o.size.width) || 0), screen.width - 2 * MARGIN), dpr);
    var top = snap(mode !== "island" && edge === "top" ? reserve + GAP : GAP, dpr);
    var h = snap(Math.min(Math.max(0, Number(o.size && o.size.height) || 0), screen.height - top - 2 * MARGIN), dpr);
    var rect = { x: snap((screen.width - w) / 2, dpr), y: top, width: w, height: h };
    var s = shape("", { top: false, right: false, bottom: false, left: false });
    return {
        x: rect.x, y: rect.y, width: rect.width, height: rect.height,
        mode: mode, edge: edge, align: "center", gap: GAP,
        seam: "", seamFrom: 0, seamTo: 0,
        corners: s.corners, radii: s.radii, hairline: s.hairline,
        motion: "grow", origin: "top", from: { x: rect.x, y: rect.y, width: rect.width, height: Math.min(56, rect.height) }
    };
}
