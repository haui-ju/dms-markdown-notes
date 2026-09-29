import QtQuick

Item {
    id: root

    required property var modelData
    required property var editor
    readonly property rect area: editor.rectAt(modelData.start)
    readonly property rect endArea: editor.rectAt(modelData.end)
    readonly property real box: Math.round(editor.font.pixelSize * 1.05)
    readonly property color ink: editor.color

    Rectangle {
        x: root.area.x - 24
        y: root.area.y
        width: 23
        height: root.area.height
        color: root.editor.decorationBackground
    }

    Rectangle {
        x: root.area.x - root.box - 7
        y: root.area.y + (root.area.height - root.box) / 2
        width: root.box
        height: root.box
        radius: Math.round(root.box * 0.28)
        color: root.modelData.checked ? root.editor.accentColor : "transparent"
        border.width: root.modelData.checked ? 0 : 1.5
        border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)

        Text {
            anchors.centerIn: parent
            visible: root.modelData.checked
            text: "\u2713"
            color: root.editor.checkMarkColor
            font.pixelSize: Math.round(root.box * 0.8)
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: root.editor.toggleTaskAt(root.modelData.start)
        }
    }

    Rectangle {
        readonly property color base: root.editor.decorationBackground
        visible: root.modelData.checked
        x: root.area.x
        y: root.area.y
        width: root.editor.width - root.area.x
        height: root.endArea.y + root.endArea.height - root.area.y
        color: Qt.rgba(base.r, base.g, base.b, 0.5)
    }
}
