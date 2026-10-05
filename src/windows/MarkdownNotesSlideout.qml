import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import "../components"

PanelWindow {
    id: root

    property var pluginData: ({})
    readonly property int panelWidth: Math.max(280, Number(pluginData.panelWidth) || 500)
    property int verticalTabsExtra: 0
    readonly property bool fromLeft: (pluginData.side || "left") === "left"
    readonly property real edgeGap: {
        const g = SettingsData.notepadEffectiveEdgeGap;
        return typeof g === "number" ? g : Theme.spacingS;
    }

    property bool isVisible: false
    property bool mapped: false
    readonly property alias container: contentContainer

    signal shown
    signal aboutToHide

    function show(screenName) {
        const target = Quickshell.screens.find(s => s.name === screenName) || CompositorService.getFocusedScreen();
        if (target && !mapped)
            screen = target;
        mapped = true;
        isVisible = true;
        shown();
    }

    function hide() {
        if (!isVisible)
            return;
        aboutToHide();
        isVisible = false;
    }

    visible: mapped
    color: "transparent"

    anchors.top: true
    anchors.bottom: true
    anchors.left: fromLeft
    anchors.right: !fromLeft

    implicitWidth: panelWidth + verticalTabsExtra + edgeGap * 2

    WlrLayershell.namespace: "dms:plugin:markdown-notes"
    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: isVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        item: surface
    }

    Item {
        anchors.fill: parent
        anchors.margins: root.edgeGap
        clip: true

        Rectangle {
            id: surface

            readonly property real targetWidth: {
                const want = root.panelWidth + root.verticalTabsExtra;
                const sw = root.screen ? root.screen.width - root.edgeGap * 4 : want;
                return Math.min(want, Math.max(root.panelWidth + root.verticalTabsExtra, sw));
            }
            property real offset: root.isVisible ? 0 : (root.fromLeft ? -width - root.edgeGap : width + root.edgeGap)

            width: targetWidth
            height: parent.height
            x: root.fromLeft ? offset : parent.width - width + offset
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.notepadTransparency)

            Behavior on width {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on offset {
                NumberAnimation {
                    duration: 260
                    easing.type: root.isVisible ? Easing.OutCubic : Easing.InCubic
                    onRunningChanged: {
                        if (!running && !root.isVisible)
                            root.mapped = false;
                    }
                }
            }

            TitleBar {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingL
                height: 32
                title: "Notas"

                IconButton {
                    iconName: "close"
                    onClicked: root.hide()
                }
            }

            Item {
                id: contentContainer
                anchors.top: header.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: Theme.spacingM
                anchors.leftMargin: Theme.spacingL
                anchors.rightMargin: Theme.spacingL
                anchors.bottomMargin: Theme.spacingL
                readonly property int noteBodyWidth: root.panelWidth - Theme.spacingL * 2
            }
        }
    }
}
