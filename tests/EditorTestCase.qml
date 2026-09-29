import QtQuick
import QtTest
import "../src/editor/logic/tables.js" as Tables

TestCase {
    id: root

    property var editor
    when: windowShown

    function init() {
        editor.setSourceMode(false);
        editor.load("");
        editor.forceActiveFocus();
    }

    function type(str) {
        for (const ch of str) {
            if (ch === " ")
                keyClick(Qt.Key_Space);
            else if (ch === "\n")
                keyClick(Qt.Key_Return);
            else if (ch === "\t")
                keyClick(Qt.Key_Tab);
            else
                keyClick(ch);
            wait(0);
        }
    }

    function md() {
        return editor.markdown().replace(/\n+$/, "");
    }

    function tables() {
        const lines = editor.markdown().split("\n");
        return Tables.find(lines).map(range => Tables.parse(lines, range));
    }

    function table(index) {
        return tables()[index || 0];
    }

    function cellAt(tableIndex, cellIndex) {
        return Tables.scan(editor.plain())[tableIndex].cells[cellIndex];
    }

    function placeInCell(tableIndex, cellIndex) {
        editor.cursorPosition = cellAt(tableIndex, cellIndex).end;
    }

    function cellText(tableIndex, cellIndex) {
        const c = cellAt(tableIndex, cellIndex);
        return editor.getText(c.start, c.end);
    }
}
