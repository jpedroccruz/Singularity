import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.theme as ThemeModule

Rectangle {
  id: root

  property color iconColor: ThemeModule.Theme.accent
  property color mutedColor: ThemeModule.Theme.muted
  property color panelColor: ThemeModule.Theme.darkBackground
  property color selectorColor: ThemeModule.Theme.selector
  property color menuColor: ThemeModule.Theme.menu
  property color borderColor: ThemeModule.Theme.border

  property int edge: 20

  // ---------- estado ----------

  readonly property var device: UPower.displayDevice

  // O módulo só existe em laptops: sem bateria de laptop, some da barra.
  readonly property bool hasBattery:
    UPower.devices.values.some(d => d.isLaptopBattery)

  // UPowerDevice.percentage vai de 0.0 a 1.0
  readonly property real pct: Math.max(0, Math.min(100,
    (device ? device.percentage : 0) * 100))


  readonly property var allProfiles: [
    { profile: PowerProfile.PowerSaver, label: "Power-saver", icon: "eco" },
    { profile: PowerProfile.Balanced, label: "Balanced", icon: "balance" },
    { profile: PowerProfile.Performance, label: "Performance", icon: "speed" }
  ]

  readonly property var profileOptions: PowerProfiles.hasPerformanceProfile
    ? allProfiles : allProfiles.slice(0, 2)

  // ---------- helpers ----------

  function batterySymbol() {
    if (pct >= 95) return "battery_full"
    if (pct >= 80) return "battery_6_bar"
    if (pct >= 65) return "battery_5_bar"
    if (pct >= 50) return "battery_4_bar"
    if (pct >= 35) return "battery_3_bar"
    if (pct >= 20) return "battery_2_bar"
    return "battery_1_bar"
  }

  function setProfile(profile) {
    PowerProfiles.profile = profile
  }

  visible: hasBattery
  implicitWidth: indicator.implicitWidth + 18
  implicitHeight: 30
  color: "transparent"

  onHasBatteryChanged: {
    if (!hasBattery) popup.visible = false
  }

  // ---------- timers ----------

  Timer {
    id: closeTimer
    interval: 180

    onTriggered: {
      if (!mouseArea.containsMouse && !panelHover.hovered)
        popup.visible = false
    }
  }

  // ---------- indicador da barra ----------

  Text {
    id: indicator
    anchors.centerIn: parent
    text: root.batterySymbol()
    color: root.iconColor
    font.family: "Material Symbols Rounded"
    font.pixelSize: 22
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
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onEntered: closeTimer.stop()
    onExited: closeTimer.restart()

    onClicked: popup.visible = !popup.visible
  }

  // ---------- popup ----------

  PanelWindow {
    id: popup

    // janela layer-shell colada na direita da tela, logo abaixo da barra
    screen: root.QsWindow.window.screen
    anchors {
      top: true
      right: true
    }
    margins.top: root.QsWindow.window.height
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "bar-popup"

    implicitWidth: 360 + root.edge
    implicitHeight: panel.implicitHeight + 4

    visible: false
    color: "transparent"

    Shape {
      anchors.left: parent.left
      anchors.top: parent.top
      width: root.edge
      height: root.edge
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        strokeWidth: 0
        fillColor: root.panelColor
        startX: root.edge
        startY: 0

        PathLine { x: root.edge; y: root.edge }
        PathArc {
          x: 0
          y: 0
          radiusX: root.edge
          radiusY: root.edge
          direction: PathArc.Counterclockwise
        }
        PathLine { x: root.edge; y: 0 }
      }
    }

    Rectangle {
      id: panel
      anchors.fill: parent
      anchors.leftMargin: root.edge

      color: root.panelColor
      bottomLeftRadius: root.edge

      implicitHeight: content.implicitHeight + 28

      HoverHandler {
        id: panelHover

        onHoveredChanged: {
          if (hovered)
            closeTimer.stop()
          else
            closeTimer.restart()
        }
      }

      ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 14
        spacing: 16

        // CABEÇALHO

        RowLayout {
          Layout.fillWidth: true
          spacing: 12

          Text {
            text: root.batterySymbol()
            color: root.iconColor
            font.family: "Material Symbols Rounded"
            font.pixelSize: 34
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
              Layout.fillWidth: true
              text: "Battery"
              color: root.iconColor
              font.family: "Rubik"
              font.pixelSize: 17
              font.bold: true
              elide: Text.ElideRight
            }
          }

          Text {
            text: Math.round(root.pct) + "%"
            color: root.iconColor
            font.family: "Rubik"
            font.pixelSize: 30
            font.bold: true
          }
        }

        // BARRA DE CARGA

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 8
          radius: 4
          color: root.selectorColor
          clip: true

          Rectangle {
            width: parent.width * root.pct / 100
            height: parent.height
            radius: parent.radius
            color: root.iconColor

            Behavior on width {
              NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
              }
            }
          }
        }

        // PERFIL DE ENERGIA

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 10

          Text {
            text: "POWER PROFILE"
            color: root.mutedColor
            font.family: "Rubik"
            font.pixelSize: 11
            font.letterSpacing: 0.5
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            uniformCellSizes: true

            Repeater {
              model: root.profileOptions

              delegate: Rectangle {
                id: profileButton

                Layout.fillWidth: true
                implicitHeight: 42
                radius: 7

                property bool selected: PowerProfiles.profile === modelData.profile

                color: selected
                  ? root.borderColor
                  : (profileMouse.containsMouse ? root.menuColor : "transparent")
                border.width: 1
                border.color: selected ? root.iconColor : root.borderColor

                RowLayout {
                  anchors.centerIn: parent
                  width: parent.width - 12
                  spacing: 6

                  Item { Layout.fillWidth: true }

                  Text {
                    text: modelData.icon
                    color: root.iconColor
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                  }

                  Text {
                    text: modelData.label
                    color: root.iconColor
                    font.family: "Rubik"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.maximumWidth: profileButton.width - 44
                  }

                  Item { Layout.fillWidth: true }
                }

                MouseArea {
                  id: profileMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setProfile(modelData.profile)
                }
              }
            }
          }
        }
      }
    }
  }
}
