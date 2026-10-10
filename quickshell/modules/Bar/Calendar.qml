import Quickshell
import QtQuick
import QtQuick.Layouts

PopupWindow {
  id: calendar

  property var target
  property date selectedDate: new Date()
  property date displayedDate: new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1)
  property color accent: "#FFA376"
  property color background: "#17100B"
  property color muted: "#765B50"
  property color gridLine: "#3A2922"
  property int calendarSideMargin: 34

  anchor.item: target
  anchor.rect.x: target ? target.width / 2 - implicitWidth / 2 : 0
  anchor.rect.y: target ? target.height + 8 : 0
  implicitWidth: 480
  implicitHeight: 395
  visible: false
  color: "transparent"
  grabFocus: false
  onVisibleChanged: {
    if (!visible) calendarHover.wasHovered = false
  }

  function monthName(month) {
    return ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
      "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"][month]
  }

  function daysInMonth(year, month) {
    return new Date(year, month + 1, 0).getDate()
  }

  function cellDate(index) {
    const first = new Date(displayedDate.getFullYear(), displayedDate.getMonth(), 1)
    const offset = (first.getDay() + 6) % 7
    return new Date(first.getFullYear(), first.getMonth(), index - offset + 1)
  }

  function sameDate(left, right) {
    return left.getFullYear() === right.getFullYear()
      && left.getMonth() === right.getMonth()
      && left.getDate() === right.getDate()
  }

  function changeMonth(amount) {
    displayedDate = new Date(displayedDate.getFullYear(), displayedDate.getMonth() + amount, 1)
  }

  function dayOfYear(date) {
    const start = new Date(date.getFullYear(), 0, 1)
    return Math.floor((date - start) / 86400000) + 1
  }

  Rectangle {
    anchors.fill: parent
    color: calendar.background
    border.width: 2
    border.color: calendar.accent
    radius: 15

    HoverHandler {
      id: calendarHover
      property bool wasHovered: false
      cursorShape: Qt.PointingHandCursor
      onHoveredChanged: {
        if (hovered) {
          wasHovered = true
          calendarCloseTimer.stop()
        } else if (wasHovered) {
          calendarCloseTimer.restart()
        }
      }
    }

    Timer {
      id: calendarCloseTimer
      interval: 180
      onTriggered: {
        if (!calendarHover.hovered) {
          calendar.visible = false
          calendarHover.wasHovered = false
        }
      }
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 26
      anchors.bottomMargin: 38
      spacing: 12

      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 14

        Text {
          text: "calendar_month"
          color: calendar.accent
          font.family: "Material Symbols Rounded"
          font.pixelSize: 42
        }

        Text {
          text: calendar.monthName(calendar.selectedDate.getMonth()) + " "
            + calendar.selectedDate.getDate()
          color: calendar.accent
          font.family: "Rubik"
          font.pixelSize: 44
          font.bold: true
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        Layout.leftMargin: calendar.calendarSideMargin
        Layout.rightMargin: calendar.calendarSideMargin
        spacing: 10

        Text {
          text: calendar.selectedDate.getFullYear()
          color: calendar.muted
          font.family: "Rubik"
          font.pixelSize: 12
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 5
          color: calendar.gridLine
          radius: 2

          Rectangle {
            width: parent.width * calendar.dayOfYear(calendar.selectedDate)
              / (calendar.selectedDate.getFullYear() % 4 === 0 ? 366 : 365)
            height: parent.height
            color: calendar.accent
            radius: 2
          }
        }

        Text {
          text: Math.round(calendar.dayOfYear(calendar.selectedDate)
            / (calendar.selectedDate.getFullYear() % 4 === 0 ? 366 : 365) * 100) + "%"
          color: calendar.muted
          font.family: "Rubik"
          font.pixelSize: 12
        }
      }

      GridLayout {
        id: calendarGrid
        columns: 7
        rowSpacing: 6
        columnSpacing: 0
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        Layout.leftMargin: calendar.calendarSideMargin
        Layout.rightMargin: calendar.calendarSideMargin

        Repeater {
          model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

          Text {
            required property string modelData
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: modelData
            color: calendar.muted
            font.family: "Rubik"
            font.pixelSize: 10
          }
        }

        Repeater {
          model: 42

          delegate: Rectangle {
            required property int index
            property date day: calendar.cellDate(index)
            property bool currentMonth: day.getMonth() === calendar.displayedDate.getMonth()
            property bool selected: calendar.sameDate(day, calendar.selectedDate)

            Layout.fillWidth: true
            Layout.preferredHeight: 29
            color: selected ? calendar.gridLine : "transparent"
            border.width: selected ? 1 : 0
            border.color: calendar.accent

            Text {
              anchors.centerIn: parent
              text: parent.day.getDate()
              color: parent.selected
                ? calendar.accent
                : parent.currentMonth ? calendar.accent : calendar.muted
              font.family: "Rubik"
              font.pixelSize: 13
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                calendar.selectedDate = parent.day
                calendar.displayedDate = new Date(parent.day.getFullYear(), parent.day.getMonth(), 1)
              }
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: calendarGrid.width
        Layout.alignment: Qt.AlignHCenter
        Layout.leftMargin: calendar.calendarSideMargin
        Layout.rightMargin: calendar.calendarSideMargin
        spacing: 12

        Text {
          text: "<"
          color: calendar.accent
          font.pixelSize: 18
          MouseArea { anchors.fill: parent; onClicked: calendar.changeMonth(-1) }
        }

        Text {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: calendar.monthName(calendar.displayedDate.getMonth()) + " "
            + calendar.displayedDate.getFullYear()
          color: calendar.muted
          font.family: "Rubik"
          font.pixelSize: 12
        }

        Text {
          text: ">"
          color: calendar.accent
          font.pixelSize: 18
          MouseArea { anchors.fill: parent; onClicked: calendar.changeMonth(1) }
        }
      }
    }
  }
}
