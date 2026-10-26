import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.theme as ThemeModule

Item {
    id: root

    property color iconColor: ThemeModule.Theme.accent
    property color mutedColor: ThemeModule.Theme.muted
    property color panelColor: ThemeModule.Theme.darkBackground
    property color selectorColor: ThemeModule.Theme.selector
    property color borderColor: ThemeModule.Theme.border
    property string iconFont: "Material Symbols Rounded"
    property int iconSize: 18
    // Raio dos cantos do popup (os de cima se curvam para dentro da barra).
    property int edge: 20
    property int popupWidth: 300
    property int focusMin: 25 // minutos de foco
    property int breakMin: 5 // minutos de descanso
    // Para testes: true deixa o módulo sempre visível.
    property bool alwaysShow: false
    // true quando o mouse está sobre a barra (o Bar liga isso ao barHover).
    property bool barHovered: false
    property string phase: "idle" // "idle", "focus" ou "break"
    property bool running: false
    property double remainingMs: 0 // tempo que falta na fase atual
    property double endAt: 0 // instante (ms) em que a fase termina
    property int cycles: 0 // pomodoros de foco concluídos
    property double closedAt: 0
    readonly property bool active: phase !== "idle"
    readonly property bool shown: alwaysShow || barHovered || active || popup.open
    readonly property string storageDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell"
    readonly property string storagePath: storageDir + "/pomodoro.json"

    function formatTime(ms) {
        const total = Math.max(0, Math.ceil(ms / 1000));
        const m = Math.floor(total / 60);
        const s = total % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function notify(title, body) {
        notifyProc.command = ["notify-send", "-a", "Pomodoro", title, body];
        notifyProc.running = true;
    }

    // Começa uma fase ("focus" ou "break") e avisa.
    function startPhase(p) {
        const minutes = p === "focus" ? root.focusMin : root.breakMin;
        root.phase = p;
        root.remainingMs = minutes * 60000;
        root.endAt = Date.now() + root.remainingMs;
        root.running = true;
        if (p === "focus")
            root.notify("Foco: " + minutes + " min", "Hora de se concentrar.");
        else
            root.notify("Descanso: " + minutes + " min", "Levante, alongue-se e descanse a vista.");
    }

    // Clique esquerdo: começa; depois pausa e retoma.
    function toggle() {
        if (root.phase === "idle") {
            root.startPhase("focus");
        } else if (root.running) {
            root.remainingMs = Math.max(0, root.endAt - Date.now());
            root.running = false;
        } else {
            root.endAt = Date.now() + root.remainingMs;
            root.running = true;
        }
    }

    function stop() {
        root.running = false;
        root.phase = "idle";
        root.remainingMs = 0;
    }

    // Chamado várias vezes por segundo enquanto roda.
    function tick() {
        if (!root.running)
            return ;

        root.remainingMs = Math.max(0, root.endAt - Date.now());
        if (root.remainingMs > 0)
            return ;

        // a fase terminou: passa para a próxima
        if (root.phase === "focus") {
            root.cycles++;
            root.startPhase("break");
        } else {
            root.startPhase("focus");
        }
    }

    function valueOf(key) {
        return key === "focus" ? root.focusMin : root.breakMin;
    }

    function change(key, delta, min, max) {
        const v = Math.max(min, Math.min(max, root.valueOf(key) + delta));
        if (key === "focus")
            root.focusMin = v;
        else
            root.breakMin = v;
        root.save();
    }

    function save() {
        file.setText(JSON.stringify({
            "focus": root.focusMin,
            "break": root.breakMin
        }));
    }

    function togglePopup() {
        if (popup.open) {
            popup.open = false;
            return ;
        }
        // o clique que acabou de fechar o popup não deve reabri-lo
        if (Date.now() - root.closedAt < 250)
            return ;

        popup.open = true;
    }

    visible: shown
    implicitWidth: bar.implicitWidth
    implicitHeight: bar.implicitHeight
    Component.onCompleted: mkdirProcess.running = true

    Process {
        id: mkdirProcess

        command: ["mkdir", "-p", root.storageDir]
    }

    FileView {
        id: file

        path: root.storagePath
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (d.focus > 0)
                    root.focusMin = d.focus;

                if (d["break"] > 0)
                    root.breakMin = d["break"];

            } catch (e) {
            }
        }
    }

    Process {
        id: notifyProc
    }

    Timer {
        interval: 250
        repeat: true
        running: root.running
        onTriggered: root.tick()
    }

    Row {
        id: bar

        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.phase === "break" ? "self_improvement" : "timer"
            // rodando: cor de destaque; parado ou pausado: cinza
            color: root.running ? root.iconColor : root.mutedColor
            font.family: root.iconFont
            font.pixelSize: root.iconSize
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.active
            text: root.formatTime(root.remainingMs)
            color: root.running ? root.iconColor : root.mutedColor
            font.family: "Rubik"
            font.pixelSize: 13
        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                root.togglePopup();
            else
                root.toggle();
        }
    }

    PopupWindow {
        id: popup

        // `open` é o estado lógico (aberto/fechado); `reveal` vai de 0 a 1 durante a
        // animação. A janela só é escondida depois que a saída termina.
        property bool open: false
        property real reveal: 0
        // o popup "brota" da barra: a largura abre primeiro, depois a altura
        readonly property real wf: Math.min(1, reveal / 0.55)
        readonly property real hf: Math.max(0, Math.min(1, (reveal - 0.1) / 0.9))

        onOpenChanged: {
            revealAnim.stop();
            if (open)
                visible = true;

            if (!open)
                root.closedAt = Date.now();
            // fechado de fora (clique fora do popup): a janela já sumiu, não anima
            if (!open && !visible) {
                reveal = 0;
                return ;
            }
            revealAnim.to = open ? 1 : 0;
            // entra desacelerando; sai acelerando de volta para dentro da barra
            revealAnim.duration = open ? 360 : 240;
            revealAnim.easing.type = open ? Easing.OutQuint : Easing.InCubic;
            revealAnim.start();
        }
        // o compositor fechou o popup (clique fora): sincroniza o estado lógico
        onVisibleChanged: {
            if (!visible && open)
                open = false;

        }

        NumberAnimation {
            id: revealAnim

            target: popup
            property: "reveal"
            onStopped: {
                if (!popup.open && popup.reveal <= 0.001)
                    popup.visible = false;

            }
        }

        // ancorado na janela da barra (não no módulo): fica no centro da tela
        anchor.window: root.QsWindow.window
        anchor.rect.x: root.QsWindow.window.width / 2 - implicitWidth / 2
        anchor.rect.y: root.QsWindow.window.height
        implicitWidth: root.popupWidth + root.edge * 2
        implicitHeight: panel.implicitHeight + 4
        visible: false
        color: "transparent"
        grabFocus: true

        // Tudo cresce a partir do canto da barra: a largura abre primeiro, depois
        // a altura, e a curva do canto côncavo cresce junto, sempre colada na barra.
        Item {
            id: popupGrow

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.edge * 2 + (popup.implicitWidth - root.edge * 2) * popup.wf
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

            Shape {
                anchors.right: parent.right
                anchors.top: parent.top
                width: root.edge
                height: root.edge
                preferredRendererType: Shape.CurveRenderer
                transformOrigin: Item.TopLeft
                scale: Math.min(1, popup.reveal / 0.5)

                ShapePath {
                    strokeWidth: 0
                    fillColor: root.panelColor
                    startX: 0
                    startY: 0

                    PathLine {
                        x: 0
                        y: root.edge
                    }

                    PathArc {
                        x: root.edge
                        y: 0
                        radiusX: root.edge
                        radiusY: root.edge
                        direction: PathArc.Clockwise
                    }

                    PathLine {
                        x: 0
                        y: 0
                    }
                }

            }

            // fundo do painel (acompanha o tamanho que está crescendo)
            Rectangle {
                id: popupBg

                anchors.fill: parent
                anchors.leftMargin: root.edge
                anchors.rightMargin: root.edge
                color: root.panelColor
                bottomLeftRadius: root.edge
                bottomRightRadius: root.edge
            }

            // conteúdo com o tamanho final, revelado pelo recorte
            Item {
                anchors.fill: popupBg
                clip: true

                Rectangle {
                    id: panel

                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: popup.implicitWidth - root.edge * 2
                    height: popup.implicitHeight
                    color: "transparent"
                    implicitHeight: content.implicitHeight + 28

                    Item {
                        anchors.fill: parent
                        focus: true
                        Keys.onEscapePressed: popup.open = false
                    }

                    ColumnLayout {
                        // TÍTULO + ESTADO
                        // TEMPOS (foco e descanso)
                        // RODAPÉ: ciclos concluídos + parar
                        // dica quando as configurações mudam durante uma sessão

                        id: content

                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "Pomodoro"
                                color: root.iconColor
                                font.family: "Rubik"
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.phase === "idle" ? "Parado" : ((root.phase === "focus" ? "Foco" : "Descanso") + " · " + root.formatTime(root.remainingMs) + (root.running ? "" : " (pausado)"))
                                color: root.mutedColor
                                font.family: "Rubik"
                                font.pixelSize: 12
                            }

                        }

                        Repeater {
                            model: [{
                                "label": "Foco",
                                "key": "focus",
                                "step": 5,
                                "min": 5,
                                "max": 90
                            }, {
                                "label": "Descanso",
                                "key": "break",
                                "step": 1,
                                "min": 1,
                                "max": 30
                            }]

                            delegate: RowLayout {
                                id: setting

                                required property var modelData

                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: setting.modelData.label
                                    color: root.iconColor
                                    font.family: "Rubik"
                                    font.pixelSize: 14
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    implicitWidth: 30
                                    implicitHeight: 30
                                    radius: 8
                                    color: minusMouse.containsMouse ? root.borderColor : root.selectorColor
                                    border.width: 1
                                    border.color: root.borderColor

                                    Text {
                                        anchors.centerIn: parent
                                        text: "remove"
                                        color: root.iconColor
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 18
                                    }

                                    MouseArea {
                                        id: minusMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.change(setting.modelData.key, -setting.modelData.step, setting.modelData.min, setting.modelData.max)
                                    }

                                }

                                Text {
                                    Layout.preferredWidth: 60
                                    horizontalAlignment: Text.AlignHCenter
                                    text: root.valueOf(setting.modelData.key) + " min"
                                    color: root.iconColor
                                    font.family: "Rubik"
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Rectangle {
                                    implicitWidth: 30
                                    implicitHeight: 30
                                    radius: 8
                                    color: plusMouse.containsMouse ? root.borderColor : root.selectorColor
                                    border.width: 1
                                    border.color: root.borderColor

                                    Text {
                                        anchors.centerIn: parent
                                        text: "add"
                                        color: root.iconColor
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 18
                                    }

                                    MouseArea {
                                        id: plusMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.change(setting.modelData.key, setting.modelData.step, setting.modelData.min, setting.modelData.max)
                                    }

                                }

                            }

                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: root.cycles === 0 ? "" : root.cycles + (root.cycles === 1 ? " ciclo concluído" : " ciclos concluídos")
                                color: root.mutedColor
                                font.family: "Rubik"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                visible: root.active
                                implicitWidth: 80
                                implicitHeight: 30
                                radius: 8
                                color: stopMouse.containsMouse ? root.borderColor : root.selectorColor
                                border.width: 1
                                border.color: stopMouse.containsMouse ? root.iconColor : root.borderColor

                                Text {
                                    anchors.centerIn: parent
                                    text: "Parar"
                                    color: root.iconColor
                                    font.family: "Rubik"
                                    font.pixelSize: 13
                                }

                                MouseArea {
                                    id: stopMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.stop();
                                        popup.open = false;
                                    }
                                }

                            }

                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.active
                            text: "Os novos tempos valem a partir da próxima fase."
                            color: root.mutedColor
                            font.family: "Rubik"
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }

                    }

                }
            }

        }

    }

}
