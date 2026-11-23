pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "theme"

Scope {
    id: root

    readonly property string folder: Quickshell.env("HOME") + "/.config/hypr/wallpaper"
    readonly property int preferredPanelWidth: 800
    readonly property int panelHeight: 272
    property string savedName: ""
    property bool opened: false
    property var wallpapers: []

    readonly property var currentWallpaper: wallpapers.find(entry => entry.filename === savedName)
        ?? wallpapers.find(entry => entry.isDefault) ?? wallpapers[0]
    readonly property var matches: {
        const term = search.text.trim().toLocaleLowerCase()
        return wallpapers.filter(entry => entry.name.toLocaleLowerCase().includes(term))
    }
    readonly property var previewWallpaper: opened ? matches[carousel.currentIndex] : null
    readonly property url backgroundSource: (previewWallpaper ?? currentWallpaper)?.url ?? ""

    function panelWidth(screenWidth: int): int {
        return Math.min(preferredPanelWidth, screenWidth - 60)
    }

    function refreshFiles(): void {
        const entries = []
        for (let i = 0; i < files.count; i++) {
            const filename = files.get(i, "fileName")
            const basename = files.get(i, "fileBaseName") ?? ""
            const modified = new Date(files.get(i, "fileModified")).getTime()
            const url = files.get(i, "fileUrl").toString()
            entries.push({
                filename,
                url: Number.isFinite(modified) ? url + "?modified=" + modified : url,
                name: basename.replace(/_main$/i, ""),
                isDefault: /_main$/i.test(basename)
            })
        }

        if (JSON.stringify(entries) === JSON.stringify(wallpapers))
            return

        const previewName = previewWallpaper?.filename ?? ""
        wallpapers = entries

        if (opened) {
            Qt.callLater(() => {
                if (root.opened)
                    root.centerWallpaper(previewName)
            })
        }
    }

    function centerWallpaper(filename: string): void {
        let index = matches.findIndex(entry => entry.filename === filename)
        if (index < 0)
            index = matches.findIndex(entry => entry.filename === currentWallpaper?.filename)
        carousel.currentIndex = index >= 0 ? index : (matches.length ? 0 : -1)
        carousel.forceLayout()
        if (carousel.currentIndex >= 0)
            carousel.positionViewAtIndex(carousel.currentIndex, ListView.Center)
    }

    function centerCurrent(): void {
        centerWallpaper(currentWallpaper?.filename ?? "")
    }

    Component.onCompleted: Qt.callLater(refreshFiles)

    function toggle(): void {
        if (opened) {
            opened = false
            return
        }
        search.clear()
        centerCurrent()
        opened = true
        Qt.callLater(() => {
            if (root.opened) {
                root.centerCurrent()
                search.forceActiveFocus()
            }
        })
    }

    function apply(index: int): void {
        const entry = matches[index]
        if (!entry)
            return
        savedName = entry.filename
        state.setText(JSON.stringify(savedName) + "\n")
        opened = false
    }

    function moveSelection(step: int): void {
        if (matches.length)
            carousel.currentIndex = Math.max(0, Math.min(matches.length - 1, carousel.currentIndex + step))
    }

    FolderListModel {
        id: files
        folder: "file://" + root.folder
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.gif", "*.tif", "*.tiff", "*.avif"]
        caseSensitive: false
        showDirs: false
        showOnlyReadable: true
    }

    Connections {
        target: files

        function onStatusChanged() { Qt.callLater(root.refreshFiles) }
        function onRowsInserted() { Qt.callLater(root.refreshFiles) }
        function onRowsRemoved() { Qt.callLater(root.refreshFiles) }
        function onRowsMoved() { Qt.callLater(root.refreshFiles) }
        function onModelReset() { Qt.callLater(root.refreshFiles) }
        function onLayoutChanged() { Qt.callLater(root.refreshFiles) }
        function onDataChanged() { Qt.callLater(root.refreshFiles) }
    }

    FileView {
        id: state
        path: root.folder + "/.selected.json"
        printErrors: false
        atomicWrites: true
        blockWrites: true
        onLoaded: {
            try {
                const filename = JSON.parse(text())
                if (typeof filename === "string")
                    root.savedName = filename
            } catch (error) {
                console.warn("Could not read wallpaper selection:", error)
            }
        }
        onSaveFailed: error => console.warn("Could not save wallpaper selection:", error)
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: background
            required property ShellScreen modelData

            screen: modelData
            anchors { top: true; left: true; right: true; bottom: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell-wallpaper"
            color: Colors.wallpaperFallback
            mask: Region {}

            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: root.backgroundSource
                sourceSize.width: background.width
                sourceSize.height: background.height
                asynchronous: true
                retainWhileLoading: true
                cache: false
            }
        }
    }

    PanelWindow {
        id: picker

        anchors.bottom: true
        implicitWidth: root.panelWidth(screen?.width ?? 1340)
        implicitHeight: root.panelHeight
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-wallpaper-picker"
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: Colors.clear
        visible: root.opened || slide > 0
        mask: Region { item: root.opened ? drawer : null }

        property real slide: root.opened ? 1 : 0
        Behavior on slide {
            NumberAnimation {
                duration: 500
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1]
            }
        }

        Rectangle {
            id: drawer
            readonly property real progress: Math.min(picker.slide, 1)
            width: parent.width
            height: parent.height
            y: height * (1 - progress)
            opacity: progress
            color: Colors.panel
            radius: 20
            bottomLeftRadius: 0
            bottomRightRadius: 0

            ListView {
                id: carousel

                readonly property int tileWidth: Math.min(248, Math.max(48, width - 24))
                readonly property int centerOffset: (width - tileWidth) / 2
                anchors.fill: parent
                anchors.topMargin: 16
                anchors.bottomMargin: 62
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                orientation: ListView.Horizontal
                boundsBehavior: Flickable.StopAtBounds
                snapMode: ListView.SnapToItem
                preferredHighlightBegin: centerOffset
                preferredHighlightEnd: centerOffset + tileWidth
                highlightRangeMode: ListView.StrictlyEnforceRange
                highlightMoveDuration: 350
                leftMargin: centerOffset
                rightMargin: centerOffset
                model: root.matches
                spacing: 10
                clip: true

                delegate: Item {
                    id: tile
                    required property int index
                    required property var modelData
                    readonly property bool selected: ListView.isCurrentItem
                    width: carousel.tileWidth
                    height: carousel.height

                    Column {
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: 8
                        scale: tile.selected ? 1 : 0.88
                        opacity: tile.selected ? 1 : 0.76

                        Behavior on scale {
                            NumberAnimation { duration: 290; easing.type: Easing.OutCubic }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 180 }
                        }

                        ClippingRectangle {
                            width: parent.width
                            height: width * 9 / 16
                            radius: 12
                            color: Colors.control

                            Image {
                                anchors.fill: parent
                                source: tile.modelData.url
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: Math.ceil(width * 1.25)
                                sourceSize.height: Math.ceil(height * 1.25)
                                asynchronous: true
                            }
                        }

                        Text {
                            width: parent.width
                            text: tile.modelData.name
                            color: tile.selected ? Colors.text : Colors.mutedText
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font.pixelSize: 14
                        }
                    }

                    TapHandler { onTapped: root.apply(tile.index) }
                }

                WheelHandler {
                    onWheel: event => {
                        const delta = event.angleDelta.x || event.angleDelta.y
                        if (delta !== 0) {
                            root.moveSelection(delta > 0 ? -1 : 1)
                            event.accepted = true
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: carousel
                visible: carousel.count === 0
                text: search.text.length ? "No matching wallpapers" : "No wallpapers found"
                color: Colors.mutedText
                font.pixelSize: 14
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 14
                height: 36
                radius: 18
                color: Colors.control

                Text {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⌕"
                    color: Colors.text
                    font.pixelSize: 23
                }

                TextInput {
                    id: search
                    anchors.left: searchIcon.right
                    anchors.right: closeButton.left
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    selectByMouse: true
                    color: Colors.text
                    selectionColor: Colors.selection
                    font.pixelSize: 14

                    onTextEdited: Qt.callLater(root.centerCurrent)
                    Keys.onReturnPressed: root.apply(carousel.currentIndex)
                    Keys.onEnterPressed: root.apply(carousel.currentIndex)
                    Keys.onEscapePressed: root.opened = false
                    Keys.onLeftPressed: event => {
                        if (!text.length)
                            root.moveSelection(-1)
                        else
                            event.accepted = false
                    }
                    Keys.onRightPressed: event => {
                        if (!text.length)
                            root.moveSelection(1)
                        else
                            event.accepted = false
                    }

                    Text {
                        anchors.fill: parent
                        visible: search.text.length === 0
                        text: "Search wallpapers"
                        color: Colors.mutedText
                        font.pixelSize: search.font.pixelSize
                    }
                }

                Text {
                    id: closeButton
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"
                    color: Colors.text
                    font.pixelSize: 19
                    TapHandler { onTapped: root.opened = false }
                }
            }
        }
    }
}
