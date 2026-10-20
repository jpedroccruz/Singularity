import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.Bar
import qs.theme as ThemeModule

PanelWindow {
    id: bar

    implicitHeight: 30
    color: ThemeModule.Theme.darkBackground

    anchors {
        top: true
        left: true
        right: true
    }

    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Image {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            source: Qt.resolvedUrl("../modules/Bar/assets/singularity.svg")
            fillMode: Image.PreserveAspectFit
            smooth: true

            Process {
                id: launcherProc

                command: ["qs", "ipc", "call", "launcher", "toggle"]
            }

            MouseArea {
                id: mouseArea

                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                hoverEnabled: true
                onClicked: launcherProc.running = true
            }

        }

        Workspaces {
            Layout.alignment: Qt.AlignVCenter
        }

    }

    Clock {
        id: clock

        anchors.centerIn: parent
    }

    Updates {
        anchors.verticalCenter: clock.verticalCenter
        anchors.right: clock.left
        anchors.rightMargin: 12
    }

    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        AppTray {
        }

        Volume {
        }

        Network {
        }

    }

}
