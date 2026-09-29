import QtQuick
import Quickshell.Io

Item {
    id: root

    readonly property bool busy: historyProc.running || saveProc.running
    readonly property var extensions: ({
            "image/png": "png",
            "image/jpeg": "jpg",
            "image/gif": "gif",
            "image/webp": "webp",
            "image/bmp": "bmp",
            "image/svg+xml": "svg"
        })

    signal imported(var sources)
    signal failed(string message)

    visible: false

    function folderFor(notePath) {
        return notePath.replace(/\.[^.\/]+$/, "");
    }

    function sourceFor(notePath, name) {
        return folderFor(notePath).split("/").pop() + "/" + name;
    }

    function pasteClipboard(notePath) {
        if (!notePath || busy)
            return;
        historyProc.notePath = notePath;
        historyProc.running = true;
    }

    function importFiles(notePath, paths) {
        if (!notePath || busy || paths.length === 0)
            return;
        saveProc.notePath = notePath;
        saveProc.command = ["sh", "-c", 'dir="$1"; shift; mkdir -p -- "$dir" || exit 1; for src in "$@"; do [ -f "$src" ] || continue; case "$src" in "$dir"/*) printf "%s\\n" "${src#"$dir"/}"; continue;; esac; name=$(basename -- "$src" | tr " " "-"); base="${name%.*}"; ext="${name##*.}"; f="$name"; n=2; while [ -e "$dir/$f" ]; do f="$base-$n.$ext"; n=$((n+1)); done; cp -- "$src" "$dir/$f" && printf "%s\\n" "$f"; done', "sh", folderFor(notePath)].concat(paths);
        saveProc.running = true;
    }

    function _saveClipboardEntry(notePath, entry) {
        saveProc.notePath = notePath;
        saveProc.command = ["sh", "-c", 'mkdir -p -- "$1" || exit 1; base="imagen-$(date +%Y%m%d-%H%M%S)"; f="$base.$3"; n=2; while [ -e "$1/$f" ]; do f="$base-$n.$3"; n=$((n+1)); done; dms clipboard get "$2" | base64 -d > "$1/$f" && [ -s "$1/$f" ] && printf "%s\\n" "$f" || { rm -f -- "$1/$f"; exit 1; }', "sh", folderFor(notePath), String(entry.id), extensions[entry.mimeType] || "png"];
        saveProc.running = true;
    }

    Process {
        id: historyProc

        property string notePath: ""

        command: ["dms", "clipboard", "history", "--json"]
        stdout: StdioCollector {
            id: historyOut
        }
        onExited: code => {
            let entry = null;
            try {
                const list = JSON.parse(historyOut.text || "[]");
                entry = Array.isArray(list) && list.length > 0 ? list[0] : null;
            } catch (e) {
                entry = null;
            }
            if (code !== 0 || !entry || !entry.isImage) {
                root.failed("El portapapeles no tiene una imagen");
                return;
            }
            root._saveClipboardEntry(notePath, entry);
        }
    }

    Process {
        id: saveProc

        property string notePath: ""

        stdout: StdioCollector {
            id: saveOut
        }
        onExited: code => {
            const names = saveOut.text.split("\n").filter(n => n !== "");
            if (code !== 0 || names.length === 0) {
                root.failed("No se pudo guardar la imagen");
                return;
            }
            root.imported(names.map(n => root.sourceFor(notePath, n)));
        }
    }
}
