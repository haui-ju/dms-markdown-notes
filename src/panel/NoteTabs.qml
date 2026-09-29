pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import "../components"

Row {
    id: root

    required property var store
    property bool dirty: false
    property int editingIndex: -1

    signal switchRequested(int index)
    signal closeRequested(int index)
    signal renameRequested(string title)
    signal newRequested
    signal editingFinished

    readonly property real tabWidth: {
        const count = Math.max(1, store.tabs.length);
        const raw = (tabScroll.width - (count - 1) * Theme.spacingXS) / count;
        return Math.max(128, Math.min(300, raw));
    }

    height: 36
    spacing: Theme.spacingXS

    ScrollView {
        id: tabScroll
        width: parent.width - newTabButton.width - Theme.spacingXS
        height: parent.height
        clip: true
        ScrollBar.horizontal.visible: false
        ScrollBar.vertical.visible: false

        Row {
            spacing: Theme.spacingXS

            Repeater {
                model: root.store.tabs

                delegate: Item {
                    id: tab

                    required property int index
                    required property string modelData
                    readonly property bool isActive: root.store.currentIndex === index
                    readonly property bool editing: root.editingIndex === index

                    width: root.tabWidth
                    height: 32
                    anchors.verticalCenter: parent?.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cornerRadius
                        color: tab.isActive ? Theme.primaryPressed : (tabMouse.containsMouse && !closeMouse.containsMouse ? Theme.primaryHoverLight : "transparent")
                        border.width: tab.isActive ? 0 : 1
                        border.color: Theme.outlineMedium

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingM
                            anchors.rightMargin: Theme.spacingM
                            spacing: Theme.spacingXS

                            StyledText {
                                visible: !tab.editing
                                width: parent.width - (closeButton.visible ? closeButton.width + Theme.spacingXS : 0)
                                anchors.verticalCenter: parent.verticalCenter
                                text: (tab.isActive && root.dirty ? "● " : "") + root.store.titleOf(tab.modelData)
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: tab.isActive ? Font.Medium : Font.Normal
                                color: tab.isActive ? Theme.primary : Theme.surfaceText
                                elide: Text.ElideMiddle
                                maximumLineCount: 1
                                wrapMode: Text.NoWrap
                            }

                            DankTextField {
                                id: renameField
                                visible: tab.editing
                                enabled: tab.editing
                                width: parent.width
                                height: parent.height
                                font.pixelSize: Theme.fontSizeSmall
                                textColor: Theme.primary
                                backgroundColor: "transparent"
                                borderWidth: 0
                                focusedBorderWidth: 0
                                topPadding: 0
                                bottomPadding: 0
                                onEditingFinished: {
                                    if (root.editingIndex === tab.index)
                                        root.renameRequested(text);
                                    root.editingIndex = -1;
                                    root.editingFinished();
                                }
                                onVisibleChanged: {
                                    if (!visible)
                                        return;
                                    text = root.store.titleOf(tab.modelData);
                                    renameFocus.restart();
                                }

                                Timer {
                                    id: renameFocus
                                    interval: 20
                                    onTriggered: {
                                        renameField.forceActiveFocus();
                                        renameField.selectAll();
                                    }
                                }
                            }

                            Rectangle {
                                id: closeButton
                                width: 20
                                height: 20
                                radius: Theme.cornerRadius
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !tab.editing
                                color: closeMouse.containsMouse ? Theme.surfaceTextHover : "transparent"

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    size: 14
                                    color: Theme.surfaceTextMedium
                                }

                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    z: 10
                                    onClicked: root.closeRequested(tab.index)
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        enabled: !tab.editing
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!tab.isActive)
                                root.switchRequested(tab.index);
                        }
                        onDoubleClicked: {
                            if (!tab.isActive)
                                root.switchRequested(tab.index);
                            root.editingIndex = tab.index;
                        }
                    }
                }
            }
        }
    }

    IconButton {
        id: newTabButton
        iconName: "add"
        tooltipText: "Nueva nota (Ctrl+N)"
        onClicked: root.newRequested()
    }
}
