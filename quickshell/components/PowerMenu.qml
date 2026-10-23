import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.theme as ThemeModule

Scope {
    id: root

    // ───────── As ÚNICAS duas cores do tema ─────────
    property color accent: ThemeModule.Theme.accent
    property color background: ThemeModule.Theme.background

    // ───────── Configuração ─────────
    property string iconFont: "Material Symbols Rounded"
    property int cardW: 180
    property int cardH: 260
    property int growW: 40
    property int growH: 60      
    property int gap: 16

    property bool shown: false

    // Troque os comandos conforme seu setup (hyprlock, uwsm stop, etc.)
    readonly property var actions: [
        { name: "Shutdown",  icon: "power_settings_new", key: Qt.Key_1, cmd: ["systemctl", "poweroff"] },
        { name: "Lock",      icon: "lock",              key: Qt.Key_2, cmd: ["loginctl", "lock-session"] },
        { name: "Reboot",    icon: "restart_alt",       key: Qt.Key_3, cmd: ["systemctl", "reboot"] },
        { name: "Suspend",   icon: "pause_circle",      key: Qt.Key_4, cmd: ["systemctl", "suspend"] },
        { name: "Logout",    icon: "logout",            key: Qt.Key_5, cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
        { name: "Hibernate", icon: "bedtime",           key: Qt.Key_6, cmd: ["systemctl", "hibernate"] },
    ]

    IpcHandler {
        target: "powermenu"

        function toggle(): void { root.shown = !root.shown }
        function open(): void   { root.shown = true }
        function close(): void  { root.shown = false }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            visible: root.shown
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "powermenu"

            property int current: -1

            onVisibleChanged: {
                if (visible) {
                    current = -1
                    keys.forceActiveFocus()
                }
            }

            function run(i) {
                root.shown = false
                Quickshell.execDetached(root.actions[i].cmd)
            }

            // Fundo escurecido (clicar fora fecha)
            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.5
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.shown = false
            }

            // Teclado
            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onPressed: (e) => {
                    const n = root.actions.length
                    if (e.key === Qt.Key_Escape) {
                        root.shown = false
                    } else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) {
                        win.current = (win.current + 1) % n
                    } else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) {
                        win.current = (win.current - 1 + n) % n
                    } else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                               && win.current >= 0) {
                        win.run(win.current)
                    } else {
                        for (let i = 0; i < n; i++)
                            if (root.actions[i].key === e.key) win.run(i)
                    }
                }
            }

            // Cartões lado a lado
            Row {
                anchors.centerIn: parent
                spacing: root.gap

                Repeater {
                    model: root.actions

                    Item {
                        id: slot
                        required property var modelData
                        required property int index

                        readonly property bool active: win.current === index

                        width: card.width
                        height: root.cardH + root.growH

                        Rectangle {
                            id: card
                            anchors.centerIn: parent

                            width: root.cardW + (slot.active ? root.growW : 0)
                            height: root.cardH + (slot.active ? root.growH : 0)
                            radius: 32
                            color: slot.active ? root.accent : root.background
                            border.width: 2
                            border.color: "transparent"

                            Behavior on width  { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color  { ColorAnimation  { duration: 180 } }

                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -16
                                text: slot.modelData.icon
                                color: slot.active ? root.background : root.accent
                                font.family: root.iconFont
                                font.pixelSize: slot.active ? 72 : 56
                                Behavior on font.pixelSize { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 28
                                text: slot.modelData.name
                                color: slot.active ? root.background : root.accent
                                font.pixelSize: 18
                                font.family: "Rubik"
                                font.bold: true
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                        }

                        MouseArea {
                            anchors.fill: card
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: win.current = slot.index
                            onClicked: win.run(slot.index)
                        }
                    }
                }
            }
        }
    }
}
