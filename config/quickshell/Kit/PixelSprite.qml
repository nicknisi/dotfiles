import QtQuick

// PixelSprite.qml - pixel art drawn crisp at any output scale (personal-looks 1.4).
//
// rows is the bitmap as strings, '#' filled and anything else empty (the
// mock's renderVals format). Each row becomes one rectangle per run of '#',
// so an 8 x 8 bot is about 15 rectangles instead of 40 cells, all without
// antialiasing.
//
// Crispness at scale 1.5: a sprite pixel is sharp only when it covers a whole
// number of device pixels, so `cell` snaps size / rows to whole device pixels,
// rounding half down (16 px -> 2 logical = 3 device px per cell; 18 -> 16;
// 24 -> 21.333; 14 -> 16, the spec's table). Every edge then sits on the same
// device-pixel phase as the sprite's origin, so a non-antialiased rectangle
// rasterises to exactly `cell * dpr` pixels wherever the parent puts it.
// snap() rounds offsets (a bob or a hop) to whole device pixels too, halves
// away from zero, so a moving sprite stays on the grid and a bob keeps its
// shape: 0 / -1 / -2 / -1 logical px is 0 / -2 / -3 / -2 device px at 1.5,
// where plain Math.round gave 0 / -1 / -3 / -1 (M2 review). personal-looks
// 1.4 asked for whole bot pixels instead (2 logical px); that would flatten
// the bob to two positions, so M2 keeps the board's four frames on device
// pixels.
//
// No `import Quickshell`: qmltestrunner loads this (tests/tst_pixel_sprite.qml).
Item {
    id: root

    property var rows: []
    // Wanted height in logical px; the drawn height is rows x cell.
    property real size: 16
    // Device pixels per logical px: the window's devicePixelRatio (1.5 on milhouse).
    property real dpr: 1
    property color color: "#ffffff"

    readonly property int rowCount: (root.rows || []).length
    readonly property int columns: {
        let n = 0;
        for (const r of (root.rows || []))
            n = Math.max(n, String(r).length);
        return n;
    }
    readonly property real cell: root.snapCell(root.size / Math.max(1, root.rowCount), root.dpr)
    readonly property var runs: root.runsOf(root.rows)

    implicitWidth: columns * cell
    implicitHeight: rowCount * cell
    width: implicitWidth
    height: implicitHeight

    // A length in logical px, rounded to whole device pixels (half down), at least one.
    function snapCell(length, ratio) {
        const r = ratio > 0 ? ratio : 1;
        return Math.max(1, Math.ceil(length * r - 0.5)) / r;
    }
    // A position or offset in logical px, rounded to the nearest device pixel,
    // halves away from zero (so snap(-v) is -snap(v)).
    function snap(value, ratio) {
        const r = ratio > 0 ? ratio : 1;
        const v = Number(value) || 0;
        return (v < 0 ? -1 : 1) * Math.round(Math.abs(v) * r) / r;
    }
    // [{ x, y, w }] in cells: one entry per horizontal run of '#'.
    function runsOf(list) {
        const out = [];
        (list || []).forEach((row, y) => {
            const s = String(row);
            let start = -1;
            for (let x = 0; x <= s.length; x++) {
                const on = x < s.length && s[x] === "#";
                if (on && start < 0) start = x;
                if (!on && start >= 0) {
                    out.push({ x: start, y: y, w: x - start });
                    start = -1;
                }
            }
        });
        return out;
    }

    Repeater {
        model: root.runs
        delegate: Rectangle {
            required property var modelData
            x: modelData.x * root.cell
            y: modelData.y * root.cell
            width: modelData.w * root.cell
            height: root.cell
            color: root.color
            antialiasing: false
        }
    }
}
