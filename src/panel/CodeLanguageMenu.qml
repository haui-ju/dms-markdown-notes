pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import "../components"
import "../editor/logic/code.js" as Code

Item {
    id: root

    required property var editor
    property int index: -1
    property string current: ""
    property rect anchor: Qt.rect(0, 0, 0, 0)
    readonly property real rowHeight: 30
    readonly property bool open: index >= 0

    function show(blockIndex, lang, rect) {
        current = Code.resolve(lang) === null ? lang : Code.resolve(lang);
        anchor = rect;
        index = blockIndex;
        list.positionViewAtIndex(Math.max(0, Code.LANGUAGES.findIndex(l => l.id === current)), ListView.Contain);
    }

    function close() {
        index = -1;
    }

    function choose(id) {
        editor.code.setLanguage(index, id);
        close();
        editor.forceActiveFocus();
    }

    anchors.fill: parent
    visible: open
    z: 30

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.close()
        onWheel: wheel => wheel.accepted = true
    }

    PopupSurface {
        readonly property bool fitsBelow: root.anchor.y + root.anchor.height + height <= root.height

        width: 190
        height: Math.min(list.contentHeight, root.rowHeight * 8) + Theme.spacingXS * 2
        x: Math.max(0, Math.min(root.anchor.x, root.width - width))
        y: fitsBelow ? root.anchor.y + root.anchor.height + Theme.spacingXS : Math.max(0, root.anchor.y - height - Theme.spacingXS)

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: Theme.spacingXS
            clip: true
            interactive: contentHeight > height
            model: Code.LANGUAGES

            delegate: MenuRow {
                required property var modelData
                width: list.width
                height: root.rowHeight
                icon: modelData.id === root.current ? "check" : "code"
                label: modelData.label
                highlighted: modelData.id === root.current
                onTriggered: root.choose(modelData.id)
            }
        }
    }
}
