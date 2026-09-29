import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "../store"
import "../editor/logic/images.js" as Images

Item {
    id: root

    property var pluginData: ({})
    property bool inPopout: false
    property bool active: false
    property bool showPathInfo: false
    property bool showMenu: false
    property bool confirmDelete: false
    property var histories: ({})
    property string historyPath: ""

    readonly property bool dirty: saveTimer.running
    readonly property alias store: store
    readonly property var editor: editorView.editor

    signal popoutRequested
    signal dockRequested
    signal hideRequested

    function focusEditor() {
        Qt.callLater(() => editor.forceActiveFocus());
    }

    function closePopups() {
        showMenu = false;
        showPathInfo = false;
        confirmDelete = false;
    }

    function flushSave() {
        if (!saveTimer.running)
            return;
        saveTimer.stop();
        store.save(editor.markdown());
    }

    function saveNow() {
        saveTimer.stop();
        if (store.currentIsAutoNamed && editor.markdown().trim() !== "") {
            dialogs.saveAs();
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
        dialogs.open();
    }

    function switchTab(index) {
        flushSave();
        store.switchTo(index);
        focusEditor();
    }

    function closeTab(index) {
        if (index === store.currentIndex)
            flushSave();
        store.closeTab(index);
        focusEditor();
    }

    function toggleSource() {
        editor.setSourceMode(!editor.sourceMode);
        focusEditor();
    }

    function onShown() {
        store.ensureTab();
        focusEditor();
    }

    function moveHistory(from, to) {
        if (from in histories) {
            histories[to] = histories[from];
            delete histories[from];
        }
        if (historyPath === from)
            historyPath = to;
    }

    function retargetAssets(from, to) {
        const a = store.assetsFolder(from).split("/").pop();
        const b = store.assetsFolder(to).split("/").pop();
        if (a === b)
            return;
        const pairs = [[Images.encodePath(a) + "/", Images.encodePath(b) + "/"], [a + "/", b + "/"]];
        if (to !== store.currentPath) {
            store.retargetFile(to, pairs);
            return;
        }
        if (!editor.retargetImages(pairs[0][0], pairs[0][1]))
            editor.retargetImages(pairs[1][0], pairs[1][1]);
    }

    function removeImage(pos, path) {
        editor.removeImageAt(pos);
        const folder = store.assetsFolder(store.currentPath) + "/";
        if (path.indexOf(folder) !== 0)
            return;
        const src = Images.encodePath(store.assetsFolder(store.currentPath).split("/").pop() + "/" + path.substring(folder.length));
        if (editor.markdown().indexOf("](" + src) < 0)
            Quickshell.execDetached(["gio", "trash", "--", path]);
    }

    function runMenuAction(action) {
        if (action === "delete" && !confirmDelete) {
            confirmDelete = true;
            return;
        }
        closePopups();
        switch (action) {
        case "source":
            toggleSource();
            break;
        case "rename":
            tabs.editingIndex = store.currentIndex;
            break;
        case "folder":
            Quickshell.execDetached(["xdg-open", store.dir]);
            break;
        case "delete":
            saveTimer.stop();
            store.trashCurrent();
            break;
        }
    }

    Binding {
        target: root.editor
        property: "imageBaseDir"
        value: store.currentPath.substring(0, store.currentPath.lastIndexOf("/"))
    }

    Connections {
        target: root.editor

        function onImagePasteRequested() {
            assets.pasteClipboard(store.currentPath);
        }

        function onImageFilesPasted(paths) {
            assets.importFiles(store.currentPath, paths);
        }

        function onImageRequested() {
            dialogs.pickImage();
        }

        function onImageActivated(pos, url, src, alt) {
            let name = src.split("/").pop();
            try {
                name = decodeURIComponent(name);
            } catch (e) {}
            imageViewer.show(pos, url, alt || name, true);
        }
    }

    NoteAssets {
        id: assets
        onImported: sources => {
            root.editor.insertImages(sources);
            root.focusEditor();
        }
        onFailed: message => ToastService.showWarning(message)
    }

    ImageViewerModal {
        id: imageViewer
        onRemoveRequested: (pos, path) => root.removeImage(pos, path)
        onDialogClosed: root.focusEditor()
    }

    NotesStore {
        id: store
        notesDir: root.pluginData.notesDir || "~/Notes"
        onRenameFailed: message => ToastService.showWarning(message)
        onMoved: (from, to) => {
            root.moveHistory(from, to);
            root.retargetAssets(from, to);
        }
        onNoteLoaded: content => {
            if (root.historyPath !== "")
                root.histories[root.historyPath] = root.editor.historyState();
            root.editor.load(content);
            root.editor.restoreHistory(root.histories[store.currentPath]);
            root.historyPath = store.currentPath;
            for (const path in root.histories) {
                if (store.tabs.indexOf(path) < 0)
                    delete root.histories[path];
            }
            root.closePopups();
        }
        onExternalChange: content => {
            if (saveTimer.running)
                return;
            const pos = root.editor.cursorPosition;
            root.editor.load(content, true);
            root.editor.cursorPosition = Math.min(pos, root.editor.length);
        }
    }

    Timer {
        id: saveTimer
        interval: 700
        onTriggered: store.save(root.editor.markdown())
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
        onActivated: root.closeTab(store.currentIndex)
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
            if (root.editor.slash.active)
                root.editor.slash.close();
            else if (root.showMenu || root.showPathInfo)
                root.closePopups();
            else
                root.hideRequested();
        }
    }

    NoteTabs {
        id: tabs
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        store: store
        dirty: root.dirty
        onSwitchRequested: index => root.switchTab(index)
        onCloseRequested: index => root.closeTab(index)
        onRenameRequested: (index, title) => store.renameAt(index, title)
        onNewRequested: root.newNote()
        onEditingFinished: root.focusEditor()
    }

    EditorView {
        id: editorView
        anchors.top: tabs.bottom
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Theme.spacingS
        anchors.bottomMargin: Theme.spacingS
        onEdited: saveTimer.restart()
    }

    NoteFooter {
        id: footer
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        inPopout: root.inPopout
        dirty: root.dirty
        menuOpen: root.showMenu
        infoOpen: root.showPathInfo
        markdown: root.editor.markdownText
        onSaveRequested: root.saveNow()
        onOpenRequested: root.openFile()
        onNewRequested: root.newNote()
        onPopoutRequested: root.popoutRequested()
        onDockRequested: root.dockRequested()
        onMenuToggled: {
            const open = !root.showMenu;
            root.closePopups();
            root.showMenu = open;
        }
        onInfoToggled: {
            const open = !root.showPathInfo;
            root.closePopups();
            root.showPathInfo = open;
        }
    }

    PathInfoPopup {
        visible: root.showPathInfo
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.spacingS
        width: Math.min(root.width, 360)
        path: store.currentPath
    }

    NoteMenu {
        visible: root.showMenu
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.spacingS
        sourceMode: root.editor.sourceMode
        confirmDelete: root.confirmDelete
        onTriggered: action => root.runMenuAction(action)
    }

    NoteFileDialogs {
        id: dialogs
        defaultSaveName: {
            const m = root.editor.markdownText.match(/^#\s+(.+)$/m);
            return (m ? store.slugify(m[1]) : "nota") + ".md";
        }
        onFileOpened: path => {
            store.openPath(path);
            root.focusEditor();
        }
        onFileSaved: path => {
            const target = /\.md$/i.test(path) ? path : path + ".md";
            if (store.currentPath)
                root.retargetAssets(store.currentPath, target);
            store.saveAs(target, root.editor.markdown());
            root.focusEditor();
        }
        onImagePicked: path => assets.importFiles(store.currentPath, [path])
    }
}
