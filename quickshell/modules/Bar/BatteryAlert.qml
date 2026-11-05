// Alerta de bateria baixa: bateria deitada + ícone "dangerous" piscando + notificação.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.theme as ThemeModule

Item {
    id: root

    property color iconColor: ThemeModule.Theme.accent
    property string iconFont: "Material Symbols Rounded"
    property int iconSize: 18
    property int threshold: 20          // alerta a partir daqui (%)
    property int criticalThreshold: 10  // segunda notificação (%)
    property int blinkInterval: 600

    readonly property var device: UPower.displayDevice
    readonly property bool hasBattery: UPower.devices.values.some((d) => d.isLaptopBattery)
    readonly property real pct: Math.max(0, Math.min(100, (device ? device.percentage : 0) * 100))
    readonly property bool discharging: device && device.state === UPowerDeviceState.Discharging
    readonly property bool low: hasBattery && discharging && pct <= threshold

    // 0 = ok, 1 = baixa, 2 = crítica
    readonly property int level: !low ? 0 : (pct <= criticalThreshold ? 2 : 1)
    property int notifiedLevel: 0

    function notify() {
        let cmd = [
            "notify-send",
            "--wait",                      // fica aguardando e imprime a ação clicada
            "-a", "Battery",
            "-u", level === 2 ? "critical" : "normal",
            "-i", "battery-caution"
        ];

        // só oferece o botão se o power-saver ainda não estiver ativo
        if (PowerProfiles.profile !== PowerProfile.PowerSaver)
            cmd.push("-A", "powersave=Ativar economia de energia");

        cmd.push(
            level === 2 ? "Bateria crítica" : "Bateria baixa",
            "Restam " + Math.round(pct) + "%. Conecte o carregador."
        );

        // um processo por notificação, para não bloquear a próxima
        notifyComp.createObject(root, { command: cmd, running: true });
    }

    onLevelChanged: {
        // só notifica ao piorar; ao carregar (level 0) o ciclo reinicia
        if (level > notifiedLevel)
            notify();

        notifiedLevel = level;
    }

    visible: low
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Component {
        id: notifyComp

        Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.trim() === "powersave")
                        PowerProfiles.profile = PowerProfile.PowerSaver;
                }
            }

            onExited: destroy(1000)
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 2
        opacity: 1

        // bateria deitada (mesmo truque do Battery.qml)
        Item {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: batt.implicitHeight
            implicitHeight: batt.implicitWidth
            width: implicitWidth
            height: implicitHeight

            Text {
                id: batt

                anchors.centerIn: parent
                rotation: 90
                text: "battery_1_bar"
                color: root.iconColor
                font.family: root.iconFont
                font.pixelSize: root.iconSize
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "warning"
            color: root.iconColor
            font.family: root.iconFont
            font.pixelSize: root.iconSize
        }

        SequentialAnimation on opacity {
            running: root.low
            loops: Animation.Infinite

            NumberAnimation {
                to: 0.15
                duration: root.blinkInterval
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                to: 1
                duration: root.blinkInterval
                easing.type: Easing.InOutSine
            }
        }
    }
}
