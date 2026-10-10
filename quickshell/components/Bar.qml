import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.modules.Bar

PanelWindow {
  id: bar

  anchors { top: true; left: true; right: true }
  implicitHeight: 30
  color: "#17100B"

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

      MouseArea {
        id: mouseArea
        cursorShape: Qt.PointingHandCursor
        anchors.fill: parent
        hoverEnabled: true
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

    AppTray {
      parentWindow: bar
    }
    Volume {}
    Network {}
    ControlPanel {}
  }

}