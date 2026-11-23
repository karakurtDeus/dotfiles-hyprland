pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import Quickshell.Io

Text {
    id: root

    property string abbreviation: ""
    text: abbreviation
    horizontalAlignment: Text.AlignHCenter
    visible: abbreviation.length > 0

    Component.onCompleted: refresh.start()

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "activelayout" || event.name === "configreloaded")
                refresh.restart()
        }
    }

    Timer {
        id: refresh
        interval: 35
        onTriggered: {
            if (devices.running)
                restart()
            else
                devices.running = true
        }
    }

    Process {
        id: devices
        command: ["hyprctl", "-j", "devices"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards ?? []
                    const keyboard = keyboards.find(device => device.main) ?? keyboards[0]
                    const code = keyboard?.layout?.split(",")[keyboard.active_layout_index]?.trim()
                    root.abbreviation = code === "us" || code === "gb" ? "EN"
                        : (code || keyboard?.active_keymap?.slice(0, 2) || "").toUpperCase()
                } catch (error) {
                    console.warn("Could not read keyboard layout:", error)
                }
            }
        }
    }
}
