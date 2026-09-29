import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import "../components"

PopupSurface {
    id: root

    property string path: ""

    height: row.implicitHeight + Theme.spacingS * 2

    Row {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        spacing: Theme.spacingS

        DankIcon {
            id: fileIcon
            anchors.verticalCenter: parent.verticalCenter
            name: "description"
            size: Theme.iconSize - 4
            color: Theme.surfaceVariantText
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: row.width - fileIcon.width - copyButton.width - Theme.spacingS * 2
            text: root.path
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            elide: Text.ElideMiddle
        }

        IconButton {
            id: copyButton
            anchors.verticalCenter: parent.verticalCenter
            iconName: "content_copy"
            iconSize: Theme.iconSize - 6
            iconColor: Theme.surfaceTextMedium
            onClicked: {
                Quickshell.execDetached(["wl-copy", root.path]);
                ToastService.showInfo("Ruta copiada al portapapeles");
            }
        }
    }
}
