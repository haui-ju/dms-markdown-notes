import QtQuick

Rectangle {
    id: root

    property string iconName
    property int iconSize: 20
    property color iconColor
    property int buttonSize: 32
    property var tooltipText

    signal clicked

    width: buttonSize
    height: buttonSize
    color: "transparent"

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
