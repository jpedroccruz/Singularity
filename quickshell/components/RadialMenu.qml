import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import qs.theme as ThemeModule

// Menu radial (estilo OPie) com 6 slots — buraco negro minimalista.
// Dois modos no mesmo menu:
//   themes      os 6 temas; cada um mostra o primeiro backgrounds da pasta dele
//   wallpapers  só os wallpapers do tema atual (6 por página; roda do mouse / PageUp / PageDown)
//
//   qs ipc call radial toggle                    abre/fecha os temas
//   qs ipc call radial toggleThemes              idem
//   qs ipc call radial toggleWallpapers          wallpapers do tema atual (o último aplicado aqui)
//   qs ipc call radial toggleWallpapersOf Igris  wallpapers de um tema específico
//   qs ipc call radial activate                  ativa o slot sob o mouse e fecha
//
// Teclas: 1-6 ativa direto; setas/Tab percorrem; Enter/Espaço ativa; Esc fecha;
//         T = temas, W = wallpapers; PageUp/PageDown = página.

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

  // ---------- pastas e comandos (AJUSTE AQUI) ----------

  // wallpapers de cada tema ficam em <themesRoot>/<nome do tema>/<wallpaperSubdir>
  // (ou defina "dir" num slot para usar outra pasta só para ele)
  property string themesRoot: Quickshell.env("HOME") + "/Singularity/themes"
  property string wallpaperSubdir: "backgrounds"

  // comando que aplica um backgrounds; o caminho do arquivo entra como último argumento
  property string wallpaperCmd: "~/Singularity/bin/singularity wallpaper set"

  property var imageFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.avif", "*.bmp", "*.gif"]

  // ---------- os 6 temas ----------
  // slot 0 fica no topo; os demais seguem no sentido horário.
  //   name:  nome do tema (também o nome da pasta)
  //   color: cor do tema
  //   cmd:   comando de shell executado ao ativar (vazio = slot desativado)
  //   dir:   (opcional) pasta de wallpapers deste tema

  property string title: "Themes"

  property var slots: [
    { name: "Igris", icon: "palette", color: "#ff6265", cmd: "~/Singularity/bin/singularity theme set Igris" },
    { name: "Ion", icon: "palette", color: "#3ca3fe", cmd: "~/Singularity/bin/singularity theme set Ion" },
    { name: "Lunar", icon: "palette", color: "#d7d7dc", cmd: "~/Singularity/bin/singularity theme set Lunar" },
    { name: "Nebula", icon: "palette", color: "#c673f8", cmd: "~/Singularity/bin/singularity theme set Nebula" },
    { name: "Solarius", icon: "palette", color: "#f37523", cmd: "~/Singularity/bin/singularity theme set Solarius" },
    { name: "Veridian", icon: "palette", color: "#35c884", cmd: "~/Singularity/bin/singularity theme set Veridian" }
  ]

  // ---------- geometria ----------

  readonly property real outerR: 360
  readonly property real innerR: 136    // onde as fatias começam (junto ao buraco)
  readonly property real size: outerR * 2 + 20

  readonly property real horizonR: 104   // raio do buraco negro
  readonly property real orbitR: (innerR + outerR) / 2   // centro das fatias, onde fica a imagem

  // ---------- estado ----------

  property bool open: false
  property bool alive: false
  property int hovered: -1

  property string mode: "themes"          // "themes" | "wallpapers"
  property string currentTheme: ""        // último tema aplicado por este menu
  property string wallpaperTheme: ""      // tema cujos wallpapers estão sendo mostrados
  property int page: 0

  readonly property string cachePath: Quickshell.env("HOME") + "/.cache/qs-radial-theme"

  FileView {
    id: themeFile
    path: root.cachePath
    printErrors: false

    onLoaded: root.currentTheme = text().trim()
  }

  function setCurrentTheme(name) {
    currentTheme = name
    themeFile.setText(name)
  }

  function themeByName(name) {
    return slots.find(s => s.name === name) || null
  }

  function dirOf(s) {
    return s.dir ? s.dir : themesRoot + "/" + s.name + "/" + wallpaperSubdir
  }

  // cor do tema cujos wallpapers estão abertos (cai na cor de destaque)
  readonly property color baseColor: {
    if (mode !== "wallpapers") return iconColor
    const s = themeByName(wallpaperTheme)
    return s && s.color ? Qt.color(s.color) : iconColor
  }

  // ---------- wallpapers do tema atual ----------

  FolderListModel {
    id: wpModel

    folder: {
      if (root.mode !== "wallpapers") return ""
      const s = root.themeByName(root.wallpaperTheme)
      const d = s ? root.dirOf(s) : root.themesRoot + "/" + root.wallpaperTheme + "/" + root.wallpaperSubdir
      return "file://" + d
    }

    nameFilters: root.imageFilters
    showDirs: false
    caseSensitive: false
  }

  readonly property int pageCount: mode === "wallpapers" ? Math.max(1, Math.ceil(wpModel.count / 6)) : 1

  // itens mostrados no anel (no máximo 6)
  readonly property var items: buildItems()

  onItemsChanged: {
    if (hovered >= items.length) hovered = -1
  }

  function buildItems() {
    if (mode === "wallpapers") {
      const n = wpModel.count
      const folder = wpModel.folder      // só para o binding reagir à troca de pasta
      const s = themeByName(wallpaperTheme)
      const color = s && s.color ? s.color : ""
      const out = []

      for (let i = page * 6; i < Math.min(n, page * 6 + 6); i++) {
        out.push({
          kind: "backgrounds",
          name: String(wpModel.get(i, "fileName")).replace(/\.[^.]+$/, ""),
          color: color,
          image: String(wpModel.get(i, "fileUrl")),
          path: String(wpModel.get(i, "filePath")),
          dir: "",
          cmd: ""
        })
      }

      return out
    }

    return slots.map(s => ({
      kind: "theme",
      name: s.name,
      color: s.color || "",
      image: "",
      path: "",
      dir: dirOf(s),
      cmd: s.cmd || ""
    }))
  }

  // ---------- abrir / fechar ----------

  function show(m, theme) {
    killTimer.stop()

    mode = m || "themes"

    if (mode === "wallpapers")
      wallpaperTheme = theme || currentTheme || (slots.length > 0 ? slots[0].name : "")

    page = 0
    hovered = -1
    alive = true
    open = true
  }

  function hide() {
    open = false
    killTimer.restart()
  }

  function toggle() {
    toggleMode("themes", "")
  }

  function toggleMode(m, theme) {
    if (open && mode === m && (!theme || theme === wallpaperTheme)) hide()
    else show(m, theme)
  }

  function nextPage() {
    page = (page + 1) % pageCount
  }

  function prevPage() {
    page = (page - 1 + pageCount) % pageCount
  }

  function activate(i) {
    const it = items[i]
    if (!it) return

    hide()

    if (it.kind === "theme") {
      if (!it.cmd) return

      Quickshell.execDetached(["sh", "-c", it.cmd])
      setCurrentTheme(it.name)
    } else {
      Quickshell.execDetached(["sh", "-c", wallpaperCmd + " \"$1\"", "sh", it.path])
    }
  }

  function activateHovered() {
    if (hovered >= 0) activate(hovered)
    else hide()
  }

  function step(d) {
    const n = items.length
    if (n === 0) return

    hovered = hovered < 0 ? (d > 0 ? 0 : n - 1) : (hovered + d + n) % n
  }

  Timer {
    id: killTimer
    interval: 220
    onTriggered: root.alive = false
  }

  // ---------- IPC ----------

  IpcHandler {
    target: "radial"

    function toggle(): void { root.toggle() }
    function show(): void { root.show("themes", "") }
    function hide(): void { root.hide() }
    function activate(): void { root.activateHovered() }

    function toggleThemes(): void { root.toggleMode("themes", "") }
    function showThemes(): void { root.show("themes", "") }

    function toggleWallpapers(): void { root.toggleMode("wallpapers", "") }
    function showWallpapers(): void { root.show("wallpapers", "") }

    function toggleWallpapersOf(theme: string): void { root.toggleMode("wallpapers", theme) }
    function showWallpapersOf(theme: string): void { root.show("wallpapers", theme) }
  }

  // ---------- janela ----------

  LazyLoader {
    active: root.alive

    PanelWindow {
      id: win

      property bool shown: false

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      WlrLayershell.namespace: "radial"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

      Timer {
        running: true
        interval: 30
        onTriggered: win.shown = true
      }

      // fundo escurecido; clicar fora fecha
      Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: (win.shown && root.open) ? 0.45 : 0

        Behavior on opacity {
          NumberAnimation { duration: 180 }
        }

        MouseArea {
          anchors.fill: parent
          onClicked: root.hide()
        }
      }

      // teclado
      Item {
        anchors.fill: parent
        focus: true

        Component.onCompleted: forceActiveFocus()

        Keys.onPressed: event => {
          const k = event.key

          if (k === Qt.Key_Escape) {
            root.hide()
          } else if (k >= Qt.Key_1 && k <= Qt.Key_6) {
            root.activate(k - Qt.Key_1)
          } else if (k === Qt.Key_Right || k === Qt.Key_Down || k === Qt.Key_Tab) {
            root.step(1)
          } else if (k === Qt.Key_Left || k === Qt.Key_Up || k === Qt.Key_Backtab) {
            root.step(-1)
          } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            root.activateHovered()
          } else if (k === Qt.Key_T) {
            root.show("themes", "")
          } else if (k === Qt.Key_W) {
            root.show("wallpapers", "")
          } else if (k === Qt.Key_PageDown) {
            root.nextPage()
          } else if (k === Qt.Key_PageUp) {
            root.prevPage()
          } else {
            return
          }

          event.accepted = true
        }
      }

      Item {
        id: ring

        width: root.size
        height: root.size
        anchors.centerIn: parent

        readonly property bool shownNow: win.shown && root.open

        // seletor: ângulo (pelo caminho mais curto), intensidade e cor
        property real selAngle: 0
        property real selStrength: 0
        property color tint: root.baseColor
        property bool animateSel: true

        scale: shownNow ? 1 : 0.92
        opacity: shownNow ? 1 : 0

        Behavior on scale {
          NumberAnimation { duration: root.open ? 220 : 140; easing.type: Easing.OutCubic }
        }

        Behavior on opacity {
          NumberAnimation { duration: root.open ? 180 : 140 }
        }

        Behavior on selAngle {
          enabled: ring.animateSel
          NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Behavior on selStrength {
          NumberAnimation { duration: 160 }
        }

        Behavior on tint {
          ColorAnimation { duration: 200 }
        }

        function rgba(c, a) {
          return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
            + Math.round(c.b * 255) + "," + a + ")"
        }

        function slotColor(i) {
          const it = root.items[i]
          return it && it.color ? Qt.color(it.color) : root.baseColor
        }

        // aponta o seletor para o item sob o mouse/teclado
        function retarget() {
          if (root.hovered >= 0 && root.hovered < root.items.length) {
            const target = -Math.PI / 2 + root.hovered * Math.PI / 3

            if (selStrength < 0.05) {
              // seletor apagado: aparece direto na fatia
              animateSel = false
              selAngle = target
              animateSel = true
            } else {
              let d = target - selAngle
              d = Math.atan2(Math.sin(d), Math.cos(d))   // caminho mais curto
              selAngle = selAngle + d
            }

            selStrength = 1
            tint = slotColor(root.hovered)
          } else {
            selStrength = 0
            tint = root.baseColor
          }
        }

        // fatia anelar (entre r0 e r1, centrada em mid) com cantos arredondados e contorno
        function paintSector(ctx, c, r0, r1, mid, half, fill, edge, edgeW) {
          const m = 7                                // raio dos cantos
          const a = m / ((r0 + r1) / 2)              // margem angular equivalente

          ctx.beginPath()
          ctx.arc(c, c, r1 - m, mid - half + a, mid + half - a, false)
          ctx.arc(c, c, r0 + m, mid + half - a, mid - half + a, true)
          ctx.closePath()

          ctx.lineJoin = "round"

          ctx.lineWidth = m * 2 + edgeW
          ctx.strokeStyle = edge
          ctx.stroke()

          ctx.lineWidth = m * 2
          ctx.strokeStyle = fill
          ctx.fillStyle = fill
          ctx.fill()
          ctx.stroke()
        }

        Connections {
          target: root

          function onItemsChanged() { canvas.requestPaint() }
          function onHoveredChanged() { ring.retarget() }
          function onBaseColorChanged() { ring.retarget() }
        }

        onSelAngleChanged: canvas.requestPaint()
        onSelStrengthChanged: canvas.requestPaint()
        onTintChanged: canvas.requestPaint()

        // poço gravitacional + fatias + destaque deslizante (como um disco de acreção que esquenta)
        Canvas {
          id: canvas
          anchors.fill: parent

          onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            const c = width / 2
            const iR = root.innerR
            const oR = root.outerR
            const n = root.items.length
            const half = Math.PI / 6 - 0.025          // meia largura de uma fatia (deixa um vão entre elas)
            const str = ring.selStrength

            // brilho que cresce em direção ao buraco
            const halo = ctx.createRadialGradient(c, c, root.horizonR, c, c, oR)
            halo.addColorStop(0, ring.rgba(ring.tint, 0.30))
            halo.addColorStop(0.18, ring.rgba(ring.tint, 0.10))
            halo.addColorStop(1, ring.rgba(ring.tint, 0))
            ctx.fillStyle = halo
            ctx.beginPath()
            ctx.arc(c, c, oR, 0, Math.PI * 2, false)
            ctx.fill()

            // fatias: escuras junto ao buraco, mais claras para fora
            const base = ctx.createRadialGradient(c, c, iR, c, c, oR)
            base.addColorStop(0, "rgba(0,0,0,0.94)")
            base.addColorStop(1, ring.rgba(root.menuColor, 0.90))

            for (let i = 0; i < n; i++) {
              const mid = -Math.PI / 2 + i * Math.PI / 3
              ring.paintSector(ctx, c, iR, oR, mid, half, base, ring.rgba(root.mutedColor, 0.30), 2)
            }

            // fatia selecionada: acende na cor do tema, mais quente perto do buraco
            if (str > 0.01) {
              const A = ring.selAngle

              const hot = ctx.createRadialGradient(c, c, iR, c, c, oR)
              hot.addColorStop(0, ring.rgba(ring.tint, 0.62 * str))
              hot.addColorStop(1, ring.rgba(ring.tint, 0.14 * str))

              ring.paintSector(ctx, c, iR, oR, A, half, hot, ring.rgba(ring.tint, 0.95 * str), 4)

              // e acende o anel do buraco na mesma direção
              ctx.lineWidth = 6
              ctx.lineCap = "round"
              ctx.strokeStyle = ring.rgba(ring.tint, 0.95 * str)
              ctx.beginPath()
              ctx.arc(c, c, root.horizonR + 16, A - Math.PI / 6 + 0.12, A + Math.PI / 6 - 0.12, false)
              ctx.stroke()
            }
          }
        }

        // anéis de lente gravitacional em volta do buraco
        Rectangle {
          anchors.centerIn: parent
          width: (root.horizonR + 16) * 2
          height: width
          radius: width / 2
          color: "transparent"
          border.width: 2
          border.color: Qt.rgba(ring.tint.r, ring.tint.g, ring.tint.b, 0.30)
        }

        // o buraco negro: disco preto com um anel fino
        Rectangle {
          id: hole
          anchors.centerIn: parent
          width: root.horizonR * 2
          height: width
          radius: width / 2
          color: "#000000"
          border.width: 3
          border.color: ring.tint
        }

        // os itens: uma imagem redonda dentro de cada fatia
        Repeater {
          model: root.items

          delegate: Item {
            id: slot

            required property var modelData
            required property int index

            readonly property bool hot: root.hovered === index
            readonly property color tc: modelData.color ? modelData.color : root.iconColor
            readonly property bool active: ring.shownNow

            // temas: primeiro backgrounds da pasta; wallpapers: a própria imagem
            readonly property string imageSrc: modelData.image
              ? modelData.image
              : (thumbModel.count > 0 ? String(thumbModel.get(0, "fileUrl")) : "")

            readonly property real ang: -Math.PI / 2 + index * Math.PI * 2 / 6

            property real appear: 0   // 0 = engolido pelo buraco, 1 = em órbita

            readonly property real r: (root.horizonR + 40) + (root.orbitR - root.horizonR - 40) * appear

            width: 180
            height: 180
            z: hot ? 5 : 0
            x: ring.width / 2 + r * Math.cos(ang) - width / 2
            y: ring.height / 2 + r * Math.sin(ang) - height / 2
            scale: 0.7 + 0.3 * appear
            opacity: ((modelData.kind === "backgrounds" || modelData.cmd) ? 1 : 0.35) * appear

            function play() {
              seq.stop()
              pause.duration = active ? index * 30 : 0
              grow.to = active ? 1 : 0
              grow.duration = active ? 260 : 120
              seq.start()
            }

            onActiveChanged: play()

            // itens recriados com o anel já aberto (troca de modo/página) também animam
            Component.onCompleted: if (active) play()

            SequentialAnimation {
              id: seq

              PauseAnimation { id: pause; duration: 0 }

              NumberAnimation {
                id: grow
                target: slot
                property: "appear"
                to: 1
                duration: 260
                easing.type: Easing.OutCubic
              }
            }

            FolderListModel {
              id: thumbModel

              folder: slot.modelData.dir ? "file://" + slot.modelData.dir : ""
              nameFilters: root.imageFilters
              showDirs: false
              caseSensitive: false
            }

            // imagem redonda no centro da fatia
            ClippingRectangle {
              id: thumb

              anchors.centerIn: parent
              width: 150
              height: 150
              radius: 75
              color: Qt.darker(slot.tc, 4)
              border.width: 4
              border.color: slot.hot ? Qt.lighter(slot.tc, 1.3) : Qt.rgba(slot.tc.r, slot.tc.g, slot.tc.b, 0.85)
              scale: slot.hot ? 1.14 : 1

              Behavior on scale {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
              }

              Image {
                anchors.fill: parent
                source: slot.imageSrc
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 320
                sourceSize.height: 320
                visible: status === Image.Ready
              }
            }
          }
        }

        // nome dentro do buraco
        Text {
          anchors.centerIn: parent
          width: (root.horizonR - 12) * 2
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          text: (root.hovered >= 0 && root.hovered < root.items.length)
            ? root.items[root.hovered].name
            : (root.mode === "wallpapers" ? "Wallpapers" : root.title)
          color: root.hovered >= 0 ? ring.tint : root.mutedColor
          font.family: root.uiFont
          font.pixelSize: 24
          font.letterSpacing: 2
          font.capitalization: Font.AllUppercase
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: root.hovered >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor

          // qual fatia está sob o ponto (-1 = centro, fora do anel ou fatia vazia)
          function pick(mx, my) {
            const dx = mx - width / 2
            const dy = my - height / 2
            const r = Math.sqrt(dx * dx + dy * dy)

            if (r < root.innerR || r > root.outerR) return -1

            let a = Math.atan2(dx, -dy)   // 0 = topo, sentido horário
            if (a < 0) a += Math.PI * 2

            const i = Math.floor((a + Math.PI / 6) / (Math.PI / 3)) % 6
            return i < root.items.length ? i : -1
          }

          onPositionChanged: mouse => root.hovered = pick(mouse.x, mouse.y)
          onExited: root.hovered = -1

          onWheel: wheel => {
            if (root.mode !== "wallpapers") return

            if (wheel.angleDelta.y < 0) root.nextPage()
            else root.prevPage()
          }

          onClicked: mouse => {
            const i = pick(mouse.x, mouse.y)
            if (i >= 0) root.activate(i)
            else root.hide()
          }
        }
      }

      // rodapé: tema/página, nome completo ou aviso de pasta vazia (só em wallpapers)
      Text {
        anchors.horizontalCenter: ring.horizontalCenter
        anchors.top: ring.bottom
        anchors.topMargin: 4
        visible: root.mode === "wallpapers"
        opacity: ring.opacity
        color: root.mutedColor
        font.family: root.uiFont
        font.pixelSize: 20
        font.letterSpacing: 2
        text: {
          if (root.items.length === 0)
            return "No images in " + String(wpModel.folder).replace("file://", "")

          if (root.hovered >= 0 && root.hovered < root.items.length)
            return root.items[root.hovered].name

          return root.wallpaperTheme + (root.pageCount > 1 ? "  ·  " + (root.page + 1) + "/" + root.pageCount : "")
        }
      }
    }
  }
}
