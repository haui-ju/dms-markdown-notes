import QtQuick
import Quickshell.Io
import "../editor/logic/links.js" as Links

Item {
    id: root

    property string dir: ""

    signal resolved(string path)
    signal failed(string message)

    visible: false

    function open(target, fromPath) {
        if (proc.running || Links.safeTarget(target) === "")
            return;
        proc.step = "find";
        proc.target = target;
        proc.from = fromPath;
        proc.command = Links.findCommand(dir, target);
        proc.running = true;
    }

    function _create(target) {
        const path = Links.newPath(dir, target);
        proc.step = "create";
        proc.path = path;
        proc.command = ["sh", "-c", 'mkdir -p -- "${1%/*}" && { [ -e "$1" ] || printf "# %s\\n" "$2" > "$1"; }', "sh", path, Links.safeTarget(target).split("/").pop()];
        proc.running = true;
    }

    Process {
        id: proc
        property string step: ""
        property string target: ""
        property string from: ""
        property string path: ""
        stdout: StdioCollector {
            id: out
        }
        onExited: code => {
            if (proc.step === "find") {
                const found = Links.pick(out.text, root.dir, proc.target, proc.from);
                if (found !== "")
                    root.resolved(found);
                else
                    Qt.callLater(root._create, proc.target);
            } else if (code === 0) {
                root.resolved(proc.path);
            } else {
                root.failed("No se pudo crear la nota «" + proc.target + "»");
            }
        }
    }
}
