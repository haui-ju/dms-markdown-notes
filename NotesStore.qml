import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// Markdown files in a plain folder: listing, loading, saving, creating,
// deleting and renaming auto-named notes after their first heading.
Item {
    id: root

    property string notesDir: "~/Notes"
    readonly property string dir: {
        const home = Quickshell.env("HOME") || "";
        const d = (notesDir || "~/Notes").trim().replace(/^~(?=$|\/)/, home);
        return d.replace(/\/+$/, "");
    }

    property string currentPath: ""
    readonly property string currentName: currentPath ? currentPath.split("/").pop() : ""
    property string lastSavedContent: ""
    property bool saving: false
    property real lastWriteAt: 0
    property bool _externalReloadPending: false

    readonly property alias model: folderModel
    readonly property int count: folderModel.count

    signal noteLoaded(string content)
    signal externalChange(string content)

    readonly property var autoNamePattern: /^nota-\d{4}-\d{2}-\d{2}-\d{6}(-\d+)?\.md$/

    visible: false

    function ensureDir() {
        if (dir)
            Quickshell.execDetached(["mkdir", "-p", dir]);
    }

    function pathAt(index) {
        return index >= 0 && index < folderModel.count ? folderModel.get(index, "filePath") : "";
    }

    function indexOfPath(path) {
        for (let i = 0; i < folderModel.count; i++) {
            if (folderModel.get(i, "filePath") === path)
                return i;
        }
        return -1;
    }

    function open(path) {
        if (!path)
            return;
        currentPath = path;
        fileView.path = "";
        fileView.path = path;
        fileView.waitForJob();
        const content = fileView.text() || "";
        lastSavedContent = content;
        noteLoaded(content);
    }

    property bool _openRecentPending: false

    function openMostRecent() {
        if (folderModel.status !== FolderListModel.Ready && !openRecentFallback.triggeredOnce) {
            _openRecentPending = true;
            openRecentFallback.restart();
            return;
        }
        _openRecentPending = false;
        if (folderModel.count > 0)
            open(pathAt(0));
        else
            create();
    }

    function save(content) {
        if (!currentPath || content === lastSavedContent)
            return;
        saving = true;
        lastSavedContent = content;
        lastWriteAt = Date.now();
        fileView.setText(content);
        saving = false;
        maybeRenameFromTitle(content);
    }

    function create() {
        ensureDir();
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd-HHmmss");
        let name = "nota-" + stamp + ".md";
        let n = 1;
        while (indexOfPath(dir + "/" + name) >= 0)
            name = "nota-" + stamp + "-" + (n++) + ".md";
        const path = dir + "/" + name;
        currentPath = path;
        lastSavedContent = "";
        fileView.path = path;
        fileView.setText("");
        noteLoaded("");
    }

    function trash(path) {
        if (!path)
            return;
        Quickshell.execDetached(["gio", "trash", "--", path]);
        if (path === currentPath) {
            currentPath = "";
            fileView.path = "";
            pickAfterDelete.restart();
        }
    }

    function slugify(title) {
        return title.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9ñ]+/g, "-").replace(/^-+|-+$/g, "").substring(0, 60);
    }

    // Notes created as "nota-<fecha>.md" take the name of their first "# heading".
    function maybeRenameFromTitle(content) {
        if (!autoNamePattern.test(currentName))
            return;
        const m = content.match(/^#\s+(.+)$/m);
        if (!m)
            return;
        const slug = slugify(m[1]);
        if (!slug)
            return;
        let target = dir + "/" + slug + ".md";
        let n = 2;
        while (indexOfPath(target) >= 0)
            target = dir + "/" + slug + "-" + (n++) + ".md";
        renameProc.command = ["mv", "-n", "--", currentPath, target];
        renameProc.target = target;
        renameProc.running = true;
    }

    Component.onCompleted: ensureDir()
    onDirChanged: ensureDir()

    FolderListModel {
        id: folderModel
        folder: root.dir ? "file://" + root.dir : ""
        nameFilters: ["*.md"]
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Time
        sortReversed: false
        onStatusChanged: {
            if (status === FolderListModel.Ready && root._openRecentPending)
                Qt.callLater(root.openMostRecent);
        }
    }

    FileView {
        id: fileView
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: true
        printErrors: false

        // Our own atomic writes also fire fileChanged; only react to foreign edits.
        onFileChanged: {
            if (Date.now() - root.lastWriteAt < 2000)
                return;
            root._externalReloadPending = true;
            reload();
        }

        onLoaded: {
            if (!root._externalReloadPending)
                return;
            root._externalReloadPending = false;
            const content = text();
            if (content === root.lastSavedContent)
                return;
            root.lastSavedContent = content;
            root.externalChange(content);
        }
    }

    Process {
        id: renameProc
        property string target: ""
        onExited: code => {
            if (code === 0) {
                root.currentPath = target;
                fileView.path = target;
            }
        }
    }

    // A folder that does not exist yet never reports Ready.
    Timer {
        id: openRecentFallback
        property bool triggeredOnce: false
        interval: 1500
        onTriggered: {
            triggeredOnce = true;
            if (root._openRecentPending)
                root.openMostRecent();
        }
    }

    Timer {
        id: pickAfterDelete
        interval: 300
        onTriggered: root.openMostRecent()
    }
}
