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
    property bool alwaysShow: false
    property bool barHovered: false
    property bool muted: false
    // apps que já mandaram notificação com o mudo ativo (nomes em minúsculas)
    property var apps: []
    readonly property bool shown: alwaysShow || barHovered || muted
    readonly property string storageDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell"
    readonly property string storagePath: storageDir + "/notification-mute"

    function toggle() {
        root.muted = !root.muted;
        file.setText(root.muted ? "true" : "false");
    }

    // Chamado pelo Clock quando uma notificação é bloqueada.
    function silence(app, entry) {
        const add = [app, entry].map((s) => {
            return (s || "").toLowerCase();
        }).filter((s) => {
            return s.length >= 3 && root.apps.indexOf(s) < 0;
        });
        if (add.length === 0)
            return ;

        root.apps = root.apps.concat(add);
        sweep();
    }

    // O stream pertence a algum app da lista?
    function inList(node) {
        const p = node.properties || {
        };
        const ids = [p["application.name"], p["application.process.binary"], p["application.icon_name"], node.name].map((s) => {
            return (s || "").toString().toLowerCase();
        }).filter((s) => {
            return s.length >= 3;
        });
        for (let i = 0; i < root.apps.length; i++) for (let j = 0; j < ids.length; j++) if (ids[j].indexOf(root.apps[i]) >= 0 || root.apps[i].indexOf(ids[j]) >= 0) {
            return true;
        }
        return false;
    }

    // Deixa o mudo dos streams da lista igual ao estado do mudo.
    function sweep() {
        const nodes = Pipewire.nodes.values;
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (!n || !n.isStream || !n.audio)
                continue;

            const cls = (n.properties || {
            })["media.class"] || "";
            if (cls !== "" && cls.indexOf("Output") < 0)
                continue;

            if (n.audio.muted !== root.muted && root.inList(n))
                n.audio.muted = root.muted;

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

    PwObjectTracker {
        objects: root.apps.length > 0 ? Pipewire.nodes.values : []
    }

    // o stream do som aparece um pouco depois da notificação
    Timer {
        interval: 200
        repeat: true
        running: root.apps.length > 0
        onTriggered: root.sweep()
    }

    Connections {
        function onValuesChanged() {
            root.sweep();
        }

        target: Pipewire.nodes
    }

    Text {
        id: icon

        anchors.centerIn: parent
        text: root.muted ? "notifications_off" : "notifications"
        color: root.muted ? root.iconColor : root.mutedColor
        font.family: root.iconFont
        font.pixelSize: root.iconSize
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggle()
    }

}
