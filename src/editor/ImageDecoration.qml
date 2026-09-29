import QtQuick

Item {
    id: root

    required property var modelData
    required property var editor
    readonly property bool selected: editor.selectionStart <= modelData.pos && editor.selectionEnd > modelData.pos

    z: 1
    x: modelData.x
    y: modelData.y
    width: modelData.width
    height: modelData.height

    Image {
        id: picture
        anchors.fill: parent
        visible: !root.modelData.missing
        source: root.modelData.missing ? "" : root.modelData.url
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        sourceSize.width: root.width * 2
    }

    Rectangle {
        anchors.fill: parent
        visible: root.modelData.missing || picture.status === Image.Error
        radius: 6
        color: root.editor.codeBackground
        border.width: 1
        border.color: root.editor.tableBorderColor

        Text {
            anchors.fill: parent
            anchors.margins: 8
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            elide: Text.ElideMiddle
            maximumLineCount: 2
            text: "Imagen no encontrada\n" + root.modelData.src
            color: root.editor.color
            opacity: 0.7
            font.pixelSize: root.editor.font.pixelSize * 0.85
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.selected
        color: root.editor.selectionColor
        opacity: 0.35
    }

    MouseArea {
        objectName: "imageArea"
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.editor.imageActivated(root.modelData.pos, root.modelData.url, root.modelData.src, root.modelData.alt)
    }
}
