import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs.theme as ThemeModule

Scope {
    // ---------- tema ----------
    // ---------- configuração ----------
    // ---------- estado ----------
    // ---------- funções ----------
    // ---------- temporizadores ----------
    // ---------- volume e microfone ----------
    // ---------- Caps Lock e Num Lock ----------
    // ---------- janela ----------

    id: root

    property color iconColor: ThemeModule.Theme.accent
    property color mutedColor: ThemeModule.Theme.muted
    property color panelColor: ThemeModule.Theme.darkBackground
    property color selectorColor: ThemeModule.Theme.selector
    property color borderColor: ThemeModule.Theme.border
    property int bottomMargin: 90 // distância da borda de baixo da tela
    property int cardWidth: 290
    property int hideDelay: 1600 // ms que o OSD fica na tela
    property string kind: "" // "volume", "mic", "caps" ou "num"
    property real level: 0 // volume (1.0 = 100%)
    property bool flag: false // volume/mic: mudo; caps/num: ligado
    property bool shown: false
    property bool ready: false // evita mostrar o OSD ao iniciar o shell
    property bool caps: false
    property bool num: false
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool hasBar: kind === "volume" || kind === "mic"
    // "ativo": volume sem mudo, ou trava ligada
    readonly property bool lit: hasBar ? !flag : flag
    readonly property string title: kind === "volume" ? "Volume" : kind === "mic" ? "Microfone" : kind === "caps" ? "Caps Lock" : kind === "num" ? "Num Lock" : ""
    readonly property string icon: {
        if (kind === "volume") {
            if (flag || level <= 0)
                return "volume_off";

            return level < 0.34 ? "volume_mute" : level < 0.67 ? "volume_down" : "volume_up";
        }
        if (kind === "mic")
            return flag ? "mic_off" : "mic";

        if (kind === "caps")
            return "keyboard_capslock";

        return "pin";
    }
    readonly property string statusText: hasBar ? (flag ? "Mudo" : Math.round(level * 100) + "%") : (flag ? "Ligado" : "Desligado")

    function show(k, lvl, f) {
        root.kind = k;
        root.level = lvl;
        root.flag = f;
        root.shown = true;
        hideTimer.restart();
    }

    function showSink() {
        if (root.ready && root.sink && root.sink.audio)
            root.show("volume", root.sink.audio.volume, root.sink.audio.muted);

    }

    function showSource() {
        if (root.ready && root.source && root.source.audio)
            root.show("mic", root.source.audio.volume, root.source.audio.muted);

    }

    // Recebe "<caps> <num>" (0 ou 1) do script abaixo.
    function parseLocks(line) {
        const p = line.trim().split(" ");
        if (p.length < 2)
            return ;

        const c = p[0] === "1";
        const n = p[1] === "1";
        if (c !== root.caps) {
            root.caps = c;
            if (root.ready)
                root.show("caps", 0, c);

        }
        if (n !== root.num) {
            root.num = n;
            if (root.ready)
                root.show("num", 0, n);

        }
    }

    Timer {
        id: hideTimer

        interval: root.hideDelay
        onTriggered: root.shown = false
    }

    // ignora as mudanças do início (o PipeWire carrega os volumes)
    Timer {
        running: true
        interval: 1500
        onTriggered: root.ready = true
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    Connections {
        function onVolumeChanged() {
            root.showSink();
        }

        function onMutedChanged() {
            root.showSink();
        }

        target: root.sink ? root.sink.audio : null
        ignoreUnknownSignals: true
    }

    Connections {
        function onVolumeChanged() {
            root.showSource();
        }

        function onMutedChanged() {
            root.showSource();
        }

        target: root.source ? root.source.audio : null
        ignoreUnknownSignals: true
    }

    // Fica rodando e só imprime uma linha quando o estado muda.
    Process {
        running: true
        command: ["sh", "-c", `
last=""
while true; do
  caps=0
  num=0
  for f in /sys/class/leds/*::capslock/brightness; do
    [ -e "$f" ] || continue
    read -r v < "$f"
    [ "$v" = 1 ] && caps=1
  done
  for f in /sys/class/leds/*::numlock/brightness; do
    [ -e "$f" ] || continue
    read -r v < "$f"
    [ "$v" = 1 ] && num=1
  done
  cur="$caps $num"
  if [ "$cur" != "$last" ]; then
    echo "$cur"
    last="$cur"
  fi
  sleep 0.15
done
`]

        stdout: SplitParser {
            onRead: (data) => {
                return root.parseLocks(data);
            }
        }

    }

    PanelWindow {
        id: win

        // continua visível até o fade de saída terminar
        visible: root.shown || card.opacity > 0.01
        anchors.bottom: true
        margins.bottom: root.bottomMargin
        implicitWidth: root.cardWidth
        implicitHeight: card.height
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "osd"

        Rectangle {
            id: card

            width: parent.width
            height: row.implicitHeight + 28
            radius: 10
            color: root.panelColor
            border.width: 2
            border.color: root.iconColor
            opacity: root.shown ? 1 : 0

            RowLayout {
                id: row

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 16
                spacing: 14

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.icon
                    color: root.lit ? root.iconColor : root.mutedColor
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 30
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: root.title
                            color: root.mutedColor
                            font.family: "Rubik"
                            font.pixelSize: 12
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.statusText
                            color: root.lit ? root.iconColor : root.mutedColor
                            font.family: "Rubik"
                            font.pixelSize: 14
                            font.bold: true
                        }

                    }

                    // barra de volume (só para volume e microfone)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        visible: root.hasBar
                        radius: 3
                        color: root.selectorColor
                        border.width: 1
                        border.color: root.borderColor

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, root.level))
                            height: parent.height
                            radius: parent.radius
                            color: root.lit ? root.iconColor : root.mutedColor

                            Behavior on width {
                                NumberAnimation {
                                    duration: 80
                                }

                            }

                        }

                    }

                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }

            }

            // sobe um pouco ao aparecer e desce ao sumir
            transform: Translate {
                y: root.shown ? 0 : 14

                Behavior on y {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

        // região de entrada vazia: o OSD nunca captura cliques
        mask: Region {
        }

    }

}
