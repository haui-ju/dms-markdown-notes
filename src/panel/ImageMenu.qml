pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import qs.Widgets
import "../components"

Item {
    id: root

    required property var editor

    property bool captionOpen: false

    readonly property bool menuOpen: {
        if (!editor || editor.sourceMode)
            return false;
        const t = editor.imageController.menuTarget;
        return t !== null && t !== undefined;
    }

    readonly property rect targetRect: {
        if (!menuOpen)
            return Qt.rect(0, 0, 0, 0);
        const t = editor.imageController.menuTarget;
        const r = editor.mapToItem(root, t.x, t.y, t.width, t.height);
        if (r.width > 0 && r.height > 0)
            return r;
        return Qt.rect(Theme.spacingS, Theme.spacingS, t.width, t.height);
    }

    z: menuOpen ? 100 : -1

    Connections {
        target: editor.imageController
        function onMenuTargetChanged() {
            root.captionOpen = false;
            captionField.text = "";
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.menuOpen
        visible: enabled
        z: 80
        onClicked: editor.imageController.closeMenu()
    }

    PopupSurface {
        visible: root.menuOpen
        z: 90
        width: Math.min(280, parent.width - Theme.spacingS * 2)
        height: menuColumn.implicitHeight + Theme.spacingS * 2
        x: Math.max(Theme.spacingS, Math.min(targetRect.x, parent.width - width - Theme.spacingS))
        y: {
            const above = targetRect.y - height - Theme.spacingXS;
            return above >= Theme.spacingS ? above : targetRect.y + targetRect.height + Theme.spacingXS;
        }

        Column {
            id: menuColumn
            width: parent.width - Theme.spacingS * 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingXS
            spacing: Theme.spacingXS

            MenuRow {
                width: parent.width
                icon: "open_in_full"
                label: "Ver imagen"
                onTriggered: root.editor.imageController.viewImage()
            }

            MenuRow {
                width: parent.width
                icon: "fit_width"
                label: "Ancho de columna"
                highlighted: {
                    const t = editor.imageController.menuTarget;
                    return t && !t.mini;
                }
                onTriggered: root.editor.imageController.applyMini(false)
            }

            MenuRow {
                width: parent.width
                icon: "photo_size_select_small"
                label: "Mini 50×50"
                highlighted: {
                    const t = editor.imageController.menuTarget;
                    return t && t.mini;
                }
                onTriggered: root.editor.imageController.applyMini(true)
            }

            MenuRow {
                width: parent.width
                visible: !root.captionOpen
                icon: "edit_note"
                label: {
                    const t = editor.imageController.menuTarget;
                    return t && t.caption ? "Editar nota al pie" : "Crear nota al pie";
                }
                onTriggered: {
                    const t = editor.imageController.menuTarget;
                    captionField.text = t ? t.caption : "";
                    root.captionOpen = true;
                    captionFocus.restart();
                }
            }

            DankTextField {
                id: captionField
                width: parent.width
                visible: root.captionOpen
                placeholderText: "Nota al pie"
                onAccepted: {
                    root.editor.imageController.applyCaption(text.trim());
                    root.captionOpen = false;
                }

                Timer {
                    id: captionFocus
                    interval: 20
                    onTriggered: captionField.forceActiveFocus()
                }
            }

            MenuRow {
                width: parent.width
                visible: root.captionOpen
                icon: "check"
                label: "Guardar nota"
                onTriggered: {
                    root.editor.imageController.applyCaption(captionField.text.trim());
                    root.captionOpen = false;
                }
            }

            MenuRow {
                width: parent.width
                visible: !root.captionOpen
                icon: "delete"
                label: "Eliminar imagen"
                onTriggered: root.editor.imageController.removeImage()
            }
        }
    }
}
