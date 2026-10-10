import QtQuick

Rectangle {
  id: root

  property color iconColor: "#FFA376"

  implicitWidth: indicator.implicitWidth + 22
  implicitHeight: 30
  color: "transparent"

  Text {
    id: indicator
    anchors.centerIn: parent
    text: "tune"
    color: root.iconColor
    font.family: "Material Symbols Rounded"
    font.pixelSize: 18
  }

  Rectangle {
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: indicator.implicitWidth
    height: 2
    radius: height / 2
    color: root.iconColor
    visible: mouseArea.containsMouse
  }

  MouseArea {
    id: mouseArea
    cursorShape: Qt.PointingHandCursor
    anchors.fill: parent
    hoverEnabled: true
  }
}
