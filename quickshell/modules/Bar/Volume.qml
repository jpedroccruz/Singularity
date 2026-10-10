import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: root

  property color iconColor: "#FFA376"
  property color mutedColor: "#765B50"
  property color panelColor: "#17100B"
  property color selectorColor: "#2A1D18"
  property color menuColor: "#211711"
  property color borderColor: "#493025"

  property var sink: Pipewire.defaultAudioSink
  property var source: Pipewire.defaultAudioSource

  property var outputDevices: Pipewire.nodes.values.filter(
    node => node.isSink && !node.isStream
  )

  property var inputDevices: Pipewire.nodes.values.filter(
    node => !node.isSink && !node.isStream && !node.name.endsWith(".monitor")
  )

  property var outputPorts: []
  property var inputPorts: []

  property string activeOutputPort: ""
  property string activeInputPort: ""

  property real volume: sink ? sink.audio.volume : 0
  property bool muted: !sink || sink.audio.muted

  function volumeSymbol() {
    if (muted || volume <= 0) return "volume_off"
    if (volume <= 0.33) return "volume_mute"
    if (volume <= 0.66) return "volume_down"
    return "volume_up"
  }

  function parsePorts(text, kind) {
    const node = kind === "output" ? root.sink : root.source
    const header = kind === "output" ? /Sink #\d+/ : /Source #\d+/

    if (!node) {
      if (kind === "output") {
        root.outputPorts = []
        root.activeOutputPort = ""
      } else {
        root.inputPorts = []
        root.activeInputPort = ""
      }
      return
    }

    const blocks = text.split(header)
    let block = ""

    for (const candidate of blocks) {
      const nameMatch = candidate.match(/^\s*Name:\s*(.+)$/m)

      if (nameMatch && nameMatch[1].trim() === node.name) {
        block = candidate
        break
      }
    }

    const ports = []
    let activePort = ""
    let insidePorts = false

    for (const line of block.split("\n")) {
      if (/^\s*Ports:\s*$/.test(line)) {
        insidePorts = true
        continue
      }

      if (!insidePorts) continue

      const activeMatch = line.match(/^\s*Active Port:\s*(.+)$/)

      if (activeMatch) {
        activePort = activeMatch[1].trim()
        break
      }

      const portMatch = line.match(/^\s+([^:\s][^:]*):\s*(.*)$/)

      if (portMatch) {
        const name = portMatch[1].trim()
        const label = portMatch[2]
          .replace(/\s+\(type:.*$/, "")
          .trim()

        ports.push({
          name,
          label: label || name
        })
      }
    }

    if (kind === "output") {
      root.outputPorts = ports
      root.activeOutputPort = activePort
    } else {
      root.inputPorts = ports
      root.activeInputPort = activePort
    }
  }

  function refreshPorts() {
    if (root.sink)
      outputPortsProcess.running = true

    if (root.source)
      inputPortsProcess.running = true
  }

  function setOutputPort(port) {
    if (!root.sink || !port) return

    setOutputPortProcess.command = [
      "pactl", "set-sink-port", root.sink.name, port
    ]
    setOutputPortProcess.running = true
  }

  function setInputPort(port) {
    if (!root.source || !port) return

    setInputPortProcess.command = [
      "pactl", "set-source-port", root.source.name, port
    ]
    setInputPortProcess.running = true
  }

  onSinkChanged: refreshPorts()
  onSourceChanged: refreshPorts()

  Component.onCompleted: refreshPorts()

  implicitWidth: indicator.implicitWidth + 18
  implicitHeight: 30
  color: "transparent"

  PwObjectTracker {
    objects: Pipewire.nodes.values.filter(
      node => node.audio && !node.isStream
    )
  }

  Process {
    id: outputPortsProcess
    command: ["pactl", "list", "sinks"]

    stdout: StdioCollector {
      onStreamFinished: root.parsePorts(this.text, "output")
    }
  }

  Process {
    id: inputPortsProcess
    command: ["pactl", "list", "sources"]

    stdout: StdioCollector {
      onStreamFinished: root.parsePorts(this.text, "input")
    }
  }

  Process {
    id: setOutputPortProcess

    onExited: {
      refreshTimer.restart()
    }
  }

  Process {
    id: setInputPortProcess

    onExited: {
      refreshTimer.restart()
    }
  }

  Timer {
    id: refreshTimer
    interval: 250
    onTriggered: root.refreshPorts()
  }

  Timer {
    id: closeTimer
    interval: 180

    onTriggered: {
      if (!mouseArea.containsMouse && !panelHover.hovered)
        popup.visible = false
    }
  }

  Text {
    id: indicator
    anchors.centerIn: parent
    text: root.volumeSymbol()
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

    onClicked: {
      popup.visible = !popup.visible

      if (popup.visible)
        root.refreshPorts()
    }
  }

  PopupWindow {
    id: popup

    anchor.item: root
    anchor.rect.x: root.width / 2 - implicitWidth / 2
    anchor.rect.y: root.height + 6

    implicitWidth: 340
    implicitHeight: panel.implicitHeight + 4

    visible: false
    color: "transparent"
    grabFocus: false

    Rectangle {
      id: panel
      anchors.fill: parent

      color: root.panelColor
      border.width: 2
      border.color: root.iconColor
      radius: 10

      implicitHeight: content.implicitHeight + 24

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

        // SAÍDA DE ÁUDIO

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 10

          Text {
            text: "OUTPUT"
            color: root.iconColor
            font.family: "Rubik"
            font.pixelSize: 13
            font.bold: true
          }

          ComboBox {
            id: outputSelector

            Layout.fillWidth: true
            implicitHeight: 42
            model: root.outputDevices
            textRole: "description"

            currentIndex: {
              if (!root.sink) return -1
              return root.outputDevices.findIndex(
                device => device.id === root.sink.id
              )
            }

            onActivated: index => {
              if (index >= 0) {
                Pipewire.preferredDefaultAudioSink =
                  root.outputDevices[index]

                refreshTimer.restart()
              }
            }

            background: Rectangle {
              color: root.selectorColor
              radius: 7
              border.width: 1
              border.color: root.borderColor
            }

            contentItem: Text {
              leftPadding: 12
              rightPadding: 30
              text: outputSelector.displayText
              color: root.iconColor
              font.family: "Rubik"
              font.pixelSize: 14
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
            }

            indicator: Text {
              x: outputSelector.width - width - 10
              anchors.verticalCenter: parent.verticalCenter
              text: "arrow_drop_down"
              color: root.iconColor
              font.family: "Material Symbols Rounded"
              font.pixelSize: 24
            }

            popup: Popup {
              y: outputSelector.height + 4
              width: outputSelector.width
              padding: 4

              background: Rectangle {
                color: root.panelColor
                border.width: 1
                border.color: root.borderColor
                radius: 7
              }

              contentItem: ListView {
                clip: true
                implicitHeight: Math.min(contentHeight, 190)
                model: outputSelector.delegateModel
                currentIndex: outputSelector.highlightedIndex
                boundsBehavior: Flickable.StopAtBounds

                ScrollIndicator.vertical: ScrollIndicator {}
              }
            }

            delegate: ItemDelegate {
              width: outputSelector.width - 8
              implicitHeight: 38
              highlighted: outputSelector.highlightedIndex === index

              background: Rectangle {
                color: parent.highlighted
                  ? root.borderColor
                  : root.menuColor
                radius: 5
              }

              contentItem: Text {
                text: modelData.description
                color: root.iconColor
                font.family: "Rubik"
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                leftPadding: 8
              }
            }
          }

          ComboBox {
            id: outputPortSelector

            Layout.fillWidth: true
            implicitHeight: 42
            model: root.outputPorts
            textRole: "label"
            enabled: root.outputPorts.length > 0

            currentIndex: {
              if (!root.activeOutputPort) return -1
              return root.outputPorts.findIndex(
                port => port.name === root.activeOutputPort
              )
            }

            onActivated: index => {
              if (index >= 0)
                root.setOutputPort(root.outputPorts[index].name)
            }

            background: Rectangle {
              color: root.selectorColor
              radius: 7
              border.width: 1
              border.color: root.borderColor
            }

            contentItem: Text {
              leftPadding: 12
              rightPadding: 30
              text: outputPortSelector.displayText || "Selecione uma porta"
              color: root.outputPorts.length
                ? root.iconColor : root.mutedColor
              font.family: "Rubik"
              font.pixelSize: 14
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
            }

            indicator: Text {
              x: outputPortSelector.width - width - 10
              anchors.verticalCenter: parent.verticalCenter
              text: "arrow_drop_down"
              color: root.iconColor
              font.family: "Material Symbols Rounded"
              font.pixelSize: 24
            }

            popup: Popup {
              y: outputPortSelector.height + 4
              width: outputPortSelector.width
              padding: 4

              background: Rectangle {
                color: root.panelColor
                border.width: 1
                border.color: root.borderColor
                radius: 7
              }

              contentItem: ListView {
                clip: true
                implicitHeight: Math.min(contentHeight, 190)
                model: outputPortSelector.delegateModel
                currentIndex: outputPortSelector.highlightedIndex
                boundsBehavior: Flickable.StopAtBounds

                ScrollIndicator.vertical: ScrollIndicator {}
              }
            }

            delegate: ItemDelegate {
              width: outputPortSelector.width - 8
              implicitHeight: 38
              highlighted: outputPortSelector.highlightedIndex === index

              background: Rectangle {
                color: parent.highlighted
                  ? root.borderColor
                  : root.menuColor
                radius: 5
              }

              contentItem: Text {
                text: modelData.label
                color: root.iconColor
                font.family: "Rubik"
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                leftPadding: 8
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
              text: "volume_up"
              color: root.iconColor
              font.family: "Material Symbols Rounded"
              font.pixelSize: 22
            }

            Slider {
              id: outputSlider

              Layout.fillWidth: true
              implicitHeight: 30
              from: 0
              to: 1
              value: root.sink ? root.sink.audio.volume : 0
              enabled: !!root.sink

              onMoved: {
                if (root.sink)
                  root.sink.audio.volume = value
              }

              background: Rectangle {
                x: outputSlider.leftPadding
                y: outputSlider.topPadding
                   + outputSlider.availableHeight / 2 - height / 2
                width: outputSlider.availableWidth
                height: 4
                radius: 2
                color: root.borderColor

                Rectangle {
                  width: outputSlider.visualPosition * parent.width
                  height: parent.height
                  radius: 2
                  color: root.iconColor
                }
              }

              handle: Rectangle {
                x: outputSlider.leftPadding
                   + outputSlider.visualPosition
                   * (outputSlider.availableWidth - width)
                y: outputSlider.topPadding
                   + outputSlider.availableHeight / 2 - height / 2
                width: 14
                height: 14
                radius: width / 2
                color: root.iconColor
                border.width: 2
                border.color: root.panelColor
              }
            }

            Text {
              Layout.preferredWidth: 42
              horizontalAlignment: Text.AlignRight
              text: Math.round(outputSlider.value * 100) + "%"
              color: root.iconColor
              font.family: "Rubik"
              font.pixelSize: 13
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          height: 1
          color: root.borderColor
        }

        // ENTRADA DE ÁUDIO

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 10

          Text {
            text: "INPUT"
            color: root.iconColor
            font.family: "Rubik"
            font.pixelSize: 13
            font.bold: true
          }

          ComboBox {
            id: inputSelector

            Layout.fillWidth: true
            implicitHeight: 42
            model: root.inputDevices
            textRole: "description"

            currentIndex: {
              if (!root.source) return -1
              return root.inputDevices.findIndex(
                device => device.id === root.source.id
              )
            }

            onActivated: index => {
              if (index >= 0) {
                Pipewire.preferredDefaultAudioSource =
                  root.inputDevices[index]

                refreshTimer.restart()
              }
            }

            background: Rectangle {
              color: root.selectorColor
              radius: 7
              border.width: 1
              border.color: root.borderColor
            }

            contentItem: Text {
              leftPadding: 12
              rightPadding: 30
              text: inputSelector.displayText
              color: root.iconColor
              font.family: "Rubik"
              font.pixelSize: 14
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
            }

            indicator: Text {
              x: inputSelector.width - width - 10
              anchors.verticalCenter: parent.verticalCenter
              text: "arrow_drop_down"
              color: root.iconColor
              font.family: "Material Symbols Rounded"
              font.pixelSize: 24
            }

            popup: Popup {
              y: inputSelector.height + 4
              width: inputSelector.width
              padding: 4

              background: Rectangle {
                color: root.panelColor
                border.width: 1
                border.color: root.borderColor
                radius: 7
              }

              contentItem: ListView {
                clip: true
                implicitHeight: Math.min(contentHeight, 190)
                model: inputSelector.delegateModel
                currentIndex: inputSelector.highlightedIndex
                boundsBehavior: Flickable.StopAtBounds

                ScrollIndicator.vertical: ScrollIndicator {}
              }
            }

            delegate: ItemDelegate {
              width: inputSelector.width - 8
              implicitHeight: 38
              highlighted: inputSelector.highlightedIndex === index

              background: Rectangle {
                color: parent.highlighted
                  ? root.borderColor
                  : root.menuColor
                radius: 5
              }

              contentItem: Text {
                text: modelData.description
                color: root.iconColor
                font.family: "Rubik"
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                leftPadding: 8
              }
            }
          }

          ComboBox {
            id: inputPortSelector

            Layout.fillWidth: true
            implicitHeight: 42
            model: root.inputPorts
            textRole: "label"
            enabled: root.inputPorts.length > 0

            currentIndex: {
              if (!root.activeInputPort) return -1
              return root.inputPorts.findIndex(
                port => port.name === root.activeInputPort
              )
            }

            onActivated: index => {
              if (index >= 0)
                root.setInputPort(root.inputPorts[index].name)
            }

            background: Rectangle {
              color: root.selectorColor
              radius: 7
              border.width: 1
              border.color: root.borderColor
            }

            contentItem: Text {
              leftPadding: 12
              rightPadding: 30
              text: inputPortSelector.displayText || "Selecione uma porta"
              color: root.inputPorts.length
                ? root.iconColor : root.mutedColor
              font.family: "Rubik"
              font.pixelSize: 14
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
            }

            indicator: Text {
              x: inputPortSelector.width - width - 10
              anchors.verticalCenter: parent.verticalCenter
              text: "arrow_drop_down"
              color: root.iconColor
              font.family: "Material Symbols Rounded"
              font.pixelSize: 24
            }

            popup: Popup {
              y: inputPortSelector.height + 4
              width: inputPortSelector.width
              padding: 4

              background: Rectangle {
                color: root.panelColor
                border.width: 1
                border.color: root.borderColor
                radius: 7
              }

              contentItem: ListView {
                clip: true
                implicitHeight: Math.min(contentHeight, 190)
                model: inputPortSelector.delegateModel
                currentIndex: inputPortSelector.highlightedIndex
                boundsBehavior: Flickable.StopAtBounds

                ScrollIndicator.vertical: ScrollIndicator {}
              }
            }

            delegate: ItemDelegate {
              width: inputPortSelector.width - 8
              implicitHeight: 38
              highlighted: inputPortSelector.highlightedIndex === index

              background: Rectangle {
                color: parent.highlighted
                  ? root.borderColor
                  : root.menuColor
                radius: 5
              }

              contentItem: Text {
                text: modelData.label
                color: root.iconColor
                font.family: "Rubik"
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                leftPadding: 8
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
              text: "mic"
              color: root.iconColor
              font.family: "Material Symbols Rounded"
              font.pixelSize: 22
            }

            Slider {
              id: inputSlider

              Layout.fillWidth: true
              implicitHeight: 30
              from: 0
              to: 1
              value: root.source ? root.source.audio.volume : 0
              enabled: !!root.source

              onMoved: {
                if (root.source)
                  root.source.audio.volume = value
              }

              background: Rectangle {
                x: inputSlider.leftPadding
                y: inputSlider.topPadding
                   + inputSlider.availableHeight / 2 - height / 2
                width: inputSlider.availableWidth
                height: 4
                radius: 2
                color: root.borderColor

                Rectangle {
                  width: inputSlider.visualPosition * parent.width
                  height: parent.height
                  radius: 2
                  color: root.iconColor
                }
              }

              handle: Rectangle {
                x: inputSlider.leftPadding
                   + inputSlider.visualPosition
                   * (inputSlider.availableWidth - width)
                y: inputSlider.topPadding
                   + inputSlider.availableHeight / 2 - height / 2
                width: 14
                height: 14
                radius: width / 2
                color: root.iconColor
                border.width: 2
                border.color: root.panelColor
              }
            }

            Text {
              Layout.preferredWidth: 42
              horizontalAlignment: Text.AlignRight
              text: Math.round(inputSlider.value * 100) + "%"
              color: root.iconColor
              font.family: "Rubik"
              font.pixelSize: 13
            }
          }
        }
      }
    }
  }
}