// Banners de notificação no topo, centralizados (estilo Ubuntu/GNOME).
// Não é um servidor: quem recebe as notificações é o NotificationServer do
// Clock, que chama push(n) a cada notificação nova.
//
// Até `maxVisible` banners ao mesmo tempo, empilhados de cima para baixo:
// o mais antigo fica em cima e cada notificação nova entra embaixo das
// outras. Quando chega uma além do limite, o mais antigo (o de cima) sai.
// Cada banner fica `displayTime` segundos na tela (pausa com o mouse em cima)
// e mostra um medidor discreto de tempo no rodapé.

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
    property real displayTime: 5 // segundos que cada banner fica na tela
    property bool criticalSticky: false // true: críticas ficam até serem fechadas
    // Altura fixa da janela (evita redimensionar a janela a cada quadro da
    // animação). Só a área dos banners recebe cliques (veja `mask`).
    property int windowHeight: (maxVisible + 1) * 180
    property var items: [] // notificações exibidas, a mais antiga primeiro (em cima)

    // A nova entra no fim da lista (embaixo). Quem passar do limite é o mais
    // antigo: cada banner percebe isso sozinho (veja `overflow` no delegate)
    // e sai com animação.
    function push(n) {
        if (items.indexOf(n) !== -1)
            return ;

        items = items.concat([n]);
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
        implicitHeight: root.windowHeight
        mask: Region {
            item: list
        }
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
                    // true quando este banner está além do limite: os mais
                    // antigos (primeiros da lista) são os que passam do limite
                    readonly property bool overflow: root.items.indexOf(modelData) < root.items.length - root.maxVisible
                    // críticas só ficam fixas se `criticalSticky` estiver ligado
                    readonly property bool sticky: critical && root.criticalSticky
                    property bool shown: false
                    property bool leaving: false
                    property real remaining: 1 // 1 = tempo cheio, 0 = acabou

                    function hide() {
                        if (leaving)
                            return ;

                        leaving = true;
                        leaveTimer.start();
                    }

                    width: list.width
                    // entra abrindo espaço e sai fechando: os outros banners
                    // deslizam suavemente para ocupar o lugar
                    height: (shown && !leaving) ? card.height : 0
                    clip: true
                    Component.onCompleted: shown = true
                    onOverflowChanged: {
                        if (overflow)
                            hide();

                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutCubic
                        }

                    }

                    // espera a animação de saída terminar antes de remover
                    Timer {
                        id: leaveTimer

                        interval: 280
                        onTriggered: root.remove(wrap.modelData)
                    }

                    // conta o tempo na tela: `remaining` vai de 1 até 0 em
                    // `displayTime` segundos e pausa com o mouse em cima
                    NumberAnimation {
                        target: wrap
                        property: "remaining"
                        from: 1
                        to: 0
                        duration: root.displayTime * 1000
                        running: wrap.shown && !wrap.leaving && !wrap.sticky
                        paused: hover.hovered
                        onStopped: {
                            if (wrap.remaining <= 0.001)
                                wrap.hide();

                        }
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

                        // medidor de tempo: linha fina no rodapé que encolhe
                        Item {
                            id: timeBar

                            visible: !wrap.sticky
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            anchors.bottomMargin: 7
                            height: 2

                            Rectangle {
                                anchors.fill: parent
                                radius: 1
                                color: root.iconColor
                                opacity: 0.15
                            }

                            Rectangle {
                                width: parent.width * wrap.remaining
                                height: parent.height
                                radius: 1
                                color: root.iconColor
                                opacity: 0.6
                            }

                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }

                        }

                        // desliza um pouco para baixo ao entrar e para cima ao sair
                        transform: Translate {
                            y: (wrap.shown && !wrap.leaving) ? 0 : -14

                            Behavior on y {
                                NumberAnimation {
                                    duration: 260
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                    }

                }

            }

        }

    }

}
