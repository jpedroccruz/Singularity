// Banners de notificação no topo, centralizados (estilo Ubuntu/GNOME).
// Não é um servidor: quem recebe as notificações é o NotificationServer do
// Clock, que chama push(n) a cada notificação nova.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs.theme as ThemeModule

Scope {
    // ---------- tema (mesmas cores do módulo de rede) ----------
    // ---------- configuração ----------
    // ---------- estado ----------
    // ---------- janela ----------

    id: root

    property color iconColor: ThemeModule.Theme.accent
    property color mutedColor: ThemeModule.Theme.muted
    property color panelColor: ThemeModule.Theme.darkBackground
    property color selectorColor: ThemeModule.Theme.selector
    property color menuColor: ThemeModule.Theme.menu
    property color borderColor: ThemeModule.Theme.border
    property int topMargin: 50 // distância do topo da tela (altura da barra + folga)
    property int cardWidth: 400
    property int maxVisible: 3 // banners ao mesmo tempo
    property real defaultTimeout: 6 // segundos (críticas ficam até serem fechadas)
    property var items: [] // notificações exibidas, a mais nova primeiro

    function push(n) {
        if (items.indexOf(n) !== -1)
            return ;

        items = [n].concat(items).slice(0, maxVisible);
    }

    function remove(n) {
        items = items.filter((x) => {
            return x !== n;
        });
    }

    function iconSource(n) {
        if (n.image && n.image !== "")
            return n.image;

        const ic = n.appIcon || "";
        if (ic === "")
            return "";

        if (ic.charAt(0) === "/")
            return "file://" + ic;

        return Quickshell.iconPath(ic, true);
    }

    ScriptModel {
        id: bannerModel

        values: root.items
    }

    PanelWindow {
        id: win

        visible: root.items.length > 0
        anchors.top: true
        margins.top: root.topMargin
        implicitWidth: root.cardWidth
        implicitHeight: list.implicitHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notifications"

        Column {
            id: list

            width: parent.width
            spacing: 8

            Repeater {
                model: bannerModel

                delegate: Item {
                    id: wrap

                    required property var modelData
                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                    readonly property var extraActions: modelData.actions.filter((a) => {
                        return a.identifier !== "default" && a.text !== "";
                    })
                    property bool shown: false
                    property bool leaving: false

                    function hide() {
                        if (leaving)
                            return ;

                        leaving = true;
                        leaveTimer.start();
                    }

                    width: list.width
                    height: card.height
                    Component.onCompleted: shown = true

                    Timer {
                        id: leaveTimer

                        interval: 230
                        onTriggered: root.remove(wrap.modelData)
                    }

                    // some sozinho depois do tempo (pausa com o mouse em cima)
                    Timer {
                        interval: {
                            const t = wrap.modelData.expireTimeout;
                            return (t > 0 ? Math.min(t, 30) : root.defaultTimeout) * 1000;
                        }
                        running: wrap.shown && !wrap.leaving && !wrap.critical && !hover.hovered
                        onTriggered: wrap.hide()
                    }

                    // a notificação foi fechada por fora (app ou botão Clear do relógio)
                    Connections {
                        function onClosed() {
                            root.remove(wrap.modelData);
                        }

                        target: wrap.modelData
                    }

                    Rectangle {
                        id: card

                        width: parent.width
                        height: row.implicitHeight + 28
                        radius: 10
                        color: root.panelColor
                        border.width: 2
                        border.color: root.iconColor
                        opacity: (wrap.shown && !wrap.leaving) ? 1 : 0

                        HoverHandler {
                            id: hover
                        }

                        // clicar executa a ação padrão (abre o app); sem ela, só some o banner
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const acts = wrap.modelData.actions;
                                for (let i = 0; i < acts.length; i++) {
                                    if (acts[i].identifier === "default") {
                                        acts[i].invoke();
                                        wrap.modelData.dismiss();
                                        return ;
                                    }
                                }
                                wrap.hide();
                            }
                        }

                        RowLayout {
                            id: row

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 12

                            // ícone
                            Rectangle {
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                radius: 6
                                color: root.menuColor
                                border.width: 1
                                border.color: root.borderColor

                                Text {
                                    anchors.centerIn: parent
                                    visible: iconImage.status !== Image.Ready
                                    text: "notifications"
                                    color: root.mutedColor
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 22
                                }

                                Image {
                                    id: iconImage

                                    anchors.centerIn: parent
                                    width: 30
                                    height: 30
                                    source: root.iconSource(wrap.modelData)
                                    sourceSize.width: 64
                                    sourceSize.height: 64
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                }

                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        Layout.fillWidth: true
                                        text: wrap.modelData.appName.toUpperCase()
                                        color: root.mutedColor
                                        font.family: "Rubik"
                                        font.pixelSize: 10
                                        font.letterSpacing: 1.5
                                        elide: Text.ElideRight
                                    }

                                    // fecha só o banner (a notificação continua na lista do relógio)
                                    Text {
                                        text: "close"
                                        color: closeMouse.containsMouse ? root.iconColor : root.mutedColor
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 16

                                        MouseArea {
                                            id: closeMouse

                                            anchors.fill: parent
                                            anchors.margins: -4
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: wrap.hide()
                                        }

                                    }

                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: wrap.modelData.summary
                                    color: root.iconColor
                                    font.family: "Rubik"
                                    font.pixelSize: 14
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: text !== ""
                                    Layout.fillWidth: true
                                    text: wrap.modelData.body
                                    color: Qt.alpha(root.iconColor, 0.75)
                                    font.family: "Rubik"
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }

                                // ações extras
                                Flow {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 6
                                    visible: wrap.extraActions.length > 0
                                    spacing: 6

                                    Repeater {
                                        model: wrap.extraActions

                                        delegate: Rectangle {
                                            required property var modelData

                                            implicitWidth: actLabel.implicitWidth + 20
                                            implicitHeight: 28
                                            radius: 4
                                            color: actMouse.containsMouse ? root.borderColor : root.selectorColor
                                            border.width: 1
                                            border.color: actMouse.containsMouse ? root.iconColor : root.borderColor

                                            Text {
                                                id: actLabel

                                                anchors.centerIn: parent
                                                text: parent.modelData.text
                                                color: root.iconColor
                                                font.family: "Rubik"
                                                font.pixelSize: 12
                                            }

                                            MouseArea {
                                                id: actMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    parent.modelData.invoke();
                                                    wrap.hide();
                                                }
                                            }

                                        }

                                    }

                                }

                            }

                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }

                        }

                        transform: Translate {
                            y: (wrap.shown && !wrap.leaving) ? 0 : -28

                            Behavior on y {
                                NumberAnimation {
                                    duration: 220
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                    }

                    // os banners de baixo deslizam quando um de cima some
                    Behavior on y {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

        }

    }

}
