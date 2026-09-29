import QtQuick

Item {
    id: root

    required property var modelData
    required property var editor
    readonly property rect first: editor.positionToRectangle(modelData.start)
    readonly property rect last: editor.positionToRectangle(modelData.end)
    readonly property real pad: 4

    z: -1
    x: Math.max(editor.leftPadding, first.x - 16)
    y: first.y - pad
    width: editor.width - editor.rightPadding - x
    height: last.y + last.height - first.y + 2 * pad

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: root.editor.quoteBackground
    }

    Rectangle {
        width: 3
        height: parent.height
        radius: 1.5
        color: root.editor.accentColor
    }
}
