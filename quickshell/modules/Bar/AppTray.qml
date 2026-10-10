import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root

  property color iconColor: "#FFA376"
  property color mutedColor: "#765B50"
  property var parentWindow
  property var contextItem
  color: "transparent"

  function activateItem(item) {
    if (item.id === "spotify-client") {
      spotifyProcess.running = false
      spotifyProcess.command = ["spotify"]
      spotifyProcess.running = true
    } else {
      item.activate()
    }
  }

  Process {
    id: spotifyProcess
  }

  QsMenuOpener {
    id: menuOpener
    menu: root.contextItem ? root.contextItem.menu : null
  }

  implicitWidth: indicator.implicitWidth + 18
  implicitHeight: 30

  Text {
    id: indicator
    anchors.centerIn: parent
    text: "keyboard_arrow_down"
    color: root.iconColor
    font.family: "Material Symbols Rounded"
    font.pixelSize: 24
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
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onPressed: function(event) {
      if (event.button === Qt.LeftButton) {
        popup.showingMenu = false
        trayHover.wasHovered = false
        trayCloseTimer.stop()
        popup.visible = !popup.visible
      }
    }
  }

  PopupWindow {
    id: popup

    property bool showingMenu: false

    anchor.item: root
    anchor.rect.x: root.width / 2 - implicitWidth / 2
    anchor.rect.y: root.height + 6
    implicitWidth: showingMenu
      ? Math.max(220, menuColumn.implicitWidth + 20)
      : Math.max(180, trayLayout.implicitWidth + 20)
    implicitHeight: showingMenu
      ? Math.max(48, trayLayout.implicitHeight + menuColumn.implicitHeight + 30)
      : Math.max(48, trayLayout.implicitHeight + 20)
    visible: false
    color: "transparent"
    grabFocus: false
    onVisibleChanged: {
      if (!visible) showingMenu = false
    }

    Rectangle {
      anchors.fill: parent
      color: "#17100B"
      border.width: 2
      border.color: root.iconColor
      radius: 10

      HoverHandler {
        id: trayHover
        property bool wasHovered: false
        onHoveredChanged: {
          if (hovered) {
            wasHovered = true
            trayCloseTimer.stop()
          } else if (wasHovered) {
            trayCloseTimer.restart()
          }
        }
      }

      Timer {
        id: trayCloseTimer
        interval: 250
        onTriggered: {
          if (!trayHover.hovered) {
            popup.visible = false
          }
        }
      }

      RowLayout {
        id: trayLayout
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 10
        spacing: 12

        Repeater {
          model: SystemTray.items

          delegate: MouseArea {
            required property var modelData

            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: function(event) {
              if (event.button === Qt.LeftButton) {
                event.accepted = true
                root.activateItem(modelData)
                popup.visible = false
                return
              }

              if (event.button === Qt.RightButton) {
                event.accepted = true
                root.contextItem = modelData
                trayCloseTimer.stop()
                trayHover.wasHovered = false
                popup.showingMenu = modelData.hasMenu
              }
            }

            Image {
              anchors.centerIn: parent
              source: parent.modelData.icon
              sourceSize.width: 22
              sourceSize.height: 22
              width: 22
              height: 22
              fillMode: Image.PreserveAspectFit
              smooth: true
            }
          }
        }
      }

      ColumnLayout {
        id: menuColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: trayLayout.bottom
        anchors.topMargin: 8
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 2
        visible: popup.showingMenu

        HoverHandler {
          id: menuHover
          property bool wasHovered: false
          onHoveredChanged: {
            if (hovered) {
              wasHovered = true
              menuCloseTimer.stop()
            } else if (wasHovered) {
              menuCloseTimer.restart()
            }
          }
        }

        Timer {
          id: menuCloseTimer
          interval: 180
          onTriggered: {
            if (!menuHover.hovered) {
              popup.visible = false
              menuHover.wasHovered = false
            }
          }
        }

        Repeater {
          model: menuOpener.children

          delegate: Rectangle {
            required property var modelData

            Layout.fillWidth: true
            Layout.preferredHeight: modelData.isSeparator ? 1 : 30
            color: modelData.isSeparator
              ? root.iconColor
              : menuMouseArea.containsMouse ? "#2A1D18" : "transparent"

            MouseArea {
              id: menuMouseArea
              anchors.fill: parent
              hoverEnabled: !modelData.isSeparator
              enabled: !modelData.isSeparator && modelData.enabled
              onClicked: {
                modelData.triggered()
                popup.visible = false
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              visible: !modelData.isSeparator

              Image {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                source: modelData.icon
                sourceSize.width: 18
                sourceSize.height: 18
                visible: modelData.icon !== ""
                fillMode: Image.PreserveAspectFit
                smooth: true
              }

              Text {
                Layout.fillWidth: true
                text: modelData.text
                color: modelData.enabled ? root.iconColor : root.mutedColor
                font.family: "Rubik"
                font.pixelSize: 13
                elide: Text.ElideRight
              }
            }
          }
        }
      }
    }
  }
}
