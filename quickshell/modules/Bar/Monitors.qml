import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
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
    property int edge: 20
    property var monitors: []
    property var mainMon: null
    property var extMon: null
    property string mode: "extended"
    property string pendingMode: ""
    property string notice: ""
    readonly property bool hasExternal: extMon !== null
    readonly property var activeMonitors: monitors.filter((m) => {
        return !m.disabled;
    })
    readonly property var scaleOptions: [1, 1.25, 1.5, 1.75, 2]
    readonly property var modeOptions: [{
        "id": "main",
        "label": "Main monitor only",
        "icon": "laptop_mac"
    }, {
        "id": "extended",
        "label": "Extended",
        "icon": "devices"
    }, {
        "id": "mirror",
        "label": "Mirror",
        "icon": "cast"
    }, {
        "id": "second",
        "label": "Second monitor only",
        "icon": "monitor"
    }]

    function resText(m) {
        return m.width + "x" + m.height + "@" + Math.round(m.refreshRate);
    }

    function modeLabel(id) {
        for (let i = 0; i < modeOptions.length; i++) {
            if (modeOptions[i].id === id)
                return modeOptions[i].label;

        }
        return "Display";
    }

    function showNotice(text, seconds) {
        root.notice = text;
        noticeTimer.interval = seconds * 1000;
        noticeTimer.restart();
    }

    function isMirrored(m) {
        if (m.mirrorOf === undefined || m.mirrorOf === null)
            return false;

        const v = String(m.mirrorOf);
        return v !== "none" && v !== "";
    }

    function parseMonitors(text) {
        let list;
        try {
            list = JSON.parse(text);
        } catch (e) {
            return ;
        }
        if (!Array.isArray(list) || list.length === 0)
            return ;

        const internal = list.find((m) => {
            return /^(eDP|LVDS|DSI)/i.test(m.name);
        });
        const main = internal || list[0];
        const ext = list.find((m) => {
            return m.name !== main.name;
        }) || null;
        root.monitors = list;
        root.mainMon = main;
        root.extMon = ext;
        if (!ext)
            return ;

        if (ext.disabled)
            root.mode = "main";
        else if (main.disabled)
            root.mode = "second";
        else if (isMirrored(ext) || isMirrored(main))
            root.mode = "mirror";
        else
            root.mode = "extended";
    }

    // ---------- geração dos comandos Lua ----------
    // A config do Hyprland é Lua, então `hyprctl keyword` é recusado. O caminho é
    // `hyprctl eval` com chamadas hl.monitor({...}). As mudanças valem até o
    // próximo `hyprctl reload`.
    function lua(name, fields) {
        const parts = ["output = \"" + name.replace(/"/g, "") + "\""];
        for (const k in fields) {
            const v = fields[k];
            parts.push(k + " = " + (typeof v === "string" ? "\"" + v + "\"" : v));
        }
        return "hl.monitor({ " + parts.join(", ") + " })";
    }

    function exactMode(m) {
        return m.width + "x" + m.height + "@" + Number(m.refreshRate).toFixed(2);
    }

    function modeStr(m, keep) {
        return keep ? exactMode(m) : "preferred";
    }

    function scaleOf(m, overrides) {
        if (overrides && overrides[m.name] !== undefined)
            return overrides[m.name];

        return m.scale > 0 ? m.scale : 1;
    }

    // mode: main | extended | mirror | second
    // overrides: { "NOME": escala } (número ou "auto")
    // keep: true mantém a resolução/taxa atuais; false usa "preferred"
    function buildLua(mode, overrides, keep) {
        const main = root.mainMon;
        const ext = root.extMon;
        const sm = scaleOf(main, overrides);
        const se = ext ? scaleOf(ext, overrides) : 1;
        const parts = [];

        function configure(m, fields) {
            parts.push(lua(m.name, fields));
        }

        if (!ext || mode === "main") {
            configure(main, {
                "mode": modeStr(main, keep),
                "position": "0x0",
                "scale": sm,
                "disabled": false,
                "mirror": ""
            });

            if (ext) {
                configure(ext, {
                    "disabled": true,
                    "mirror": ""
                });
            }
        } else if (mode === "second") {
            // Ativa o monitor externo antes de desativar o principal.
            configure(ext, {
                "mode": modeStr(ext, keep),
                "position": "0x0",
                "scale": se,
                "disabled": false,
                "mirror": ""
            });

            configure(main, {
                "disabled": true,
                "mirror": ""
            });
        } else if (mode === "mirror") {
            // Reativa o principal e remove qualquer espelhamento antigo.
            configure(main, {
                "mode": modeStr(main, keep),
                "position": "0x0",
                "scale": sm,
                "disabled": false,
                "mirror": ""
            });

            // O monitor externo deve espelhar explicitamente o principal.
            configure(ext, {
                "mode": modeStr(ext, keep),
                "position": "0x0",
                "scale": se,
                "disabled": false,
                "mirror": main.name
            });
        } else {
            configure(main, {
                "mode": modeStr(main, keep),
                "position": "0x0",
                "scale": sm,
                "disabled": false,
                "mirror": ""
            });

            // O externo fica à direita do principal, considerando a escala lógica.
            const x = typeof sm === "number"
                ? Math.round((main.width || 0) / sm) + "x0"
                : "auto-right";

            configure(ext, {
                "mode": modeStr(ext, keep),
                "position": x,
                "scale": se,
                "disabled": false,
                "mirror": ""
            });
        }

        return "(function() " + parts.join("; ") + " end)()";
    }

    function runLua(code) {
        if (!root.mainMon)
            return ;

        if (applyProcess.running)
            return ;

        applyProcess.command = ["hyprctl", "eval", code];
        applyProcess.running = true;
    }

    function setMode(id) {
        if (!root.hasExternal || id === root.mode || applyProcess.running)
            return ;

        root.pendingMode = id;
        runLua(buildLua(id, null, false));
    }

    // Reaplica o wallpaper atual somente na saída externa.
    // O arquivo de estado fica em ~/.local/state/singulartiy/current-wallpaper;
    // se o estado não existir ou o caminho for inválido, usa o fallback original.
    function applyExternalWallpaper() {
        if (!root.extMon || !root.pendingMode || root.pendingMode !== "extended")
            return ;

        wallpaperProcess.command = [
            "bash",
            "-lc",
            'wallpaper="$(cat "$HOME/.local/state/singulartiy/current-wallpaper" 2>/dev/null)"; ' +
            'if [ -z "$wallpaper" ] || [ ! -f "$wallpaper" ]; then ' +
            'wallpaper="$HOME/.config/colorSchemes/wallpaper.jpg"; fi; ' +
            'if [ -f "$wallpaper" ]; then awww img "$wallpaper" --outputs "$1"; ' +
            'else exit 2; fi',
            "singularity-wallpaper",
            root.extMon.name
        ];
        wallpaperProcess.running = true;
    }

    function setScale(m, s) {
        const ov = {
        };
        ov[m.name] = s;
        runLua(buildLua(root.mode, ov, true));
    }

    function refresh() {
        if (!listProcess.running)
            listProcess.running = true;

    }

    implicitWidth: indicator.width + 18
    implicitHeight: 30
    color: "transparent"
    Component.onCompleted: refresh()

    Process {
        id: listProcess

        command: ["hyprctl", "monitors", "all", "-j"]

        stdout: StdioCollector {
            onStreamFinished: root.parseMonitors(this.text)
        }

    }

    Process {
        id: applyProcess

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.showNotice("FALHA AO APLICAR", 5);
            } else {
                root.mode = root.pendingMode;
                if (root.pendingMode === "extended")
                    root.applyExternalWallpaper();
            }

            root.pendingMode = "";
            refreshTimer.restart();
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (/error|fail|invalid/i.test(this.text))
                    root.showNotice("FALHA AO APLICAR", 5);

            }
        }

    }

    Process {
        id: wallpaperProcess

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.showNotice("MODO APLICADO; FALHA NO WALLPAPER", 5);
        }
    }

    Timer {
        id: statusTimer

        interval: popup.open ? 2000 : 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshTimer

        interval: 700
        onTriggered: root.refresh()
    }

    Timer {
        id: noticeTimer

        onTriggered: root.notice = ""
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
        // caixa fixa um pouco maior que o glifo, para a borda não ser cortada
        width: 28
        height: 24
        leftPadding: 3
        rightPadding: 3
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
        text: "monitor"
        color: root.iconColor
        font.family: "Material Symbols Rounded"
        font.pixelSize: 18
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: indicator.width
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
        id: monitorDelegate

        ColumnLayout {
            id: monItem

            property var mon: modelData

            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Chip {
                    Layout.fillWidth: true
                    label: "Auto"
                    selected: false
                    onClicked: root.setScale(monItem.mon, "auto")
                }

                Repeater {
                    model: root.scaleOptions

                    delegate: Chip {
                        Layout.fillWidth: true
                        label: modelData + "x"
                        selected: Math.abs(monItem.mon.scale - modelData) < 0.01
                        onClicked: root.setScale(monItem.mon, modelData)
                    }

                }

            }

        }

    }

    PanelWindow {
        id: popup

        // `open` é o estado lógico; `reveal` vai de 0 a 1 durante a animação.
        property bool open: false
        property real reveal: 0
        // a largura abre primeiro, depois a altura
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
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        onVisibleChanged: {
            if (visible)
                root.refresh();

        }

        NumberAnimation {
            id: revealAnim

            target: popup
            property: "reveal"
        }

        anchors {
            top: true
            right: true
        }

        Item {
            id: popupGrow

            anchors.top: parent.top
            anchors.right: parent.right
            width: root.edge + (popup.implicitWidth - root.edge) * popup.wf
            height: popup.implicitHeight * popup.hf
            opacity: Math.min(1, popup.reveal * 3)

            // curva que liga o popup à barra
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

            Rectangle {
                id: popupBg

                anchors.fill: parent
                anchors.leftMargin: root.edge
                color: root.panelColor
                bottomLeftRadius: root.edge
            }

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
                        // MODOS (só com monitor externo)
                        // ESCALA (um bloco por monitor ligado)

                        id: content

                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 16

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: 30
                                horizontalAlignment: Text.AlignHCenter
                                text: "monitor"
                                color: root.iconColor
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 26
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                // um título por monitor ligado: nome + resolução@taxa em cinza
                                Repeater {
                                    model: root.activeMonitors

                                    delegate: RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: modelData.name
                                            color: root.iconColor
                                            font.family: "Rubik"
                                            font.pixelSize: 14
                                            font.bold: true
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: root.resText(modelData)
                                            color: root.mutedColor
                                            font.family: "Rubik"
                                            font.pixelSize: 13
                                            elide: Text.ElideRight
                                        }

                                    }

                                }

                                // avisos rápidos (ex.: falha ao aplicar)
                                Text {
                                    Layout.fillWidth: true
                                    visible: root.notice !== ""
                                    text: root.notice
                                    color: root.mutedColor
                                    font.family: "Rubik"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }

                            }

                        }

                        Rectangle {
                            Layout.fillWidth: true
                            visible: root.hasExternal
                            height: 1
                            color: root.borderColor
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.hasExternal
                            spacing: 10

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 8
                                rowSpacing: 8

                                Repeater {
                                    model: root.modeOptions

                                    delegate: ModeButton {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        icon: modelData.icon
                                        label: modelData.label
                                        selected: root.mode === modelData.id
                                        onClicked: root.setMode(modelData.id)
                                    }

                                }

                            }

                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: root.borderColor
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Text {
                                text: "SCALE"
                                color: root.iconColor
                                font.family: "Rubik"
                                font.pixelSize: 13
                                font.bold: true
                            }

                            Repeater {
                                model: root.activeMonitors
                                delegate: monitorDelegate
                            }

                        }

                    }

                }

            }

        }

    }

    // chip de escala
    component Chip: Rectangle {
        id: chip

        property string label: ""
        property bool selected: false
        property color accent: ThemeModule.Theme.accent
        property color idleColor: ThemeModule.Theme.selector
        property color hoverColor: ThemeModule.Theme.menu
        property color lineColor: ThemeModule.Theme.border

        signal clicked()

        implicitHeight: 30
        implicitWidth: 40
        radius: 7
        color: selected ? lineColor : (chipArea.containsMouse ? hoverColor : idleColor)
        border.width: 1
        border.color: (selected || chipArea.containsMouse) ? accent : lineColor

        Text {
            anchors.centerIn: parent
            text: chip.label
            color: chip.accent
            font.family: "Rubik"
            font.pixelSize: 12
            font.bold: chip.selected
        }

        MouseArea {
            id: chipArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }

    }

    // botão de modo de exibição (ícone em cima, texto embaixo)
    component ModeButton: Rectangle {
        id: btn

        property string icon: ""
        property string label: ""
        property bool selected: false
        property color accent: ThemeModule.Theme.accent
        property color mutedColor: ThemeModule.Theme.muted
        property color idleColor: ThemeModule.Theme.selector
        property color hoverColor: ThemeModule.Theme.menu
        property color lineColor: ThemeModule.Theme.border

        signal clicked()

        implicitHeight: 64
        implicitWidth: 120
        radius: 7
        color: selected ? lineColor : (btnArea.containsMouse ? hoverColor : idleColor)
        border.width: 1
        border.color: (selected || btnArea.containsMouse) ? accent : lineColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: btn.icon
                color: btn.selected ? btn.accent : btn.mutedColor
                font.family: "Material Symbols Rounded"
                font.pixelSize: 22
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: btn.label
                color: btn.accent
                font.family: "Rubik"
                font.pixelSize: 12
                font.bold: btn.selected
                elide: Text.ElideRight
            }

        }

        MouseArea {
            id: btnArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }

    }

}
