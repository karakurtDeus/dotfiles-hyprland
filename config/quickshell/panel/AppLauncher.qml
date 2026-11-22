pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "theme"

PanelWindow {
    id: root

    anchors.bottom: true
    implicitWidth: Math.min(480, (screen?.width ?? 512) - 32)
    implicitHeight: Math.min(440, (screen?.height ?? 472) - 32)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-app-launcher"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: Colors.clear
    visible: opened || slide > 0
    mask: Region {
        item: root.opened ? drawer : null
    }

    property bool opened: false
    property bool clipboardMode: false
    property var clipboardEntries: []
    property string clipboardError: ""
    readonly property string emptyMessage: clipboardMode
        ? (clipboardList.running ? "Loading clipboard history…" : "No clipboard entries found")
        : "No applications found"
    readonly property var entries: clipboardMode ? clipboardMatches : applications
    readonly property var clipboardMatches: {
        const query = search.text.trim().toLowerCase()
        return clipboardEntries.filter(entry => entry.name.toLowerCase().includes(query)
            || entry.comment.toLowerCase().includes(query))
    }
    property real slide: opened ? 1 : 0
    readonly property var applications: {
        const query = search.text.trim().toLowerCase()
        const entries = DesktopEntries.applications.values
        return entries.filter(application => {
            if (application.noDisplay)
                return false
            if (!query)
                return true
            const fields = [application.name, application.genericName, application.comment, application.id]
            return fields.some(field => (field ?? "").toLowerCase().includes(query))
        }).sort((a, b) => {
            if (query) {
                const aStarts = a.name.toLowerCase().startsWith(query)
                const bStarts = b.name.toLowerCase().startsWith(query)
                if (aStarts !== bStarts)
                    return aStarts ? -1 : 1
            }
            return a.name.localeCompare(b.name)
        })
    }

    function open(showClipboard: bool): void {
        clipboardMode = showClipboard
        clipboardError = ""
        if (showClipboard) {
            clipboardEntries = []
            clipboardList.running = true
        }
        search.clear()
        opened = true
        selectFirst()
        Qt.callLater(() => search.forceActiveFocus())
    }

    function selectFirst(): void {
        results.currentIndex = entries.length > 0 ? 0 : -1
        results.positionViewAtBeginning()
    }

    function moveSelection(step: int): void {
        if (!entries.length)
            return
        results.currentIndex = Math.max(0, Math.min(entries.length - 1, results.currentIndex + step))
        results.positionViewAtIndex(results.currentIndex, ListView.Contain)
    }

    function launch(index: int): void {
        const entry = entries[index]
        if (!entry)
            return
        if (clipboardMode) {
            if (restore.running)
                return
            clipboardError = ""
            restore.command = ["bash", Quickshell.shellPath("restore-clipboard.sh"), entry.id]
            restore.running = true
        } else {
            opened = false
            entry.execute()
        }
    }

    onEntriesChanged: selectFirst()

    Process {
        id: clipboardList
        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                const entries = []
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t")
                    const id = line.slice(0, tab)
                    if (tab < 1 || !/^\d+$/.test(id))
                        continue
                    const preview = line.slice(tab + 1)
                    const image = preview.match(/^\[\[ binary data (.+) (\w+) (\d+x\d+) \]\]$/)
                    entries.push({
                        id,
                        name: image ? image[2].toUpperCase() + " image" : (preview || "Text"),
                        comment: image ? image[3] + "  ·  " + image[1] : "",
                        icon: image ? "image-x-generic" : "edit-paste",
                        marker: image ? "▧" : "▤"
                    })
                }
                root.clipboardEntries = entries
            }
        }
    }

    Process {
        id: restore
        onExited: exitCode => {
            if (!root.clipboardMode)
                return
            if (exitCode === 0)
                root.opened = false
            else
                root.clipboardError = "Could not restore this clipboard entry"
        }
    }

    Behavior on slide {
        NumberAnimation {
            duration: 500
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1]
        }
    }

    Rectangle {
        id: drawer

        readonly property real progress: Math.min(root.slide, 1)
        width: parent.width
        height: parent.height
        y: height * (1 - progress)
        opacity: progress
        color: Colors.panel
        radius: 20
        bottomLeftRadius: 0
        bottomRightRadius: 0

        ListView {
            id: results

            anchors.fill: parent
            anchors.topMargin: 12
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.bottomMargin: 59
            model: root.entries
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row

                required property int index
                required property var modelData

                width: results.width
                height: 45
                radius: 12
                color: ListView.isCurrentItem ? Colors.control : Colors.clear

                Image {
                    id: applicationIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    sourceSize.width: 24
                    sourceSize.height: 24
                    fillMode: Image.PreserveAspectFit
                    source: Quickshell.iconPath(row.modelData.icon || "application-x-executable", true)
                }

                Text {
                    anchors.centerIn: applicationIcon
                    visible: applicationIcon.status !== Image.Ready
                    text: root.clipboardMode ? row.modelData.marker : row.modelData.name.charAt(0).toUpperCase()
                    color: Colors.accent
                    font.pixelSize: 15
                    font.bold: true
                }

                Column {
                    anchors.left: applicationIcon.right
                    anchors.leftMargin: 11
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        width: parent.width
                        text: row.modelData.name
                        textFormat: Text.PlainText
                        color: Colors.text
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: text.length > 0
                        text: root.clipboardMode ? row.modelData.comment : (row.modelData.comment || row.modelData.genericName || "")
                        textFormat: Text.PlainText
                        color: Colors.mutedText
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered)
                            results.currentIndex = row.index
                    }
                }

                TapHandler {
                    onTapped: root.launch(row.index)
                }
            }
        }

        Text {
            anchors.centerIn: results
            visible: results.count === 0
            text: root.emptyMessage
            color: Colors.mutedText
            font.pixelSize: 14
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: searchBar.top
            anchors.bottomMargin: 5
            visible: root.clipboardMode && root.clipboardError.length > 0
            text: root.clipboardError
            color: Colors.error
            font.pixelSize: 12
        }

        Rectangle {
            id: searchBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 12
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
                anchors.right: clearButton.left
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                activeFocusOnTab: true
                clip: true
                font.pixelSize: 14
                color: Colors.text
                selectionColor: Colors.selection
                selectByMouse: true

                Keys.onUpPressed: root.moveSelection(-1)
                Keys.onDownPressed: root.moveSelection(1)
                Keys.onReturnPressed: root.launch(results.currentIndex)
                Keys.onEnterPressed: root.launch(results.currentIndex)
                Keys.onEscapePressed: root.opened = false

                Text {
                    anchors.fill: parent
                    visible: search.text.length === 0
                    text: root.clipboardMode ? "Search clipboard" : "Search apps"
                    color: Colors.mutedText
                    font.pixelSize: search.font.pixelSize
                }
            }

            Text {
                id: clearButton

                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "×"
                color: Colors.text
                font.pixelSize: 19

                TapHandler {
                    onTapped: {
                        if (search.text.length)
                            search.clear()
                        else
                            root.opened = false
                    }
                }
            }
        }
    }
}
