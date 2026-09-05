// Spark.qml - a rolling series as a row of tiny bars.
//
// Bars rather than a polyline because the rest of the desktop is squared off:
// rounding is 0 everywhere, so a curve would be the only soft thing on screen.
//
// Older samples fade toward the left, which gives the strip a direction without
// needing an axis, a label or a border.
//
// An Item wrapping a Row rather than being one, because a positioner computes
// its own implicit size from its children, and children sized off the parent
// would chase it around forever.
import QtQuick

Item {
    id: spark

    property var values: []
    property color tint: Theme.fg

    // Scaled to the tallest sample in the window rather than to a flat 0..100.
    // A laptop sits under 10% almost all the time, so an absolute scale draws a
    // 1px line and throws away the only thing a sparkline is for, which is the
    // shape of the change. `floor` stops an idle machine amplifying its own
    // rounding noise into a mountain range.
    property real floor: 25
    readonly property real peak: {
        let m = spark.floor;
        for (const v of spark.values) m = Math.max(m, v ?? 0);
        return m;
    }
    // No gap between bars. Spaced bars at these values read as a dotted line
    // rather than as a graph, because an idle machine only ever fills a few
    // pixels of each one; butted together they make a single silhouette that is
    // legible at a glance.
    property int barWidth: 3
    property int barGap: 0

    implicitHeight: 14
    implicitWidth: values.length * barWidth + Math.max(0, values.length - 1) * barGap

    Row {
        anchors.fill: parent
        spacing: spark.barGap

        Repeater {
            model: spark.values

            Item {
                required property int index
                required property var modelData

                width: spark.barWidth
                height: spark.height

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    // A floor of 1px so an idle series still reads as a series
                    // rather than as empty space.
                    height: Math.max(1, parent.height * Math.min(1, (modelData ?? 0) / spark.peak))
                    color: spark.tint
                    opacity: 0.4 + 0.6 * (index / Math.max(1, spark.values.length - 1))

                    Behavior on height {
                        NumberAnimation { duration: Theme.base; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
