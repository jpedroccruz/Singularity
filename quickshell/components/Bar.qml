import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.modules.Bar
import qs.theme as ThemeModule

PanelWindow {
  id: bar

  anchors { top: true; left: true; right: true }
  implicitHeight: 30
  color: ThemeModule.Theme.darkBackground

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
    anchors.centerIn: parent
  }

  RowLayout {
    anchors.right: parent.right
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter

    AppTray {}
    Volume {}
    Network {}
  }
}