import QtQuick
import QtQuick.Templates
import "theme"

Slider {
    id: control
    required property string icon
    required property string iconFamily

    width: 24
    height: 116
    padding: 0
    orientation: Qt.Vertical
    from: 0
    to: 1

    background: Rectangle {
        radius: width / 2
        color: Colors.control

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height - control.handle.y
            radius: width / 2
            color: Colors.accent
            visible: control.value > 0
        }
    }

    handle: Rectangle {
        width: control.width
        height: width
        y: control.visualPosition * (control.availableHeight - height)
        radius: width / 2
        color: control.enabled ? Colors.text : Colors.mutedText

        Text {
            anchors.centerIn: parent
            font.family: control.iconFamily
            font.pixelSize: 15
            color: Colors.panel
            text: control.pressed ? Math.round(control.value * 100) : control.icon
        }
    }
}
