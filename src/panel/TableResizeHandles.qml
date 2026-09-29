pragma ComponentBehavior: Bound
import QtQuick
import qs.Common

Item {
    id: root

    required property var editor
    readonly property real handleWidth: 10

    anchors.fill: parent
    visible: !editor.sourceMode

    Repeater {
        model: root.editor.table.geometries

        delegate: Item {
            id: tableHandles

            required property var modelData

            anchors.fill: parent

            Repeater {
                model: tableHandles.modelData.edges.length - 1

                delegate: MouseArea {
                    id: handle

                    required property int index
                    readonly property int edge: index + 1
                    readonly property real edgeX: tableHandles.modelData.edges[edge]
                    property real dragX: edgeX

                    x: edgeX - width / 2
                    y: tableHandles.modelData.top
                    width: root.handleWidth
                    height: Math.max(1, tableHandles.modelData.bottom - tableHandles.modelData.top)
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: Qt.SplitHCursor
                    onPressed: mouse => dragX = x + mouse.x
                    onPositionChanged: mouse => {
                        if (pressed)
                            dragX = Math.max(0, Math.min(root.width, x + mouse.x));
                    }
                    onReleased: {
                        if (Math.abs(dragX - edgeX) >= 2)
                            root.editor.table.resize(tableHandles.modelData.table, edge, dragX);
                        dragX = edgeX;
                    }
                    onCanceled: dragX = edgeX

                    Rectangle {
                        visible: handle.containsMouse || handle.pressed
                        x: (handle.pressed ? handle.dragX - handle.x : handle.width / 2) - width / 2
                        width: 2
                        height: parent.height
                        radius: 1
                        color: Theme.primary
                    }
                }
            }
        }
    }
}
