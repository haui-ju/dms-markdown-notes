import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "markdownNotes"

    StringSetting {
        settingKey: "notesDir"
        label: "Carpeta de notas"
        description: "Donde se guardan los archivos .md (admite ~)"
        placeholder: "~/Notes"
        defaultValue: "~/Notes"
    }

    SliderSetting {
        settingKey: "panelWidth"
        label: "Ancho del panel"
        minimum: 280
        maximum: 1000
        defaultValue: 500
        unit: "px"
    }

    SelectionSetting {
        settingKey: "side"
        label: "Lado del panel"
        options: [
            {
                label: "Izquierda",
                value: "left"
            },
            {
                label: "Derecha",
                value: "right"
            }
        ]
        defaultValue: "left"
    }
}
