import QtQuick
import qs

// MatchText.qml - a result title with the letters the query matched drawn in
// weight 600 (500 for monospace rows) over a `faint` underline 3 px below the
// baseline (launcher-pickers 4.6, Main board).
//
// `ranges` are [start, end) pairs from core/Match.js ranges(). Qt's Text has
// no per-span underline colour or offset, so the title is laid out as a Row
// of plain Text runs, each matched run with a 1 px Rectangle under it. Runs
// are placed by each Text's own `advance`: FontMetrics advances came out about
// 1 px per glyph wider than the drawn text on Wayland (hinted metrics), which
// opened gaps between runs. A title wider than the room falls back to one
// elided StyledText line with the matched runs in bold and no underline.
Item {
    id: root

    property string text: ""
    property var ranges: []
    property color color: Tokens.fg
    property color underline: Tokens.faint
    property string family: "Adwaita Sans"
    property int pixelSize: 13
    property bool mono: false
    readonly property int matchWeight: mono ? Font.Medium : Font.DemiBold

    implicitHeight: plainMetrics.height
    implicitWidth: highlighted ? line.width : natural.advance.width

    FontMetrics {
        id: plainMetrics
        font.family: root.family
        font.pixelSize: root.pixelSize
    }

    // [{ text, matched }] in order.
    readonly property var runs: {
        const out = [];
        const t = root.text, r = Array.isArray(root.ranges) ? root.ranges : [];
        let at = 0;
        const push = (from, to, matched) => {
            if (to > from) out.push({ text: t.slice(from, to), matched: matched });
        };
        for (const pair of r) {
            const s = Math.max(at, Math.min(t.length, pair[0])), e = Math.max(s, Math.min(t.length, pair[1]));
            push(at, s, false);
            push(s, e, true);
            at = e;
        }
        push(at, t.length, false);
        return out;
    }
    readonly property bool highlighted: runs.some(p => p.matched)
    readonly property bool fits: line.width <= root.width + 0.5

    function escaped(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // Laid out runs, shown when the title fits. Always built while highlighted
    // so its width can say whether it fits.
    Row {
        id: line
        visible: root.highlighted && root.fits
        height: root.height
        Repeater {
            model: root.highlighted ? root.runs : []
            Item {
                id: run
                required property var modelData
                width: label.advance.width
                height: line.height
                Text {
                    id: label
                    text: run.modelData.text
                    textFormat: Text.PlainText
                    color: root.color
                    font.family: root.family
                    font.pixelSize: root.pixelSize
                    font.weight: run.modelData.matched ? root.matchWeight : Font.Normal
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    visible: run.modelData.matched
                    width: label.implicitWidth
                    height: 1
                    color: root.underline
                    y: Math.round((root.height - plainMetrics.height) / 2 + plainMetrics.ascent + 3)
                }
            }
        }
    }
    // The plain title's own width, unaffected by the room it is given.
    Text {
        id: natural
        visible: false
        text: root.highlighted ? "" : root.text
        textFormat: Text.PlainText
        font.family: root.family
        font.pixelSize: root.pixelSize
    }
    // One line otherwise: no highlight, or a title too wide to lay out in runs.
    Text {
        visible: !line.visible
        anchors.verticalCenter: parent.verticalCenter
        width: root.width
        text: root.highlighted ? root.runs.map(p => p.matched ? "<b>" + root.escaped(p.text) + "</b>" : root.escaped(p.text)).join("") : root.text
        textFormat: root.highlighted ? Text.StyledText : Text.PlainText
        elide: Text.ElideRight
        maximumLineCount: 1
        color: root.color
        font.family: root.family
        font.pixelSize: root.pixelSize
    }
}
