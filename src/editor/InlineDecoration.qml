import QtQuick

Item {
    id: root

    required property var modelData
    required property var editor
    property bool chip: false
    property color fill: editor.linkBackground
    readonly property rect first: editor.rectAt(modelData.start)
    readonly property rect last: editor.rectAt(modelData.end)
    readonly property bool wrapped: last.y > first.y + first.height / 2
    readonly property real lineEnd: editor.width - editor.rightPadding
    readonly property real pad: chip ? 1 : 2

    z: -1

    Repeater {
        model: root.wrapped ? [
            {
                x: root.first.x,
                y: root.first.y,
                w: root.lineEnd - root.first.x,
                h: root.first.height
            },
            {
                x: root.editor.leftPadding,
                y: root.last.y,
                w: root.last.x - root.editor.leftPadding,
                h: root.last.height
            }
        ] : [
            {
                x: root.first.x,
                y: root.first.y,
                w: root.last.x - root.first.x,
                h: root.first.height
            }
        ]

        delegate: Item {
            required property var modelData

            x: modelData.x - root.pad
            y: modelData.y
            width: Math.max(0, modelData.w + root.pad * 2)
            height: modelData.h

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: root.chip ? 1 : 0
                anchors.bottomMargin: root.chip ? 1 : 0
                radius: root.chip ? 5 : 3
                color: root.fill
            }

            Rectangle {
                visible: !root.chip
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 2
                anchors.rightMargin: 2
                height: 1
                color: root.editor.accentColor
            }
        }
    }
}
