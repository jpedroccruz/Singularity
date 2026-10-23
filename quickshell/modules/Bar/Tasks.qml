// Módulo Tasks
// Lista de tarefas simples: adicionar e remover.
// As tarefas ficam salvas em ~/.local/state/quickshell/tasks.json.
//
// Na barra é só um ícone, como o Updates:
// - invisível por padrão
// - aparece em cinza quando o mouse passa por cima da barra
// - fica sempre visível, na cor de destaque, quando há tarefas
// clique: abre o popup (centralizado, integrado à barra, como o do Clock)

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.theme as ThemeModule

Item {
    id: root

    // ---------- tema ----------

    property color iconColor: ThemeModule.Theme.accent
    property color mutedColor: ThemeModule.Theme.muted
    property color panelColor: ThemeModule.Theme.darkBackground
    property color selectorColor: ThemeModule.Theme.selector
    property color borderColor: ThemeModule.Theme.border
    property string iconFont: "Material Symbols Rounded"
    property int iconSize: 18

    // ---------- configuração ----------

    // Raio dos cantos do popup: os de baixo são arredondados e os de cima se
    // curvam para dentro da barra, como se o popup fosse parte dela.
    property int edge: 20
    property int popupWidth: 320
    // Para testes: true deixa o módulo sempre visível.
    property bool alwaysShow: false
    // true quando o mouse está sobre a barra. Por padrão o módulo detecta
    // sozinho; o Bar pode sobrescrever: `Tasks { barHovered: barHover.hovered }`.
    property bool barHovered: autoHover.hovered

    // ---------- estado ----------

    property var tasks: [] // lista de textos
    property double closedAt: 0
    readonly property bool active: tasks.length > 0
    readonly property bool shown: alwaysShow || barHovered || active || popup.visible
    readonly property string storageDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell"
    readonly property string storagePath: storageDir + "/tasks.json"

    // ---------- funções ----------

    function save() {
        file.setText(JSON.stringify(root.tasks));
    }

    function addTask(text) {
        const t = text.trim();
        if (t === "")
            return ;

        root.tasks = root.tasks.concat([t]);
        save();
    }

    function removeTask(index) {
        const copy = root.tasks.slice();
        copy.splice(index, 1);
        root.tasks = copy;
        save();
    }

    function togglePopup() {
        if (popup.visible) {
            popup.visible = false;
            return ;
        }
        // o clique que acabou de fechar o popup não deve reabri-lo
        if (Date.now() - root.closedAt < 250)
            return ;

        popup.visible = true;
    }

    visible: shown
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight
    Component.onCompleted: mkdirProcess.running = true

    // ---------- armazenamento ----------

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
                const data = JSON.parse(text());
                root.tasks = Array.isArray(data) ? data.filter((t) => {
                    return typeof t === "string" && t !== "";
                }) : [];
            } catch (e) {
                root.tasks = [];
            }
        }
        onLoadFailed: root.tasks = []
    }

    // ---------- hover na barra inteira ----------

    // Um HoverHandler preso ao conteúdo da janela da barra, para saber
    // se o mouse está em qualquer ponto dela (não só em cima do módulo).
    Item {
        parent: root.QsWindow.window ? root.QsWindow.window.contentItem : null
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0

        HoverHandler {
            id: autoHover
        }

    }

    // ---------- indicador da barra ----------

    Text {
        id: icon

        anchors.centerIn: parent
        text: "checklist"
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
        acceptedButtons: Qt.LeftButton
        onClicked: root.togglePopup()
    }

    // ---------- popup ----------

    PopupWindow {
        id: popup

        // ancorado na janela da barra (não no módulo): fica no centro da tela
        anchor.window: root.QsWindow.window
        anchor.rect.x: root.QsWindow.window.width / 2 - implicitWidth / 2
        anchor.rect.y: root.QsWindow.window.height
        implicitWidth: root.popupWidth + root.edge * 2
        implicitHeight: panel.implicitHeight + 4
        visible: false
        color: "transparent"
        grabFocus: true
        onVisibleChanged: {
            if (visible)
                input.forceActiveFocus();
            else
                root.closedAt = Date.now();
        }

        // cantos côncavos que ligam o popup à barra
        Shape {
            anchors.left: parent.left
            anchors.top: parent.top
            width: root.edge
            height: root.edge
            preferredRendererType: Shape.CurveRenderer

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

        Rectangle {
            id: panel

            anchors.fill: parent
            anchors.leftMargin: root.edge
            anchors.rightMargin: root.edge
            color: root.panelColor
            bottomLeftRadius: root.edge
            bottomRightRadius: root.edge
            implicitHeight: content.implicitHeight + 28

            ColumnLayout {
                id: content

                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // TÍTULO

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Tarefas"
                        color: root.iconColor
                        font.family: "Rubik"
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: root.active
                        text: root.tasks.length
                        color: root.mutedColor
                        font.family: "Rubik"
                        font.pixelSize: 13
                    }

                }

                // NOVA TAREFA

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    TextField {
                        id: input

                        Layout.fillWidth: true
                        placeholderText: "Nova tarefa..."
                        placeholderTextColor: root.mutedColor
                        color: root.iconColor
                        selectByMouse: true
                        font.family: "Rubik"
                        font.pixelSize: 13
                        leftPadding: 12
                        rightPadding: 12
                        onAccepted: {
                            root.addTask(text);
                            text = "";
                        }
                        Keys.onEscapePressed: popup.visible = false

                        background: Rectangle {
                            radius: 10
                            color: root.selectorColor
                            border.width: 1
                            border.color: input.activeFocus ? root.iconColor : root.borderColor
                        }

                    }

                    Rectangle {
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: 10
                        color: root.iconColor
                        opacity: input.text.trim() !== "" ? 1 : 0.5

                        Text {
                            anchors.centerIn: parent
                            text: "add"
                            color: root.panelColor
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 22
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.addTask(input.text);
                                input.text = "";
                                input.forceActiveFocus();
                            }
                        }

                    }

                }

                // LISTA

                ListView {
                    id: list

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 220)
                    visible: root.active
                    clip: true
                    spacing: 6
                    model: root.tasks
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: item

                        required property int index
                        required property string modelData

                        width: ListView.view.width
                        height: itemRow.implicitHeight + 16
                        radius: 10
                        color: root.selectorColor
                        border.width: 1
                        border.color: root.borderColor

                        RowLayout {
                            id: itemRow

                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 6
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: item.modelData
                                color: root.iconColor
                                font.family: "Rubik"
                                font.pixelSize: 13
                                wrapMode: Text.Wrap
                            }

                            Rectangle {
                                implicitWidth: 28
                                implicitHeight: 28
                                radius: 8
                                color: removeMouse.containsMouse ? root.panelColor : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "close"
                                    color: removeMouse.containsMouse ? root.iconColor : root.mutedColor
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 18
                                }

                                MouseArea {
                                    id: removeMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.removeTask(item.index)
                                }

                            }

                        }

                    }

                }

                // LISTA VAZIA

                Text {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    visible: !root.active
                    text: "Nenhuma tarefa"
                    color: root.mutedColor
                    font.family: "Rubik"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                }

            }

        }

    }

}
