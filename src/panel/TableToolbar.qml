pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import "../components"
import "../editor/logic/slash.js" as Slash

PopupSurface {
    id: root

    required property var editor
    readonly property var info: editor.table.info
    readonly property real gap: Theme.spacingXS
    readonly property var densityIcons: ({
            compacto: "density_small",
            normal: "density_medium",
            amplio: "density_large"
        })

    function iconFor(id, fallback) {
        if (id === "density" && info)
            return densityIcons[info.density] || fallback;
        if (id === "fullWidth" && info && info.fullWidth)
            return "width_normal";
        return fallback;
    }

    visible: info !== null && !editor.sourceMode
    width: actions.implicitWidth + Theme.spacingXS * 2
    height: actions.implicitHeight + Theme.spacingXS * 2
    x: editor.width - width
    y: info ? (info.top >= height + gap ? info.top - height - gap : info.bottom + gap) : 0

    Row {
        id: actions
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: Slash.TABLE

            delegate: IconButton {
                required property var modelData
                buttonSize: 28
                iconName: root.iconFor(modelData.id, modelData.icon)
                highlighted: modelData.id === "fullWidth" && root.info !== null && root.info.fullWidth
                iconColor: modelData.id === "tableRemove" ? Theme.error : Theme.surfaceText
                tooltipText: modelData.label
                onClicked: {
                    root.editor.runCommand(modelData.id);
                    root.editor.forceActiveFocus();
                }
            }
        }
    }
}
