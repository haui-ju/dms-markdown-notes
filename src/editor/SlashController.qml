import QtQuick
import "logic/slash.js" as Slash

QtObject {
    id: root

    required property var editor
    property bool active: false
    property int start: -1
    property string query: ""
    property int index: 0
    property bool inTable: false
    property var items: []

    function canOpenAt(pos) {
        if (editor.code.at(pos))
            return false;
        return pos === 0 || /[\s\u00A0\u2029\uFDD0\uFDD1]/.test(editor.plain().charAt(pos - 1));
    }

    function open(pos) {
        start = pos;
        query = "";
        index = 0;
        inTable = editor.table.locate(pos) !== null;
        items = inTable ? Slash.TABLE : Slash.BLOCKS;
        active = true;
    }

    function close() {
        if (!active)
            return;
        active = false;
        start = -1;
        query = "";
        index = 0;
        items = [];
    }

    function refresh() {
        if (!active)
            return;
        const pos = editor.cursorPosition;
        if (pos < start || start >= editor.length || editor.getText(start, start + 1) !== "/") {
            close();
            return;
        }
        const q = editor.getText(start + 1, Math.max(pos, start + 1));
        if (q.length > Slash.MAX_QUERY || /[\u2029\uFDD0\uFDD1\u2028]/.test(q)) {
            close();
            return;
        }
        const found = Slash.filter(inTable ? Slash.TABLE : Slash.BLOCKS, q);
        if (found.length === 0) {
            close();
            return;
        }
        if (q !== query)
            index = 0;
        query = q;
        items = found;
    }

    function move(delta) {
        if (items.length > 0)
            index = (index + delta + items.length) % items.length;
    }

    function accept(i) {
        const cmd = items[i === undefined ? index : i];
        const from = start;
        const to = start + 1 + query.length;
        close();
        if (!cmd)
            return false;
        editor.removeText(from, to);
        editor.runCommand(cmd.id);
        return true;
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Up:
            move(-1);
            return true;
        case Qt.Key_Down:
            move(1);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Tab:
            return items.length > 0 ? accept() : (close(), false);
        case Qt.Key_Escape:
            close();
            return true;
        }
        return false;
    }
}
