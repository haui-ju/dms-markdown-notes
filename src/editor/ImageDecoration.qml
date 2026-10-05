import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Widgets

Item {
    id: root

    required property var modelData
    required property var editor

    readonly property bool selected: editor.selectionStart <= modelData.pos && editor.selectionEnd > modelData.pos
    readonly property real pictureH: modelData.imageHeight || modelData.height
    readonly property bool showCaption: !modelData.mini && modelData.caption !== ""
    readonly property real miniRadius: 6

    z: 5
    clip: false
    x: modelData.x
    y: modelData.y
    width: modelData.width
    height: Math.max(modelData.height, pictureH + (showCaption ? captionLabel.implicitHeight + 4 : 0))

    Item {
        id: miniFrame
        visible: root.modelData.mini && !root.modelData.missing
        width: root.modelData.width
        height: root.modelData.imageHeight

        Image {
            id: picture
            anchors.fill: parent
            source: root.modelData.url
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            mipmap: true
            sourceSize.width: parent.width * 2
            visible: false
        }

        Rectangle {
            id: miniMask
            anchors.fill: parent
            radius: root.miniRadius
            color: "white"
            visible: false
            layer.enabled: true
            layer.smooth: true
        }

        OpacityMask {
            anchors.fill: parent
            source: picture
            maskSource: miniMask
        }
    }

    Image {
        id: pictureFull
        anchors.left: parent.left
        anchors.top: parent.top
        width: parent.width
        height: root.pictureH
        visible: !root.modelData.mini && !root.modelData.missing
        source: root.modelData.missing ? "" : root.modelData.url
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        sourceSize.width: root.width * 2
    }

    Rectangle {
        width: root.modelData.mini ? root.modelData.width : parent.width
        height: root.pictureH
        visible: root.modelData.missing || (root.modelData.mini ? picture.status === Image.Error : pictureFull.status === Image.Error)
        radius: root.modelData.mini ? root.miniRadius : 6
        clip: root.modelData.mini
        color: root.editor.codeBackground
        border.width: 1
        border.color: root.editor.tableBorderColor

        Text {
            anchors.fill: parent
            anchors.margins: root.modelData.mini ? 4 : 8
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            elide: Text.ElideMiddle
            maximumLineCount: root.modelData.mini ? 3 : 2
            text: root.modelData.mini ? "?" : "Imagen no encontrada\n" + root.modelData.src
            color: root.editor.color
            opacity: 0.7
            font.pixelSize: root.editor.font.pixelSize * (root.modelData.mini ? 0.7 : 0.85)
        }
    }

    StyledText {
        id: captionLabel
        visible: root.showCaption
        anchors.top: root.modelData.mini ? miniFrame.bottom : pictureFull.bottom
        anchors.topMargin: 4
        width: parent.width
        text: root.modelData.caption
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        maximumLineCount: 3
        font.pixelSize: root.editor.font.pixelSize * 0.85
        font.italic: true
        color: root.editor.color
        opacity: 0.75
    }

    Rectangle {
        anchors.top: parent.top
        width: root.modelData.mini ? root.modelData.width : parent.width
        height: root.pictureH
        radius: root.modelData.mini ? root.miniRadius : 0
        visible: root.selected
        color: root.editor.selectionColor
        opacity: 0.35
    }

    MouseArea {
        objectName: "imageArea"
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        z: 10
        onClicked: root.editor.imageController.openFromModel(root.modelData)
    }
}
