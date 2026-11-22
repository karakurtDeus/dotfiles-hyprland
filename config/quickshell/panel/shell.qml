import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Effects
import Quickshell.Hyprland
import "theme"

ShellRoot {
	PanelWindow {
		id: leftPanel
		anchors {
			left: true
			top: true
			bottom: true
		}

		implicitWidth: 50
		color: Colors.panel

		Text {
			id: clockLabel
			anchors.bottom: powerButton.top
			anchors.bottomMargin: 7
			anchors.horizontalCenter: parent.horizontalCenter

			text: Qt.formatDateTime(clock.date, "hh\nmm\nAP")
			horizontalAlignment: Text.AlignHCenter
			color: Colors.barText
			font.family: "JetBrainsMono Nerd Font Mono"
			font.pixelSize: 20
		}

		Rectangle {
			id: powerButton
			anchors.bottom: parent.bottom
			anchors.bottomMargin: 8
			anchors.horizontalCenter: parent.horizontalCenter
			width: 32
			height: width
			radius: 10
			color: powerMenu.opened ? WorkspaceSettings.activeBackground
				: powerPointer.containsMouse ? Colors.control : Colors.clear
			Accessible.role: Accessible.Button
			Accessible.name: "Power menu"

			Text {
				id: powerIcon
				anchors.centerIn: parent
				text: "\uf8c7"
				font.family: powerSymbols.name
				font.pixelSize: 22
				color: powerMenu.opened ? WorkspaceSettings.activeDot : WorkspaceSettings.activeBackground
			}

			MouseArea {
				id: powerPointer
				anchors.fill: parent
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: {
					if (!powerMenu.opened) {
						profileMenu.opened = false
						appLauncher.opened = false
						wallpaperPicker.opened = false
						trayMenu.visible = false
					}
					powerMenu.opened = !powerMenu.opened
				}
			}
		}

		TrayMenu { id: trayMenu }

		PanelGroup {
			anchors.bottom: clockLabel.top
			anchors.bottomMargin: 12
			anchors.horizontalCenter: parent.horizontalCenter
			spacing: 5
			visible: trayItems.count > 0

			Repeater {
				id: trayItems
				model: SystemTray.items

				delegate: Rectangle {
					id: trayButton
					required property SystemTrayItem modelData

					width: 32
					height: width
					radius: width / 2
					color: trayMouse.containsMouse || (trayMenu.visible && trayMenu.trayAnchor === trayButton) ? Colors.hover : Colors.clear

					Image {
						anchors.centerIn: parent
						width: 19
						height: 19
						sourceSize.width: 19
						sourceSize.height: 19
						fillMode: Image.PreserveAspectFit
						source: trayButton.modelData.icon
					}

					MouseArea {
						id: trayMouse
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

						onClicked: event => {
							const item = trayButton.modelData
							if (event.button === Qt.MiddleButton)
								item.secondaryActivate()
							else if (event.button === Qt.RightButton || item.onlyMenu)
								trayMenu.openFor(item, trayButton)
							else if (event.button === Qt.LeftButton)
								item.activate()
						}
					}
				}
			}
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
			color: Colors.barText
			font.pixelSize: 14
		}


		Rectangle {
			id: oniButton
			anchors.top: parent.top
			anchors.topMargin: 8
			anchors.horizontalCenter: parent.horizontalCenter
			width: powerButton.width
			height: powerButton.height
			radius: powerButton.radius
			color: profileMenu.opened ? WorkspaceSettings.activeBackground
				: oniPointer.containsMouse ? Colors.control : Colors.clear
			Accessible.role: Accessible.Button
			Accessible.name: "Oni menu"

			Image {
				anchors.centerIn: parent
				width: powerIcon.font.pixelSize
				height: width
				source: Qt.resolvedUrl("assets/oni.svg")
				sourceSize.width: width * 2
				sourceSize.height: height * 2
				fillMode: Image.PreserveAspectFit
				layer.enabled: true
				layer.effect: MultiEffect {
					colorization: 1
					colorizationColor: profileMenu.opened ? WorkspaceSettings.activeDot : WorkspaceSettings.activeBackground
				}
			}

			MouseArea {
				id: oniPointer
				anchors.fill: parent
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: {
					if (!profileMenu.opened) {
						powerMenu.opened = false
						appLauncher.opened = false
						wallpaperPicker.opened = false
						trayMenu.visible = false
					}
					profileMenu.opened = !profileMenu.opened
				}
			}
		}

		UpdateIndicator {
			id: updateIndicator
			buttonSize: powerButton.width
			iconFont: powerIcon.font
			countFont: clockLabel.font
			anchors.top: oniButton.bottom
			anchors.topMargin: 5
			anchors.horizontalCenter: parent.horizontalCenter
		}

		PanelGroup {
			anchors.top: updateIndicator.bottom
			anchors.topMargin: 8
			anchors.horizontalCenter: parent.horizontalCenter
			spacing: 3
			visible: WorkspaceSettings.count > 0
			color: WorkspaceSettings.groupBackground

			Repeater {
				model: Math.max(0, WorkspaceSettings.count)

				delegate: Item {
					id: workspaceButton
					required property int index
					readonly property int workspaceId: index + 1
					readonly property var workspace: Hyprland.workspaces.values.find(ws => ws.id === workspaceId)
					readonly property bool selected: Hyprland.focusedWorkspace?.id === workspaceId
					readonly property bool occupied: (workspace?.toplevels.values.length ?? 0) > 0

					width: 32
					height: Math.max(26, WorkspaceSettings.activeSize, WorkspaceSettings.occupiedSize, WorkspaceSettings.emptySize)

					Rectangle {
						anchors.centerIn: parent
						width: workspaceButton.selected ? WorkspaceSettings.activeSize
							: workspaceButton.occupied ? WorkspaceSettings.occupiedSize : WorkspaceSettings.emptySize
						height: width
						radius: width / 2
						color: workspaceButton.selected ? WorkspaceSettings.activeBackground
							: workspaceButton.occupied ? WorkspaceSettings.occupiedDot : WorkspaceSettings.emptyDot

						Rectangle {
							anchors.centerIn: parent
							visible: workspaceButton.selected
							width: WorkspaceSettings.activeDotSize
							height: width
							radius: width / 2
							color: WorkspaceSettings.activeDot
						}
					}
				}
			}
		}
	}

	component EdgeStrip: PanelWindow {
		implicitWidth: 8
		implicitHeight: 8
		exclusiveZone: 8
		color: Colors.panel
		mask: Region {}
	}

	EdgeStrip {
		id: topBorder
		anchors { top: true; left: true; right: true }
	}

	EdgeStrip {
		id: rightBorder
		anchors { right: true; top: true; bottom: true }
	}

	EdgeStrip {
		anchors { bottom: true; left: true; right: true }
	}

	PanelWindow {
		anchors {
			top: true
			bottom: true
			left: true
			right: true
		}

		exclusionMode: ExclusionMode.Ignore
		color: Colors.clear
		mask: Region {}

		Canvas {
			anchors.fill: parent
			onWidthChanged: requestPaint()
			onHeightChanged: requestPaint()

			onPaint: {
				const ctx = getContext("2d")
				const radius = 10

				ctx.clearRect(0, 0, width, height)
				ctx.fillStyle = Colors.panel

				function drawCorner(x, y, flipX, flipY) {
					ctx.save()
					ctx.translate(x, y)
					ctx.scale(flipX, flipY)
					ctx.beginPath()
					ctx.moveTo(0, 0)
					ctx.lineTo(radius, 0)
					ctx.arcTo(0, 0, 0, radius, radius)
					ctx.closePath()
					ctx.fill()
					ctx.restore()
				}

				drawCorner(50, 8, 1, 1)
				drawCorner(width - 8, 8, -1, 1)
				drawCorner(50, height - 8, 1, -1)
				drawCorner(width - 8, height - 8, -1, -1)
			}
		}
	}

	RightControls {
		borderWidth: rightBorder.implicitWidth
		implicitWidth: leftPanel.implicitWidth + borderWidth
	}

	FontLoader {
		id: powerSymbols
		source: "file:///usr/share/fonts/TTF/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf"
	}

	PowerMenu {
		id: powerMenu
		barWidth: leftPanel.implicitWidth
		borderWidth: rightBorder.implicitWidth
		panelColor: rightBorder.color
		iconFamily: powerSymbols.name

		onActionRequested: action => {
			if (action === "logout")
				Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"])
			else if (action === "poweroff" || action === "reboot")
				Quickshell.execDetached(["systemctl", action])
		}
	}

	AppLauncher {
		id: appLauncher
	}

	IpcHandler {
		target: "launcher"

		function toggle(): void {
			powerMenu.opened = false
			profileMenu.opened = false
			if (appLauncher.opened && !appLauncher.clipboardMode)
				appLauncher.opened = false
			else {
				wallpaperPicker.opened = false
				appLauncher.open(false)
			}
		}
	}

	IpcHandler {
		target: "clipboard"

		function toggle(): void {
			powerMenu.opened = false
			profileMenu.opened = false
			if (appLauncher.opened && appLauncher.clipboardMode)
				appLauncher.opened = false
			else {
				wallpaperPicker.opened = false
				appLauncher.open(true)
			}
		}
	}

	WallpaperPicker { id: wallpaperPicker }

	ProfileMenu {
		id: profileMenu
		screen: leftPanel.screen
		implicitWidth: wallpaperPicker.panelWidth(screen?.width ?? 1340)
		implicitHeight: wallpaperPicker.panelHeight
	}

	IpcHandler {
		target: "wallpaper"

		function toggle(): void {
			powerMenu.opened = false
			profileMenu.opened = false
			appLauncher.opened = false
			wallpaperPicker.toggle()
		}
	}

	NotificationServer {
		id: notificationServer
		bodySupported: true
		actionsSupported: true
		imageSupported: true

		onNotification: notification => notification.tracked = true
	}

	NotificationPopups {
		server: notificationServer
		topBorderWidth: topBorder.implicitHeight
		rightBorderWidth: rightBorder.implicitWidth
		frameColor: rightBorder.color
	}

	SystemClock {
		id: clock
		precision: SystemClock.Minutes
	}
}
