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

  // ---------- tema ----------

  property color iconColor: ThemeModule.Theme.accent
  property color mutedColor: ThemeModule.Theme.muted
  property color panelColor: ThemeModule.Theme.darkBackground
  property color selectorColor: ThemeModule.Theme.selection
  property color menuColor: ThemeModule.Theme.darkerBackground
  property color borderColor: ThemeModule.Theme.muted

  property string uiFont: "Rubik"
  property string iconFont: "Material Symbols Rounded"
  property string emojiFont: "Noto Color Emoji"

  // ---------- opções ----------

  // depois de copiar do clipboard, cola automaticamente na janela anterior (precisa de wtype)
  property bool pasteAfterClip: false

  // emoji: copia e também digita na janela anterior (precisa de wtype; sem ele só copia)
  property bool typeEmoji: true

  // onde procurar a lista de emojis (primeiro que carregar).
  // aceita o all_emojis.txt do rofi-emoji e o emoji-test.txt do Unicode
  readonly property var emojiPaths: [
    "/usr/share/unicode/emoji/emoji-test.txt",
    "/usr/share/unicode/emoji-test.txt",
    "/usr/share/rofi-emoji/all_emojis.txt",
    Quickshell.env("HOME") + "/.config/quickshell/emoji-test.txt"
  ]

  // ---------- modos ----------

  readonly property var modes: [
    { id: "apps",  label: "Apps",  glyph: "apps",          hint: "^1", placeholder: "Search apps…" },
    { id: "clip",  label: "Clip",  glyph: "content_paste", hint: "^2", placeholder: "Search clipboard…" },
    { id: "emoji", label: "Emoji", glyph: "mood",          hint: "^3", placeholder: "Search emoji…" },
    { id: "cmd",   label: "Run",   glyph: "terminal",      hint: "^4", placeholder: "Run command…" }
  ]

  function modeInfo(id) {
    return modes.find(m => m.id === id) || modes[0]
  }

  // ---------- estado ----------

  property bool open: false
  property bool alive: false
  property string mode: "apps"
  property var recents: ({ apps: [], emoji: [] })
  property var clipEntries: []
  property var emojis: []
  property int emojiTry: 0

  signal clearSearch()

  readonly property string recentPath:
    Quickshell.env("HOME") + "/.cache/qs-launcher-recent.json"

  function setMode(m) {
    mode = m
    if (m === "clip") loadClip()
    clearSearch()
  }

  function show(m) {
    killTimer.stop()
    setMode(m || "apps")
    alive = true
    open = true
  }

  function hide() {
    open = false
    killTimer.restart()
  }

  function toggle() {
    if (open) hide()
    else show("apps")
  }

  Timer {
    id: killTimer
    interval: 240
    onTriggered: root.alive = false
  }

  // ---------- recentes ----------

  FileView {
    id: recentFile
    path: root.recentPath
    printErrors: false

    onLoaded: {
      try {
        let d = JSON.parse(text())
        if (Array.isArray(d)) d = { apps: d, emoji: [] }   // formato antigo
        root.recents = { apps: d.apps || [], emoji: d.emoji || [] }
      } catch (e) {
        root.recents = { apps: [], emoji: [] }
      }
    }
  }

  function markRecent(kind, id) {
    const cur = (recents[kind] || []).filter(x => x !== id)
    cur.unshift(id)

    const next = { apps: recents.apps || [], emoji: recents.emoji || [] }
    next[kind] = cur.slice(0, 30)

    recents = next
    recentFile.setText(JSON.stringify(next))
  }

  function isRecent(kind, id) {
    return (recents[kind] || []).indexOf(id) !== -1
  }

  // ---------- clipboard (cliphist) ----------
  // requer: wl-paste --type text --watch cliphist store (e o mesmo para image)

  Process {
    id: clipProc
    command: ["cliphist", "list"]

    stdout: StdioCollector {
      onStreamFinished: root.parseClip(text)
    }
  }

  Process {
    id: delProc
    onExited: root.loadClip()
  }

  function loadClip() {
    clipProc.running = true
  }

  function parseClip(t) {
    const out = []

    for (const line of t.split("\n")) {
      const tab = line.indexOf("\t")
      if (tab < 0) continue

      const text = line.slice(tab + 1).trim()

      out.push({
        id: line.slice(0, tab),
        text: text,
        isImage: /^\[\[ binary data/.test(text)
      })
    }

    clipEntries = out
  }

  function copyClip(it) {
    Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", it.id])

    if (pasteAfterClip)
      Quickshell.execDetached(["sh", "-c", "sleep 0.35; wtype -M ctrl v -m ctrl"])
  }

  function deleteClip(it) {
    clipEntries = clipEntries.filter(e => e.id !== it.id)

    delProc.command = ["sh", "-c", "printf '%s\\t\\n' \"$1\" | cliphist delete", "sh", it.id]
    delProc.running = true
  }

  // ---------- emoji ----------

  FileView {
    id: emojiFile
    path: root.emojiPaths[root.emojiTry]
    printErrors: false

    onLoaded: root.parseEmoji(text())

    onLoadFailed: {
      if (root.emojiTry < root.emojiPaths.length - 1) root.emojiTry++
    }
  }

  function parseEmoji(t) {
    const out = []
    let group = ""

    for (const raw of t.split("\n")) {
      const line = raw.trim()

      if (line.startsWith("# group:")) {
        group = line.slice(8).trim()
        continue
      }

      if (line === "" || line[0] === "#") continue

      if (/^[0-9A-F]+(\s[0-9A-F]+)*\s*;/.test(line)) {
        // formato emoji-test.txt: "1F600 ; fully-qualified # 😀 E1.0 grinning face"
        if (line.indexOf("; fully-qualified") === -1) continue

        const m = line.match(/#\s+(\S+)\s+E[\d.]+\s+(.+)$/)
        if (!m || m[2].indexOf("skin tone") !== -1) continue

        out.push({ char: m[1], name: m[2], sub: group })
      } else {
        // formato rofi-emoji: "😀 grinning face <small>(face, grin)</small>"
        const sp = line.search(/\s/)
        if (sp < 1) continue

        const rest = line.slice(sp).replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim()
        if (rest.indexOf("skin tone") !== -1) continue

        const p = rest.indexOf("(")
        const name = (p > 0 ? rest.slice(0, p) : rest).trim()
        const kw = p > 0 ? rest.slice(p).replace(/[()]/g, "").trim() : ""

        out.push({ char: line.slice(0, sp), name: name, sub: kw || group })
      }
    }

    emojis = out
  }

  function copyEmoji(ch) {
    Quickshell.execDetached(["wl-copy", ch])

    if (typeEmoji)
      Quickshell.execDetached(["sh", "-c", "sleep 0.35; wtype \"$1\"", "sh", ch])
  }

  // ---------- itens (formato único para todos os modos) ----------

  function mk(o) {
    return {
      kind: o.kind,
      id: o.id || "",
      title: o.title || "",
      subtitle: o.subtitle || "",
      recent: o.recent || false,
      icon: o.icon || "",       // ícone de desktop entry
      glyph: o.glyph || "",     // ícone Material Symbols
      emoji: o.emoji || "",
      isImage: o.isImage || false,
      app: o.app || null,
      text: o.text || ""
    }
  }

  function currentItems(query) {
    switch (mode) {
      case "clip": return clipItems(query)
      case "emoji": return emojiItems(query)
      case "cmd": return cmdItems(query)
      default: return appItems(query)
    }
  }

  function emptyText(query) {
    switch (mode) {
      case "clip":
        return query.trim() === "" ? "Clipboard history is empty\n(is wl-paste --watch cliphist store running?)" : "No matches"
      case "emoji":
        return emojis.length === 0 ? "Emoji list not found\n(install rofi-emoji or unicode-emoji)" : "No matches"
      case "cmd":
        return "Type a command and press Enter"
      default:
        return "No apps found"
    }
  }

  // ----- apps -----

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

  function appItems(query) {
    const q = query.trim().toLowerCase()
    const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay)
    const rec = recents.apps
    let list

    if (q === "") {
      const rank = a => {
        const i = rec.indexOf(a.id)
        return i === -1 ? 999 : i
      }

      list = apps.sort((a, b) => rank(a) - rank(b) || a.name.localeCompare(b.name))
    } else {
      list = apps
        .map(a => ({ a: a, s: score(a, q) + (rec.indexOf(a.id) !== -1 ? 0.5 : 0) }))
        .filter(x => x.s > 0)
        .sort((x, y) => y.s - x.s || x.a.name.localeCompare(y.a.name))
        .map(x => x.a)
    }

    return list.map(a => mk({
      kind: "app",
      app: a,
      id: a.id,
      title: a.name,
      subtitle: a.genericName || "",
      recent: rec.indexOf(a.id) !== -1,
      icon: a.icon || "application-x-executable"
    }))
  }

  // ----- clipboard -----

  function clipItems(query) {
    const q = query.trim().toLowerCase()

    return clipEntries
      .filter(e => q === "" || e.text.toLowerCase().includes(q))
      .slice(0, 300)
      .map(e => mk({
        kind: "clip",
        id: e.id,
        title: e.isImage ? "Image" : e.text,
        subtitle: e.isImage ? e.text.replace(/^\[\[ binary data (.*) \]\]$/, "$1") : "",
        glyph: e.isImage ? "image" : "content_paste",
        isImage: e.isImage,
        text: e.text
      }))
  }

  // ----- emoji -----

  function emojiItems(query) {
    const q = query.trim().toLowerCase()
    const rec = recents.emoji
    let list

    if (q === "") {
      const first = rec.map(c => emojis.find(e => e.char === c)).filter(e => e)
      const rest = emojis.filter(e => rec.indexOf(e.char) === -1)
      list = first.concat(rest)
    } else {
      list = emojis
        .map((e, i) => {
          const name = e.name.toLowerCase()
          let s = 0

          if (name.startsWith(q)) s = 3
          else if (name.includes(" " + q)) s = 2.5
          else if (name.includes(q)) s = 2
          else if (e.sub.toLowerCase().includes(q)) s = 1

          if (s > 0 && rec.indexOf(e.char) !== -1) s += 0.5

          return { e: e, s: s, i: i }
        })
        .filter(x => x.s > 0)
        .sort((x, y) => y.s - x.s || x.i - y.i)
        .slice(0, 300)
        .map(x => x.e)
    }

    return list.map(e => mk({
      kind: "emoji",
      id: e.char,
      title: e.name,
      subtitle: e.sub,
      emoji: e.char,
      recent: rec.indexOf(e.char) !== -1
    }))
  }

  // ----- comando -----

  function cmdItems(query) {
    const t = query.trim()
    if (t === "") return []

    return [mk({ kind: "cmd", id: t, title: t, subtitle: "Run in shell", glyph: "terminal", text: t })]
  }

  // ---------- IPC ----------
  // qs ipc call launcher toggle
  // qs ipc call launcher toggleMode clip   (apps | clip | emoji | cmd)

  IpcHandler {
    target: "launcher"

    function toggle(): void { root.toggle() }
    function show(): void { root.show("apps") }
    function hide(): void { root.hide() }

    function showMode(mode: string): void { root.show(mode) }

    function toggleMode(mode: string): void {
      if (root.open && root.mode === mode) root.hide()
      else root.show(mode)
    }
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

      function launch(it) {
        if (!it) return

        switch (it.kind) {
          case "app":
            root.markRecent("apps", it.app.id)
            root.hide()
            it.app.execute()
            break

          case "clip":
            root.hide()
            root.copyClip(it)
            break

          case "emoji":
            root.markRecent("emoji", it.id)
            root.hide()
            root.copyEmoji(it.emoji)
            break

          case "cmd":
            root.hide()
            Quickshell.execDetached(["sh", "-c", it.text])
            break
        }
      }

      function switchMode(m, rest) {
        root.setMode(m)
        search.text = rest || ""
        search.forceActiveFocus()
      }

      Connections {
        target: root

        function onClearSearch() { search.text = "" }
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

        width: 480
        height: 490 + overshoot
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

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
          spacing: 10

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
                text: root.modeInfo(root.mode).glyph
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
                    switch (event.key) {
                      case Qt.Key_J:
                      case Qt.Key_N:
                        list.incrementCurrentIndex()
                        event.accepted = true
                        break

                      case Qt.Key_K:
                      case Qt.Key_P:
                        list.decrementCurrentIndex()
                        event.accepted = true
                        break

                      case Qt.Key_1: win.switchMode("apps");  event.accepted = true; break
                      case Qt.Key_2: win.switchMode("clip");  event.accepted = true; break
                      case Qt.Key_3: win.switchMode("emoji"); event.accepted = true; break
                      case Qt.Key_4: win.switchMode("cmd");   event.accepted = true; break

                      case Qt.Key_D:
                        if (root.mode === "clip" && list.currentItem) {
                          root.deleteClip(list.currentItem.modelData)
                          event.accepted = true
                        }
                        break
                    }
                  } else if (event.key === Qt.Key_Backspace && text === "" && root.mode !== "apps") {
                    // backspace com a busca vazia volta para apps
                    win.switchMode("apps")
                    event.accepted = true
                  }
                }

                Keys.onReturnPressed: win.launch(list.currentItem ? list.currentItem.modelData : null)
                Keys.onEnterPressed: win.launch(list.currentItem ? list.currentItem.modelData : null)

                Text {
                  visible: search.text.length === 0
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.modeInfo(root.mode).placeholder
                  color: root.mutedColor
                  font: search.font
                }
              }
            }
          }

          // abas de modo
          RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
              model: root.modes

              delegate: Rectangle {
                id: chip

                required property var modelData

                readonly property bool active: root.mode === modelData.id

                Layout.fillWidth: true
                implicitHeight: 28
                radius: 4
                color: active ? root.selectorColor : (chipArea.containsMouse ? root.menuColor : "transparent")
                border.width: 1
                border.color: active ? root.iconColor : root.borderColor

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 5

                  Text {
                    text: chip.modelData.glyph
                    color: chip.active ? root.iconColor : root.mutedColor
                    font.family: root.iconFont
                    font.pixelSize: 16
                  }

                  Text {
                    text: chip.modelData.label
                    color: chip.active ? root.iconColor : root.mutedColor
                    font.family: root.uiFont
                    font.pixelSize: 12
                  }

                  Text {
                    visible: chip.modelData.hint !== ""
                    text: chip.modelData.hint
                    color: root.mutedColor
                    font.family: root.uiFont
                    font.pixelSize: 11
                    opacity: 0.7
                  }
                }

                MouseArea {
                  id: chipArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: win.switchMode(chip.modelData.id)
                }
              }
            }
          }

          // resultados
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
              id: list

              anchors.fill: parent
              clip: true
              spacing: 2
              currentIndex: 0
              highlightMoveDuration: 0
              boundsBehavior: Flickable.StopAtBounds
              model: root.currentItems(search.text)

              onModelChanged: currentIndex = 0

              ScrollIndicator.vertical: ScrollIndicator {}

              delegate: Rectangle {
                id: row

                required property var modelData
                required property int index

                property bool thumbReady: false
                readonly property string thumbPath: "/tmp/qs-cliphist/" + modelData.id + ".img"

                width: ListView.view.width
                height: 56
                radius: 4

                color: ListView.isCurrentItem ? root.selectorColor
                  : (hover.containsMouse ? root.menuColor : "transparent")

                border.width: ListView.isCurrentItem ? 1 : 0
                border.color: root.borderColor

                // miniatura de imagens do clipboard (decodifica só as visíveis)
                Process {
                  id: thumbProc
                  command: ["sh", "-c",
                    "mkdir -p /tmp/qs-cliphist && [ -s \"$1\" ] || cliphist decode \"$2\" > \"$1\"",
                    "sh", row.thumbPath, row.modelData.id]
                  onExited: code => row.thumbReady = (code === 0)
                }

                Component.onCompleted: {
                  if (modelData.kind === "clip" && modelData.isImage) thumbProc.running = true
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 8
                  anchors.rightMargin: row.modelData.kind === "clip" ? 40 : 10
                  spacing: 12

                  Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 6
                    color: root.menuColor
                    border.width: 1
                    border.color: root.borderColor
                    clip: true

                    IconImage {
                      anchors.centerIn: parent
                      implicitSize: 26
                      visible: row.modelData.icon !== ""
                      source: row.modelData.icon !== ""
                        ? Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                        : ""
                    }

                    Text {
                      anchors.centerIn: parent
                      visible: row.modelData.glyph !== "" && !thumb.visible
                      text: row.modelData.glyph
                      color: root.mutedColor
                      font.family: root.iconFont
                      font.pixelSize: 22
                    }

                    Text {
                      anchors.centerIn: parent
                      visible: row.modelData.emoji !== ""
                      text: row.modelData.emoji
                      font.family: root.emojiFont
                      font.pixelSize: 22
                    }

                    Image {
                      id: thumb
                      anchors.fill: parent
                      anchors.margins: 2
                      asynchronous: true
                      fillMode: Image.PreserveAspectCrop
                      sourceSize.width: 80
                      sourceSize.height: 80
                      source: row.thumbReady ? "file://" + row.thumbPath : ""
                      visible: status === Image.Ready
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3

                    Text {
                      Layout.fillWidth: true
                      text: row.modelData.title
                      color: root.iconColor
                      font.family: root.uiFont
                      font.pixelSize: 14
                      elide: Text.ElideRight
                      maximumLineCount: 1
                    }

                    // some quando não há badge nem descrição, assim o título
                    // fica centralizado na linha
                    RowLayout {
                      visible: row.modelData.recent || row.modelData.subtitle !== ""
                      spacing: 8

                      Rectangle {
                        visible: row.modelData.recent
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
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: row.modelData.subtitle
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

                // botão de apagar (só no clipboard)
                Item {
                  visible: row.modelData.kind === "clip"
                    && (row.ListView.isCurrentItem || hover.containsMouse || delArea.containsMouse)
                  anchors.right: parent.right
                  anchors.rightMargin: 8
                  anchors.verticalCenter: parent.verticalCenter
                  width: 28
                  height: 28

                  Text {
                    anchors.centerIn: parent
                    text: "delete"
                    color: delArea.containsMouse ? root.iconColor : root.mutedColor
                    font.family: root.iconFont
                    font.pixelSize: 18
                  }

                  MouseArea {
                    id: delArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.deleteClip(row.modelData)
                  }
                }
              }
            }

            Text {
              anchors.centerIn: parent
              visible: list.count === 0
              horizontalAlignment: Text.AlignHCenter
              text: root.emptyText(search.text)
              color: root.mutedColor
              font.family: root.uiFont
              font.pixelSize: 13
            }
          }
        }
      }
    }
  }
}
