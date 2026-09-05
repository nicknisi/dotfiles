// Notifications.qml - the piece that was missing entirely.
//
// Nothing owned org.freedesktop.Notifications on this machine, so every notification
// was being dropped on the floor, including batsignal's low-battery warnings.
// Declaring a NotificationServer claims that bus name.
//
// A notification is discarded the moment the callback returns unless something
// marks it `tracked`, which is what onNotification does below.
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    NotificationServer {
        id: server

        // Advertised capabilities. Senders check these, so only claim what the
        // delegate below actually renders.
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: false
        inlineReplySupported: false

        onNotification: notification => {
            notification.tracked = true;
        }
    }

    PanelWindow {
        id: popups

        anchors { top: true; right: true }
        margins { top: Theme.barHeight + 8; right: 8 }

        implicitWidth: 380
        implicitHeight: Math.max(1, layout.implicitHeight)

        color: "transparent"
        visible: server.trackedNotifications.values.length > 0

        // Float over everything, and never reserve screen space.
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore

        ColumnLayout {
            id: layout
            width: parent.width
            spacing: 8

            Repeater {
                model: server.trackedNotifications

                Rectangle {
                    required property var modelData

                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical

                    Layout.fillWidth: true
                    implicitHeight: content.implicitHeight + 20
                    radius: 6
                    color: Theme.bgAlt
                    border.width: 1
                    border.color: critical ? Theme.red
                                : modelData.urgency === NotificationUrgency.Low ? Theme.muted
                                : Theme.blue

                    // Critical notifications stay until acted on; that is the whole
                    // point of the urgency. Everything else uses the sender's
                    // timeout, falling back to 5s when it asks for the default (-1).
                    Timer {
                        running: !parent.critical
                        interval: modelData.expireTimeout > 0 ? modelData.expireTimeout : 5000
                        onTriggered: modelData.expire()
                    }

                    ColumnLayout {
                        id: content
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Image {
                                visible: source != ""
                                source: modelData.image !== "" ? modelData.image
                                      : modelData.appIcon !== "" ? `image://icon/${modelData.appIcon}`
                                      : ""
                                sourceSize.width: 32
                                sourceSize.height: 32
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                fillMode: Image.PreserveAspectFit
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.appName
                                    color: Theme.muted
                                    elide: Text.ElideRight
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 3
                                    visible: text !== ""
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.summary
                                    color: Theme.fg
                                    elide: Text.ElideRight
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.body
                            color: Theme.fg
                            visible: text !== ""
                            wrapMode: Text.WordWrap
                            maximumLineCount: 6
                            elide: Text.ElideRight
                            textFormat: Text.StyledText
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
                        }

                        RowLayout {
                            spacing: 6
                            visible: modelData.actions.length > 0

                            Repeater {
                                model: modelData.actions

                                Rectangle {
                                    required property var modelData

                                    implicitWidth: actionText.implicitWidth + 16
                                    implicitHeight: actionText.implicitHeight + 8
                                    radius: 4
                                    color: actionArea.containsMouse ? Theme.muted : Theme.bg

                                    Text {
                                        id: actionText
                                        anchors.centerIn: parent
                                        text: parent.modelData.text
                                        color: Theme.fg
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize - 2
                                    }

                                    MouseArea {
                                        id: actionArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: parent.modelData.invoke()
                                    }
                                }
                            }
                        }
                    }

                    // Click anywhere else to dismiss. Placed after the content so
                    // action buttons win the click.
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: modelData.dismiss()
                    }
                }
            }
        }
    }
}
