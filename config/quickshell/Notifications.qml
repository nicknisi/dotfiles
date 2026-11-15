// Notifications.qml - the toasts, in the classic bar modes (pill, full, rail).
//
// The D-Bus server itself lives in NotificationServer.qml (PLAN M3), so the
// island can show the same notifications as banners. In island mode these
// toasts stay hidden and the island's notif state takes their place.
//
// Critical notifications stay until acted on; everything else goes after the
// sender's timeout, or 4200 ms when it asks for the default
// (IslandMachine.notifTimeout, the rule the island banner uses too).
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import "lib/IslandMachine.js" as IslandMachine

Scope {
    id: root

    // The NotificationServer.qml instance (shell.qml).
    property var source: null
    readonly property var server: root.source?.server ?? NotificationState.server
    readonly property var tracked: root.server?.trackedNotifications ?? null

    PanelWindow {
        id: popups

        // Top right by default, dropping to the bottom right when the capsule
        // is along the bottom, and stepping in when it is along the right.
        anchors { top: Prefs.edge !== "bottom"; bottom: Prefs.edge === "bottom"; right: true }
        margins {
            top:    Prefs.edge === "top"    ? Theme.barHeight + 8  : 8
            bottom: Prefs.edge === "bottom" ? Theme.barHeight + 8  : 8
            right:  Prefs.edge === "right"  ? Theme.barHeight + 12 : 8
        }

        implicitWidth: 380 + 2 * Theme.shadowPadding
        implicitHeight: Math.max(1, layout.implicitHeight + 2 * Theme.shadowPadding)
        mask: Region { item: layout }

        color: "transparent"
        visible: Prefs.barMode !== "island" && (root.tracked?.values ?? []).some(notification =>
            !NotificationState.dnd || notification.urgency === NotificationUrgency.Critical)

        // Float over everything, and never reserve screen space.
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore

        ColumnLayout {
            id: layout
            x: Theme.shadowPadding
            y: Theme.shadowPadding
            width: parent.width - 2 * Theme.shadowPadding
            spacing: Theme.shadowPadding

            Repeater {
                model: root.tracked

                Rectangle {
                    id: toast
                    required property var modelData

                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical

                    visible: !NotificationState.dnd || critical
                    Layout.fillWidth: true
                    implicitHeight: content.implicitHeight + 20
                    radius: Theme.panelRadius
                    color: Theme.bgAlt
                    SurfaceShadow { surface: toast }
                    border.width: 1
                    border.color: critical ? Theme.red
                                : modelData.urgency === NotificationUrgency.Low ? Theme.muted
                                : Theme.blue

                    // Critical notifications stay until acted on; that is the whole
                    // point of the urgency. Everything else uses the sender's
                    // timeout, falling back to 4200 ms when it asks for the
                    // default (-1). In island mode the island's banner owns the
                    // timeout instead.
                    Timer {
                        running: !parent.critical && Prefs.barMode !== "island"
                        interval: Math.max(1, IslandMachine.notifTimeout(modelData.expireTimeout, parent.critical))
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
                                    color: Theme.secondary
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

                    // Click to go to it: the sender's default action first (Slack
                    // jumps to the message), then the window itself, whatever
                    // workspace it is on. Right click only dismisses. Placed after
                    // the content so action buttons win the click.
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton)
                                NotificationState.open(modelData);
                            else
                                modelData.dismiss();
                        }
                    }
                }
            }
        }
    }
}
