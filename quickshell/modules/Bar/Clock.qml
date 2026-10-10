import QtQuick
import qs.modules.Bar as Modules

Rectangle {
  id: clock

  property string icon: ""
  property color iconColor: "#FFA376"
  property real maxLabelWidth: -1
  property string value: Qt.formatDateTime(new Date(), "ddd MMM dd HH:mm")
  property int interval: 1000

  implicitWidth: content.implicitWidth
  color: "transparent"
  implicitHeight: content.implicitHeight

  Modules.Item {
    id: content
    anchors.centerIn: parent
    icon: clock.icon
    label: clock.value
    iconColor: clock.iconColor
    maxLabelWidth: clock.maxLabelWidth
  }

  MouseArea {
    id: clockMouseArea
    cursorShape: Qt.PointingHandCursor
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    onPressed: function(event) {
      if (event.button === Qt.LeftButton) {
        event.accepted = true
        calendar.visible = !calendar.visible
      }
    }
  }

  Calendar {
    id: calendar
    target: clock
  }

  Timer {
    interval: clock.interval
    running: true
    repeat: true
    onTriggered: clock.value = Qt.formatDateTime(new Date(), "ddd MMM dd HH:mm")
  }
}
