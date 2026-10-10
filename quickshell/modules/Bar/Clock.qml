import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

Rectangle {
  id: root

  // ---------- tema (mesmas cores do módulo de rede) ----------

  property color iconColor: "#FFA376"
  property color mutedColor: "#765B50"
  property color panelColor: "#17100B"
  property color selectorColor: "#2A1D18"
  property color menuColor: "#211711"
  property color borderColor: "#493025"

  // ---------- configuração ----------

  // Formato do relógio na barra (ex.: "HH:mm", "ddd d MMM  HH:mm", "HH:mm:ss")
  property string barFormat: "ddd MMM dd HH:mm"

  // Primeiro dia da semana no calendário: 0 = domingo, 1 = segunda
  property int firstDay: 0

  // Raio dos cantos do popup: os de baixo são arredondados e os de cima se
  // curvam para dentro da barra, como se o popup fosse parte dela.
  property int edge: 20

  // ---------- estado ----------

  property int viewYear: new Date().getFullYear()
  property int viewMonth: new Date().getMonth()

  property var times: ({})        // id da notificação -> hora em que chegou
  property int tick: 0            // força a atualização do "há X min"
  property double closedAt: 0

  // Se você já tem um NotificationServer em outro módulo, apague o bloco
  // "NotificationServer" abaixo e aponte esta propriedade para o modelo dele.
  readonly property var notifications: server.trackedNotifications
  readonly property var notifList: notifications.values.slice().reverse()
  readonly property int count: notifications.values.length

  readonly property var days: buildDays(viewYear, viewMonth, clock.date)

  readonly property var weekdayLabels: {
    const out = []

    // 1º de janeiro de 2023 foi um domingo
    for (let i = 0; i < 7; i++) {
      const d = new Date(2023, 0, 1 + ((root.firstDay + i) % 7))
      out.push(cap(Qt.formatDate(d, "ddd")).charAt(0))
    }

    return out
  }

  readonly property string monthTitle: {
    const d = new Date(viewYear, viewMonth, 1)
    let t = cap(Qt.formatDate(d, "MMMM"))

    if (viewYear !== clock.date.getFullYear())
      t += " " + viewYear

    return t
  }

  // ---------- helpers ----------

  function cap(s) {
    return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s
  }

  function longDate(d) {
    const pt = Qt.locale().name.indexOf("pt") === 0

    return cap(Qt.formatDate(d, pt ? "d 'de' MMMM 'de' yyyy" : "MMMM d, yyyy"))
  }

  function buildDays(y, m, now) {
    const first = new Date(y, m, 1)
    const offset = (first.getDay() - root.firstDay + 7) % 7
    const out = []

    for (let i = 0; i < 42; i++) {
      const d = new Date(y, m, 1 - offset + i)

      out.push({
        day: d.getDate(),
        inMonth: d.getMonth() === m,
        today: d.getFullYear() === now.getFullYear()
          && d.getMonth() === now.getMonth()
          && d.getDate() === now.getDate()
      })
    }

    return out
  }

  function shiftMonth(delta) {
    const d = new Date(viewYear, viewMonth + delta, 1)

    viewYear = d.getFullYear()
    viewMonth = d.getMonth()
  }

  function resetView() {
    viewYear = clock.date.getFullYear()
    viewMonth = clock.date.getMonth()
  }

  function ago(n, t) {
    const at = root.times[n.id]

    if (!at) return ""

    const s = Math.floor((Date.now() - at) / 1000)

    if (s < 60) return "Just now"

    const m = Math.floor(s / 60)
    if (m < 60) return m + " min ago"

    const h = Math.floor(m / 60)
    if (h < 24) return h + " h ago"

    return Math.floor(h / 24) + " d ago"
  }

  function iconSource(n) {
    if (n.image && n.image !== "") return n.image

    const ic = n.appIcon || ""

    if (ic === "") return ""
    if (ic.charAt(0) === "/") return "file://" + ic

    return Quickshell.iconPath(ic, true)
  }

  function clearAll() {
    const list = root.notifications.values.slice()

    for (let i = 0; i < list.length; i++)
      list[i].dismiss()
  }

  function togglePopup() {
    if (popup.visible) {
      popup.visible = false
      return
    }

    // o clique que acabou de fechar o popup não deve reabri-lo
    if (Date.now() - root.closedAt < 250) return

    popup.visible = true
  }

  // ---------- fontes de dados ----------

  SystemClock {
    id: clock
    precision: root.barFormat.indexOf("s") >= 0
      ? SystemClock.Seconds : SystemClock.Minutes
  }

  NotificationPopups {
    id: popups
  }

  // Este módulo vira o servidor de notificações. Só pode existir um por
  // sessão: pare mako, dunst, swaync etc. antes de usar.
  NotificationServer {
    id: server

    keepOnReload: true
    bodySupported: true
    bodyMarkupSupported: false
    actionsSupported: true
    imageSupported: true
    persistenceSupported: true

    onNotification: n => {
      root.times[n.id] = Date.now()
      n.tracked = true
      popups.push(n)
    }
  }

  Timer {
    interval: 30000
    running: popup.visible
    repeat: true
    onTriggered: root.tick++
  }

  // ---------- indicador da barra ----------

  implicitWidth: barRow.implicitWidth + 18
  implicitHeight: 30
  color: "transparent"

  Row {
    id: barRow
    anchors.centerIn: parent
    spacing: 6

    Text {
      id: label
      anchors.verticalCenter: parent.verticalCenter
      text: Qt.formatDateTime(clock.date, root.barFormat)
      color: root.iconColor
      font.family: "Rubik"
      font.pixelSize: 16
    }

    // ponto: há notificações na lista
    Rectangle {
      visible: root.count > 0
      anchors.verticalCenter: parent.verticalCenter
      width: 6
      height: 6
      radius: 3
      color: root.iconColor
    }
  }

  Rectangle {
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: barRow.implicitWidth
    height: 2
    radius: height / 2
    color: root.iconColor
    visible: mouseArea.containsMouse || popup.visible
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor

    onClicked: root.togglePopup()
  }

  // ---------- popup ----------

  PopupWindow {
    id: popup

    anchor.item: root
    anchor.rect.x: root.width / 2 - implicitWidth / 2
    anchor.rect.y: root.height

    implicitWidth: 700 + root.edge * 2
    implicitHeight: Math.max(panel.implicitHeight + 4, 400)

    visible: false
    color: "transparent"
    grabFocus: true

    onVisibleChanged: {
      if (visible) {
        root.resetView()
        root.tick++
      } else {
        root.closedAt = Date.now()
      }
    }

    // cantos côncavos que ligam o popup à barra
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

    Shape {
      anchors.right: parent.right
      anchors.top: parent.top
      width: root.edge
      height: root.edge
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        strokeWidth: 0
        fillColor: root.panelColor
        startX: 0
        startY: 0

        PathLine { x: 0; y: root.edge }
        PathArc {
          x: root.edge
          y: 0
          radiusX: root.edge
          radiusY: root.edge
          direction: PathArc.Clockwise
        }
        PathLine { x: 0; y: 0 }
      }
    }

    Rectangle {
      id: panel
      anchors.fill: parent
      anchors.leftMargin: root.edge
      anchors.rightMargin: root.edge

      color: root.panelColor
      bottomLeftRadius: root.edge
      bottomRightRadius: root.edge

      implicitHeight: content.implicitHeight + 28

      Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: popup.visible = false
      }

      RowLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        // ===== NOTIFICAÇÕES =====

        ColumnLayout {
          Layout.preferredWidth: 340
          Layout.fillHeight: true
          spacing: 12

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
              id: list
              anchors.fill: parent
              clip: true
              spacing: 8
              boundsBehavior: Flickable.StopAtBounds
              model: root.notifList

              ScrollIndicator.vertical: ScrollIndicator {}

              delegate: Rectangle {
                id: card

                required property var modelData

                readonly property bool critical:
                  modelData.urgency === NotificationUrgency.Critical
                readonly property var extraActions:
                  modelData.actions.filter(a => a.identifier !== "default" && a.text !== "")

                width: ListView.view.width
                height: cardRow.implicitHeight + 24
                radius: 6
                color: cardHover.hovered ? Qt.lighter(root.selectorColor, 1.1)
                                         : root.selectorColor
                border.width: 1
                border.color: critical ? root.iconColor : root.borderColor

                HoverHandler {
                  id: cardHover
                }

                // clicar no cartão executa a ação padrão (se existir)
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor

                  onClicked: {
                    const acts = card.modelData.actions

                    for (let i = 0; i < acts.length; i++) {
                      if (acts[i].identifier === "default") {
                        acts[i].invoke()
                        card.modelData.dismiss()
                        popup.visible = false
                        return
                      }
                    }
                  }
                }

                RowLayout {
                  id: cardRow
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: 12
                  spacing: 10

                  // ícone
                  Rectangle {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 6
                    color: root.menuColor
                    border.width: 1
                    border.color: root.borderColor

                    Text {
                      anchors.centerIn: parent
                      visible: iconImage.status !== Image.Ready
                      text: "notifications"
                      color: root.mutedColor
                      font.family: "Material Symbols Rounded"
                      font.pixelSize: 20
                    }

                    Image {
                      id: iconImage
                      anchors.centerIn: parent
                      width: 26
                      height: 26
                      source: root.iconSource(card.modelData)
                      sourceSize.width: 64
                      sourceSize.height: 64
                      fillMode: Image.PreserveAspectFit
                      asynchronous: true
                      smooth: true
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 3

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 8

                      Text {
                        Layout.fillWidth: true
                        text: card.modelData.summary
                        color: root.iconColor
                        font.family: "Rubik"
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideRight
                      }

                      Text {
                        text: root.ago(card.modelData, root.tick)
                        color: root.mutedColor
                        font.family: "Rubik"
                        font.pixelSize: 11
                      }

                      // dispensar
                      Text {
                        text: "close"
                        color: closeMouse.containsMouse ? root.iconColor : root.mutedColor
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 16

                        MouseArea {
                          id: closeMouse
                          anchors.fill: parent
                          anchors.margins: -4
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: card.modelData.dismiss()
                        }
                      }
                    }

                    Text {
                      visible: text !== ""
                      Layout.fillWidth: true
                      text: card.modelData.body
                      color: Qt.alpha(root.iconColor, 0.75)
                      font.family: "Rubik"
                      font.pixelSize: 12
                      wrapMode: Text.WordWrap
                      maximumLineCount: 3
                      elide: Text.ElideRight
                      textFormat: Text.PlainText
                    }

                    // ações extras
                    Flow {
                      Layout.fillWidth: true
                      Layout.topMargin: 4
                      visible: card.extraActions.length > 0
                      spacing: 6

                      Repeater {
                        model: card.extraActions

                        delegate: Rectangle {
                          required property var modelData

                          implicitWidth: actLabel.implicitWidth + 20
                          implicitHeight: 26
                          radius: 4
                          color: actMouse.containsMouse ? root.borderColor : "transparent"
                          border.width: 1
                          border.color: root.borderColor

                          Text {
                            id: actLabel
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            color: root.iconColor
                            font.family: "Rubik"
                            font.pixelSize: 12
                          }

                          MouseArea {
                            id: actMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: parent.modelData.invoke()
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            // lista vazia
            ColumnLayout {
              visible: root.count === 0
              anchors.centerIn: parent
              spacing: 6

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "notifications_off"
                color: root.mutedColor
                font.family: "Material Symbols Rounded"
                font.pixelSize: 36
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "No notifications"
                color: root.mutedColor
                font.family: "Rubik"
                font.pixelSize: 13
              }
            }
          }

          // rodapé
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
              Layout.fillWidth: true
              text: root.count === 0 ? ""
                : root.count + (root.count === 1 ? " notification" : " notifications")
              color: root.mutedColor
              font.family: "Rubik"
              font.pixelSize: 12
              elide: Text.ElideRight
            }

            Rectangle {
              implicitWidth: 88
              implicitHeight: 34
              radius: 4
              opacity: root.count > 0 ? 1 : 0.5
              color: clearMouse.containsMouse && root.count > 0
                ? root.borderColor : root.selectorColor
              border.width: 1
              border.color: clearMouse.containsMouse && root.count > 0
                ? root.iconColor : root.borderColor

              Text {
                anchors.centerIn: parent
                text: "Clear"
                color: root.iconColor
                font.family: "Rubik"
                font.pixelSize: 13
              }

              MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.count > 0
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clearAll()
              }
            }
          }
        }

        // divisória
        Rectangle {
          Layout.fillHeight: true
          implicitWidth: 1
          color: root.borderColor
        }

        // ===== CALENDÁRIO =====

        ColumnLayout {
          Layout.preferredWidth: 300
          Layout.alignment: Qt.AlignTop
          spacing: 14

          ColumnLayout {
            spacing: 0

            Text {
              text: root.cap(Qt.formatDate(clock.date, "dddd"))
              color: root.mutedColor
              font.family: "Rubik"
              font.pixelSize: 14
            }

            Text {
              text: root.longDate(clock.date)
              color: root.iconColor
              font.family: "Rubik"
              font.pixelSize: 20
              font.bold: true
            }
          }

          Rectangle {
            Layout.fillWidth: true
            implicitHeight: calCol.implicitHeight + 24
            radius: 8
            color: root.selectorColor
            border.width: 1
            border.color: root.borderColor

            ColumnLayout {
              id: calCol
              anchors.fill: parent
              anchors.margins: 12
              spacing: 8

              // navegação do mês
              RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Rectangle {
                  implicitWidth: 28
                  implicitHeight: 28
                  radius: 4
                  color: prevMouse.containsMouse ? root.menuColor : "transparent"

                  Text {
                    anchors.centerIn: parent
                    text: "chevron_left"
                    color: root.iconColor
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                  }

                  MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shiftMonth(-1)
                  }
                }

                // clicar no título volta para o mês atual
                Text {
                  Layout.fillWidth: true
                  horizontalAlignment: Text.AlignHCenter
                  text: root.monthTitle
                  color: root.iconColor
                  font.family: "Rubik"
                  font.pixelSize: 14
                  font.bold: true

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetView()
                  }
                }

                Rectangle {
                  implicitWidth: 28
                  implicitHeight: 28
                  radius: 4
                  color: nextMouse.containsMouse ? root.menuColor : "transparent"

                  Text {
                    anchors.centerIn: parent
                    text: "chevron_right"
                    color: root.iconColor
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                  }

                  MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shiftMonth(1)
                  }
                }
              }

              // dias da semana + dias do mês
              GridLayout {
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 2
                columnSpacing: 0
                uniformCellWidths: true

                Repeater {
                  model: root.weekdayLabels

                  delegate: Text {
                    required property string modelData

                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: root.mutedColor
                    font.family: "Rubik"
                    font.pixelSize: 11
                    font.bold: true
                  }
                }

                Repeater {
                  model: root.days

                  delegate: Item {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 34

                    Rectangle {
                      anchors.centerIn: parent
                      width: 30
                      height: 30
                      radius: 15
                      color: parent.modelData.today ? root.iconColor
                        : (dayMouse.containsMouse ? root.menuColor : "transparent")

                      Text {
                        anchors.centerIn: parent
                        text: parent.parent.modelData.day
                        color: parent.parent.modelData.today ? root.panelColor
                          : (parent.parent.modelData.inMonth ? root.iconColor : root.mutedColor)
                        font.family: "Rubik"
                        font.pixelSize: 13
                        font.bold: parent.parent.modelData.today
                      }
                    }

                    MouseArea {
                      id: dayMouse
                      anchors.fill: parent
                      hoverEnabled: true
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
