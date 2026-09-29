import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property string title: ""
    property string icon: ""
    property bool draggable: false
    property real leftPadding: 0
    property real rightPadding: 0
    default property alias actions: actionRow.data

    signal dragStarted
    signal doubleClicked

    MouseArea {
        anchors.fill: parent
        enabled: root.draggable
        onPressed: root.dragStarted()
        onDoubleClicked: root.doubleClicked()
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: root.leftPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingS

        DankIcon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: Theme.iconSize - 2
            color: Theme.primary
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
            color: Theme.surfaceText
        }
    }

    Row {
        id: actionRow
        anchors.right: parent.right
        anchors.rightMargin: root.rightPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS
    }
}
