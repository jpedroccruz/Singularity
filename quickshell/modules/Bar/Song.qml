// Módulo Song
// Na barra: só um equalizador animado no ritmo da música. Ele lê o áudio
// real do sistema com o `cava` (obrigatório para a animação funcionar).
// Ao clicar: popup com capa, título, artista, controles e barra de
// progresso arrastável. Funciona com qualquer player MPRIS (Spotify,
// navegador, VLC, mpv...). O Spotify tem prioridade sobre os demais.

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import qs.theme as ThemeModule

Rectangle {
    // ---------- estado ----------
    // ---------- helpers ----------
    // ---------- processos ----------
    // ---------- timers ----------
    // ---------- indicador da barra: só o equalizador ----------
    // ---------- popup ----------

    id: root

    property color iconColor: ThemeModule.Theme.accent
    property color mutedColor: ThemeModule.Theme.muted
    property color panelColor: ThemeModule.Theme.darkBackground
    property color selectorColor: ThemeModule.Theme.selector
    property color menuColor: ThemeModule.Theme.menu
    property color borderColor: ThemeModule.Theme.border
    // Raio dos cantos do popup (igual ao Network).
    property int edge: 20
    readonly property int barCount: 8
    property var levels: [0, 0, 0, 0, 0, 0, 0, 0] // 0..1 por barrinha
    // Player ativo, por ordem de prioridade:
    // 1) Spotify tocando  2) qualquer player tocando
    // 3) Spotify pausado  4) o primeiro da lista
    readonly property var player: {
        const list = Mpris.players.values;
        const isSpotify = (p) => {
            return (p.identity || "").toLowerCase().indexOf("spotify") >= 0 || (p.dbusName || "").toLowerCase().indexOf("spotify") >= 0;
        };
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying && isSpotify(list[i]))
                return list[i];

        }
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return list[i];

        }
        for (let i = 0; i < list.length; i++) {
            if (isSpotify(list[i]))
                return list[i];

        }
        return list.length > 0 ? list[0] : null;
    }
    readonly property bool hasPlayer: player !== null
    readonly property bool playerIsSpotify: hasPlayer && ((player.identity || "").toLowerCase().indexOf("spotify") >= 0 || (player.dbusName || "").toLowerCase().indexOf("spotify") >= 0)
    readonly property bool playing: hasPlayer && player.isPlaying
    readonly property string trackTitle: hasPlayer && player.trackTitle !== "" ? player.trackTitle : "Nada tocando"
    readonly property string trackArtist: hasPlayer ? player.trackArtist : ""
    readonly property string artUrl: hasPlayer ? player.trackArtUrl : ""
    readonly property real length: hasPlayer ? player.length : 0
    readonly property real position: hasPlayer ? player.position : 0
    readonly property bool canSeek: hasPlayer && player.canSeek && player.positionSupported && player.lengthSupported && length > 0

    // Leva até a fonte: vídeo no navegador, Spotify, etc.
    // Usa o IPC do Hyprland pelo próprio Quickshell. No Hyprland 0.55+ o
    // dispatch é uma expressão Lua (hl.dsp.*), não mais "focuswindow ...".
    function focusSource() {
        if (!hasPlayer)
            return ;

        if (player.canRaise)
            player.raise();

        if (playerIsSpotify) {
            Hyprland.dispatch("hl.dsp.focus({ window = [==[class:^(spotify|Spotify)$]==] })");
        } else if (trackTitle !== "" && hasPlayer) {
            const escaped = trackTitle.replace(/[.*+?^${}()|[\]\\\/]/g, "\\$&");
            Hyprland.dispatch("hl.dsp.focus({ window = [==[title:.*" + escaped + ".*]==] })");
        }
        popup.open = false;
    }

    function formatTime(sec) {
        if (!isFinite(sec) || sec < 0)
            sec = 0;

        const s = Math.floor(sec);
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    function parseCava(line) {
        const parts = line.split(";").filter((p) => {
            return p !== "";
        });
        if (parts.length === 0)
            return ;

        const out = [];
        for (let i = 0; i < root.barCount; i++) {
            const v = parseFloat(parts[i]);
            out.push(isNaN(v) ? 0 : Math.max(0, Math.min(1, v / 1000)));
        }
        root.levels = out;
    }

    function resetLevels() {
        const out = [];
        for (let i = 0; i < root.barCount; i++) out.push(0)
        root.levels = out;
    }

    onPlayingChanged: {
        if (!playing)
            resetLevels();

    }
    implicitWidth: eq.implicitWidth + 18
    implicitHeight: 30
    color: "transparent"

    // Lê o áudio do sistema e imprime um valor 0..1000 por barra, uma linha
    // por quadro: "120;800;450;600;300;...". Só roda enquanto há música tocando.
    Process {
        id: cavaProcess

        running: root.playing
        command: ["sh", "-c", "cfg=\"${XDG_RUNTIME_DIR:-/tmp}/qs-song-cava.conf\"; " + "printf '%s\\n' " + "'[general]' 'bars = " + root.barCount + "' 'framerate = 60' 'sensitivity = 100' " + "'[input]' 'method = pulse' 'source = auto' " + "'[smoothing]' 'monstercat = 0' 'waves = 0' 'noise_reduction = 20' " + "'[output]' 'method = raw' 'raw_target = /dev/stdout' " + "'data_format = ascii' 'ascii_max_range = 1000' " + "'bar_delimiter = 59' 'frame_delimiter = 10' > \"$cfg\"; " + "exec cava -p \"$cfg\""]
        onRunningChanged: {
            if (!running)
                root.resetLevels();

        }

        stdout: SplitParser {
            onRead: (data) => {
                return root.parseCava(data);
            }
        }

    }

    // O MPRIS não avisa a posição sozinho: precisa pedir a atualização.
    Timer {
        interval: 250
        running: popup.open && root.playing
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    Timer {
        id: closeTimer

        interval: 180
        onTriggered: {
            if (!mouseArea.containsMouse && !panelHover.hovered && !seekArea.pressed)
                popup.open = false;

        }
    }

    Row {
        id: eq

        anchors.centerIn: parent
        spacing: 2
        height: 18

        Repeater {
            model: root.barCount

            delegate: Rectangle {
                required property int index

                anchors.verticalCenter: parent.verticalCenter
                width: 2.5
                radius: width / 2
                height: 3 + root.levels[index] * 15
                color: root.playing ? root.iconColor : root.mutedColor

                Behavior on height {
                    NumberAnimation {
                        duration: 35
                    }

                }

            }

        }

    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: eq.implicitWidth
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
        onClicked: popup.open = !popup.open
    }

    PanelWindow {
        id: popup

        // `open` é o estado lógico (aberto/fechado); `reveal` vai de 0 a 1 durante a
        // animação. A janela continua visível até a saída terminar.
        property bool open: false
        property real reveal: 0
        // true: pula a animação (usado para reabrir a janela no mesmo lugar)
        property bool instant: false
        // o popup "brota" da barra: a largura abre primeiro, depois a altura
        readonly property real wf: Math.min(1, reveal / 0.55)
        readonly property real hf: Math.max(0, Math.min(1, (reveal - 0.1) / 0.9))

        onOpenChanged: {
            revealAnim.stop();
            if (instant) {
                reveal = open ? 1 : 0;
                return ;
            }
            revealAnim.to = open ? 1 : 0;
            // entra desacelerando; sai acelerando de volta para dentro da barra
            revealAnim.duration = open ? 360 : 240;
            revealAnim.easing.type = open ? Easing.OutQuint : Easing.InCubic;
            revealAnim.start();
        }

        NumberAnimation {
            id: revealAnim

            target: popup
            property: "reveal"
        }

        screen: root.QsWindow.window.screen
        margins.top: root.QsWindow.window.height
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "bar-popup"
        implicitWidth: 340 + root.edge
        implicitHeight: panel.implicitHeight + 4
        visible: open || reveal > 0.001
        color: "transparent"

        anchors {
            top: true
            left: true
        }

        // Tudo cresce a partir do canto da barra: a largura abre primeiro, depois
        // a altura, e a curva do canto côncavo cresce junto, sempre colada na barra.
        Item {
            id: popupGrow

            anchors.top: parent.top
            anchors.left: parent.left
            width: root.edge + (popup.implicitWidth - root.edge) * popup.wf
            height: popup.implicitHeight * popup.hf
            opacity: Math.min(1, popup.reveal * 3)

            // curva que liga o popup à barra (cresce a partir do canto de cima)
            Shape {
                anchors.right: parent.right
                anchors.top: parent.top
                width: root.edge
                height: root.edge
                preferredRendererType: Shape.CurveRenderer
                transformOrigin: Item.TopLeft
                scale: Math.min(1, popup.reveal / 0.5)

                ShapePath {
                    strokeWidth: 0
                    fillColor: root.panelColor
                    startX: 0
                    startY: 0

                    PathLine {
                        x: 0
                        y: root.edge
                    }

                    PathArc {
                        x: root.edge
                        y: 0
                        radiusX: root.edge
                        radiusY: root.edge
                        direction: PathArc.Clockwise
                    }

                    PathLine {
                        x: 0
                        y: 0
                    }
                }

            }

            // fundo do painel (acompanha o tamanho que está crescendo)
            Rectangle {
                id: popupBg

                anchors.fill: parent
                anchors.rightMargin: root.edge
                color: root.panelColor
                bottomRightRadius: root.edge
            }

            // conteúdo com o tamanho final, revelado pelo recorte
            Item {
                anchors.fill: popupBg
                clip: true

                Rectangle {
                    id: panel

                    anchors.top: parent.top
                    anchors.left: parent.left
                    width: popup.implicitWidth - root.edge
                    height: popup.implicitHeight
                    color: "transparent"
                    implicitHeight: content.implicitHeight + 24

                    HoverHandler {
                        id: panelHover

                        onHoveredChanged: {
                            if (hovered)
                                closeTimer.stop();
                            else
                                closeTimer.restart();
                        }
                    }

                    ColumnLayout {
                        // CAPA (esquerda) + NOME/ARTISTA (ao lado)
                        // BARRA DE PROGRESSO
                        // CONTROLES

                        id: content

                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Item {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 104
                                implicitHeight: 104

                                Rectangle {
                                    id: coverMask

                                    anchors.fill: parent
                                    radius: 12
                                    visible: false
                                    layer.enabled: true
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 12
                                    color: root.selectorColor
                                    border.width: 1
                                    border.color: root.borderColor
                                    visible: cover.status !== Image.Ready

                                    Text {
                                        anchors.centerIn: parent
                                        text: "music_note"
                                        color: root.mutedColor
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 40
                                    }

                                }

                                Image {
                                    id: cover

                                    anchors.fill: parent
                                    source: root.artUrl
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    visible: status === Image.Ready
                                    layer.enabled: true

                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: coverMask
                                    }

                                }

                                // hover: escurece a capa e mostra o ícone de "abrir"
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 12
                                    color: "#000000"
                                    opacity: coverMouse.containsMouse ? 0.45 : 0
                                    visible: root.hasPlayer

                                    Text {
                                        anchors.centerIn: parent
                                        text: "open_in_new"
                                        color: "#ffffff"
                                        opacity: coverMouse.containsMouse ? 1 : 0
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 34
                                    }

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 120
                                        }

                                    }

                                }

                                MouseArea {
                                    id: coverMouse

                                    anchors.fill: parent
                                    enabled: root.hasPlayer
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.focusSource()
                                }

                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3

                                Text {
                                    Layout.fillWidth: true
                                    text: root.trackTitle
                                    color: root.iconColor
                                    font.family: "Rubik"
                                    font.pixelSize: 16
                                    font.bold: true
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: root.trackArtist
                                    color: root.mutedColor
                                    font.family: "Rubik"
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }

                            }

                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Item {
                                id: seekArea0

                                property real dragValue: 0
                                readonly property bool dragging: seekArea.pressed
                                readonly property real shown: dragging ? dragValue : (root.length > 0 ? Math.max(0, Math.min(1, root.position / root.length)) : 0)

                                Layout.fillWidth: true
                                implicitHeight: 16

                                Rectangle {
                                    id: track

                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 5
                                    radius: height / 2
                                    color: root.selectorColor
                                    border.width: 1
                                    border.color: root.borderColor

                                    Rectangle {
                                        width: parent.width * seekArea0.shown
                                        height: parent.height
                                        radius: parent.radius
                                        color: root.iconColor
                                    }

                                }

                                Rectangle {
                                    visible: root.canSeek
                                    width: seekArea.pressed ? 14 : 11
                                    height: width
                                    radius: width / 2
                                    color: root.iconColor
                                    anchors.verticalCenter: track.verticalCenter
                                    x: Math.max(0, Math.min(track.width - width, track.width * seekArea0.shown - width / 2))

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 90
                                        }

                                    }

                                }

                                MouseArea {
                                    id: seekArea

                                    function valueAt(x) {
                                        return Math.max(0, Math.min(1, x / width));
                                    }

                                    anchors.fill: parent
                                    enabled: root.canSeek
                                    hoverEnabled: true
                                    cursorShape: root.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onPressed: (mouse) => {
                                        return seekArea0.dragValue = valueAt(mouse.x);
                                    }
                                    onPositionChanged: (mouse) => {
                                        if (pressed)
                                            seekArea0.dragValue = valueAt(mouse.x);

                                    }
                                    onReleased: (mouse) => {
                                        const v = valueAt(mouse.x);
                                        seekArea0.dragValue = v;
                                        if (root.hasPlayer && root.length > 0) {
                                            root.player.position = v * root.length;
                                            root.player.positionChanged();
                                        }
                                    }
                                }

                            }

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: root.formatTime(seekArea0.dragging ? seekArea0.dragValue * root.length : root.position)
                                    color: root.mutedColor
                                    font.family: "Rubik"
                                    font.pixelSize: 12
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: root.formatTime(root.length)
                                    color: root.mutedColor
                                    font.family: "Rubik"
                                    font.pixelSize: 12
                                }

                            }

                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 18

                            Rectangle {
                                implicitWidth: 40
                                implicitHeight: 40
                                radius: 12
                                color: prevMouse.containsMouse ? root.selectorColor : "transparent"
                                opacity: root.hasPlayer && root.player.canGoPrevious ? 1 : 0.4

                                Text {
                                    anchors.centerIn: parent
                                    text: "skip_previous"
                                    color: root.iconColor
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 28
                                }

                                MouseArea {
                                    id: prevMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: root.hasPlayer && root.player.canGoPrevious
                                    onClicked: root.player.previous()
                                }

                            }

                            Rectangle {
                                implicitWidth: 52
                                implicitHeight: 52
                                radius: 26
                                color: root.iconColor
                                opacity: root.hasPlayer && root.player.canTogglePlaying ? 1 : 0.4
                                scale: playMouse.pressed ? 0.94 : 1

                                Text {
                                    anchors.centerIn: parent
                                    text: root.playing ? "pause" : "play_arrow"
                                    color: root.panelColor
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 32
                                }

                                MouseArea {
                                    id: playMouse

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: root.hasPlayer && root.player.canTogglePlaying
                                    onClicked: root.player.togglePlaying()
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 90
                                    }

                                }

                            }

                            Rectangle {
                                implicitWidth: 40
                                implicitHeight: 40
                                radius: 12
                                color: nextMouse.containsMouse ? root.selectorColor : "transparent"
                                opacity: root.hasPlayer && root.player.canGoNext ? 1 : 0.4

                                Text {
                                    anchors.centerIn: parent
                                    text: "skip_next"
                                    color: root.iconColor
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 28
                                }

                                MouseArea {
                                    id: nextMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: root.hasPlayer && root.player.canGoNext
                                    onClicked: root.player.next()
                                }

                            }

                        }

                    }

                }
            }

        }

    }

}
