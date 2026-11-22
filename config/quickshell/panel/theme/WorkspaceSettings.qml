pragma Singleton

import QtQuick

QtObject {
    // Number of workspace slots shown in the bar, starting at workspace 1.
    readonly property int count: 5

    // Background behind all workspace slots.
    readonly property color groupBackground: Colors.group

    // Focused workspace: a large circle with a smaller center dot.
    readonly property int activeSize: 23
    readonly property int activeDotSize: 8
    readonly property color activeBackground: Colors.accent
    readonly property color activeDot: Colors.selection

    // Unfocused workspace with open windows.
    readonly property int occupiedSize: 12
    readonly property color occupiedDot: Colors.mutedText

    // Unfocused workspace without windows.
    readonly property int emptySize: 6
    readonly property color emptyDot: Colors.hover
}
