import QtQuick
import qs
import qs.Kit
import "../lib/CrewModel.js" as CrewModel

// CrewPanel.qml - the island grown into the Crew (personal-looks 3.5, Personal board).
//
//   ┌ The Crew  4 aboard                    Today  $4.37 ┐   header 30
//   │ [bot]  Pi                                needs you │   rows 52, gap 8
//   │        tmux · waiting for approval                 │
//   │ [bot]  Riker · worker                     working  │
//   │ ...                                                │
//   │      Click a bot to jump to its window or tmux pane│   footer 11
//   └────────────────────────────────────────────────────┘
//
// 460 wide, or as wide as the rest pill when that is wider: the panel opens
// from the bots at the pill's right end, and a narrower panel would morph out
// from under the pointer that opened it, which then closes it (M2 review).
// Padding 16, as tall as its rows (CrewModel.panelHeight, which the island
// morphs to), the footer two gaps below the last row (the board's spacer).
// Up to seven rows fit under the island's 560 ceiling; past that, "+N more".
// A row that needs you sits on `accentTint`; hover is `fillLow`, pressed
// `fillHigh`, the keyboard selection a 1 px `accent` ring. On the tint the
// where line and the state word keep their mood colours only where those read
// at 4.5:1, else `fg` (inkDim on accentTint is under 4.5 on 31 of the 37
// packs, accent on 19; fg passes on all, tests/token-parity.cjs).
// Riker workers and Rex have no window, so their rows do not jump and do not
// light up; the where line names the job instead.
//
// Rows are built from the shown ids only (the CrewStrip gate), so the feed's
// answers every few seconds do not rebuild them or restart their bots. Their
// bots share one Kit/CrewClock and stagger like the rest pill's.
//
// Data in as plain values from Island/IslandView. jump(id) goes back up; the
// view asks Crew to run bin/crew-jump.
Layer {
    id: panel

    property var agents: []
    property int total: 0
    property var spendToday: null
    property real dpr: 1
    // The rest pill's width (its body width): the panel is never narrower.
    property real restWidth: 0
    // The host's gate on the bots' loops (the session not idle).
    property bool animated: true
    // Keyboard selection, an index into the shown rows; -1 for none.
    property int selected: -1

    signal jump(string id)
    signal pin

    readonly property var shownRows: CrewModel.rows(panel.agents)
    readonly property real hugHeight: CrewModel.panelHeight((panel.agents || []).length)
    property var ids: []
    readonly property var byId: {
        const map = {};
        for (const a of (panel.agents || []))
            map[a.id] = a;
        return map;
    }
    readonly property int builds: rows.builds
    readonly property alias footer: footer
    readonly property alias clock: rowClock

    width: Math.max(CrewModel.PANEL.width, panel.restWidth)
    height: hugHeight

    // The row drawn for ids[index], for tests.
    function rowAt(index: int): Item {
        return rows.itemAt(index);
    }

    function syncIds() {
        const next = panel.shownRows.shown.map(a => String(a.id));
        const same = next.length === panel.ids.length && next.every((id, i) => id === panel.ids[i]);
        if (!same) panel.ids = next;
        if (panel.selected >= next.length) panel.selected = next.length - 1;
    }
    onShownRowsChanged: syncIds()
    Component.onCompleted: syncIds()

    // Keyboard: start on the first row that needs you, else the first row.
    function move(step: int) {
        const n = panel.ids.length;
        if (n === 0) return;
        if (panel.selected < 0) {
            const first = panel.ids.findIndex(id => panel.byId[id]?.attention);
            panel.selected = first >= 0 ? first : 0;
            return;
        }
        panel.selected = Math.max(0, Math.min(n - 1, panel.selected + step));
    }
    function activate() {
        const id = panel.ids[panel.selected];
        if (id && panel.byId[id]?.jumpable) panel.jump(id);
    }
    onCurrentChanged: if (!current) selected = -1

    // Every second working row's bot starts half a bob later (CrewStrip.phaseFor).
    function phaseFor(index: int): int {
        let working = 0;
        for (let i = 0; i < index; i++)
            if (panel.byId[panel.ids[i]]?.mood === "working") working++;
        return (working % 2) * 2;
    }
    // Text on the needs row's accentTint: the colour wanted where it reads at 4.5:1, else fg.
    function onTint(wanted: color): color {
        return Tokens.contrast(wanted, Tokens.accentTint) >= 4.5 ? wanted : Tokens.fg;
    }

    CrewClock {
        id: rowClock
        step: CrewModel.clockStep(panel.ids.map(id => panel.byId[id]?.mood ?? "asleep"))
        running: panel.current && panel.animated && Motion.loops
    }

    Accessible.role: Accessible.Grouping
    Accessible.name: CrewModel.summary({ total: panel.total, attention: (panel.agents || []).filter(a => a.attention).length })

    // Empty panel space pins it, like the rest pill's button.
    MouseArea {
        anchors.fill: parent
        onClicked: panel.pin()
        Accessible.ignored: true
    }

    Column {
        x: CrewModel.PANEL.padding
        y: CrewModel.PANEL.padding
        width: parent.width - 2 * CrewModel.PANEL.padding
        spacing: CrewModel.PANEL.gap

        // ---- header ----
        Item {
            width: parent.width
            height: CrewModel.PANEL.header
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "The Crew"
                    color: Tokens.fg
                    font.family: "Adwaita Sans"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.total + " aboard"
                    color: Tokens.inkDim
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: spendText.text !== ""
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Today"
                    color: Tokens.inkDim
                    font.family: "Adwaita Sans"
                    font.pixelSize: 12
                }
                Text {
                    id: spendText
                    anchors.verticalCenter: parent.verticalCenter
                    text: CrewModel.money(panel.spendToday)
                    color: Tokens.fg
                    font.family: "Monaspace Argon"
                    font.pixelSize: 12
                }
            }
        }

        // ---- rows ----
        Column {
            width: parent.width
            spacing: CrewModel.PANEL.gap
            visible: panel.ids.length > 0

            Repeater {
                id: rows
                property int builds: 0
                model: panel.ids
                delegate: Rectangle {
                    id: row
                    required property string modelData
                    required property int index
                    readonly property var agent: panel.byId[modelData] ?? null
                    readonly property bool needs: agent?.attention === true
                    readonly property bool jumpable: agent?.jumpable === true
                    readonly property bool selected: panel.selected === index
                    readonly property alias bot: rowBot
                    readonly property alias whereLine: whereText
                    readonly property alias stateLine: stateWord

                    width: parent.width
                    height: CrewModel.PANEL.row
                    radius: 12
                    color: needs ? Tokens.accentTint : rowPointer.pressed && jumpable ? Tokens.fillHigh
                        : rowPointer.containsMouse && jumpable ? Tokens.fillLow : "transparent"
                    border.width: selected ? 1 : 0
                    border.color: Tokens.accent
                    Component.onCompleted: rows.builds++

                    Accessible.role: Accessible.Button
                    Accessible.name: (agent?.name ?? "") + ", " + (agent?.state ?? "")
                    Accessible.description: agent?.where ?? ""
                    Accessible.onPressAction: if (row.jumpable) panel.jump(row.modelData)

                    Rectangle {
                        id: tile
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 34
                        radius: 10
                        color: Tokens.raised
                        CrewBot {
                            id: rowBot
                            anchors.centerIn: parent
                            mood: row.agent?.mood ?? "asleep"
                            riker: row.agent?.riker === true
                            dpr: panel.dpr
                            phase: panel.phaseFor(row.index)
                            clock: rowClock
                        }
                    }
                    Column {
                        anchors.left: tile.right
                        anchors.leftMargin: 12
                        anchors.right: stateWord.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            width: parent.width
                            text: row.agent?.name ?? ""
                            color: Tokens.fg
                            elide: Text.ElideRight
                            font.family: "Adwaita Sans"
                            font.pixelSize: 13
                        }
                        Text {
                            id: whereText
                            width: parent.width
                            text: row.agent?.where ?? ""
                            color: row.needs ? panel.onTint(Tokens.inkDim) : Tokens.inkDim
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.family: "Adwaita Sans"
                            font.pixelSize: 12
                        }
                    }
                    Text {
                        id: stateWord
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.agent?.state ?? ""
                        color: row.needs ? panel.onTint(Tokens.accent) : Tokens.inkDim
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: rowPointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: row.jumpable ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: row.jumpable ? panel.jump(row.modelData) : panel.pin()
                    }
                }
            }
        }

        // No agents: one row's worth of words [NOT IN MOCK].
        Item {
            width: parent.width
            height: CrewModel.PANEL.row
            visible: panel.ids.length === 0
            Text {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "No agents running"
                color: Tokens.inkDim
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
        }

        Text {
            visible: panel.shownRows.more > 0
            x: 10
            height: CrewModel.PANEL.more
            verticalAlignment: Text.AlignVCenter
            text: "+" + panel.shownRows.more + " more"
            color: Tokens.inkDim
            font.family: "Adwaita Sans"
            font.pixelSize: 12
        }

        // The board's flexible spacer: one more gap above the footer. (A
        // zero-height item would not do: Column skips empty items.)
        Item {
            id: footer
            width: parent.width
            height: CrewModel.PANEL.gap + CrewModel.PANEL.footer
            Text {
                y: CrewModel.PANEL.gap
                width: parent.width
                height: CrewModel.PANEL.footer
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "Click a bot to jump to its window or tmux pane"
                color: Tokens.inkDim
                font.family: "Adwaita Sans"
                font.pixelSize: 11
            }
        }
    }
}
