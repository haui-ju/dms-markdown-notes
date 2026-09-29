import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import "../components"

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

        TitleBar {
            id: titleBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 44
            z: 10
            title: "Notas"
            icon: "edit_note"
            draggable: true
            leftPadding: Theme.spacingM
            rightPadding: Theme.spacingS
            onDragStarted: windowControls.tryStartMove()
            onDoubleClicked: windowControls.tryToggleMaximize()

            IconButton {
                visible: windowControls.canMaximize
                circular: false
                iconName: win.maximized ? "fullscreen_exit" : "fullscreen"
                onClicked: windowControls.tryToggleMaximize()
            }

            IconButton {
                circular: false
                iconName: "close"
                onClicked: win.hide()
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
