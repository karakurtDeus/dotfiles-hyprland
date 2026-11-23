pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "theme"

ClippingRectangle {
    id: root

    required property string userName
    property string textFontFamily: "monospace"
    property string profileDirectory: Quickshell.env("HOME") + "/.config/hypr/profile"
    property bool playbackActive: false
    property bool mediaVisible: playbackActive

    readonly property string helper: Quickshell.shellPath("profile-data.py")
    property var media: ({})
    property bool refreshingMedia: false

    radius: width / 2
    color: Colors.group

    onPlaybackActiveChanged: {
        if (playbackActive)
            mediaRefresh.restart()
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
        enabled: root.playbackActive

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
            if (!root.playbackActive)
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

    Text {
        anchors.centerIn: parent
        visible: !root.media.url || !avatar.item || !avatar.item.frameReady
        text: root.userName.charAt(0).toUpperCase()
        font.family: root.textFontFamily
        font.pixelSize: root.width * 0.35
        color: Colors.accent
    }

    Loader {
        id: avatar
        anchors.fill: parent
        active: root.mediaVisible && !!root.media.url && !root.refreshingMedia
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
            playing: root.playbackActive
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
                autoPlay: root.playbackActive
            }

            Connections {
                target: root
                function onPlaybackActiveChanged() {
                    if (root.playbackActive)
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
