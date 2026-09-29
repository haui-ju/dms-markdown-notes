import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string notesDir: "~/Notes"
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string dir: {
        const d = (notesDir || "~/Notes").trim().replace(/^~(?=$|\/)/, home);
        return d.replace(/\/+$/, "");
    }
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/dms-markdown-notes"

    property var tabs: []
    property int currentIndex: -1
    readonly property string currentPath: currentIndex >= 0 && currentIndex < tabs.length ? tabs[currentIndex] : ""
    readonly property string currentName: currentPath ? currentPath.split("/").pop() : ""
    readonly property bool currentIsAutoNamed: autoNamePattern.test(currentName)

    property string lastSavedContent: ""
    property real lastWriteAt: 0
    property bool _externalReloadPending: false
    property bool sessionLoaded: false

    signal noteLoaded(string content)
    signal externalChange(string content)
    signal moved(string from, string to)

    readonly property var autoNamePattern: /^nota-\d{4}-\d{2}-\d{2}-\d{6}(-\d+)?\.md$/

    visible: false

    function assetsFolder(path) {
        return path.replace(/\.[^.\/]+$/, "");
    }

    function titleOf(path) {
        return path.split("/").pop().replace(/\.md$/i, "");
    }

    function ensureDirs() {
        Quickshell.execDetached(["mkdir", "-p", dir, stateDir]);
    }

    function _load(path) {
        fileView.path = "";
        fileView.path = path;
        fileView.waitForJob();
        const content = fileView.text() || "";
        lastSavedContent = content;
        noteLoaded(content);
    }

    function switchTo(index) {
        if (index < 0 || index >= tabs.length)
            return;
        currentIndex = index;
        _load(tabs[index]);
        saveSession();
    }

    function openPath(path) {
        if (!path)
            return;
        const i = tabs.indexOf(path);
        if (i >= 0) {
            switchTo(i);
            return;
        }
        tabs = tabs.concat([path]);
        switchTo(tabs.length - 1);
    }

    function create() {
        ensureDirs();
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd-HHmmss");
        let name = "nota-" + stamp + ".md";
        let n = 1;
        while (tabs.indexOf(dir + "/" + name) >= 0)
            name = "nota-" + stamp + "-" + (n++) + ".md";
        openPath(dir + "/" + name);
    }

    function ensureTab() {
        if (tabs.length === 0)
            create();
        else if (currentIndex < 0)
            switchTo(0);
    }

    function closeTab(index) {
        if (index < 0 || index >= tabs.length)
            return;
        const next = tabs.slice();
        next.splice(index, 1);
        tabs = next;
        if (tabs.length === 0) {
            currentIndex = -1;
            create();
            return;
        }
        const target = index < currentIndex ? currentIndex - 1 : Math.min(currentIndex, tabs.length - 1);
        currentIndex = -1;
        switchTo(target);
    }

    function save(content) {
        if (!currentPath || content === lastSavedContent)
            return;
        lastSavedContent = content;
        lastWriteAt = Date.now();
        fileView.setText(content);
        if (currentIsAutoNamed)
            maybeRenameFromTitle(content);
    }

    function trashCurrent() {
        const path = currentPath;
        if (!path)
            return;
        Quickshell.execDetached(["sh", "-c", 'gio trash -- "$1"; [ -d "$2" ] && gio trash -- "$2"', "sh", path, assetsFolder(path)]);
        closeTab(currentIndex);
    }

    function slugify(title) {
        return title.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").substring(0, 60);
    }

    function renameCurrent(newTitle) {
        const slug = (newTitle || "").trim().replace(/\.md$/i, "").replace(/[\/\\]/g, "-");
        if (!slug || !currentPath)
            return;
        const folder = currentPath.substring(0, currentPath.lastIndexOf("/"));
        _moveCurrent(folder + "/" + slug + ".md", false);
    }

    function saveAs(path, content) {
        if (!path)
            return;
        if (!/\.md$/i.test(path))
            path += ".md";
        const old = currentPath;
        lastSavedContent = content;
        lastWriteAt = Date.now();
        fileView.path = path;
        fileView.setText(content);
        const next = tabs.slice();
        next[currentIndex] = path;
        tabs = next;
        saveSession();
        if (!old || old === path)
            return;
        const temporary = autoNamePattern.test(old.split("/").pop());
        Quickshell.execDetached(["sh", "-c", '[ -d "$1" ] && [ ! -e "$2" ] && if [ "$3" = 1 ]; then mv -n -- "$1" "$2"; else cp -r -- "$1" "$2"; fi', "sh", assetsFolder(old), assetsFolder(path), temporary ? "1" : "0"]);
        if (temporary)
            Quickshell.execDetached(["rm", "-f", "--", old]);
    }

    function maybeRenameFromTitle(content) {
        const m = content.match(/^#\s+(.+)$/m);
        if (!m)
            return;
        const slug = slugify(m[1]);
        if (slug)
            _moveCurrent(dir + "/" + slug + ".md", true);
    }

    function _moveCurrent(target, uniquify) {
        if (target === currentPath)
            return;
        const moveAssets = 's="${1%.*}"; d="${t%.*}"; [ -d "$s" ] && [ ! -e "$d" ] && mv -n -- "$s" "$d"; printf %s "$t"';
        renameProc.source = currentPath;
        renameProc.target = target;
        renameProc.index = currentIndex;
        renameProc.command = uniquify ? ["sh", "-c", 't="$2"; b="${t%.md}"; n=2; while [ -e "$t" ]; do t="$b-$n.md"; n=$((n+1)); done; mv -n -- "$1" "$t" || exit 1; ' + moveAssets, "sh", currentPath, target] : ["sh", "-c", 't="$2"; [ -e "$t" ] && exit 3; mv -n -- "$1" "$t" || exit 1; ' + moveAssets, "sh", currentPath, target];
        renameProc.running = true;
    }

    function saveSession() {
        if (!sessionLoaded)
            return;
        sessionFile.setText(JSON.stringify({
            tabs: tabs,
            current: currentIndex
        }, null, 2));
    }

    function loadSession() {
        let data = {};
        try {
            data = JSON.parse(sessionFile.text() || "{}");
        } catch (e) {
            data = {};
        }
        tabs = Array.isArray(data.tabs) ? data.tabs.filter(p => typeof p === "string" && p) : [];
        sessionLoaded = true;
        if (tabs.length > 0)
            switchTo(Math.max(0, Math.min(data.current || 0, tabs.length - 1)));
    }

    Component.onCompleted: ensureDirs()
    onDirChanged: ensureDirs()

    FileView {
        id: sessionFile
        path: root.stateDir + "/session.json"
        blockLoading: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            if (!root.sessionLoaded)
                root.loadSession();
        }
        onLoadFailed: {
            if (!root.sessionLoaded)
                root.loadSession();
        }
    }

    FileView {
        id: fileView
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: true
        printErrors: false

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
        property string source: ""
        property string target: ""
        property int index: -1
        stdout: StdioCollector {
            id: renameOut
        }
        onExited: code => {
            if (code !== 0)
                return;
            const newPath = renameOut.text.trim() || target;
            const next = root.tabs.slice();
            if (index >= 0 && index < next.length) {
                next[index] = newPath;
                root.tabs = next;
            }
            if (index === root.currentIndex)
                fileView.path = newPath;
            root.saveSession();
            root.moved(source, newPath);
        }
    }
}
