pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import "theme"

PanelWindow {
    id: root
    required property NotificationServer server
    required property int topBorderWidth
    required property int rightBorderWidth
    required property color frameColor

    readonly property int joinRadius: 14
    readonly property int cardPadding: 12

    anchors { top: true; right: true }
    implicitWidth: Math.min(440, (screen?.width ?? 468) - 28) + joinRadius
    implicitHeight: topBorderWidth + cardPadding * 2 + stack.height + joinRadius
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    visible: cards.count > 0
    color: Colors.clear
    mask: Region { item: stack }

    Item {
        anchors.fill: parent

        Canvas {
            id: frame
            anchors.fill: parent

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            Connections {
                target: root

                function onFrameColorChanged() { frame.requestPaint() }
                function onTopBorderWidthChanged() { frame.requestPaint() }
                function onRightBorderWidthChanged() { frame.requestPaint() }
            }

            onPaint: {
                const ctx = getContext("2d")
                const join = root.joinRadius
                const bottom = height - join
                const right = width - root.rightBorderWidth
                const top = root.topBorderWidth

                ctx.clearRect(0, 0, width, height)
                ctx.fillStyle = root.frameColor
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(width, 0)
                ctx.lineTo(width, height)
                ctx.lineTo(right, height)
                ctx.arcTo(right, bottom, right - join, bottom, join)
                ctx.arcTo(join, bottom, join, top, 20)
                ctx.arcTo(join, top, 0, top, join)
                ctx.closePath()
                ctx.fill()
            }
        }

        Column {
            id: stack
            anchors.top: parent.top
            anchors.topMargin: root.topBorderWidth + root.cardPadding
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.joinRadius + root.cardPadding
            anchors.rightMargin: root.rightBorderWidth + root.cardPadding
            spacing: 7

            Repeater {
                id: cards
                model: root.server.trackedNotifications

                delegate: Rectangle {
                    id: card
                    required property Notification modelData

                    property bool expanded: false
                    readonly property string iconSource: {
                        const image = modelData.image
                        const iconPrefix = "image://icon/"
                        const imageUrl = image.startsWith(iconPrefix)
                            ? Quickshell.iconPath(image.slice(iconPrefix.length), true)
                            : image
                        return imageUrl || Quickshell.iconPath(modelData.appIcon
                            || DesktopEntries.byId(modelData.desktopEntry)?.icon || "", true)
                    }
                    width: stack.width
                    height: content.height + 20
                    radius: 13
                    color: Colors.group

                    HoverHandler { id: hover }

                    Timer {
                        id: expiration
                        readonly property int requestedTimeout: card.modelData.expireTimeout
                        interval: requestedTimeout > 0 ? requestedTimeout : 6000
                        running: requestedTimeout !== 0 && !hover.hovered && !card.expanded
                        onTriggered: card.modelData.expire()
                    }

                    Column {
                        id: content
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        spacing: 8

                        Item {
                            width: parent.width
                            height: Math.max(40, details.height)

                            Rectangle {
                                id: icon
                                width: 38
                                height: width
                                radius: width / 2
                                color: Colors.hover
                                anchors.left: parent.left
                                anchors.top: parent.top

                                Image {
                                    id: appIcon
                                    anchors.centerIn: parent
                                    width: 24
                                    height: 24
                                    sourceSize.width: 24
                                    sourceSize.height: 24
                                    fillMode: Image.PreserveAspectFit
                                    source: card.iconSource
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: appIcon.status !== Image.Ready
                                    text: "ℹ"
                                    color: Colors.text
                                    font.pixelSize: 21
                                    font.bold: true
                                }
                            }

                            Column {
                                id: details
                                anchors.left: icon.right
                                anchors.leftMargin: 10
                                anchors.right: chevron.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Text {
                                    width: parent.width
                                    text: card.modelData.summary || card.modelData.appName || "Notification"
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: Colors.text
                                    font.pixelSize: 14
                                }

                                Text {
                                    width: parent.width
                                    visible: text.length > 0
                                    text: card.modelData.body
                                    textFormat: Text.PlainText
                                    wrapMode: card.expanded ? Text.Wrap : Text.NoWrap
                                    maximumLineCount: card.expanded ? 8 : 1
                                    elide: Text.ElideRight
                                    color: Colors.mutedText
                                    font.pixelSize: 13
                                }
                            }

                            Text {
                                id: chevron
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.topMargin: 2
                                width: 18
                                horizontalAlignment: Text.AlignHCenter
                                text: card.expanded ? "▴" : "▾"
                                color: Colors.text
                                font.pixelSize: 14
                            }

                            TapHandler { onTapped: card.expanded = !card.expanded }
                            TapHandler {
                                acceptedButtons: Qt.MiddleButton
                                onTapped: card.modelData.dismiss()
                            }
                        }

                        Flow {
                            width: parent.width
                            visible: card.expanded
                            spacing: 6

                            Repeater {
                                model: card.expanded ? card.modelData.actions : []

                                delegate: Rectangle {
                                    id: actionButton
                                    required property NotificationAction modelData
                                    width: Math.min(actionLabel.implicitWidth + 18, content.width)
                                    height: 27
                                    radius: 10
                                    color: Colors.hover

                                    Text {
                                        id: actionLabel
                                        anchors.centerIn: parent
                                        width: Math.min(implicitWidth, parent.width - 18)
                                        text: actionButton.modelData.text
                                        elide: Text.ElideRight
                                        color: Colors.text
                                        font.pixelSize: 12
                                    }

                                    TapHandler { onTapped: actionButton.modelData.invoke() }
                                }
                            }

                            Rectangle {
                                width: dismissLabel.implicitWidth + 18
                                height: 27
                                radius: 10
                                color: Colors.hover

                                Text {
                                    id: dismissLabel
                                    anchors.centerIn: parent
                                    text: "Dismiss"
                                    color: Colors.text
                                    font.pixelSize: 12
                                }

                                TapHandler { onTapped: card.modelData.dismiss() }
                            }
                        }
                    }
                }
            }
        }
    }
}
