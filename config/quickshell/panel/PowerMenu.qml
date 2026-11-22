pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Wayland
import "theme"

PanelWindow {
    id: root

    required property int barWidth
    required property int borderWidth
    required property color panelColor
    required property string iconFamily

    property bool opened: false
    property real slide: opened ? 1 : 0
    signal actionRequested(string action)

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-power-menu"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: Colors.clear
    visible: opened || slide > 0

    mask: Region {
        x: root.barWidth
        width: root.opened ? Math.max(0, root.width - x) : 0
        height: root.height
    }

    Behavior on slide {
        NumberAnimation {
            duration: 500
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1]
        }
    }

    function request(action: string): void {
        if (!opened || !action)
            return
        opened = false
        actionRequested(action)
    }

    onOpenedChanged: {
        if (opened)
            Qt.callLater(() => keys.forceActiveFocus())
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.opened = false

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: root.barWidth
            anchors.topMargin: root.borderWidth
            anchors.rightMargin: root.borderWidth
            anchors.bottomMargin: root.borderWidth
            radius: 10
            color: Colors.scrim
            opacity: Math.min(root.slide, 1)

            TapHandler { onTapped: root.opened = false }
        }

        Rectangle {
            id: drawer

            readonly property int join: 14
            width: 96 + root.borderWidth
            height: buttons.implicitHeight + 28
            x: keys.width - width * Math.min(root.slide, 1)
            anchors.verticalCenter: parent.verticalCenter
            opacity: Math.min(root.slide, 1)
            radius: 20
            topRightRadius: 0
            bottomRightRadius: 0
            color: root.panelColor

            Canvas {
                anchors.fill: parent
                anchors.topMargin: -drawer.join
                anchors.bottomMargin: -drawer.join
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    const edge = width - root.borderWidth
                    const radius = drawer.join

                    function joinCorner() {
                        ctx.beginPath()
                        ctx.moveTo(edge, 0)
                        ctx.arcTo(edge, radius, edge - radius, radius, radius)
                        ctx.lineTo(edge, radius)
                        ctx.closePath()
                        ctx.fill()
                    }

                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = root.panelColor
                    joinCorner()
                    ctx.save()
                    ctx.translate(0, height)
                    ctx.scale(1, -1)
                    joinCorner()
                    ctx.restore()
                }
            }

            MouseArea { anchors.fill: parent }

            Column {
                id: buttons

                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -root.borderWidth / 2
                spacing: 12

                Repeater {
                    model: [
                        { action: "", label: "Lock screen", icon: "\ue899" },
                        { action: "poweroff", label: "Power off", icon: "\uf8c7" },
                        { action: "logout", label: "Log out", icon: "\ue9ba" },
                        { action: "reboot", label: "Restart", icon: "\uf053" }
                    ]

                    delegate: Rectangle {
                        id: button

                        required property var modelData
                        readonly property bool available: modelData.action !== ""

                        width: 68
                        height: width
                        radius: 18
                        color: pointer.containsMouse && available ? Colors.accent : Colors.group
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.label

                        Text {
                            anchors.centerIn: parent
                            text: button.modelData.icon
                            font.family: root.iconFamily
                            font.pixelSize: 32
                            color: !button.available ? Colors.disabledIcon
                                : pointer.containsMouse ? Colors.panel : Colors.text
                        }

                        MouseArea {
                            id: pointer
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: button.available ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.request(button.modelData.action)
                        }

                        Controls.ToolTip.visible: pointer.containsMouse
                        Controls.ToolTip.delay: 450
                        Controls.ToolTip.text: available ? modelData.label : "Lock screen unavailable"
                    }
                }
            }
        }
    }
}
