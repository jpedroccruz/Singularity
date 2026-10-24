import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme as ThemeModule

Item {
    id: root

    property color iconColor: ThemeModule.Theme.accent
    property color mutedColor: ThemeModule.Theme.muted
    property string iconFont: "Material Symbols Rounded"
    property int iconSize: 18
    // Para testes: true deixa o módulo sempre visível.
    property bool alwaysShow: false
    // true quando o mouse está sobre a barra (o Bar liga isso ao barHover).
    property bool barHovered: false
    // true = bloqueando o hypridle
    property bool inhibit: false
    readonly property bool active: inhibit
    readonly property bool shown: alwaysShow || barHovered || active

    function toggle() {
        root.inhibit = !root.inhibit;
    }

    visible: shown
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    // O inibidor precisa de uma janela visível: usa a própria barra.
    IdleInhibitor {
        enabled: root.inhibit
        window: root.QsWindow.window
    }

    Text {
        id: icon

        anchors.centerIn: parent
        text: "coffee"
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
