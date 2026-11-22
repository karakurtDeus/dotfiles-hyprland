import QtQuick
import "theme"

Rectangle {
    default property alias entries: layout.data
    property alias spacing: layout.spacing

    width: 40
    height: layout.implicitHeight + 8
    radius: 12
    color: Colors.group

    Column {
        id: layout
        anchors.centerIn: parent
    }
}
