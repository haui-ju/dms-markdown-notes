import QtQuick
import Quickshell.Io
import "search.js" as Search
import "../editor/logic/tags.js" as Tags

Item {
    id: root

    property string dir: ""
    property string query: ""
    property var results: []
    property string resultsQuery: ""
    property bool _again: false
    readonly property bool busy: proc.running || debounce.running
    readonly property bool listingTags: query.trim() === "#"
    readonly property bool tooShort: query.trim().length < Search.MIN_QUERY && !listingTags

    visible: false

    function search(text) {
        query = text;
        debounce.restart();
    }

    function refresh() {
        debounce.stop();
        _run();
    }

    function _command(q) {
        if (q === "#")
            return Tags.listCommand(dir);
        const tag = Tags.fromQuery(q);
        return tag !== "" ? Tags.searchCommand(dir, tag, Search.PER_FILE) : Search.command(dir, q);
    }

    function _run() {
        const q = query.trim();
        if ((q.length < Search.MIN_QUERY && q !== "#") || dir === "") {
            results = [];
            resultsQuery = q;
            return;
        }
        if (proc.running) {
            _again = true;
            return;
        }
        proc.query = q;
        proc.command = _command(q);
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
            if (code !== 0)
                root.results = [];
            else if (proc.query === "#")
                root.results = Tags.parseList(out.text);
            else
                root.results = Search.parse(out.text, root.dir);
            root.resultsQuery = proc.query;
        }
    }
}
