import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme as ThemeModule

Item {
    // ---------- armazenamento ----------
    // ---------- hyprsunset ----------
    // ---------- indicador da barra ----------

    id: root

    property color iconColor: ThemeModule.Theme.accent
    property color mutedColor: ThemeModule.Theme.muted
    property string iconFont: "Material Symbols Rounded"
    property int iconSize: 18
    // Temperatura de cor em Kelvin (menor = mais amarelado). Padrão do hyprsunset: 6000.
    property int temperature: 4000
    // Para testes: true deixa o módulo sempre visível.
    property bool alwaysShow: false
    // true quando o mouse está sobre a barra (o Bar liga isso ao barHover).
    property bool barHovered: false
    // true = night light ligado
    property bool nightOn: false
    readonly property bool active: nightOn
    readonly property bool shown: alwaysShow || barHovered || active
    readonly property string storageDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell"
    readonly property string storagePath: storageDir + "/night-light"

    function toggle() {
        root.nightOn = !root.nightOn;
        file.setText(root.nightOn ? "true" : "false");
    }

    visible: shown
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight
    Component.onCompleted: mkdirProcess.running = true

    Process {
        id: mkdirProcess

        command: ["mkdir", "-p", root.storageDir]
    }

    FileView {
        id: file

        path: root.storagePath
        printErrors: false
        onLoaded: root.nightOn = text().trim() === "true"
    }

    // Fica rodando enquanto o night light estiver ligado. Antes de iniciar,
    // encerra qualquer hyprsunset já aberto (para não ficar duplicado); o
    // `exec` faz o processo ser o próprio hyprsunset, então desligar o
    // módulo o encerra de verdade.
    Process {
        id: sunsetProc

        running: root.nightOn
        command: ["sh", "-c", "pkill -x hyprsunset 2>/dev/null; exec hyprsunset -t \"$1\"", "sh", root.temperature.toString()]
        // se o hyprsunset fechar sozinho (ou não existir), volta para "desligado"
        onExited: {
            if (root.nightOn) {
                root.nightOn = false;
                file.setText("false");
            }
        }
    }

    Text {
        id: icon

        anchors.centerIn: parent
        text: "nightlight"
        // ativo: cor de destaque; inativo: cinza
        color: root.active ? root.iconColor : root.mutedColor
        font.family: root.iconFont
        font.pixelSize: root.iconSize
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggle()
    }

}
