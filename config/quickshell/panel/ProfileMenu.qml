pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import "theme"

PanelWindow {
    id: root

    property string textFontFamily: "monospace"
    property date currentDate: new Date()
    property string profileDirectory: Quickshell.env("HOME") + "/.config/hypr/profile"
    readonly property string userName: Quickshell.env("USER") || Quickshell.env("HOME").split("/").pop()
    readonly property string helper: Quickshell.shellPath("profile-data.py")
    readonly property var sink: Pipewire.defaultAudioSink
    property bool opened: false
    property real slide: opened ? 1 : 0
    property var stats: ({})
    readonly property int avatarDiameter: Math.min(222, implicitHeight - 40, Math.round(implicitWidth * 0.30))

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
        if (opened)
            Qt.callLater(() => drawer.forceActiveFocus())
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
        readonly property bool compact: width < 500
        readonly property int textSize: compact ? 10 : 14

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
            anchors.margins: drawer.compact ? 12 : 24
            spacing: drawer.compact ? 12 : 28

            ProfileAvatar {
                Layout.preferredWidth: root.avatarDiameter
                Layout.preferredHeight: root.avatarDiameter
                Layout.alignment: Qt.AlignVCenter
                userName: root.userName
                textFontFamily: root.textFontFamily
                profileDirectory: root.profileDirectory
                playbackActive: root.opened
                mediaVisible: root.opened || root.slide > 0
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: drawer.compact ? 10 : 13

                Column {
                    id: profileHeader

                    Layout.fillWidth: true
                    Layout.leftMargin: statCard.padding
                    Layout.rightMargin: statCard.padding
                    spacing: 3

                    Text {
                        width: parent.width
                        text: root.userName
                        height: drawer.compact ? 28 : 35
                        textFormat: Text.PlainText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        color: Colors.accent
                        font.pixelSize: drawer.compact ? 19 : 24
                        font.weight: Font.Medium
                    }

                    Text {
                        width: parent.width
                        text: root.currentDate.toLocaleString(Qt.locale("en_US"), "dddd, MMMM d, yyyy")
                        height: drawer.compact ? 15 : 19
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        color: Colors.mutedText
                        font.family: root.textFontFamily
                        font.pixelSize: drawer.compact ? 10 : 13
                    }
                }

                Rectangle {
                    id: statCard

                    readonly property int padding: drawer.compact ? 8 : 16
                    Layout.fillWidth: true
                    Layout.preferredHeight: statsGrid.implicitHeight + padding * 2
                    radius: 14
                    color: Colors.group

                    GridLayout {
                        id: statsGrid

                        anchors.fill: parent
                        anchors.margins: statCard.padding
                        columns: 2
                        uniformCellWidths: true
                        rowSpacing: drawer.compact ? 3 : 5
                        columnSpacing: drawer.compact ? 8 : 28

                        Repeater {
                            model: [
                                ["Uptime", root.uptime(root.stats.uptime)],
                                ["Audio", root.sink?.audio?.muted ? "Muted" : root.percent(
                                    root.sink?.audio ? Math.round(root.sink.audio.volume * 100) : null)],
                                ["CPU", root.percent(root.stats.cpu)],
                                ["Battery", root.percent(root.stats.battery)],
                                ["RAM", root.percent(root.stats.memory)],
                                [drawer.compact ? "Up" : "Upload", root.speed(root.stats.upload)],
                                ["GPU", root.percent(root.stats.gpu)],
                                [drawer.compact ? "Down" : "Download", root.speed(root.stats.download)]
                            ]

                            delegate: Item {
                                id: metric
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredHeight: drawer.compact ? 16 : 20

                                Text {
                                    id: metricValue

                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, parent.width * 0.7)
                                    text: metric.modelData[1]
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideRight
                                    font.family: root.textFontFamily
                                    font.pixelSize: drawer.textSize
                                    color: Colors.text
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: metricValue.left
                                    anchors.rightMargin: drawer.compact ? 3 : 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: metric.modelData[0]
                                    elide: Text.ElideRight
                                    font.family: root.textFontFamily
                                    font.pixelSize: drawer.textSize
                                    color: Colors.mutedText
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
