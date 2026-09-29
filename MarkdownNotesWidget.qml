import QtQuick
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

    pillClickAction: () => toggleRequest.set({
            t: Date.now(),
            screen: root.parentScreen?.name ?? ""
        })

    horizontalBarPill: Component {
        DankIcon {
            name: "edit_note"
            size: root.iconSize
            color: Theme.widgetIconColor
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: "edit_note"
            size: root.iconSize
            color: Theme.widgetIconColor
        }
    }
}
