pragma Singleton

import QtQuick

QtObject {
    // Bar, frame and drawer backgrounds.
    readonly property color panel: "#131217"
    readonly property color group: "#201d25"
    readonly property color control: "#28252e"
    readonly property color hover: "#393341"

    // Text, icons and highlights.
    readonly property color text: "#e9e2ef"
    readonly property color mutedText: "#c9c1d0"
    readonly property color barText: "#e9e2ef"
    readonly property color disabledIcon: "#817989"
    readonly property color accent: "#cebff0"
    readonly property color selection: "#554574"
    readonly property color error: "#ef9eab"

    // Background and transparent surfaces.
    readonly property color wallpaperFallback: "#131217"
    readonly property color clear: "transparent"
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.48)
}
