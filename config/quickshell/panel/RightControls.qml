pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import "theme"

PanelWindow {
    id: root

    anchors {
        right: true
    }

    required property int borderWidth

    implicitHeight: 288
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-right-controls"
    color: Colors.clear
    visible: !fullscreenActive
    mask: Region {
        x: root.open ? 0 : root.width - 24
        y: root.open ? 0 : (root.height - 56) / 2
        width: root.open ? root.width : 24
        height: root.open ? root.height : 56
    }

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var specialWorkspace: {
        const name = monitor?.lastIpcObject?.specialWorkspace?.name
        return name ? Hyprland.workspaces.values.find(workspace => workspace.name === name) : null
    }
    readonly property bool fullscreenActive: {
        const workspace = specialWorkspace ?? monitor?.activeWorkspace
        return workspace?.toplevels.values.some(window => {
            const state = window.lastIpcObject
            return (state?.fullscreen ?? 0) >= 2 || (state?.fullscreenClient ?? 0) >= 2
        }) ?? false
    }

    onFullscreenActiveChanged: {
        if (fullscreenActive) {
            closeTimer.stop()
            open = false
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "fullscreen")
                Hyprland.refreshToplevels()
            if (event.name === "activespecialv2")
                Hyprland.refreshMonitors()
        }
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink?.audio
    property bool open: false
    property real slide: open ? 1 : 0

    Timer {
        id: closeTimer
        interval: 200
        onTriggered: root.open = false
    }

    Behavior on slide {
        NumberAnimation {
            duration: 500
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1]
        }
    }

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    Item {
        id: hoverArea

        anchors.fill: parent

        HoverHandler {
            onHoveredChanged: {
                if (hovered && !root.fullscreenActive) {
                    closeTimer.stop()
                    root.open = true
                } else {
                    closeTimer.restart()
                }
            }
        }

        Rectangle {
            id: drawer
            width: hoverArea.width
            height: hoverArea.height - 24
            x: width * (1 - Math.min(root.slide, 1))
            anchors.verticalCenter: parent.verticalCenter
            opacity: Math.min(root.slide, 1)
            radius: 13
            topRightRadius: 0
            bottomRightRadius: 0
            color: Colors.panel

            Canvas {
                anchors.fill: parent
                anchors.topMargin: -12
                anchors.bottomMargin: -12

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = drawer.color
                    const edge = width - root.borderWidth
                    const r = 12
                    ctx.beginPath()
                    ctx.moveTo(edge, 0)
                    ctx.arcTo(edge, r, edge - r, r, r)
                    ctx.lineTo(edge, r)
                    ctx.closePath()
                    ctx.fill()

                    ctx.save()
                    ctx.translate(0, height)
                    ctx.scale(1, -1)
                    ctx.beginPath()
                    ctx.moveTo(edge, 0)
                    ctx.arcTo(edge, r, edge - r, r, r)
                    ctx.lineTo(edge, r)
                    ctx.closePath()
                    ctx.fill()
                    ctx.restore()
                }
            }

            Column {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -root.borderWidth / 2
                spacing: 10

                FilledControl {
                    iconFamily: symbols.name
                    icon: root.audio?.muted || value === 0 ? "\ue04f" : "\ue050"
                    enabled: !!root.audio
                    to: 1.5
                    value: root.audio?.volume ?? 0
                    onMoved: root.audio.volume = value
                }

                FilledControl {
                    iconFamily: symbols.name
                    icon: "\ue3ab"
                    value: 1
                    enabled: false
                }
            }
        }
    }

    FontLoader {
        id: symbols
        source: "file:///usr/share/fonts/TTF/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf"
    }
}
