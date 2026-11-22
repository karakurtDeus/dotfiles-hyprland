pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Widgets
import "theme"

PanelWindow {
    id: root

    property string profileDirectory: Quickshell.env("HOME") + "/.config/hypr/profile"
    readonly property string userName: Quickshell.env("USER") || Quickshell.env("HOME").split("/").pop()
    readonly property string helper: Quickshell.shellPath("profile-data.py")
    readonly property var sink: Pipewire.defaultAudioSink
    property bool opened: false
    property real slide: opened ? 1 : 0
    property var media: ({})
    property bool refreshingMedia: false
    property var stats: ({})

    anchors.top: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-profile"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: Colors.clear
    visible: opened || slide > 0
    mask: Region { item: root.opened ? drawer : null }

    Behavior on slide {
        NumberAnimation {
            duration: 500
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1]
        }
    }

    onOpenedChanged: {
        if (opened) {
            mediaRefresh.restart()
            Qt.callLater(() => drawer.forceActiveFocus())
        }
    }

    function percent(value): string {
        return value === null || value === undefined ? "N/A" : value + "%"
    }

    function uptime(seconds): string {
        if (seconds === null || seconds === undefined)
            return "N/A"
        const minutes = Math.floor(seconds / 60)
        const hours = Math.floor(minutes / 60)
        const days = Math.floor(hours / 24)
        return (days ? days + "d " : "") + (hours % 24) + "h " + (minutes % 60) + "m"
    }

    function speed(bytes): string {
        if (bytes === null || bytes === undefined)
            return "N/A"
        if (bytes >= 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(1) + " MiB/s"
        return (bytes / 1024).toFixed(1) + " KiB/s"
    }

    FolderListModel {
        id: profileFiles
        folder: "file://" + root.profileDirectory
        showDirs: false
        showOnlyReadable: true
        showHidden: false
    }

    Connections {
        target: profileFiles
        enabled: root.opened

        function onRowsInserted() { mediaRefresh.restart() }
        function onRowsRemoved() { mediaRefresh.restart() }
        function onModelReset() { mediaRefresh.restart() }
        function onLayoutChanged() { mediaRefresh.restart() }
        function onDataChanged() { mediaRefresh.restart() }
    }

    Timer {
        id: mediaRefresh
        interval: 120
        onTriggered: {
            if (!root.opened)
                return
            if (mediaScan.running)
                restart()
            else
                mediaScan.running = true
        }
    }

    Process {
        id: mediaScan
        command: ["python3", root.helper, "media", root.profileDirectory]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    const next = JSON.parse(text)
                    if (next.url !== root.media.url || next.modified !== root.media.modified) {
                        root.refreshingMedia = true
                        root.media = next
                        Qt.callLater(() => root.refreshingMedia = false)
                    }
                }
            }
        }
    }

    Process {
        command: ["python3", "-u", root.helper, "stats"]
        running: root.opened
        stdout: SplitParser {
            onRead: line => {
                if (line.trim())
                    root.stats = JSON.parse(line)
            }
        }
    }

    PwObjectTracker {
        objects: root.opened && root.sink ? [root.sink] : []
    }

    Rectangle {
        id: drawer
        readonly property real progress: Math.min(root.slide, 1)
        readonly property int textSize: width < 500 ? 11 : 16

        width: parent.width
        height: parent.height
        y: -height * (1 - progress)
        opacity: progress
        radius: 20
        topLeftRadius: 0
        topRightRadius: 0
        color: Colors.panel
        focus: true
        Keys.onEscapePressed: root.opened = false

        RowLayout {
            anchors.fill: parent
            anchors.margins: drawer.width < 500 ? 12 : 24
            spacing: drawer.width < 500 ? 12 : 32

            ClippingRectangle {
                id: portrait
                readonly property int diameter: Math.min(222, drawer.height - 40, Math.round(drawer.width * 0.30))
                Layout.preferredWidth: diameter
                Layout.preferredHeight: diameter
                Layout.alignment: Qt.AlignVCenter
                radius: width / 2
                color: Colors.group

                Text {
                    anchors.centerIn: parent
                    visible: !root.media.url || !avatar.item || !avatar.item.frameReady
                    text: root.userName.charAt(0).toUpperCase()
                    font.pixelSize: portrait.width * 0.35
                    color: Colors.accent
                }

                Loader {
                    id: avatar
                    anchors.fill: parent
                    active: (root.opened || root.slide > 0) && !!root.media.url && !root.refreshingMedia
                    sourceComponent: root.media.kind === "video" ? video
                        : root.media.kind === "animated" ? animation : still
                }

                Component {
                    id: still
                    Image {
                        readonly property bool frameReady: status === Image.Ready
                        source: root.media.url ? root.media.url + "?modified=" + root.media.modified : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: Math.round(width * 2)
                        sourceSize.height: Math.round(height * 2)
                        asynchronous: true
                    }
                }

                Component {
                    id: animation
                    AnimatedImage {
                        readonly property bool frameReady: status === AnimatedImage.Ready
                        source: root.media.url ? root.media.url + "?modified=" + root.media.modified : ""
                        fillMode: Image.PreserveAspectCrop
                        playing: root.opened
                        cache: false
                    }
                }

                Component {
                    id: video
                    VideoOutput {
                        id: output
                        property bool frameReady: false
                        fillMode: VideoOutput.PreserveAspectCrop

                        MediaPlayer {
                            id: player
                            source: root.media.url ?? ""
                            videoOutput: output
                            loops: MediaPlayer.Infinite
                            autoPlay: root.opened
                        }

                        Connections {
                            target: root
                            function onOpenedChanged() {
                                if (root.opened)
                                    player.play()
                                else
                                    player.pause()
                            }
                        }

                        Connections {
                            target: output.videoSink
                            function onVideoFrameChanged() { output.frameReady = true }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: drawer.width < 500 ? 12 : 18

                Item {
                    Layout.fillWidth: true
                    implicitHeight: userLabel.implicitHeight

                    Text {
                        id: userLabel
                        width: (parent.width + statsGrid.columnSpacing) / 2
                        text: root.userName
                        textFormat: Text.PlainText
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        color: Colors.text
                        font.pixelSize: drawer.width < 500 ? 20 : 30
                    }
                }

                GridLayout {
                    id: statsGrid
                    Layout.fillWidth: true
                    columns: 2
                    uniformCellWidths: true
                    rowSpacing: drawer.width < 500 ? 8 : 13
                    columnSpacing: drawer.width < 500 ? 7 : 28

                    Repeater {
                        model: [
                            ["Uptime", root.uptime(root.stats.uptime)],
                            ["Audio", root.sink?.audio?.muted ? "Muted" : root.percent(
                                root.sink?.audio ? Math.round(root.sink.audio.volume * 100) : null)],
                            ["CPU", root.percent(root.stats.cpu)],
                            ["GPU", root.percent(root.stats.gpu)],
                            ["RAM", root.percent(root.stats.memory)],
                            ["Download", root.speed(root.stats.download)],
                            ["Upload", root.speed(root.stats.upload)],
                            ["Battery", root.percent(root.stats.battery)]
                        ]

                        delegate: Text {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: modelData[0] + "  " + modelData[1]
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            font.pixelSize: drawer.textSize
                            color: Colors.mutedText
                        }
                    }
                }
            }
        }
    }
}
