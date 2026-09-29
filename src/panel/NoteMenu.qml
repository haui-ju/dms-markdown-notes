pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import "../components"

PopupSurface {
    id: root

    property bool sourceMode: false
    property bool confirmDelete: false

    signal triggered(string action)

    width: 240
    height: column.implicitHeight + Theme.spacingS * 2

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Theme.spacingXS

        Repeater {
            model: [
                {
                    icon: "search",
                    label: "Buscar en las notas",
                    action: "search"
                },
                {
                    icon: root.sourceMode ? "visibility" : "code",
                    label: root.sourceMode ? "Ver formateado" : "Ver Markdown",
                    action: "source"
                },
                {
                    icon: "drive_file_rename_outline",
                    label: "Renombrar nota",
                    action: "rename"
                },
                {
                    icon: "folder",
                    label: "Abrir carpeta de notas",
                    action: "folder"
                },
                {
                    icon: "delete",
                    label: root.confirmDelete ? "¿Seguro? Clic para borrar" : "Mover a la papelera",
                    action: "delete",
                    danger: true
                }
            ]

            delegate: MenuRow {
                required property var modelData
                width: column.width
                icon: modelData.icon
                label: modelData.label
                danger: modelData.danger === true
                onTriggered: root.triggered(modelData.action)
            }
        }
    }
}
