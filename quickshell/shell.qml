import QtQuick
import Quickshell
import qs.components as Components

ShellRoot {
    Variants {
        model: Quickshell.screens

        Components.Bar {
            required property var modelData

            targetScreen: modelData
        }

    }

    Components.Launcher {
    }

    Components.PowerMenu {
    }

    Components.RadialMenu {
    }

    Components.Osd {
    }

}
