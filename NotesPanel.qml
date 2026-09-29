pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

// Tabs + Markdown editor + footer, shared by the slideout and the floating window.
Item {
    id: root

    property var pluginData: ({})
    property bool inPopout: false
    property bool active: false
    property bool sourceMode: false
    property bool showPathInfo: false
    property bool showMenu: false
    property bool confirmDelete: false
    property int editingIndex: -1

    readonly property bool dirty: saveTimer.running
    readonly property alias store: store

    signal popoutRequested
    signal dockRequested
    signal hideRequested

    function focusEditor() {
        Qt.callLater(() => editor.forceActiveFocus());
    }

    function flushSave() {
        if (saveTimer.running) {
            saveTimer.stop();
            store.save(editor.markdown());
        }
    }

    function saveNow() {
        saveTimer.stop();
        if (store.currentIsAutoNamed && editor.markdown().trim() !== "") {
            saveBrowserLoader.active = true;
            saveBrowserLoader.item?.open();
            return;
        }
        store.save(editor.markdown());
    }

    function newNote() {
        flushSave();
        store.create();
        focusEditor();
    }

    function openFile() {
        flushSave();
        openBrowserLoader.active = true;
        openBrowserLoader.item?.open();
    }

    function toggleSource() {
        sourceMode = !sourceMode;
        editor.setSourceMode(sourceMode);
        focusEditor();
    }

    function onShown() {
        store.ensureTab();
        focusEditor();
    }

    NotesStore {
        id: store
        notesDir: root.pluginData.notesDir || "~/Notes"
        onNoteLoaded: content => {
            editor.load(content);
            root.confirmDelete = false;
            root.showMenu = false;
        }
        onExternalChange: content => {
            if (saveTimer.running)
                return;
            const pos = editor.cursorPosition;
            editor.load(content);
            editor.cursorPosition = Math.min(pos, editor.length);
        }
    }

    Timer {
        id: saveTimer
        interval: 700
        onTriggered: store.save(editor.markdown())
    }

    Shortcut {
        enabled: root.active
        sequence: "Ctrl+N"
        onActivated: root.newNote()
    }

    Shortcut {
        enabled: root.active
        sequence: "Ctrl+S"
        onActivated: root.saveNow()
    }

    Shortcut {
        enabled: root.active
        sequence: "Ctrl+O"
        onActivated: root.openFile()
    }

    Shortcut {
        enabled: root.active
        sequence: "Ctrl+W"
        onActivated: {
            root.flushSave();
            store.closeTab(store.currentIndex);
        }
    }

    Shortcut {
        enabled: root.active
        sequence: "Ctrl+Shift+M"
        onActivated: root.toggleSource()
    }

    Shortcut {
        enabled: root.active
        sequence: "Escape"
        onActivated: {
            if (root.showMenu || root.showPathInfo) {
                root.showMenu = false;
                root.showPathInfo = false;
                return;
            }
            root.hideRequested();
        }
    }

    // Tabs
    Row {
        id: tabRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 36
        spacing: Theme.spacingXS

        readonly property real tabWidth: {
            const count = Math.max(1, store.tabs.length);
            const raw = (tabScroll.width - (count - 1) * Theme.spacingXS) / count;
            return Math.max(128, Math.min(300, raw));
        }

        ScrollView {
            id: tabScroll
            width: parent.width - newTabButton.width - Theme.spacingXS
            height: parent.height
            clip: true
            ScrollBar.horizontal.visible: false
            ScrollBar.vertical.visible: false

            Row {
                spacing: Theme.spacingXS

                Repeater {
                    model: store.tabs

                    delegate: Item {
                        id: tab
                        required property int index
                        required property string modelData

                        readonly property bool isActive: store.currentIndex === index
                        readonly property bool editing: root.editingIndex === index

                        width: tabRow.tabWidth
                        height: 32
                        anchors.verticalCenter: parent?.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.cornerRadius
                            color: tab.isActive ? Theme.primaryPressed : (tabMouse.containsMouse && !closeMouse.containsMouse ? Theme.primaryHoverLight : "transparent")
                            border.width: tab.isActive ? 0 : 1
                            border.color: Theme.outlineMedium

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingM
                                spacing: Theme.spacingXS

                                StyledText {
                                    visible: !tab.editing
                                    width: parent.width - (closeButton.visible ? closeButton.width + Theme.spacingXS : 0)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (tab.isActive && root.dirty ? "● " : "") + store.titleOf(tab.modelData)
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: tab.isActive ? Font.Medium : Font.Normal
                                    color: tab.isActive ? Theme.primary : Theme.surfaceText
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 1
                                    wrapMode: Text.NoWrap
                                }

                                DankTextField {
                                    id: renameField
                                    visible: tab.editing
                                    enabled: tab.editing
                                    width: parent.width
                                    height: parent.height
                                    font.pixelSize: Theme.fontSizeSmall
                                    textColor: Theme.primary
                                    backgroundColor: "transparent"
                                    borderWidth: 0
                                    focusedBorderWidth: 0
                                    topPadding: 0
                                    bottomPadding: 0
                                    onEditingFinished: {
                                        if (root.editingIndex === tab.index)
                                            store.renameCurrent(text);
                                        root.editingIndex = -1;
                                        root.focusEditor();
                                    }
                                    onVisibleChanged: {
                                        if (!visible)
                                            return;
                                        text = store.titleOf(tab.modelData);
                                        renameFocus.restart();
                                    }

                                    Timer {
                                        id: renameFocus
                                        interval: 20
                                        onTriggered: {
                                            renameField.forceActiveFocus();
                                            renameField.selectAll();
                                        }
                                    }
                                }

                                Rectangle {
                                    id: closeButton
                                    width: 20
                                    height: 20
                                    radius: Theme.cornerRadius
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !tab.editing
                                    color: closeMouse.containsMouse ? Theme.surfaceTextHover : "transparent"

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "close"
                                        size: 14
                                        color: Theme.surfaceTextMedium
                                    }

                                    MouseArea {
                                        id: closeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        z: 10
                                        onClicked: {
                                            if (tab.isActive)
                                                root.flushSave();
                                            store.closeTab(tab.index);
                                            root.focusEditor();
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            enabled: !tab.editing
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (tab.isActive)
                                    return;
                                root.flushSave();
                                store.switchTo(tab.index);
                                root.focusEditor();
                            }
                            onDoubleClicked: {
                                if (!tab.isActive) {
                                    root.flushSave();
                                    store.switchTo(tab.index);
                                }
                                root.editingIndex = tab.index;
                            }
                        }
                    }
                }
            }
        }

        DankActionButton {
            id: newTabButton
            width: 32
            height: 32
            iconName: "add"
            iconSize: Theme.iconSize - 4
            iconColor: Theme.surfaceText
            tooltipText: "Nueva nota (Ctrl+N)"
            onClicked: root.newNote()
        }
    }

    // Editor
    Rectangle {
        id: editorFrame
        anchors.top: tabRow.bottom
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Theme.spacingS
        anchors.bottomMargin: Theme.spacingS
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceText, 0.03)
        border.width: 1
        border.color: Theme.outlineMedium

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            contentWidth: width
            contentHeight: editor.contentHeight + Theme.spacingL
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            property real savedY: 0

            function ensureVisible(r) {
                if (contentY >= r.y)
                    contentY = r.y;
                else if (contentY + height <= r.y + r.height)
                    contentY = r.y + r.height - height;
            }

            MarkdownEditor {
                id: editor
                width: flick.width
                height: Math.max(flick.height, contentHeight)
                focus: true
                color: Theme.surfaceText
                selectionColor: Theme.primary
                selectedTextColor: Theme.background
                // Qt serializes fixed-pitch text as `code`, so the rich view needs a proportional font.
                font.family: sourceMode ? SettingsData.monoFontFamily : SettingsData.fontFamily
                font.pixelSize: (SettingsData.notepadFontSize || 14) * (SettingsData.fontScale || 1)
                onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                onEdited: saveTimer.restart()
                onRewriteStarted: flick.savedY = flick.contentY
                onRewriteFinished: flick.contentY = Math.min(flick.savedY, Math.max(0, flick.contentHeight - flick.height))

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onTapped: eventPoint => {
                        const hit = editor.isMarkerHit(eventPoint.position.x, eventPoint.position.y);
                        if (hit >= 0)
                            editor.toggleTaskAt(hit);
                    }
                }

                StyledText {
                    visible: editor.length === 0 && !editor.sourceMode
                    text: "Escribe…  # título, - lista, [] tarea, **negrita**"
                    color: Theme.surfaceVariantText
                    font.pixelSize: editor.font.pixelSize
                    opacity: 0.6
                }
            }
        }
    }

    // Footer
    Column {
        id: footer
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.spacingXS

        Item {
            width: parent.width
            height: 32

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingL

                Repeater {
                    model: [
                        {
                            icon: "save",
                            label: "Guardar",
                            color: Theme.primary,
                            action: "save"
                        },
                        {
                            icon: "folder_open",
                            label: "Abrir",
                            color: Theme.secondary,
                            action: "open"
                        },
                        {
                            icon: "note_add",
                            label: "Nuevo",
                            color: Theme.surfaceText,
                            action: "new"
                        }
                    ]

                    delegate: Row {
                        required property var modelData
                        spacing: Theme.spacingS

                        DankActionButton {
                            iconName: modelData.icon
                            iconSize: Theme.iconSize - 2
                            iconColor: modelData.color
                            onClicked: {
                                if (modelData.action === "save")
                                    root.saveNow();
                                else if (modelData.action === "open")
                                    root.openFile();
                                else
                                    root.newNote();
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceTextMedium
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankActionButton {
                    visible: !root.inPopout
                    iconName: "open_in_new"
                    iconSize: Theme.iconSize - 2
                    iconColor: Theme.surfaceText
                    tooltipText: "Ventana flotante"
                    onClicked: root.popoutRequested()
                }

                DankActionButton {
                    visible: root.inPopout
                    iconName: "dock_to_right"
                    iconSize: Theme.iconSize - 2
                    iconColor: Theme.surfaceText
                    tooltipText: "Volver al panel lateral"
                    onClicked: root.dockRequested()
                }

                DankActionButton {
                    iconName: "more_horiz"
                    iconSize: Theme.iconSize - 2
                    iconColor: root.showMenu ? Theme.primary : Theme.surfaceText
                    onClicked: {
                        root.showPathInfo = false;
                        root.confirmDelete = false;
                        root.showMenu = !root.showMenu;
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: Theme.spacingL

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const len = editor.markdown().length;
                    if (len === 0)
                        return "Vacío";
                    return len === 1 ? "1 carácter" : len + " caracteres";
                }
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: editor.length > 0
                text: "Líneas: " + editor.markdown().replace(/\n+$/, "").split("\n").length
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
            }

            Row {
                spacing: Theme.spacingXS

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.dirty ? "Guardando..." : "Guardado"
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.dirty ? Theme.primary : Theme.success
                }

                DankActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "info"
                    iconSize: Theme.iconSizeSmall
                    iconColor: root.showPathInfo ? Theme.primary : Theme.surfaceTextMedium
                    buttonSize: 20
                    onClicked: {
                        root.showMenu = false;
                        root.showPathInfo = !root.showPathInfo;
                    }
                }
            }
        }
    }

    // Path info popup
    StyledRect {
        visible: root.showPathInfo
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.spacingS
        width: Math.min(root.width, 360)
        height: pathRow.implicitHeight + Theme.spacingS * 2
        radius: Theme.cornerRadius
        color: Theme.floatingWindowNestedSurface
        border.color: Theme.outlineMedium
        border.width: 1
        z: 10

        Row {
            id: pathRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            spacing: Theme.spacingS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "description"
                size: Theme.iconSize - 4
                color: Theme.surfaceVariantText
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: pathRow.width - (Theme.iconSize - 4) - copyPath.width - Theme.spacingS * 2
                text: store.currentPath
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                elide: Text.ElideMiddle
            }

            DankActionButton {
                id: copyPath
                anchors.verticalCenter: parent.verticalCenter
                iconName: "content_copy"
                iconSize: Theme.iconSize - 6
                iconColor: Theme.surfaceTextMedium
                onClicked: {
                    Quickshell.execDetached(["wl-copy", store.currentPath]);
                    ToastService.showInfo("Ruta copiada al portapapeles");
                }
            }
        }
    }

    // "..." menu
    StyledRect {
        id: menu
        visible: root.showMenu
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.spacingS
        width: 240
        height: menuColumn.implicitHeight + Theme.spacingS * 2
        radius: Theme.cornerRadius
        color: Theme.floatingWindowNestedSurface
        border.color: Theme.outlineMedium
        border.width: 1
        z: 10

        Column {
            id: menuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Theme.spacingXS

            Repeater {
                model: [
                    {
                        icon: root.sourceMode ? "visibility" : "code",
                        label: root.sourceMode ? "Ver formateado" : "Ver Markdown",
                        action: "source"
                    },
                    {
                        icon: "drive_file_rename_outline",
                        label: "Renombrar nota",
                        action: "rename"
                    },
                    {
                        icon: "folder",
                        label: "Abrir carpeta de notas",
                        action: "folder"
                    },
                    {
                        icon: "delete",
                        label: root.confirmDelete ? "¿Seguro? Clic para borrar" : "Mover a la papelera",
                        action: "delete",
                        danger: true
                    }
                ]

                delegate: Rectangle {
                    required property var modelData
                    width: menuColumn.width
                    height: 34
                    radius: Theme.cornerRadius
                    color: itemMouse.containsMouse ? Theme.primaryHoverLight : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM

                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: modelData.icon
                            size: Theme.iconSize - 6
                            color: modelData.danger ? Theme.error : Theme.surfaceText
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            font.pixelSize: Theme.fontSizeSmall
                            color: modelData.danger ? Theme.error : Theme.surfaceText
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            switch (modelData.action) {
                            case "source":
                                root.showMenu = false;
                                root.toggleSource();
                                break;
                            case "rename":
                                root.showMenu = false;
                                root.editingIndex = store.currentIndex;
                                break;
                            case "folder":
                                root.showMenu = false;
                                Quickshell.execDetached(["xdg-open", store.dir]);
                                break;
                            case "delete":
                                if (!root.confirmDelete) {
                                    root.confirmDelete = true;
                                    return;
                                }
                                root.confirmDelete = false;
                                root.showMenu = false;
                                saveTimer.stop();
                                store.trashCurrent();
                                break;
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: openBrowserLoader
        active: false
        sourceComponent: FileBrowserSurfaceModal {
            browserTitle: "Abrir nota"
            browserIcon: "folder_open"
            browserType: "markdown_notes_open"
            fileExtensions: ["*.md", "*.markdown", "*.txt"]
            allowStacking: true
            onFileSelected: path => {
                const clean = decodeURI(path.toString().replace(/^file:\/\//, ""));
                store.openPath(clean);
                close();
                root.focusEditor();
            }
        }
    }

    Loader {
        id: saveBrowserLoader
        active: false
        sourceComponent: FileBrowserSurfaceModal {
            browserTitle: "Guardar nota"
            browserIcon: "save"
            browserType: "markdown_notes_save"
            fileExtensions: ["*.md"]
            allowStacking: true
            saveMode: true
            defaultFileName: {
                const m = editor.markdown().match(/^#\s+(.+)$/m);
                return (m ? store.slugify(m[1]) : "nota") + ".md";
            }
            onFileSelected: path => {
                const clean = decodeURI(path.toString().replace(/^file:\/\//, ""));
                store.saveAs(clean, editor.markdown());
                close();
                root.focusEditor();
            }
        }
    }
}
