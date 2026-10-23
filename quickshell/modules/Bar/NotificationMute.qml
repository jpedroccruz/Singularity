// Módulo NotificationMute
// Um clique liga/desliga o "não perturbe": as notificações novas deixam de
// aparecer como banner e de tocar som. Elas continuam na lista do relógio.
// Este módulo só guarda o estado em `muted`. Quem aplica o bloqueio é o
// Clock, que recebe as notificações (veja no Bar: `Clock { muted: ... }`).
// Na barra é só um ícone, como o Updates:
// - invisível por padrão
// - aparece em cinza quando o mouse passa por cima da barra
// - fica sempre visível, na cor de destaque, enquanto estiver ativado

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme as ThemeModule

Item {
    // ---------- armazenamento (lembra o estado depois de reiniciar) ----------
    // ---------- hover na barra inteira ----------
    // ---------- indicador da barra ----------

    id: root

    property color iconColor: ThemeModule.Theme.accent
    property color mutedColor: ThemeModule.Theme.muted
    property string iconFont: "Material Symbols Rounded"
    property int iconSize: 18
    // Para testes: true deixa o módulo sempre visível.
    property bool alwaysShow: false
    // true quando o mouse está sobre a barra. Por padrão o módulo detecta
    // sozinho; o Bar pode sobrescrever: `NotificationMute { barHovered: barHover.hovered }`.
    property bool barHovered: false
    // true = notificações silenciadas (sem banner e sem som)
    property bool muted: false
    readonly property bool active: muted
    readonly property bool shown: alwaysShow || barHovered || active
    readonly property string storageDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell"
    readonly property string storagePath: storageDir + "/notification-mute"

    function toggle() {
        root.muted = !root.muted;
        file.setText(root.muted ? "true" : "false");
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
        onLoaded: root.muted = text().trim() === "true"
    }

    Text {
        id: icon

        anchors.centerIn: parent
        text: root.muted ? "notifications_off" : "notifications"
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
