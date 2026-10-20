// Indicador de atualizações pendentes.
// Só aparece quando há atualizações; some sozinho quando não há (visible: false
// faz o layout da barra ignorar o item).
// requer: pacman-contrib (checkupdates). AUR opcional via yay/yay.
// clique esquerdo: abre um terminal rodando a atualização
// clique direito: checa de novo agora

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme as ThemeModule

Item {
    id: root

    property color iconColor: ThemeModule.Theme.accent
    property color mutedColor: ThemeModule.Theme.muted
    property string iconFont: "Material Symbols Rounded"
    property int iconSize: 18
    property string aurHelper: "yay" // "paru", "yay" ou "" para ignorar o AUR
    property string terminal: "kitty" // terminal usado ao clicar
    property var terminalArgs: ["--class", "updates"] // classe da janela (para o window_rule)
    property string updateCommand: "yay -Syu"
    property int interval: 30 * 60 * 1000 // checa a cada 30 min
    property var packages: [] // linhas "pkg antiga -> nova"
    readonly property int count: packages.length

    function check() {
        checkProc.running = true;
    }

    function upgrade() {
        if (!upgradeProc.running)
            upgradeProc.running = true;

    }

    visible: count > 0
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Process {
        id: checkProc

        // checkupdates usa um banco temporário (não precisa de root);
        // o AUR só é consultado se o helper existir
        command: ["sh", "-c", "checkupdates 2>/dev/null; " + "if [ -n \"$1\" ] && command -v \"$1\" >/dev/null 2>&1; then \"$1\" -Qua 2>/dev/null; fi; " + "true", "sh", root.aurHelper]

        stdout: StdioCollector {
            onStreamFinished: root.packages = text.split("\n").filter((l) => {
                return l.trim() !== "";
            })
        }

    }

    // roda o upgrade num terminal e rechecka quando ele fecha
    Process {
        id: upgradeProc

        command: [root.terminal].concat(root.terminalArgs, ["-e", "bash", "-c", root.updateCommand + "; echo; read -n 1 -s -r -p 'Done. Press any key to close…'"])
        onExited: root.check()
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: root.interval
        onTriggered: root.check()
    }

    // na hora do login a rede pode ainda não estar pronta: tenta de novo logo depois
    Timer {
        running: true
        interval: 20000
        onTriggered: root.check()
    }

    Text {
        id: icon

        anchors.centerIn: parent
        text: "sync"
        color: area.containsMouse ? root.mutedColor : root.iconColor
        font.family: root.iconFont
        font.pixelSize: root.iconSize
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                root.check();
            else
                root.upgrade();
        }
    }

}
