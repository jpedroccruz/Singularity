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
        notifyProc.command = [
            "notify-send",
            "-a", "Battery",
            "-u", level === 2 ? "critical" : "normal",
            "-i", "battery-caution",
            level === 2 ? "Bateria crítica" : "Bateria baixa",
            "Restam " + Math.round(pct) + "%. Conecte o carregador."
        ];
        notifyProc.running = true;
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

    Process {
        id: notifyProc
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