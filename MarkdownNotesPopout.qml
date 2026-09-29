import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

DankFloatingWindow {
    id: win

    readonly property alias container: contentContainer

    function show() {
        visible = true;
    }

    function hide() {
        visible = false;
    }

    title: "Notas"
    minimumSize: Qt.size(360, 320)
    implicitWidth: 640
    implicitHeight: 760
    surfaceColor: Theme.notepadWindowSurface
    visible: false

    onClosed: win.visible = false

    Item {
        anchors.fill: parent

        Item {
            id: titleBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 44
            z: 10

            MouseArea {
                anchors.fill: parent
                onPressed: windowControls.tryStartMove()
                onDoubleClicked: windowControls.tryToggleMaximize()
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "edit_note"
                    size: Theme.iconSize - 2
                    color: Theme.primary
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notas"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS

                DankActionButton {
                    visible: windowControls.canMaximize
                    circular: false
                    iconName: win.maximized ? "fullscreen_exit" : "fullscreen"
                    iconSize: Theme.iconSize - 4
                    iconColor: Theme.surfaceText
                    onClicked: windowControls.tryToggleMaximize()
                }

                DankActionButton {
                    circular: false
                    iconName: "close"
                    iconSize: Theme.iconSize - 4
                    iconColor: Theme.surfaceText
                    onClicked: win.hide()
                }
            }
        }

        Item {
            id: contentContainer
            anchors.top: titleBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spacingM
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: win
    }
}
