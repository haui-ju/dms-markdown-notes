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
        description: "Usa una fuente instalada; Fira Code o JetBrains Mono muestran ligaduras como -> y =>"
        placeholder: "Noto Sans, Fira Code o JetBrains Mono"
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

    SelectionSetting {
        settingKey: "tabLayout"
        label: "Disposición de pestañas"
        options: [
            {
                label: "Horizontal",
                value: "horizontal"
            },
            {
                label: "Vertical",
                value: "vertical"
            }
        ]
        defaultValue: "horizontal"
    }
}
