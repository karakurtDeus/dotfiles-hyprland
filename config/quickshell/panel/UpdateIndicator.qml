pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "theme"

Item {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cacheDir: Quickshell.env("XDG_CACHE_HOME") || home + "/.cache"
    readonly property string updateScript: Quickshell.shellPath("package-updates.sh")
    required property int buttonSize
    required property font iconFont
    required property font countFont
    property int pendingCount: -1
    readonly property string displayedCount: pendingCount < 0 ? "––" : String(Math.min(pendingCount, 99)).padStart(2, "0")

    width: buttonSize
    height: contents.implicitHeight + 4
    Accessible.role: Accessible.Button
    Accessible.name: "System updates, " + (pendingCount < 0 ? "count loading" : pendingCount + " available")
    Accessible.onPressAction: launchUpdate()

    function acceptCount(text: string): void {
        const input = text.trim()
        if (/^\d+$/.test(input))
            pendingCount = Number(input)
    }

    function launchUpdate(): void {
        if (!updateTerminal.running)
            updateTerminal.running = true
    }

    Component.onCompleted: scan.running = true

    FileView {
        path: root.cacheDir + "/updates"
        printErrors: false
        onLoaded: {
            if (root.pendingCount < 0)
                root.acceptCount(text())
        }
    }

    Process {
        id: scan
        command: ["bash", root.updateScript, "--scan"]

        stdout: StdioCollector {
            onStreamFinished: root.acceptCount(text)
        }
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: true
        onTriggered: {
            if (!updateTerminal.running)
                scan.running = true
        }
    }

    Process {
        id: updateTerminal
        command: ["kitty", "--directory", root.home, "bash", root.updateScript, "--update"]
        onExited: scan.running = true
    }

    Column {
        id: contents
        anchors.centerIn: parent
        width: parent.width

        Text {
            width: parent.width
            height: root.buttonSize
            text: "\ue923"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: WorkspaceSettings.activeBackground
            font: root.iconFont
        }

        Text {
            width: parent.width
            text: root.displayedCount
            horizontalAlignment: Text.AlignHCenter
            color: Colors.barText
            font: root.countFont
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.launchUpdate()
    }
}
