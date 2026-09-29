import QtQuick
import qs.Common
import qs.Widgets

Row {
    id: root

    property string icon: ""
    property string label: ""
    property color iconColor: Theme.surfaceText

    signal clicked

    spacing: Theme.spacingS

    IconButton {
        iconName: root.icon
        iconSize: Theme.iconSize - 2
        iconColor: root.iconColor
        onClicked: root.clicked()
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceTextMedium
    }
}
