import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import qs.theme as ThemeModule

Rectangle {
    id: root

    property color iconColor: ThemeModule.Theme.accent
    property color mutedColor: ThemeModule.Theme.muted
    property color panelColor: ThemeModule.Theme.darkBackground
    // Raio dos cantos do popup: os de baixo são arredondados e os de cima se
    // curvam para dentro da barra, como se o popup fosse parte dela.
    property int edge: 20
    property var parentWindow
    property var contextItem

    function activateItem(item) {
        if (item.id === "spotify-client") {
            spotifyProcess.running = false;
            spotifyProcess.command = ["spotify"];
            spotifyProcess.running = true;
        } else {
            item.activate();
        }
    }

    color: "transparent"
    implicitWidth: indicator.implicitWidth + 18
    implicitHeight: 30

    Process {
        id: spotifyProcess
    }

    QsMenuOpener {
        id: menuOpener

        menu: root.contextItem ? root.contextItem.menu : null
    }

    Text {
        id: indicator

        anchors.centerIn: parent
        text: "keyboard_arrow_down"
        color: root.iconColor
        font.family: "Material Symbols Rounded"
        font.pixelSize: 24
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

        cursorShape: Qt.PointingHandCursor
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: function(event) {
            if (event.button === Qt.LeftButton) {
                popup.showingMenu = false;
                trayHover.wasHovered = false;
                trayCloseTimer.stop();
                popup.open = !popup.open;
            }
        }
    }

    PanelWindow {
        id: popup

        // `open` é o estado lógico (aberto/fechado); `reveal` vai de 0 a 1 durante a
        // animação. A janela continua visível até a saída terminar.
        property bool open: false
        property real reveal: 0
        // true: pula a animação (usado para reabrir a janela no mesmo lugar)
        property bool instant: false
        // o popup "brota" da barra: a largura abre primeiro, depois a altura
        readonly property real wf: Math.min(1, reveal / 0.55)
        readonly property real hf: Math.max(0, Math.min(1, (reveal - 0.1) / 0.9))

        onOpenChanged: {
            revealAnim.stop();
            if (instant) {
                reveal = open ? 1 : 0;
                return ;
            }
            revealAnim.to = open ? 1 : 0;
            // entra desacelerando; sai acelerando de volta para dentro da barra
            revealAnim.duration = open ? 360 : 240;
            revealAnim.easing.type = open ? Easing.OutQuint : Easing.InCubic;
            revealAnim.start();
        }

        NumberAnimation {
            id: revealAnim

            target: popup
            property: "reveal"
        }

        property bool showingMenu: false

        // janela layer-shell colada na direita da tela, logo abaixo da barra
        screen: root.QsWindow.window.screen
        margins.top: root.QsWindow.window.height
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "bar-popup"
        implicitWidth: root.edge + (showingMenu ? Math.max(220, menuColumn.implicitWidth + 20) : Math.max(180, trayLayout.implicitWidth + 20))
        implicitHeight: showingMenu ? Math.max(48, trayLayout.implicitHeight + menuColumn.implicitHeight + 30) : Math.max(48, trayLayout.implicitHeight + 20)
        visible: open || reveal > 0.001
        color: "transparent"
        onVisibleChanged: {
            if (!visible)
                showingMenu = false;

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

                    HoverHandler {
                        id: trayHover

                        property bool wasHovered: false

                        onHoveredChanged: {
                            if (hovered) {
                                wasHovered = true;
                                trayCloseTimer.stop();
                            } else if (wasHovered) {
                                trayCloseTimer.restart();
                            }
                        }
                    }

                    Timer {
                        id: trayCloseTimer

                        interval: 250
                        onTriggered: {
                            if (!trayHover.hovered)
                                popup.open = false;

                        }
                    }

                    RowLayout {
                        id: trayLayout

                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 10
                        spacing: 12

                        Repeater {
                            model: SystemTray.items

                            delegate: MouseArea {
                                required property var modelData

                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onPressed: function(event) {
                                    if (event.button === Qt.LeftButton) {
                                        event.accepted = true;
                                        root.activateItem(modelData);
                                        popup.open = false;
                                        return ;
                                    }
                                    if (event.button === Qt.RightButton) {
                                        event.accepted = true;
                                        root.contextItem = modelData;
                                        trayCloseTimer.stop();
                                        trayHover.wasHovered = false;
                                        popup.showingMenu = modelData.hasMenu;
                                    }
                                }

                                Image {
                                    anchors.centerIn: parent
                                    source: parent.modelData.icon
                                    sourceSize.width: 22
                                    sourceSize.height: 22
                                    width: 22
                                    height: 22
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }

                            }

                        }

                    }

                    ColumnLayout {
                        id: menuColumn

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: trayLayout.bottom
                        anchors.topMargin: 8
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 2
                        visible: popup.showingMenu

                        HoverHandler {
                            id: menuHover

                            property bool wasHovered: false

                            onHoveredChanged: {
                                if (hovered) {
                                    wasHovered = true;
                                    menuCloseTimer.stop();
                                } else if (wasHovered) {
                                    menuCloseTimer.restart();
                                }
                            }
                        }

                        Timer {
                            id: menuCloseTimer

                            interval: 180
                            onTriggered: {
                                if (!menuHover.hovered) {
                                    popup.open = false;
                                    menuHover.wasHovered = false;
                                }
                            }
                        }

                        Repeater {
                            model: menuOpener.children

                            delegate: Rectangle {
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: modelData.isSeparator ? 1 : 30
                                color: modelData.isSeparator ? root.iconColor : menuMouseArea.containsMouse ? ThemeModule.Theme.selector : "transparent"

                                MouseArea {
                                    id: menuMouseArea

                                    anchors.fill: parent
                                    hoverEnabled: !modelData.isSeparator
                                    enabled: !modelData.isSeparator && modelData.enabled
                                    onClicked: {
                                        modelData.triggered();
                                        popup.open = false;
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    visible: !modelData.isSeparator

                                    Image {
                                        Layout.preferredWidth: 18
                                        Layout.preferredHeight: 18
                                        source: modelData.icon
                                        sourceSize.width: 18
                                        sourceSize.height: 18
                                        visible: modelData.icon !== ""
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.text
                                        color: modelData.enabled ? root.iconColor : root.mutedColor
                                        font.family: "Rubik"
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }

                                }

                            }

                        }

                    }

                }
            }

        }

    }

}
