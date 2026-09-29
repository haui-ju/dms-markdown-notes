import QtQuick
import "logic/markdown.js" as Md
import "logic/tables.js" as Tables

TextEdit {
    id: root

    property bool sourceMode: false
    property int revision: 0
    property string markdownText: ""
    property color decorationBackground: "transparent"
    property color accentColor: "#8ab4f8"
    property color checkMarkColor: "#000000"
    property color ruleColor: Qt.rgba(color.r, color.g, color.b, 0.18)
    readonly property alias slash: slashController
    readonly property alias table: tableController
    property var _tasks: []
    property var _rules: []
    property int _plainAfterFormatPos: -1
    property bool _loading: false

    signal edited
    signal rewriteStarted
    signal rewriteFinished

    textFormat: sourceMode ? TextEdit.PlainText : TextEdit.MarkdownText
    wrapMode: TextEdit.Wrap
    selectByMouse: true
    persistentSelection: true
    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

    onTextChanged: {
        revision++;
        markdownText = sourceMode ? text : Tables.repair(text, plain());
        decorationTimer.restart();
        slashController.refresh();
        tableController.refresh();
        if (!_loading)
            edited();
    }
    onCursorPositionChanged: {
        slashController.refresh();
        tableController.refresh();
    }
    onWidthChanged: decorationTimer.restart()
    onContentHeightChanged: decorationTimer.restart()
    onSourceModeChanged: decorationTimer.restart()

    SlashController {
        id: slashController
        editor: root
    }

    TableController {
        id: tableController
        editor: root
    }

    Timer {
        id: decorationTimer
        interval: 30
        onTriggered: root.refreshDecorations()
    }

    Repeater {
        model: root._rules
        delegate: RuleDecoration {
            editor: root
        }
    }

    Repeater {
        model: root._tasks
        delegate: TaskDecoration {
            editor: root
        }
    }

    function refreshDecorations() {
        const d = decorations();
        _tasks = d ? d.tasks : [];
        _rules = d ? d.rules : [];
        tableController.refresh();
    }

    function decorations() {
        return sourceMode ? null : Md.decorations(markdownText, plain());
    }

    function _assign(md) {
        if (md !== "") {
            text = sourceMode ? md : Tables.prepare(md);
            return;
        }
        text = Md.MARKER;
        remove(0, length);
    }

    function load(md) {
        slashController.close();
        _loading = true;
        _assign(md);
        _loading = false;
        cursorPosition = 0;
    }

    function markdown() {
        return markdownText.replace(/\uE000/g, "");
    }

    function setSourceMode(on) {
        if (on === sourceMode)
            return;
        slashController.close();
        const md = markdownText;
        const pos = cursorPosition;
        _loading = true;
        sourceMode = on;
        _assign(md);
        _loading = false;
        cursorPosition = on ? 0 : Math.min(pos, length);
    }

    function plain() {
        return getText(0, length);
    }

    function blockRange(pos) {
        return Md.blockRange(plain(), pos);
    }

    function currentBlock() {
        return blockRange(cursorPosition);
    }

    function removeText(from, to) {
        _loading = true;
        remove(from, to);
        _loading = false;
        cursorPosition = from;
    }

    function replaceMarkdown(md, placeCursor) {
        slashController.close();
        rewriteStarted();
        _loading = true;
        _assign(md);
        placeCursor();
        _loading = false;
        rewriteFinished();
        edited();
    }

    function _dropMarker() {
        const p = plain().indexOf(Md.MARKER);
        if (p >= 0)
            remove(p, p + 1);
        return p;
    }

    function rewriteLineAt(pos, fn) {
        const block = blockRange(pos);
        const shift = (pos === block.start && block.text.length > 0) ? 1 : 0;
        slashController.close();
        _loading = true;
        insert(pos + shift, Md.MARKER);
        const lines = markdownText.split("\n");
        const found = lines.findIndex(l => l.indexOf(Md.MARKER) >= 0);
        const idx = found < 0 ? -1 : Md.joinParagraph(lines, found);
        const result = idx < 0 ? null : fn(lines[idx], Md.parseLine(lines[idx]));
        if (result === null || result === undefined) {
            _dropMarker();
            cursorPosition = pos;
            _loading = false;
            return false;
        }
        rewriteStarted();
        lines[idx] = result;
        _assign(lines.join("\n"));
        const p = _dropMarker();
        if (p >= 0)
            cursorPosition = Math.max(0, p - shift);
        _loading = false;
        rewriteFinished();
        edited();
        return true;
    }

    function tryBlockShortcut() {
        const block = currentBlock();
        const prefix = plain().substring(block.start, cursorPosition);
        if (!/^(#{1,3}|[-*+]|\d+[.)]|>|\[ ?\]|\[[xX]\])$/.test(prefix))
            return false;
        return rewriteLineAt(cursorPosition, (line, p) => {
            const after = p.list ? p.rest.substring(p.rest.indexOf(Md.MARKER)) : line.substring(line.indexOf(Md.MARKER));
            const state = /x/i.test(prefix) ? "x" : " ";
            if (p.list)
                return p.task || !/^\[[ xX]?\]$/.test(prefix) ? null : p.indent + p.bullet + " [" + state + "] " + after;
            if (/^#{1,3}$/.test(prefix))
                return prefix + " " + after;
            if (/^[-*+]$/.test(prefix))
                return "- " + after;
            if (/^\d+[.)]$/.test(prefix))
                return prefix.replace(")", ".") + " " + after;
            if (prefix === ">")
                return "> " + after;
            return "- [" + state + "] " + after;
        });
    }

    function _insertBlock(markup) {
        const block = currentBlock();
        if (block.text.length > 0)
            cursorPosition = block.end;
        return rewriteLineAt(cursorPosition, (line, p) => {
            const keep = Md.blockContent(line, p).trim() !== "" ? line.replace(Md.MARKER, "") + "\n\n" : "";
            return keep + markup;
        });
    }

    function insertRule() {
        return _insertBlock("---\n\n" + Md.MARKER);
    }

    function insertCodeBlock() {
        return _insertBlock("```\n" + Md.MARKER + "\n```");
    }

    function tryEnterShortcut() {
        const block = currentBlock();
        if (cursorPosition !== block.end)
            return false;
        if (/^(---|\*\*\*|___)$/.test(block.text))
            return rewriteLineAt(cursorPosition, (line, p) => p.list ? null : "---\n\n" + Md.MARKER);
        if (block.text === "```")
            return rewriteLineAt(cursorPosition, (line, p) => p.list ? null : "```\n" + Md.MARKER + "\n```");
        if (block.text === "" || block.text === Md.BLANK)
            return rewriteLineAt(cursorPosition, (line, p) => p.list || /^(#{1,6}\s|>)/.test(line) ? "\n" + Md.MARKER : Md.BLANK + "\n\n" + Md.MARKER);
        return rewriteLineAt(cursorPosition, line => /^#{1,6}\s/.test(line) ? line.replace(Md.MARKER, "") + "\n\n" + Md.MARKER : null);
    }

    function clearBlankLine() {
        const block = currentBlock();
        if (block.text !== Md.BLANK)
            return;
        removeText(block.start, block.end);
    }

    function tryBackspaceShortcut() {
        const block = currentBlock();
        if (block.text === Md.BLANK) {
            _loading = true;
            if (block.start > 0)
                remove(block.start - 1, block.end);
            else
                remove(0, Math.min(length, block.end + 1));
            _loading = false;
            edited();
            return true;
        }
        if (cursorPosition !== block.start)
            return false;
        return rewriteLineAt(cursorPosition, (line, p) => {
            if (p.list)
                return p.rest;
            return /^(#{1,6}\s+|>\s?)/.test(line) ? Md.stripBlockPrefix(line) : null;
        });
    }

    function fixNewTaskItem() {
        if (currentBlock().text !== "")
            return;
        rewriteLineAt(cursorPosition, (line, p) => p.list && /x/i.test(p.task) ? p.indent + p.bullet + " [ ] " + p.rest.substring(p.rest.indexOf(Md.MARKER)) : null);
    }

    function _wrapBefore(pos, literal, inner, wrap) {
        const re = new RegExp(Md.literalPattern(literal) + Md.MARKER);
        return rewriteLineAt(pos, line => re.test(line) ? line.replace(re, wrap + Md.escape(inner) + wrap + Md.MARKER) : null);
    }

    function tryInlineShortcut(typed) {
        const block = currentBlock();
        const found = Md.findInline(plain().substring(block.start, cursorPosition) + typed);
        if (!found)
            return false;
        const literal = found.wrap + found.inner + found.wrap.substring(0, found.wrap.length - typed.length);
        if (!_wrapBefore(cursorPosition, literal, found.inner, found.wrap))
            return false;
        _plainAfterFormatPos = cursorPosition;
        return true;
    }

    function wrapSelection(wrap) {
        if (sourceMode || selectionStart === selectionEnd)
            return false;
        const s = selectionStart;
        const e = selectionEnd;
        const inner = getText(s, e);
        if (/[\u2029\uFDD0\uFDD1]/.test(inner))
            return false;
        deselect();
        if (!_wrapBefore(e, inner, inner, wrap))
            return false;
        select(cursorPosition - inner.length, cursorPosition);
        return true;
    }

    function _removeStrayMarker() {
        const cur = cursorPosition;
        _loading = true;
        const p = _dropMarker();
        _loading = false;
        if (p >= 0)
            cursorPosition = cur > p ? cur - 1 : cur;
    }

    function setBlockType(type, toggle) {
        if (sourceMode || tableController.locate(cursorPosition))
            return false;
        return rewriteLineAt(cursorPosition, (line, p) => {
            const rest = Md.stripBlockPrefix(p.list ? p.rest : line);
            const indent = p.indent || "";
            switch (type) {
            case "h1":
                return "# " + rest;
            case "h2":
                return "## " + rest;
            case "h3":
                return "### " + rest;
            case "bullet":
                return indent + "- " + rest;
            case "number":
                return indent + "1. " + rest;
            case "task":
                return p.list && p.task && toggle !== false ? indent + "- " + rest : indent + "- [ ] " + rest;
            case "quote":
                return "> " + rest;
            default:
                return rest;
            }
        });
    }

    function runCommand(id) {
        switch (id) {
        case "table":
            return tableController.insert();
        case "rule":
            return insertRule();
        case "code":
            return insertCodeBlock();
        case "rowAdd":
            return tableController.addRow();
        case "columnAdd":
            return tableController.addColumn();
        case "rowRemove":
            return tableController.removeRow();
        case "columnRemove":
            return tableController.removeColumn();
        case "tableRemove":
            return tableController.remove();
        default:
            return setBlockType(id, false);
        }
    }

    function toggleTaskAt(pos) {
        if (sourceMode || tableController.locate(pos))
            return false;
        return rewriteLineAt(pos, (line, p) => {
            if (!p.list || !p.task)
                return null;
            return p.indent + p.bullet + " [" + (/x/i.test(p.task) ? " " : "x") + "] " + p.rest;
        });
    }

    function isMarkerHit(x, y) {
        const pos = positionAt(x, y);
        if (tableController.locate(pos))
            return -1;
        const block = blockRange(pos);
        const r = positionToRectangle(block.start);
        if (y < r.y || y > r.y + r.height || x >= r.x - 2)
            return -1;
        return block.start;
    }

    function _handleCtrl(key, shift) {
        switch (key) {
        case Qt.Key_B:
            return wrapSelection("**");
        case Qt.Key_I:
            return wrapSelection("*");
        case Qt.Key_E:
            return wrapSelection("`");
        case Qt.Key_1:
            return setBlockType("h1");
        case Qt.Key_2:
            return setBlockType("h2");
        case Qt.Key_3:
            return setBlockType("h3");
        case Qt.Key_0:
            return setBlockType("p");
        case Qt.Key_L:
            return setBlockType(shift ? "bullet" : "task");
        case Qt.Key_O:
            return shift && setBlockType("number");
        }
        return false;
    }

    Keys.onShortcutOverride: event => {
        if (slashController.active && event.key === Qt.Key_Escape)
            event.accepted = true;
    }

    Keys.onPressed: event => {
        if (sourceMode)
            return;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const alt = (event.modifiers & Qt.AltModifier) !== 0;
        const collapsed = selectionStart === selectionEnd;
        const printable = !ctrl && !alt && event.text.length === 1 && event.text.charCodeAt(0) >= 32;

        if (slashController.active && slashController.handleKey(event)) {
            event.accepted = true;
            return;
        }

        if (_plainAfterFormatPos >= 0) {
            const armedPos = _plainAfterFormatPos;
            _plainAfterFormatPos = -1;
            if (printable && cursorPosition === armedPos && collapsed) {
                _loading = true;
                insert(armedPos, Md.MARKER);
                cursorPosition = armedPos + 1;
                _loading = false;
                Qt.callLater(_removeStrayMarker);
                return;
            }
        }

        if (ctrl && !alt) {
            event.accepted = _handleCtrl(event.key, shift);
            return;
        }

        const cell = tableController.locateSelection();
        if (cell && tableController.handleKey(event, cell)) {
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Space && !alt) {
            if (collapsed && !cell && tryBlockShortcut())
                event.accepted = true;
            return;
        }

        if (printable && collapsed) {
            clearBlankLine();
            if (event.text === "/" && slashController.canOpenAt(cursorPosition))
                slashController.open(cursorPosition);
        }

        if (event.key === Qt.Key_Backspace && !alt && collapsed) {
            if (!cell && tryBackspaceShortcut())
                event.accepted = true;
            return;
        }

        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !shift) {
            if (collapsed && tryEnterShortcut()) {
                event.accepted = true;
                return;
            }
            Qt.callLater(fixNewTaskItem);
            return;
        }

        if ((event.text === "*" || event.text === "`" || event.text === "~") && collapsed && tryInlineShortcut(event.text))
            event.accepted = true;
    }
}
