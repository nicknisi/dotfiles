// Compact notification history popup anchored to the registered bar bell.
import Quickshell
import QtQuick
import QtQuick.Layouts
import "MenuAnchor.js" as MenuAnchor

PopupWindow {
    id: center

    readonly property Item bellAnchor: NotificationState.centerAnchorItem
    readonly property var monitor: NotificationState.centerScreen
    readonly property string edge: NotificationState.centerEdge
    readonly property bool side: edge === "left" || edge === "right"
    readonly property real maxFrameHeight: Math.max(160,
        ((monitor && monitor.height) ? monitor.height : 720) - Theme.barExtent - 16 - 2 * Theme.shadowPadding)
    readonly property string headingFont: Theme.headingFont || Theme.font
    readonly property string uiFont: Theme.uiFont || Theme.font

    readonly property var offset: MenuAnchor.position(edge, "end", bellAnchor?.width ?? 0,
        bellAnchor?.height ?? 0, frame.width, frame.height, Theme.shadowPadding, 8)
    function reposition() { if (visible) anchor.updateAnchor(); }
    onOffsetChanged: reposition()
    visible: NotificationState.centerOpen && bellAnchor !== null
    anchor {
        item: center.bellAnchor
        rect.x: center.offset.x
        rect.y: center.offset.y
        rect.width: 1
        rect.height: 1
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        adjustment: PopupAdjustment.Slide
    }

    implicitWidth: Math.min(392, ((monitor && monitor.width) ? monitor.width : 480) - 2 * Theme.shadowPadding)
        + 2 * Theme.shadowPadding
    implicitHeight: Math.min(frame.implicitHeight, maxFrameHeight) + 2 * Theme.shadowPadding
    color: "transparent"
    grabFocus: true
    onClosed: NotificationState.closeCenter()

    onVisibleChanged: {
        if (visible) {
            NotificationState.markRead();
            frame.forceActiveFocus();
            center.reposition();
        }
    }

    Connections {
        target: NotificationState
        function onAnchorGeometryChanged() { center.reposition(); }
    }

    Connections {
        target: center.bellAnchor
        ignoreUnknownSignals: true
        function onXChanged() { center.reposition(); }
        function onYChanged() { center.reposition(); }
        function onWidthChanged() { center.reposition(); }
        function onHeightChanged() { center.reposition(); }
    }

    ShellSurface {
        id: frame
        x: Theme.shadowPadding
        y: Theme.shadowPadding
        width: parent.width - 2 * Theme.shadowPadding
        implicitHeight: Math.min(520, center.maxFrameHeight)
        height: Math.min(implicitHeight, center.maxFrameHeight)
        prominent: true
        fill: Theme.surface
        SurfaceShadow { surface: frame }
        focus: true
        Keys.onEscapePressed: NotificationState.closeCenter()
        MenuNavigation { scope: frame }

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Notifications"
                        color: Theme.fg
                        font.family: center.headingFont
                        font.pixelSize: Theme.fontSize + 7
                        font.bold: true
                    }
                    Text {
                        text: NotificationState.dnd
                            ? `${NotificationState.count} recent · do not disturb on`
                            : `${NotificationState.count} recent`
                        color: Theme.secondary
                        font.family: center.uiFont
                        font.pixelSize: Theme.fontSize - 2
                    }
                }

                BarModule {
                    text: "Close notifications"
                    onClicked: NotificationState.closeCenter()
                    Text {
                        text: ""
                        color: Theme.secondary
                        font.family: Theme.icons
                        font.pixelSize: 16
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                BarModule {
                    Layout.fillWidth: true
                    text: NotificationState.dnd ? "Turn off do not disturb" : "Turn on do not disturb"
                    highlighted: NotificationState.dnd
                    onClicked: NotificationState.toggleDnd()
                    Text {
                        text: NotificationState.dnd ? "  DND on" : "  DND off"
                        color: NotificationState.dnd ? Theme.yellow : Theme.accent
                        font.family: Theme.icons
                        font.pixelSize: Theme.fontSize
                    }
                }

                BarModule {
                    text: "Clear notification history"
                    enabled: NotificationState.count > 0
                    onClicked: NotificationState.clear()
                    Text {
                        text: "Clear"
                        color: Theme.secondary
                        font.family: center.uiFont
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.borderIdle
            }

            ListView {
                id: history

                Layout.fillWidth: true
                Layout.fillHeight: true
                model: NotificationState.history
                spacing: 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                activeFocusOnTab: true

                delegate: ShellSurface {
                    required property int index
                    required property string appName
                    required property string summary
                    required property string body
                    required property bool critical
                    required property double created

                    width: history.width
                    implicitHeight: notificationText.implicitHeight + 24
                    radius: Theme.controlRadius
                    fill: Theme.raised
                    prominent: critical
                    outlineColor: history.activeFocus && index === history.currentIndex ? Theme.accent : critical ? Theme.red : Theme.borderIdle

                    ColumnLayout {
                        id: notificationText
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                Layout.fillWidth: true
                                text: summary
                                color: Theme.fg
                                font.family: center.uiFont
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: Qt.formatDateTime(new Date(created), "HH:mm")
                                color: Theme.secondary
                                font.family: center.uiFont
                                font.pixelSize: Theme.fontSize - 3
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: appName
                            color: critical ? Theme.red : Theme.accent
                            font.family: center.uiFont
                            font.pixelSize: Theme.fontSize - 3
                            visible: text !== ""
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: body
                            color: Theme.secondary
                            font.family: center.uiFont
                            font.pixelSize: Theme.fontSize - 1
                            textFormat: Text.StyledText
                            wrapMode: Text.WordWrap
                            maximumLineCount: 6
                            elide: Text.ElideRight
                            visible: text !== ""
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "No notifications yet"
                    color: Theme.secondary
                    font.family: center.uiFont
                    font.pixelSize: Theme.fontSize
                    visible: NotificationState.count === 0
                }
            }
        }
    }
}
