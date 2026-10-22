import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Io
import qs.theme as ThemeModule

RowLayout {
    id: root

    property int workspaceCount: 10
    property color accent: ThemeModule.Theme.accent
    property color mutedAccent: ThemeModule.Theme.muted

    function workspaceFor(id) {
        for (const workspace of Hyprland.workspaces.values) {
            if (workspace.id === id)
                return workspace;

        }
        return null;
    }

    function activateWorkspace(id) {
        const workspace = workspaceFor(id);
        if (workspace) {
            workspace.activate();
        } else {
            workspaceProcess.running = false;
            workspaceProcess.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + id + " })"];
            workspaceProcess.running = true;
        }
    }

    spacing: 6
    implicitHeight: 21

    Process {
        id: workspaceProcess
    }

    Repeater {
        model: root.workspaceCount

        delegate: Rectangle {
            required property int index
            readonly property bool active: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === index + 1
            readonly property bool occupied: root.workspaceFor(index + 1) && root.workspaceFor(index + 1).toplevels.values.length > 0
            readonly property bool hovered: mouseArea.containsMouse
            readonly property bool highlighted: active || hovered

            visible: index < 5 || active || occupied
            Layout.preferredWidth: highlighted ? 46 : 21
            Layout.preferredHeight: 21
            radius: height / 2
            color: highlighted ? root.accent : "transparent"
            border.width: 2
            border.color: highlighted || occupied ? root.accent : root.mutedAccent

            Text {
                anchors.centerIn: parent
                text: parent.index + 1
                color: parent.active || parent.hovered ? ThemeModule.Theme.background : parent.occupied ? root.accent : root.mutedAccent
                font.family: "Rubik"
                font.pixelSize: 12

                Behavior on color {
                    ColorAnimation {
                        duration: 180
                    }

                }

            }

            MouseArea {
                id: mouseArea

                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.activateWorkspace(parent.index + 1)
            }

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: 180
                }

            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 180
                }

            }

        }

    }

}
