import QtQuick

Item {
    id: root

    property alias text: input.text
    property alias cursorPosition: input.cursorPosition
    property string placeholderText: ""
    property string leftIconName: ""
    property bool showClearButton: false
    property var keyForwardTargets: []

    signal accepted

    function forceActiveFocus() {
        input.forceActiveFocus();
    }

    function selectAll() {
        input.selectAll();
    }

    height: 40

    TextInput {
        id: input
        anchors.fill: parent
        Keys.forwardTo: root.keyForwardTargets
        onAccepted: root.accepted()
    }
}
