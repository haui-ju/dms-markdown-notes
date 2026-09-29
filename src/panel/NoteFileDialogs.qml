import QtQuick
import qs.Modals.FileBrowser

Item {
    id: root

    property string defaultSaveName: "nota.md"

    signal fileOpened(string path)
    signal fileSaved(string path)
    signal imagePicked(string path)

    function toPath(url) {
        return decodeURI(url.toString().replace(/^file:\/\//, ""));
    }

    function open() {
        openLoader.active = true;
        openLoader.item?.open();
    }

    function saveAs() {
        saveLoader.active = true;
        saveLoader.item?.open();
    }

    function pickImage() {
        imageLoader.active = true;
        imageLoader.item?.open();
    }

    Loader {
        id: imageLoader
        active: false
        sourceComponent: FileBrowserSurfaceModal {
            browserTitle: "Insertar imagen"
            browserIcon: "image"
            browserType: "markdown_notes_image"
            fileExtensions: ["*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.bmp", "*.svg"]
            allowStacking: true
            onFileSelected: path => {
                close();
                root.imagePicked(root.toPath(path));
            }
        }
    }

    Loader {
        id: openLoader
        active: false
        sourceComponent: FileBrowserSurfaceModal {
            browserTitle: "Abrir nota"
            browserIcon: "folder_open"
            browserType: "markdown_notes_open"
            fileExtensions: ["*.md", "*.markdown", "*.txt"]
            allowStacking: true
            onFileSelected: path => {
                close();
                root.fileOpened(root.toPath(path));
            }
        }
    }

    Loader {
        id: saveLoader
        active: false
        sourceComponent: FileBrowserSurfaceModal {
            browserTitle: "Guardar nota"
            browserIcon: "save"
            browserType: "markdown_notes_save"
            fileExtensions: ["*.md"]
            allowStacking: true
            saveMode: true
            defaultFileName: root.defaultSaveName
            onFileSelected: path => {
                close();
                root.fileSaved(root.toPath(path));
            }
        }
    }
}
