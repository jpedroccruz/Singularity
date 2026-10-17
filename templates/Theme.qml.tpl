pragma Singleton

import QtQuick

QtObject {
    readonly property color accent: "{{ accent }}"
    readonly property color selection: "{{ selection }}"
    readonly property color muted: "{{ muted }}"

    readonly property color background: "{{ background }}"
    readonly property color darkBackground: "{{ dark_background }}"
    readonly property color darkerBackground: "{{ darker_background }}"
    readonly property color lighterBackground: "{{ lighter_background }}"

    readonly property color foreground: "{{ foreground }}"
    readonly property color darkForeground: "{{ dark_foreground }}"
    readonly property color lightForeground: "{{ light_foreground }}"
    readonly property color brightForeground: "{{ bright_foreground }}"
}
