pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import "../components"

PopupSurface {
    id: root

    required property var editor
    property rect caret: Qt.rect(0, 0, 0, 0)
    readonly property var slash: editor.slash
    readonly property real rowHeight: 34
    readonly property real gap: Theme.spacingXS
    readonly property bool fitsBelow: caret.y + caret.height + gap + height <= parent.height

    visible: slash.active && slash.items.length > 0
    width: 240
    height: Math.min(list.contentHeight, rowHeight * 8) + Theme.spacingXS * 2
    x: Math.max(0, Math.min(caret.x, parent.width - width))
    y: fitsBelow ? caret.y + caret.height + gap : Math.max(0, caret.y - height - gap)
    z: 20

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: Theme.spacingXS
        clip: true
        interactive: contentHeight > height
        model: root.slash.items
        currentIndex: root.slash.index
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: MenuRow {
            required property int index
            required property var modelData
            width: list.width
            height: root.rowHeight
            icon: modelData.icon
            label: modelData.label
            highlighted: root.slash.index === index
            onHoveredChanged: {
                if (hovered)
                    root.slash.index = index;
            }
            onTriggered: {
                root.slash.accept(index);
                root.editor.forceActiveFocus();
            }
        }
    }
}
