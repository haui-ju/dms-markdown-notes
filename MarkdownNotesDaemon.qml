import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

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
                slideout.toggle(req.screen || "");
        }
    }

    MarkdownNotesSlideout {
        id: slideout
        pluginData: root.pluginData
    }

    IpcHandler {
        target: "markdownNotes"

        function toggle(): string {
            slideout.toggle("");
            return slideout.isVisible ? "shown" : "hidden";
        }

        function open(): string {
            slideout.show("");
            return "shown";
        }

        function close(): string {
            slideout.hide();
            return "hidden";
        }

        function newNote(): string {
            slideout.newNote();
            return "created";
        }
    }
}
