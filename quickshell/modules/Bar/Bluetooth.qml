import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Wayland
import qs.theme as ThemeModule

Rectangle {
    id: root

    property color iconColor: ThemeModule.Theme.accent
    property color mutedColor: ThemeModule.Theme.muted
    property color panelColor: ThemeModule.Theme.darkBackground
    property color selectorColor: ThemeModule.Theme.selector
    property color menuColor: ThemeModule.Theme.menu
    property color borderColor: ThemeModule.Theme.border
    // Raio dos cantos do popup: os de baixo são arredondados e os de cima se
    // curvam para dentro da barra, como se o popup fosse parte dela.
    property int edge: 20
    readonly property var adapter: Bluetooth.defaultAdapter
    // O módulo só existe em máquinas com adaptador Bluetooth (placa/dongle)
    readonly property bool hasAdapter: Bluetooth.adapters.values.length > 0
    readonly property bool powered: !!adapter && adapter.enabled
    readonly property bool scanning: powered && adapter.discovering
    readonly property var devices: adapter ? adapter.devices.values : []
    // dispositivo que está sendo pareado (conecta sozinho quando terminar)
    property var pendingDevice: null
    readonly property var pairedList: sortDevices(devices.filter((d) => {
        return d.paired || d.bonded;
    }))
    readonly property var availableList: sortDevices(devices.filter((d) => {
        return !(d.paired || d.bonded) && hasName(d);
    }))
    readonly property var connectedList: pairedList.filter((d) => {
        return d.connected;
    })
    readonly property string title: {
        if (connectedList.length === 0)
            return "Bluetooth";

        const first = connectedList[0].name || connectedList[0].deviceName || "Bluetooth";
        return connectedList.length > 1 ? first + " +" + (connectedList.length - 1) : first;
    }

    function hasName(d) {
        const n = d.name || d.deviceName || "";
        // aparelhos sem nome aparecem só com o endereço MAC: ignora
        return n !== "" && !/^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/.test(n);
    }

    function sortDevices(list) {
        return list.slice().sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;

            return (a.name || "").localeCompare(b.name || "");
        });
    }

    function barSymbol() {
        if (!powered)
            return "bluetooth_disabled";

        return connectedList.length > 0 ? "bluetooth_connected" : "bluetooth";
    }

    function deviceSymbol(d) {
        const i = (d.icon || "").toLowerCase();
        if (i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0)
            return "headphones";

        if (i.indexOf("speaker") >= 0 || i.indexOf("audio") >= 0)
            return "speaker";

        if (i.indexOf("keyboard") >= 0)
            return "keyboard";

        if (i.indexOf("mouse") >= 0)
            return "mouse";

        if (i.indexOf("gaming") >= 0)
            return "sports_esports";

        if (i.indexOf("phone") >= 0)
            return "smartphone";

        if (i.indexOf("computer") >= 0)
            return "computer";

        return "bluetooth";
    }

    function statusText(d) {
        if (root.pendingDevice === d)
            return "Pareando...";

        if (d.state === BluetoothDeviceState.Connecting)
            return "Conectando...";

        if (d.state === BluetoothDeviceState.Disconnecting)
            return "Desconectando...";

        return d.connected ? "Conectado" : "";
    }

    function togglePower() {
        if (root.adapter)
            root.adapter.enabled = !root.adapter.enabled;

    }

    function activate(d) {
        if (d.paired || d.bonded) {
            if (d.connected)
                d.disconnect();
            else
                d.connect();
            return ;
        }
        // não pareado: pareia e, quando terminar, confia e conecta
        root.pendingDevice = d;
        pendingTimer.restart();
        d.pair();
    }

    implicitWidth: indicator.implicitWidth + 18
    implicitHeight: 30
    color: "transparent"
    visible: hasAdapter
    onHasAdapterChanged: {
        if (!hasAdapter)
            popup.open = false;

    }

    // procura aparelhos só enquanto o popup está aberto
    Binding {
        target: root.adapter
        property: "discovering"
        value: popup.open && root.powered
        when: root.adapter !== null
        restoreMode: Binding.RestoreNone
    }

    // termina o pareamento: confia no aparelho e conecta
    Connections {
        function onPairedChanged() {
            const d = root.pendingDevice;
            if (d && d.paired) {
                d.trusted = true;
                d.connect();
                root.pendingDevice = null;
                pendingTimer.stop();
            }
        }

        target: root.pendingDevice
        ignoreUnknownSignals: true
    }

    Timer {
        id: pendingTimer

        interval: 30000
        onTriggered: root.pendingDevice = null
    }

    Timer {
        id: closeTimer

        interval: 180
        onTriggered: {
            if (!mouseArea.containsMouse && !panelHover.hovered)
                popup.open = false;

        }
    }

    Text {
        id: indicator

        anchors.centerIn: parent
        text: root.barSymbol()
        color: root.powered ? root.iconColor : root.mutedColor
        font.family: "Material Symbols Rounded"
        font.pixelSize: 18
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: indicator.implicitWidth
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

    Component {
        id: deviceDelegate

        Rectangle {
            id: row

            Layout.fillWidth: true
            implicitHeight: 40
            radius: 7
            color: modelData.connected ? root.selectorColor : (rowHover.hovered ? root.menuColor : "transparent")

            HoverHandler {
                id: rowHover
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activate(modelData)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 12
                spacing: 10

                Text {
                    text: root.deviceSymbol(modelData)
                    color: root.iconColor
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 20
                }

                Text {
                    Layout.fillWidth: true
                    text: modelData.name || modelData.deviceName
                    color: root.iconColor
                    font.family: "Rubik"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                Text {
                    visible: text !== ""
                    text: root.statusText(modelData)
                    color: root.mutedColor
                    font.family: "Rubik"
                    font.pixelSize: 12
                }

                // esquecer dispositivo pareado (aparece ao passar o mouse)
                Text {
                    visible: rowHover.hovered && (modelData.paired || modelData.bonded)
                    text: "close"
                    color: forgetMouse.containsMouse ? root.iconColor : root.mutedColor
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18

                    MouseArea {
                        id: forgetMouse

                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.forget()
                    }

                }

            }

        }

    }

    PanelWindow {
        id: popup

        // `open` é o estado lógico (aberto/fechado); `reveal` vai de 0 a 1 durante a
        // animação. A janela continua visível até a saída terminar.
        property bool open: false
        property real reveal: 0
        // o popup "brota" da barra: a largura abre primeiro, depois a altura
        readonly property real wf: Math.min(1, reveal / 0.55)
        readonly property real hf: Math.max(0, Math.min(1, (reveal - 0.1) / 0.9))

        onOpenChanged: {
            revealAnim.stop();
            revealAnim.to = open ? 1 : 0;
            // entra desacelerando; sai acelerando de volta para dentro da barra
            revealAnim.duration = open ? 360 : 240;
            revealAnim.easing.type = open ? Easing.OutQuint : Easing.InCubic;
            revealAnim.start();
        }
        // janela layer-shell colada na direita da tela, logo abaixo da barra
        screen: root.QsWindow.window.screen
        margins.top: root.QsWindow.window.height
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "bar-popup"
        implicitWidth: 340 + root.edge
        implicitHeight: panel.implicitHeight + 4
        visible: open || reveal > 0.001
        color: "transparent"

        NumberAnimation {
            id: revealAnim

            target: popup
            property: "reveal"
        }

        anchors {
            top: true
            right: true
        }

        // Tudo cresce a partir do canto da barra: a largura abre primeiro, depois
        // a altura, e a curva do canto côncavo cresce junto, sempre colada na barra.
        Item {
            id: popupGrow

            anchors.top: parent.top
            anchors.right: parent.right
            width: root.edge + (popup.implicitWidth - root.edge) * popup.wf
            height: popup.implicitHeight * popup.hf
            opacity: Math.min(1, popup.reveal * 3)

            // curva que liga o popup à barra (cresce a partir do canto de cima)
            Shape {
                anchors.left: parent.left
                anchors.top: parent.top
                width: root.edge
                height: root.edge
                preferredRendererType: Shape.CurveRenderer
                transformOrigin: Item.TopRight
                scale: Math.min(1, popup.reveal / 0.5)

                ShapePath {
                    strokeWidth: 0
                    fillColor: root.panelColor
                    startX: root.edge
                    startY: 0

                    PathLine {
                        x: root.edge
                        y: root.edge
                    }

                    PathArc {
                        x: 0
                        y: 0
                        radiusX: root.edge
                        radiusY: root.edge
                        direction: PathArc.Counterclockwise
                    }

                    PathLine {
                        x: root.edge
                        y: 0
                    }

                }

            }

            // fundo do painel (acompanha o tamanho que está crescendo)
            Rectangle {
                id: popupBg

                anchors.fill: parent
                anchors.leftMargin: root.edge
                color: root.panelColor
                bottomLeftRadius: root.edge
            }

            // conteúdo com o tamanho final, revelado pelo recorte
            Item {
                anchors.fill: popupBg
                clip: true

                Rectangle {
                    id: panel

                    anchors.top: parent.top
                    anchors.right: parent.right
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
                        // CABEÇALHO
                        // PAREADOS
                        // DISPONÍVEIS

                        id: content

                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 16

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: root.barSymbol()
                                color: root.powered ? root.iconColor : root.mutedColor
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 26
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: root.title
                                    color: root.iconColor
                                    font.family: "Rubik"
                                    font.pixelSize: 14
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                // nome do adaptador em uso
                                Text {
                                    Layout.fillWidth: true
                                    text: root.adapter ? (root.adapter.adapterId || root.adapter.name || "--") : "--"
                                    color: root.mutedColor
                                    font.family: "Rubik"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }

                            }

                            // liga/desliga Bluetooth
                            Rectangle {
                                implicitWidth: 46
                                implicitHeight: 24
                                radius: 7
                                color: root.selectorColor
                                border.width: 1
                                border.color: root.borderColor

                                Rectangle {
                                    width: 20
                                    height: 16
                                    radius: 5
                                    y: 3
                                    x: root.powered ? parent.width - width - 4 : 4
                                    color: root.powered ? root.iconColor : root.mutedColor

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: 120
                                        }

                                    }

                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.togglePower()
                                }

                            }

                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: root.borderColor
                        }

                        Text {
                            visible: !root.powered
                            Layout.fillWidth: true
                            text: "Bluetooth Off"
                            color: root.mutedColor
                            font.family: "Rubik"
                            font.pixelSize: 13
                        }

                        Flickable {
                            id: devFlick

                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(devColumn.implicitHeight, 300)
                            visible: root.powered
                            contentWidth: width
                            contentHeight: devColumn.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: devColumn

                                width: devFlick.width
                                spacing: 6

                                Text {
                                    visible: root.pairedList.length > 0
                                    text: "PAIRED DEVICES"
                                    color: root.iconColor
                                    font.family: "Rubik"
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                Repeater {
                                    model: root.pairedList
                                    delegate: deviceDelegate
                                }

                                Text {
                                    Layout.topMargin: root.pairedList.length > 0 ? 8 : 0
                                    text: "AVAILABLE DEVICES"
                                    color: root.iconColor
                                    font.family: "Rubik"
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                Repeater {
                                    model: root.availableList
                                    delegate: deviceDelegate
                                }

                                Text {
                                    visible: root.availableList.length === 0
                                    text: root.scanning ? "Searching..." : "No devices found"
                                    color: root.mutedColor
                                    font.family: "Rubik"
                                    font.pixelSize: 13
                                }

                            }

                            ScrollIndicator.vertical: ScrollIndicator {
                            }

                        }

                    }

                }

            }

        }

    }

}
