pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "theme"

PopupWindow {
    id: root

    property SystemTrayItem trayItem
    property Item trayAnchor
    property list<QsMenuHandle> levels: []
    property int menuHeight: 38

    anchor.item: trayAnchor
    anchor.edges: Edges.Right | Edges.Bottom
    anchor.gravity: Edges.Right | Edges.Top
    anchor.margins.left: 8
    implicitWidth: 240
    implicitHeight: menuHeight + 12
    color: Colors.clear
    grabFocus: true
    visible: false

    function openFor(item: SystemTrayItem, button: Item): void {
        trayItem = item
        trayAnchor = button
        menuHeight = 38
        levels = item.hasMenu && item.menu ? [item.menu] : []
        visible = true
        surface.forceActiveFocus()
    }

    function goBack(): void {
        if (levels.length > 1)
            levels = Array.from(levels).slice(0, -1)
        else
            visible = false
    }

    onVisibleChanged: {
        if (!visible) {
            levels = []
            trayItem = null
        }
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        color: Colors.panel
        radius: 13
        focus: true

        Keys.onEscapePressed: root.visible = false
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Backspace) {
                root.goBack()
                event.accepted = true
            }
        }

        Repeater {
            model: root.levels.length

            delegate: Item {
                id: page
                required property int index
                readonly property bool current: index === root.levels.length - 1
                readonly property int preferredHeight: Math.max(34, back.height + Math.min(360, Math.ceil(rows.contentHeight)))

                anchors.fill: parent
                anchors.margins: 6
                visible: current

                onCurrentChanged: {
                    if (current)
                        root.menuHeight = preferredHeight
                }
                onPreferredHeightChanged: {
                    if (current)
                        root.menuHeight = preferredHeight
                }
                Component.onCompleted: {
                    if (current)
                        root.menuHeight = preferredHeight
                }

                QsMenuOpener {
                    id: opener
                    menu: root.levels[page.index] ?? null
                }

                Rectangle {
                    id: back
                    width: parent.width
                    height: page.index > 0 ? 32 : 0
                    visible: height > 0
                    radius: 8
                    color: backPointer.containsMouse ? Colors.control : Colors.clear

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "‹  Back"
                        color: Colors.text
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: backPointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.goBack()
                    }
                }

                ListView {
                    id: rows
                    anchors.top: back.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    model: opener.children
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: row
                        required property QsMenuEntry modelData
                        width: rows.width
                        height: modelData.isSeparator ? 9 : 31
                        radius: 8
                        color: pointer.containsMouse && pointer.enabled ? Colors.control : Colors.clear

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 9
                            anchors.rightMargin: 9
                            height: 1
                            color: Colors.hover
                            visible: row.modelData.isSeparator
                        }

                        Item {
                            anchors.fill: parent
                            visible: !row.modelData.isSeparator
                            opacity: row.modelData.enabled ? 1 : 0.45

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 9
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                horizontalAlignment: Text.AlignHCenter
                                color: Colors.accent
                                text: {
                                    if (row.modelData.buttonType === QsMenuButtonType.RadioButton)
                                        return row.modelData.checkState === Qt.Checked ? "●" : "○"
                                    if (row.modelData.buttonType === QsMenuButtonType.CheckBox)
                                        return row.modelData.checkState === Qt.Checked ? "✓" : "□"
                                    return ""
                                }
                            }

                            Image {
                                anchors.left: parent.left
                                anchors.leftMargin: 9
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                height: 16
                                sourceSize.width: 16
                                sourceSize.height: 16
                                fillMode: Image.PreserveAspectFit
                                source: row.modelData.buttonType === QsMenuButtonType.None ? row.modelData.icon : ""
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: arrow.left
                                anchors.leftMargin: 33
                                anchors.rightMargin: 5
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.text
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: Colors.text
                                font.pixelSize: 13
                            }

                            Text {
                                id: arrow
                                anchors.right: parent.right
                                anchors.rightMargin: 9
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.hasChildren ? "›" : ""
                                color: Colors.mutedText
                                font.pixelSize: 16
                            }
                        }

                        MouseArea {
                            id: pointer
                            anchors.fill: parent
                            enabled: !row.modelData.isSeparator && row.modelData.enabled
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (row.modelData.hasChildren) {
                                    root.levels = Array.from(root.levels).concat([row.modelData])
                                } else {
                                    row.modelData.triggered()
                                    root.visible = false
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: rows
                    visible: rows.count === 0
                    text: "No actions available"
                    color: Colors.mutedText
                    font.pixelSize: 13
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 6
            visible: root.levels.length === 0
            color: openPointer.containsMouse ? Colors.control : Colors.clear
            radius: 8

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "Open"
                color: Colors.text
                font.pixelSize: 13
            }

            MouseArea {
                id: openPointer
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.trayItem?.activate()
                    root.visible = false
                }
            }
        }
    }
}
