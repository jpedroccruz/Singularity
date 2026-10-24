import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.theme as ThemeModule

Item {
    id: root

    property color iconColor: ThemeModule.Theme.accent
    property color mutedColor: ThemeModule.Theme.muted
    property string iconFont: "Material Symbols Rounded"
    property int iconSize: 18
    property int guardMs: 3000
    property var silentApps: ["zapzap"]
    property bool debug: false
    property bool alwaysShow: false
    property bool barHovered: false
    property bool muted: false
    property var guards: [] // apps cujo áudio deve ficar silenciado agora
    property var touched: [] // streams que nós silenciamos (para restaurar)
    property var dbgSeen: ({
    }) // mensagens de debug já impressas
    readonly property bool active: muted
    readonly property bool shown: alwaysShow || barHovered || active
    readonly property string storageDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell"
    readonly property string storagePath: storageDir + "/notification-mute"

    function toggle() {
        root.muted = !root.muted;
        file.setText(root.muted ? "true" : "false");
    }

    // Chamado pelo Clock quando uma notificação é bloqueada.
    function silence(app, entry) {
        const a = (app || "").toLowerCase();
        const e = (entry || "").toLowerCase();
        if (a === "" && e === "")
            return ;

        root.guards = root.guards.concat([{
            "app": a,
            "entry": e,
            "until": Date.now() + root.guardMs
        }]);
        if (root.debug) {
            console.log("[NotificationMute] notificação de app='" + a + "' entry='" + e + "'");
            const nodes = Pipewire.nodes.values;
            for (let i = 0; i < nodes.length; i++) {
                if (nodes[i] && nodes[i].isStream)
                    console.log("[NotificationMute] stream: " + root.streamIds(nodes[i]).join(" | "));

            }
        }
        sweep();
    }

    // Identificadores de um stream de áudio (nome do app, binário, etc).
    function streamIds(node) {
        const p = node.properties || {
        };
        const raw = [p["application.name"], p["application.process.binary"], p["application.icon_name"], node.name];
        const out = [];
        for (let i = 0; i < raw.length; i++) {
            const v = (raw[i] || "").toString().toLowerCase();
            if (v.length >= 3)
                out.push(v);

        }
        return out;
    }

    // O nome do stream corresponde ao app alvo?
    function nameMatches(node, g) {
        const keys = [g.app, g.entry].filter((k) => {
            return k.length >= 3;
        });
        const ids = root.streamIds(node);
        for (let i = 0; i < keys.length; i++) {
            for (let j = 0; j < ids.length; j++) {
                if (ids[j].indexOf(keys[i]) >= 0 || keys[i].indexOf(ids[j]) >= 0)
                    return true;

            }
        }
        return false;
    }

    // O stream é de reprodução de áudio e dá para controlar o mudo dele?
    function eligible(node) {
        // obs.: nos streams de reprodução o PipeWire marca isSink = true,
        // então não dá para usar isSink para separá-los
        if (!node.isStream || !node.audio)
            return false;

        // se a classe vier preenchida, só aceita reprodução (não microfone)
        const cls = (node.properties || {
        })["media.class"] || "";
        return cls === "" || cls.indexOf("Output") >= 0;
    }

    // O stream pertence ao app alvo e pode ser silenciado?
    function matches(node, g) {
        return root.eligible(node) && root.nameMatches(node, g);
    }

    // Apps que devem estar silenciados agora: os do `silentApps` (enquanto o
    // mudo estiver ativo) e os que acabaram de enviar uma notificação.
    function activeTargets() {
        const now = Date.now();
        const live = root.guards.filter((g) => {
            return g.until > now;
        });
        if (live.length !== root.guards.length)
            root.guards = live;

        const out = live.slice();
        if (root.muted) {
            for (let i = 0; i < root.silentApps.length; i++) out.push({
                "app": root.silentApps[i].toLowerCase(),
                "entry": ""
            })
        }
        return out;
    }

    // Silencia os streams dos apps-alvo e restaura quando não há mais alvo.
    function sweep() {
        const targets = root.activeTargets();
        if (targets.length > 0) {
            const nodes = Pipewire.nodes.values;
            const added = [];
            for (let i = 0; i < nodes.length; i++) {
                const n = nodes[i];
                if (!n || !n.isStream || root.touched.indexOf(n) >= 0)
                    continue;

                if (root.debug) {
                    for (let j = 0; j < targets.length; j++) {
                        if (root.nameMatches(n, targets[j]) && !root.eligible(n)) {
                            const msg = "[NotificationMute] achei " + root.streamIds(n).join(" | ") + " mas não dá para silenciar: audio=" + (n.audio ? "ok" : "null") + " isSink=" + n.isSink + " class=" + ((n.properties || {
                            })["media.class"] || "?");
                            // imprime cada mensagem só uma vez
                            if (root.dbgSeen[msg] === undefined) {
                                root.dbgSeen[msg] = true;
                                console.log(msg);
                            }
                        }
                    }
                }
                if (!n.audio || n.audio.muted)
                    continue;

                for (let j = 0; j < targets.length; j++) {
                    if (root.matches(n, targets[j])) {
                        n.audio.muted = true;
                        added.push(n);
                        if (root.debug)
                            console.log("[NotificationMute] silenciado: " + root.streamIds(n).join(" | ") + " (muted=" + n.audio.muted + ")");

                        break;
                    }
                }
            }
            if (added.length > 0)
                root.touched = root.touched.concat(added);

        } else if (root.touched.length > 0) {
            for (let i = 0; i < root.touched.length; i++) {
                const t = root.touched[i];
                try {
                    if (t && t.audio)
                        t.audio.muted = false;

                } catch (e) {
                }
            }
            if (root.debug)
                console.log("[NotificationMute] áudio restaurado");

            root.touched = [];
        }
    }

    onMutedChanged: sweep()
    visible: shown
    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight
    Component.onCompleted: mkdirProcess.running = true

    Process {
        id: mkdirProcess

        command: ["mkdir", "-p", root.storageDir]
    }

    FileView {
        id: file

        path: root.storagePath
        printErrors: false
        onLoaded: root.muted = text().trim() === "true"
    }

    // Precisa acompanhar os streams para ler as propriedades e silenciá-los.
    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    // Enquanto há algo silenciado, confere a cada instante: o stream do som
    // da notificação pode aparecer um pouco depois da própria notificação.
    Timer {
        interval: 100
        repeat: true
        running: root.guards.length > 0 || root.touched.length > 0 || (root.muted && root.silentApps.length > 0)
        onTriggered: root.sweep()
    }

    // Reage na hora quando aparece um stream novo (ex.: o som da notificação).
    Connections {
        function onValuesChanged() {
            if (root.muted || root.guards.length > 0)
                root.sweep();

        }

        target: Pipewire.nodes
    }

    Text {
        id: icon

        anchors.centerIn: parent
        text: root.muted ? "notifications_off" : "notifications"
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
        onClicked: root.toggle()
    }

}
