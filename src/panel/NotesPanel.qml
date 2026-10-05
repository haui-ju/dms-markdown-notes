import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "../store"
import "../editor/logic/images.js" as Images
import "../editor/logic/links.js" as Links
import "../store/search.js" as Search

Item {
    id: root

    property var pluginData: ({})
    property bool inPopout: false
    property bool active: false
    property bool showPathInfo: false
    property bool showMenu: false
    property bool confirmDelete: false
    property bool showSearch: false
    property var pendingMatch: null
    property var histories: ({})
    property string historyPath: ""
    property string tabLayout: String(root.pluginData.tabLayout || "horizontal")
    readonly property bool verticalTabs: tabLayout === "vertical"

    onVerticalTabsChanged: resetTabsUi()

    Connections {
        target: root
        function onPluginDataChanged() {
            const next = String(root.pluginData.tabLayout || "horizontal");
            if (next === root.tabLayout)
                return;
            root.resetTabsUi();
            root.tabLayout = next;
        }
    }
    readonly property int verticalNavWidth: 188
    readonly property int verticalNavGap: Theme.spacingXS
    readonly property int horizontalTabBand: 36
    readonly property int slideoutExtraWidth: verticalTabs && !inPopout ? verticalNavWidth + verticalNavGap : 0
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
        showSearch = false;
        confirmDelete = false;
    }

    function resetTabsUi() {
        tabsHorizontal.cancelTabDrag();
        tabsVertical.cancelTabDrag();
        tabsHorizontal.overflowOpen = false;
        tabsVertical.overflowOpen = false;
        tabsHorizontal.editingIndex = -1;
        tabsVertical.editingIndex = -1;
    }

    function openSearch(text) {
        flushSave();
        closePopups();
        showSearch = true;
        searchPopup.open(text);
    }

    function closeSearch() {
        closePopups();
        focusEditor();
    }

    function toggleSearch() {
        if (showSearch)
            closeSearch();
        else
            openSearch();
    }

    function openMatch(path, line, query) {
        closePopups();
        flushSave();
        pendingMatch = {
            path: path,
            line: line,
            query: query
        };
        if (path === store.currentPath)
            applyMatch();
        else
            store.openPath(path);
        focusEditor();
    }

    function applyMatch() {
        const m = pendingMatch;
        pendingMatch = null;
        if (!m || m.path !== store.currentPath)
            return;
        let pos;
        if (editor.sourceMode) {
            pos = Search.lineOffset(editor.text, m.line, m.query);
        } else {
            const k = Search.occurrence(editor.markdown(), m.line, m.query);
            pos = k < 0 ? -1 : Search.find(editor.plain(), m.query, k);
        }
        if (pos >= 0)
            editor.select(pos, Math.min(pos + m.query.length, editor.length));
    }

    function flushSave() {
        if (!saveTimer.running)
            return;
        saveTimer.stop();
        store.save(editor.exportMarkdown());
    }

    function saveNow() {
        saveTimer.stop();
        if (store.currentIsAutoNamed && editor.markdown().trim() !== "") {
            dialogs.saveAs();
            return;
        }
        store.save(editor.exportMarkdown());
    }

    function newNote() {
        flushSave();
        store.create();
        focusEditor();
    }

    function openNote(target) {
        const path = Links.notePath(store.dir, store.home, target);
        if (path === "")
            return "";
        flushSave();
        closePopups();
        Quickshell.execDetached(["mkdir", "-p", "--", path.substring(0, path.lastIndexOf("/"))]);
        store.openPath(path);
        focusEditor();
        return path;
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
        Qt.callLater(() => {
            editor.relayoutDecorations();
            if (editor.width > 0 && editor.imageMaxWidth > 0)
                editor._relayoutImages();
            focusEditor();
        });
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
        case "search":
            openSearch();
            break;
        case "source":
            toggleSource();
            break;
        case "repair":
            ToastService.showInfo("Código reparado: " + editor.repairEscapedCode() + " cambios");
            focusEditor();
            break;
        case "rename":
            tabsVertical.editingIndex = store.currentIndex;
            tabsHorizontal.editingIndex = store.currentIndex;
            break;
        case "folder":
            Quickshell.execDetached(["xdg-open", store.dir]);
            break;
        case "toggleLayout":
            resetTabsUi();
            tabLayout = verticalTabs ? "horizontal" : "vertical";
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

        function onWikiLinkActivated(target) {
            links.open(target, store.currentPath);
        }

        function onTagActivated(tag) {
            root.openSearch("#" + tag);
        }

        function onImageActivated(pos, url, src, alt) {
            let name = src.split("/").pop();
            try {
                name = decodeURIComponent(name);
            } catch (e) {}
            imageViewer.show(pos, url, name, true, Images.captionText(alt));
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

    NoteLinks {
        id: links
        dir: store.dir
        onResolved: path => {
            root.flushSave();
            store.openPath(path);
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
            Qt.callLater(() => root.editor.relayoutDecorations());
            root.historyPath = store.currentPath;
            for (const path in root.histories) {
                if (store.tabs.indexOf(path) < 0)
                    delete root.histories[path];
            }
            root.closePopups();
            if (root.pendingMatch)
                Qt.callLater(root.applyMatch);
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
        onTriggered: store.save(root.editor.exportMarkdown())
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
        sequence: "Ctrl+F"
        onActivated: root.toggleSearch()
    }

    Shortcut {
        enabled: root.active
        sequence: "Escape"
        onActivated: {
            if (root.editor.slash.active)
                root.editor.slash.close();
            else if (root.showSearch)
                root.closeSearch();
            else if (root.editor.imageController.menuTarget)
                root.editor.imageController.closeMenu();
            else if (root.showMenu || root.showPathInfo)
                root.closePopups();
            else
                root.hideRequested();
        }
    }

    MouseArea {
        id: tabDragCapture
        anchors.fill: parent
        z: 600
        enabled: tabsVertical.dragActive || tabsHorizontal.dragActive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        preventStealing: true
        propagateComposedEvents: false
        onPositionChanged: mouse => {
            if (tabsVertical.dragActive)
                tabsVertical.hostDragMove(mouse.x, mouse.y);
            else if (tabsHorizontal.dragActive)
                tabsHorizontal.hostDragMove(mouse.x, mouse.y);
        }
        onReleased: mouse => {
            if (tabsVertical.dragActive)
                tabsVertical.hostDragEnd(mouse.x, mouse.y);
            else if (tabsHorizontal.dragActive)
                tabsHorizontal.hostDragEnd(mouse.x, mouse.y);
        }
        onCanceled: root.resetTabsUi()
    }

    Item {
        id: body
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top

        NoteTabs {
            id: tabsVertical
            visible: root.verticalTabs
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: root.verticalNavWidth
            navWidth: root.verticalNavWidth
            vertical: true
            dragHost: root
            store: store
            dirty: root.dirty
            onSwitchRequested: index => root.switchTab(index)
            onCloseRequested: index => root.closeTab(index)
            onRenameRequested: (index, title) => store.renameAt(index, title)
            onNewRequested: root.newNote()
            onEditingFinished: root.focusEditor()
        }

        NoteTabs {
            id: tabsHorizontal
            visible: !root.verticalTabs
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 36
            navWidth: root.verticalNavWidth
            vertical: false
            dragHost: root
            overflowHost: body
            store: store
            dirty: root.dirty
            onSwitchRequested: index => root.switchTab(index)
            onCloseRequested: index => root.closeTab(index)
            onRenameRequested: (index, title) => store.renameAt(index, title)
            onNewRequested: root.newNote()
            onEditingFinished: root.focusEditor()
        }
    }

    EditorView {
        id: editorView
        z: 1
        anchors.top: body.top
        anchors.bottom: footer.top
        anchors.left: body.left
        anchors.leftMargin: root.verticalTabs ? root.verticalNavWidth + root.verticalNavGap : 0
        anchors.right: body.right
        anchors.topMargin: Theme.spacingS + (root.verticalTabs ? 0 : root.horizontalTabBand)
        anchors.bottomMargin: Theme.spacingS
        fontFamily: String(root.pluginData.noteFont ?? "Noto Sans").trim()
        onEdited: saveTimer.restart()
        onWidthChanged: {
            if (width > 0)
                Qt.callLater(editor.relayoutDecorations);
        }
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
        verticalTabs: root.verticalTabs
        confirmDelete: root.confirmDelete
        escapedCode: root.showMenu ? root.editor.escapedCodeCount() : 0
        onTriggered: action => root.runMenuAction(action)
    }

    SearchPopup {
        id: searchPopup
        visible: root.showSearch
        anchors.top: editorView.top
        anchors.left: editorView.left
        anchors.right: editorView.right
        anchors.topMargin: Theme.spacingS
        dir: store.dir
        onPicked: (path, line, query) => root.openMatch(path, line, query)
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
            store.saveAs(target, root.editor.exportMarkdown());
            root.focusEditor();
        }
        onImagePicked: path => assets.importFiles(store.currentPath, [path])
    }
}
