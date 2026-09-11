// Full-height notification history sidebar on the right edge.
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: center

    visible: NotificationState.centerOpen && NotificationState.centerScreen !== null
    screen: NotificationState.centerScreen
    anchors { top: true; right: true; bottom: true; left: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "notification-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: NotificationState.closeCenter()
    }

    Rectangle {
        id: frame
        anchors { top: parent.top; right: parent.right; bottom: parent.bottom; margins: Theme.gap }
        width: Math.min(420, parent.width - 2 * Theme.gap)
        radius: Theme.panelRadius
        color: Theme.surface
        SurfaceShadow { surface: frame }
        MouseArea {
            anchors.fill: parent
            onClicked: mouse => mouse.accepted = true
        }
        border.width: 1
        border.color: Theme.borderActive
        focus: center.visible
        Keys.onEscapePressed: NotificationState.closeCenter()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
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
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 7
                        font.bold: true
                    }
                    Text {
                        text: NotificationState.dnd
                            ? `${NotificationState.count} recent · do not disturb on`
                            : `${NotificationState.count} recent`
                        color: Theme.secondary
                        font.family: Theme.font
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
                        font.family: Theme.font
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

                delegate: Rectangle {
                    required property string appName
                    required property string summary
                    required property string body
                    required property bool critical
                    required property double created

                    width: history.width
                    implicitHeight: notificationText.implicitHeight + 24
                    radius: Theme.controlRadius
                    color: Theme.raised
                    border.width: critical ? 1 : 0
                    border.color: Theme.red

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
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: Qt.formatDateTime(new Date(created), "HH:mm")
                                color: Theme.secondary
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 3
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: appName
                            color: critical ? Theme.red : Theme.accent
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 3
                            visible: text !== ""
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: body
                            color: Theme.secondary
                            font.family: Theme.font
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
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    visible: NotificationState.count === 0
                }
            }
        }
    }
}
