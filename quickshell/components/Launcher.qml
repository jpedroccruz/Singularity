import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.theme as ThemeModule

Scope {
  id: root

  // ---------- tema (mesmas cores/fontes do componente de rede) ----------

  property color iconColor: ThemeModule.Theme.accent
  property color mutedColor: ThemeModule.Theme.muted
  property color panelColor: ThemeModule.Theme.darkBackground
  property color selectorColor: ThemeModule.Theme.selection
  property color menuColor: ThemeModule.Theme.darkerBackground
  property color borderColor: ThemeModule.Theme.muted

  property string uiFont: "Rubik"
  property string iconFont: "Material Symbols Rounded"

  // ---------- estado ----------

  property bool open: false     // painel visível (anima subindo/descendo)
  property bool alive: false    // janela existe (fica viva durante a animação de saída)
  property var recents: []      // ids dos apps, mais recente primeiro

  readonly property string recentPath:
    Quickshell.env("HOME") + "/.cache/qs-launcher-recent.json"

  function show() {
    killTimer.stop()
    alive = true
    open = true
  }

  function hide() {
    open = false
    killTimer.restart()
  }

  function toggle() {
    if (open) hide()
    else show()
  }

  Timer {
    id: killTimer
    interval: 240
    onTriggered: root.alive = false
  }

  FileView {
    id: recentFile
    path: root.recentPath
    printErrors: false

    onLoaded: {
      try { root.recents = JSON.parse(text()) } catch (e) { root.recents = [] }
    }
  }

  function markRecent(id) {
    const r = recents.filter(x => x !== id)
    r.unshift(id)
    recents = r.slice(0, 20)
    recentFile.setText(JSON.stringify(recents))
  }

  function isRecent(app) {
    return recents.indexOf(app.id) !== -1
  }

  // ---------- busca ----------

  function subsequence(needle, hay) {
    let i = 0

    for (const c of hay) {
      if (c === needle[i]) i++
      if (i === needle.length) return true
    }

    return needle.length === 0
  }

  function score(app, q) {
    const name = (app.name || "").toLowerCase()
    const extra = ((app.genericName || "") + " " + (app.comment || "")).toLowerCase()

    if (name.startsWith(q)) return 4
    if (name.includes(q)) return 3
    if (extra.includes(q)) return 2
    if (subsequence(q, name)) return 1

    return 0
  }

  function filtered(query) {
    const q = query.trim().toLowerCase()
    const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay)

    if (q === "") {
      const rank = a => {
        const i = recents.indexOf(a.id)
        return i === -1 ? 999 : i
      }

      return apps.sort((a, b) => rank(a) - rank(b) || a.name.localeCompare(b.name))
    }

    return apps
      .map(a => ({ a: a, s: score(a, q) + (isRecent(a) ? 0.5 : 0) }))
      .filter(x => x.s > 0)
      .sort((x, y) => y.s - x.s || x.a.name.localeCompare(y.a.name))
      .map(x => x.a)
  }

  // ---------- IPC ----------
  // qs ipc call launcher toggle

  IpcHandler {
    target: "launcher"

    function toggle(): void { root.toggle() }
    function show(): void { root.show() }
    function hide(): void { root.hide() }
  }

  // ---------- janela ----------

  LazyLoader {
    active: root.alive

    PanelWindow {
      id: win

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      WlrLayershell.namespace: "launcher"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

      function launch(app) {
        if (!app) return

        root.markRecent(app.id)
        root.hide()
        app.execute()
      }

      // clicar fora fecha
      MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
      }

      Rectangle {
        id: panel

        property bool shown: false

        // parte do painel que fica para fora da tela: esconde a borda inferior
        // e os cantos arredondados de baixo, como se ele saísse do fundo da tela
        readonly property int overshoot: 12

        width: 460
        height: 440 + overshoot
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        // sobe de baixo da tela; na saída desce de volta
        anchors.bottomMargin: (shown && root.open) ? -overshoot : -(height + 4)

        Behavior on anchors.bottomMargin {
          NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        radius: 10
        color: root.panelColor
        border.width: 2
        border.color: root.iconColor

        Component.onCompleted: search.forceActiveFocus()

        Timer {
          running: true
          interval: 60
          onTriggered: panel.shown = true
        }

        // impede que cliques no painel fechem o launcher
        MouseArea {
          anchors.fill: parent
        }

        // alça
        Rectangle {
          width: 36
          height: 4
          radius: 2
          color: root.mutedColor
          anchors.top: parent.top
          anchors.topMargin: 8
          anchors.horizontalCenter: parent.horizontalCenter
        }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 14
          anchors.topMargin: 22
          anchors.bottomMargin: 14 + panel.overshoot
          spacing: 12

          // campo de busca
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 42
            radius: 6
            color: root.selectorColor
            border.width: 1
            border.color: search.activeFocus ? root.iconColor : root.borderColor

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 10

              Text {
                text: "search"
                color: root.mutedColor
                font.family: root.iconFont
                font.pixelSize: 20
              }

              TextInput {
                id: search

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                color: root.iconColor
                selectionColor: root.borderColor
                selectedTextColor: root.iconColor
                font.family: root.uiFont
                font.pixelSize: 14
                clip: true

                onTextChanged: list.currentIndex = 0

                Keys.onEscapePressed: root.hide()
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onTabPressed: list.incrementCurrentIndex()
                Keys.onBacktabPressed: list.decrementCurrentIndex()

                Keys.onPressed: event => {
                  if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                      list.incrementCurrentIndex()
                      event.accepted = true
                    } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                      list.decrementCurrentIndex()
                      event.accepted = true
                    }
                  }
                }

                Keys.onReturnPressed: win.launch(list.currentItem ? list.currentItem.modelData : null)
                Keys.onEnterPressed: win.launch(list.currentItem ? list.currentItem.modelData : null)

                Text {
                  visible: search.text.length === 0
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Search apps…"
                  color: root.mutedColor
                  font: search.font
                }
              }
            }
          }

          // resultados
          ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            currentIndex: 0
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds
            model: root.filtered(search.text)

            ScrollIndicator.vertical: ScrollIndicator {}

            delegate: Rectangle {
              id: row

              required property var modelData
              required property int index

              width: ListView.view.width
              height: 56
              radius: 4

              color: ListView.isCurrentItem ? root.selectorColor
                : (hover.containsMouse ? root.menuColor : "transparent")

              border.width: ListView.isCurrentItem ? 1 : 0
              border.color: root.borderColor

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 10
                spacing: 12

                Rectangle {
                  Layout.preferredWidth: 40
                  Layout.preferredHeight: 40
                  radius: 6
                  color: root.menuColor
                  border.width: 1
                  border.color: root.borderColor

                  IconImage {
                    anchors.centerIn: parent
                    implicitSize: 26
                    source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignVCenter
                  spacing: 3

                  Text {
                    Layout.fillWidth: true
                    text: row.modelData.name
                    color: root.iconColor
                    font.family: root.uiFont
                    font.pixelSize: 14
                    elide: Text.ElideRight
                  }

                  // some quando não há badge nem descrição, assim o nome
                  // fica centralizado na linha
                  RowLayout {
                    visible: root.isRecent(row.modelData)
                      || (row.modelData.genericName || "") !== ""
                    spacing: 8

                    Rectangle {
                      visible: root.isRecent(row.modelData)
                      implicitWidth: badgeLabel.implicitWidth + 12
                      implicitHeight: 15
                      radius: 3
                      color: root.selectorColor
                      border.width: 1
                      border.color: root.borderColor

                      Text {
                        id: badgeLabel
                        anchors.centerIn: parent
                        text: "recent"
                        color: root.mutedColor
                        font.family: root.uiFont
                        font.pixelSize: 9
                        font.letterSpacing: 0.5
                      }
                    }

                    Text {
                      visible: text !== ""
                      text: row.modelData.genericName || ""
                      color: root.mutedColor
                      font.family: root.uiFont
                      font.pixelSize: 11
                      elide: Text.ElideRight
                    }
                  }
                }
              }

              MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: list.currentIndex = row.index
                onClicked: win.launch(row.modelData)
              }
            }
          }
        }
      }
    }
  }
}
