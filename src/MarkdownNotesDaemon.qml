import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "windows"
import "panel"

PluginComponent {
    id: root

    property bool popoutMode: false

    function toggle(screenName) {
        if (popoutMode) {
            if (popout.visible)
                popout.hide();
            else
                popout.show();
            return;
        }
        if (slideout.isVisible)
            slideout.hide();
        else
            slideout.show(screenName);
    }

    function isShown() {
        return popoutMode ? popout.visible : slideout.isVisible;
    }

    PluginGlobalVar {
        id: toggleRequest
        varName: "toggleRequest"
        defaultValue: null
    }

    Connections {
        target: toggleRequest
        function onValueChanged() {
            const req = toggleRequest.value;
            if (req && req.t)
                root.toggle(req.screen || "");
        }
    }

    MarkdownNotesSlideout {
        id: slideout
        pluginData: root.pluginData
        onShown: panel.onShown()
        onAboutToHide: panel.flushSave()
    }

    MarkdownNotesPopout {
        id: popout
        onVisibleChanged: {
            if (visible)
                panel.onShown();
            else
                panel.flushSave();
        }
    }

    NotesPanel {
        id: panel
        parent: root.popoutMode ? popout.container : slideout.container
        anchors.fill: parent
        pluginData: root.pluginData
        inPopout: root.popoutMode
        active: root.popoutMode ? popout.visible : slideout.isVisible

        onHideRequested: root.popoutMode ? popout.hide() : slideout.hide()
        onPopoutRequested: {
            slideout.hide();
            root.popoutMode = true;
            popout.show();
        }
        onDockRequested: {
            popout.hide();
            root.popoutMode = false;
            slideout.show("");
        }
    }

    IpcHandler {
        target: "markdownNotes"

        function toggle(): string {
            root.toggle("");
            return root.isShown() ? "shown" : "hidden";
        }

        function open(): string {
            if (!root.isShown())
                root.toggle("");
            return "shown";
        }

        function close(): string {
            if (root.isShown())
                root.toggle("");
            return "hidden";
        }

        function popout(): string {
            panel.popoutRequested();
            return "popout";
        }

        function dock(): string {
            panel.dockRequested();
            return "docked";
        }

        function newNote(): string {
            if (!root.isShown())
                root.toggle("");
            panel.newNote();
            return "created";
        }

        function openNote(name: string): string {
            if (!root.isShown())
                root.toggle("");
            return panel.openNote(name) || "invalid";
        }

        function search(query: string): string {
            if (!root.isShown())
                root.toggle("");
            Qt.callLater(() => panel.openSearch(query));
            return "search";
        }
    }
}
