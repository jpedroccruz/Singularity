
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs.theme as ThemeModule

Scope {
    id: root

    // ---------- tema ----------

    property color iconColor: ThemeModule.Theme.accent
    property color mutedColor: ThemeModule.Theme.muted
    property color panelColor: ThemeModule.Theme.darkBackground
    property color selectorColor: ThemeModule.Theme.selector
    property color borderColor: ThemeModule.Theme.border

    // ---------- configuração ----------

    property int bottomMargin: 90
    property int cardWidth: 290
    property int hideDelay: 1600

    // ---------- estado ----------

    property string kind: ""
    property real level: 0
    property bool flag: false
    property bool shown: false
    property bool ready: false
    property bool caps: false
    property bool num: false
    property int brightnessPercent: -1

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property bool hasBar:
        kind === "volume" ||
        kind === "mic" ||
        kind === "brightness"

    readonly property bool lit: hasBar ? !flag : flag

    readonly property string title: {
        if (kind === "volume")
            return "Volume";
        if (kind === "mic")
            return "Microfone";
        if (kind === "brightness")
            return "Brilho";
        if (kind === "caps")
            return "Caps Lock";
        if (kind === "num")
            return "Num Lock";

        return "";
    }

    readonly property string icon: {
        if (kind === "volume") {
            if (flag || level <= 0)
                return "volume_off";

            return level < 0.34
                ? "volume_mute"
                : level < 0.67
                    ? "volume_down"
                    : "volume_up";
        }

        if (kind === "mic")
            return flag ? "mic_off" : "mic";

        if (kind === "brightness") {
            return level < 0.34
                ? "brightness_low"
                : level < 0.67
                    ? "brightness_medium"
                    : "brightness_high";
        }

        if (kind === "caps")
            return "keyboard_capslock";

        return "pin";
    }

    readonly property string statusText: {
        if (kind === "brightness")
            return Math.round(level * 100) + "%";

        if (hasBar)
            return flag ? "Mudo" : Math.round(level * 100) + "%";

        return flag ? "Ligado" : "Desligado";
    }

    // ---------- funções ----------

    function show(k, lvl, f) {
        root.kind = k;
        root.level = lvl;
        root.flag = f;
        root.shown = true;

        hideTimer.restart();
    }

    function showSink() {
        if (root.ready && root.sink && root.sink.audio) {
            root.show(
                "volume",
                root.sink.audio.volume,
                root.sink.audio.muted
            );
        }
    }

    function showSource() {
        if (root.ready && root.source && root.source.audio) {
            root.show(
                "mic",
                root.source.audio.volume,
                root.source.audio.muted
            );
        }
    }

    function parseSystemState(line) {
        const p = line.trim().split(/\s+/);

        if (p.length < 3)
            return;

        const c = p[0] === "1";
        const n = p[1] === "1";
        const b = Number(p[2]);

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

        if (Number.isFinite(b) && b >= 0 && b <= 100) {
            if (b !== root.brightnessPercent) {
                root.brightnessPercent = b;

                if (root.ready)
                    root.show("brightness", b / 100, false);
            }
        }
    }

    // ---------- temporizadores ----------

    Timer {
        id: hideTimer

        interval: root.hideDelay

        onTriggered: root.shown = false
    }

    // Ignora as mudanças do início enquanto o PipeWire carrega.
    Timer {
        running: true
        interval: 1500

        onTriggered: root.ready = true
    }

    // ---------- volume e microfone ----------

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    Connections {
        target: root.sink ? root.sink.audio : null
        ignoreUnknownSignals: true

        function onVolumeChanged() {
            root.showSink();
        }

        function onMutedChanged() {
            root.showSink();
        }
    }

    Connections {
        target: root.source ? root.source.audio : null
        ignoreUnknownSignals: true

        function onVolumeChanged() {
            root.showSource();
        }

        function onMutedChanged() {
            root.showSource();
        }
    }

    // ---------- Caps Lock, Num Lock e brilho ----------

    Process {
        running: true

        command: [
            "sh",
            "-c",
            `
last=""

while true; do
    caps=0
    num=0
    brightness=-1

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

    for f in /sys/class/backlight/*/brightness; do
        [ -r "$f" ] || continue

        dir="\${f%/brightness}"

        read -r current < "$f"
        read -r maximum < "$dir/max_brightness"

        if [ "$maximum" -gt 0 ] 2>/dev/null; then
            brightness=$((current * 100 / maximum))
            break
        fi
    done

    cur="$caps $num $brightness"

    if [ "$cur" != "$last" ]; then
        echo "$cur"
        last="$cur"
    fi

    sleep 0.15
done
`
        ]

        stdout: SplitParser {
            onRead: data => root.parseSystemState(data)
        }
    }

    // ---------- janela ----------

    PanelWindow {
        id: win

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

                    color: root.lit
                        ? root.iconColor
                        : root.mutedColor

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

                            color: root.lit
                                ? root.iconColor
                                : root.mutedColor

                            font.family: "Rubik"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }

                    // Barra de volume, microfone e brilho.
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6

                        visible: root.hasBar

                        radius: 3

                        color: root.selectorColor

                        border.width: 1
                        border.color: root.borderColor

                        Rectangle {
                            width: parent.width *
                                Math.max(0, Math.min(1, root.level))

                            height: parent.height

                            radius: parent.radius

                            color: root.lit
                                ? root.iconColor
                                : root.mutedColor

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

            // Sobe ao aparecer e desce ao desaparecer.
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

        // O OSD nunca captura cliques.
        mask: Region {}
    }
}
