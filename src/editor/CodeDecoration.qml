pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root

    required property var modelData
    required property var editor
    readonly property bool hasSelection: editor.selectionStart !== editor.selectionEnd

    z: 1
    x: 0
    y: modelData.top
    width: editor.width
    height: modelData.bottom - modelData.top

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: root.editor.codeBackground
    }

    Repeater {
        model: root.modelData.lines

        delegate: Item {
            id: line

            required property var modelData
            readonly property int from: Math.max(modelData.start, root.editor.selectionStart)
            readonly property int to: Math.min(modelData.end, root.editor.selectionEnd)
            readonly property bool selected: root.hasSelection && from <= to && (from < to || root.editor.selectionEnd > modelData.end)

            y: modelData.y - root.modelData.top
            width: root.width
            height: modelData.height

            Rectangle {
                visible: line.selected
                x: line.selected ? root.editor.positionToRectangle(line.from).x : 0
                width: line.selected ? (root.editor.selectionEnd > line.modelData.end ? root.width - root.editor.rightPadding : root.editor.positionToRectangle(line.to).x) - x : 0
                height: parent.height
                color: root.editor.selectionColor
                opacity: 0.35
            }

            Text {
                x: line.modelData.x
                height: parent.height
                verticalAlignment: Text.AlignTop
                text: line.modelData.html
                textFormat: Text.StyledText
                color: root.editor.color
                font.family: root.editor.codeFontFamily
                font.pixelSize: root.editor.font.pixelSize
            }
        }
    }
}
