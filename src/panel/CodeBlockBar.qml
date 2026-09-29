pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import "../components"

Item {
    id: root

    required property var modelData
    required property var editor
    readonly property var head: modelData.lines[0]
    readonly property real padHeight: modelData.lines.length > 1 ? modelData.lines[1].y - head.y : head.height
    readonly property real buttonSize: Math.min(padHeight, 24)
    readonly property bool focused: editor.activeFocus && editor.cursorPosition >= head.start && editor.cursorPosition <= modelData.lines[modelData.lines.length - 1].end
    readonly property bool active: hover.hovered || focused
    property bool copied: false

    signal languageRequested(int index, string lang, Item anchor)

    function copy() {
        if (!editor.code.copy(modelData.index))
            return;
        copied = true;
        copiedTimer.restart();
    }

    z: 2
    y: modelData.top
    width: parent ? parent.width : 0
    height: modelData.bottom - modelData.top
    visible: modelData.padded && !editor.sourceMode

    HoverHandler {
        id: hover
    }

    Timer {
        id: copiedTimer
        interval: 1400
        onTriggered: root.copied = false
    }

    Rectangle {
        id: chip
        x: root.editor.leftPadding - Theme.spacingXS
        y: (root.padHeight - height) / 2
        width: chipRow.implicitWidth + Theme.spacingXS * 2
        height: Math.min(root.padHeight, 22)
        radius: Theme.cornerRadius / 2
        color: chipMouse.containsMouse ? Theme.primaryHoverLight : "transparent"
        opacity: root.active || chipMouse.containsMouse ? 1 : 0.55

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 2

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.modelData.label
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "expand_more"
                size: Theme.fontSizeSmall + 2
                color: Theme.surfaceVariantText
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.languageRequested(root.modelData.index, root.modelData.lang, chip)
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: root.editor.rightPadding - Theme.spacingXS
        y: (root.padHeight - height) / 2
        spacing: 2
        opacity: root.active ? 1 : 0

        IconButton {
            buttonSize: root.buttonSize
            iconSize: Theme.fontSizeSmall + 2
            iconName: root.copied ? "check" : "content_copy"
            highlighted: root.copied
            tooltipText: root.copied ? "Copiado" : "Copiar código"
            onClicked: root.copy()
        }

        IconButton {
            buttonSize: root.buttonSize
            iconSize: Theme.fontSizeSmall + 2
            iconName: "delete"
            iconColor: Theme.error
            tooltipText: "Eliminar bloque"
            onClicked: {
                root.editor.code.remove(root.modelData.index);
                root.editor.forceActiveFocus();
            }
        }
    }
}
