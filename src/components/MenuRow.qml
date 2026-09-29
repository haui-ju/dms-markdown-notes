import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property bool danger: false
    property bool highlighted: false
    readonly property bool hovered: mouse.containsMouse
    readonly property color tint: danger ? Theme.error : Theme.surfaceText

    signal triggered

    height: 34
    radius: Theme.cornerRadius
    color: highlighted || hovered ? Theme.primaryHoverLight : "transparent"

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingM

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: Theme.iconSize - 6
            color: root.tint
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.pixelSize: Theme.fontSizeSmall
            color: root.tint
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
