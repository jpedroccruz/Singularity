import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root

  property string icon: ""
  property string label: ""
  property color iconColor: "#FFA376"
  property real maxLabelWidth: -1
  property bool hovered: mouseArea.containsMouse

  implicitWidth: row.implicitWidth + 22
  implicitHeight: 33
  radius: height / 2
  color: "transparent"

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 7

    Text {
      text: root.icon
      color: root.iconColor
      font.family: "Material Symbols Rounded"
      font.pixelSize: 16
      visible: root.icon !== ""
    }

    Text {
      text: root.label
      color: root.iconColor
      font.family: "Rubik"
      font.pixelSize: 16
      elide: Text.ElideRight
      Layout.maximumWidth: root.maxLabelWidth > 0 ? root.maxLabelWidth : Infinity
      visible: root.label !== ""
    }
  }

  Rectangle {
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: row.width
    height: 3
    color: root.iconColor
    visible: root.hovered
    radius: height / 2
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
  }
}