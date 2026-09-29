pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import qs.Widgets
import "../components"

Column {
    id: root

    property bool inPopout: false
    property bool dirty: false
    property bool menuOpen: false
    property bool infoOpen: false
    property string markdown: ""

    signal saveRequested
    signal openRequested
    signal newRequested
    signal popoutRequested
    signal dockRequested
    signal menuToggled
    signal infoToggled

    spacing: Theme.spacingXS

    Item {
        width: parent.width
        height: 32

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingL

            IconLabelButton {
                icon: "save"
                label: "Guardar"
                iconColor: Theme.primary
                onClicked: root.saveRequested()
            }

            IconLabelButton {
                icon: "folder_open"
                label: "Abrir"
                iconColor: Theme.secondary
                onClicked: root.openRequested()
            }

            IconLabelButton {
                icon: "note_add"
                label: "Nuevo"
                onClicked: root.newRequested()
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            IconButton {
                iconName: root.inPopout ? "dock_to_right" : "open_in_new"
                iconSize: Theme.iconSize - 2
                tooltipText: root.inPopout ? "Volver al panel lateral" : "Ventana flotante"
                onClicked: root.inPopout ? root.dockRequested() : root.popoutRequested()
            }

            IconButton {
                iconName: "more_horiz"
                iconSize: Theme.iconSize - 2
                highlighted: root.menuOpen
                onClicked: root.menuToggled()
            }
        }
    }

    Row {
        width: parent.width
        spacing: Theme.spacingL

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                const len = root.markdown.length;
                if (len === 0)
                    return "Vacío";
                return len === 1 ? "1 carácter" : len + " caracteres";
            }
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.markdown.length > 0
            text: "Líneas: " + root.markdown.replace(/\n+$/, "").split("\n").length
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
        }

        Row {
            spacing: Theme.spacingXS

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.dirty ? "Guardando..." : "Guardado"
                font.pixelSize: Theme.fontSizeSmall
                color: root.dirty ? Theme.primary : Theme.success
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                iconName: "info"
                iconSize: Theme.iconSizeSmall
                iconColor: root.infoOpen ? Theme.primary : Theme.surfaceTextMedium
                buttonSize: 20
                onClicked: root.infoToggled()
            }
        }
    }
}
