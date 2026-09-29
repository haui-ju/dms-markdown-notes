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

    StringSetting {
        settingKey: "noteFont"
        label: "Fuente de las notas"
        description: "Noto Sans separa más las líneas que otras fuentes. Déjalo vacío para usar la fuente del sistema"
        placeholder: "Noto Sans"
        defaultValue: "Noto Sans"
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
