import Quickshell
import QtQuick
import Quickshell.Hyprland

ShellRoot {
	PanelWindow {
		anchors {
			left: true
			top: true
			bottom: true
		}

		implicitWidth: 50
		color: "#2e3440"

		Text {
			//anchors.top: parent.top
    			//anchors.topMargin: 0
    			//anchors.horizontalCenter: parent.horizontalCenter
			anchors.bottom: parent.bottom
			anchors.bottomMargin: 10
			anchors.horizontalCenter: parent.horizontalCenter

    		text: Qt.formatDateTime(clock.date, "HH\nmm")
    		horizontalAlignment: Text.AlignHCenter
			color: "white"
    		font.pixelSize: 20	
		}

		Text {
			anchors.centerIn: parent

			width: Math.min(240, parent.height / 3)
			rotation: -90
			text: {
				const workspace = Hyprland.focusedWorkspace
				const window = Hyprland.activeToplevel

				if (!workspace || window?.workspace?.id !== workspace.id)
					return "Desktop"

				const appClass = window.lastIpcObject?.class
				if (!appClass)
					return window.title || "Desktop"

				return DesktopEntries.heuristicLookup(appClass)?.name || appClass
			}
			horizontalAlignment: Text.AlignHCenter
			elide: Text.ElideRight
			color: "white"
			font.pixelSize: 14
		}


		Column {
			anchors.top: parent.top
			anchors.topMargin: 10
			anchors.horizontalCenter: parent.horizontalCenter
			spacing: 6

			Repeater {
				model: [1, 2, 3, 4, 5, 6]

				delegate: Text {
					required property int modelData

					text: modelData
					color: Hyprland.focusedWorkspace?.id === modelData ? "#88c0d0" : "white"
					font.pixelSize: 18
				}
			}
		}
	}

	SystemClock {
		id: clock
		precision: SystemClock.Minutes
	}
}
