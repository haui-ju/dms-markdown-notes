pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import "../components"

PopupSurface {
    id: root

    property bool sourceMode: false
    property bool verticalTabs: false
    property bool confirmDelete: false
    property int escapedCode: 0

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
                    icon: "healing",
                    label: "Reparar barras en código (" + root.escapedCode + ")",
                    action: "repair",
                    hidden: root.escapedCode === 0
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
                    icon: "view_agenda",
                    label: root.verticalTabs ? "Pestañas horizontales" : "Pestañas verticales",
                    action: "toggleLayout"
                },
                {
                    icon: "delete",
                    label: root.confirmDelete ? "¿Seguro? Clic para borrar" : "Mover a la papelera",
                    action: "delete",
                    danger: true
                }
            ].filter(item => !item.hidden)

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
