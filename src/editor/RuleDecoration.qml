import QtQuick

Rectangle {
    id: root

    required property int modelData
    required property var editor
    readonly property rect area: editor.rectAt(modelData)

    y: area.y
    width: editor.width
    height: area.height
    color: editor.decorationBackground

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 1
        color: root.editor.ruleColor
    }
}
