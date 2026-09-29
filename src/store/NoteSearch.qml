import QtQuick
import Quickshell.Io
import "search.js" as Search

Item {
    id: root

    property string dir: ""
    property string query: ""
    property var results: []
    property string resultsQuery: ""
    property bool _again: false
    readonly property bool busy: proc.running || debounce.running
    readonly property bool tooShort: query.trim().length < Search.MIN_QUERY

    visible: false

    function search(text) {
        query = text;
        debounce.restart();
    }

    function refresh() {
        debounce.stop();
        _run();
    }

    function _run() {
        const q = query.trim();
        if (q.length < Search.MIN_QUERY || dir === "") {
            results = [];
            resultsQuery = q;
            return;
        }
        if (proc.running) {
            _again = true;
            return;
        }
        proc.query = q;
        proc.command = Search.command(dir, q);
        proc.running = true;
    }

    Timer {
        id: debounce
        interval: 180
        onTriggered: root._run()
    }

    Process {
        id: proc
        property string query: ""
        stdout: StdioCollector {
            id: out
        }
        onExited: code => {
            if (root._again || proc.query !== root.query.trim()) {
                root._again = false;
                Qt.callLater(root._run);
                return;
            }
            root.results = code === 0 ? Search.parse(out.text, root.dir) : [];
            root.resultsQuery = proc.query;
        }
    }
}
