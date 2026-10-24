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

    // LEFT
    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Image {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            source: Qt.resolvedUrl("../modules/Bar/assets/singularity.svg")
            smooth: true

            Process {
                id: launcherProc

                command: ["qs", "ipc", "call", "powermenu", "toggle"]
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

        Song {
            Layout.alignment: Qt.AlignVCenter
        }

    }

    // CENTER
    Clock {
        id: clock

        anchors.centerIn: parent
        muted: notifMute.muted
        onSuppressed: (app, entry) => {
            return notifMute.silence(app, entry);
        }
    }

    Updates {
        anchors.verticalCenter: clock.verticalCenter
        anchors.right: clock.left
        anchors.rightMargin: 12
    }

    Row {
        id: rightOfClock

        anchors.verticalCenter: clock.verticalCenter
        anchors.left: clock.right
        anchors.leftMargin: 12
        spacing: 12

        Tasks {
            barHovered: barHover.hovered
        }

        NotificationMute {
            id: notifMute

            barHovered: barHover.hovered
        }

        NightLight {
            barHovered: barHover.hovered
        }

        IdleInhibitor {
            barHovered: barHover.hovered
        }

        Pomodoro {
            barHovered: barHover.hovered
        }

    }

    // Detector compartilhado da barra.
    // Fica abaixo dos módulos para não interferir na interação.
    HoverHandler {
        id: barHover
    }

    // RIGHT
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
