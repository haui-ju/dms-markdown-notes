import QtQuick
import "logic/markdown.js" as Md
import "logic/tables.js" as Tables
import "logic/code.js" as Code
import "logic/paste.js" as Paste
import "logic/images.js" as Images

TextEdit {
    id: root

    property bool sourceMode: false
    property int revision: 0
    property string markdownText: ""
    property color decorationBackground: "transparent"
    property color accentColor: "#8ab4f8"
    property color checkMarkColor: "#000000"
    property color ruleColor: Qt.rgba(color.r, color.g, color.b, 0.18)
    property color quoteBackground: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.08)
    property color tableBorderColor: Qt.tint(decorationBackground, Qt.rgba(color.r, color.g, color.b, 0.3))
    property var tableLayouts: []
    property color selectionTextColor: "#000000"
    property bool _repaintFlip: false
    property color codeBackground: Qt.tint(decorationBackground, Qt.rgba(color.r, color.g, color.b, 0.06))
    property var codeColors: ({
            keyword: "#c678dd",
            string: "#98c379",
            comment: "#7f848e",
            number: "#d19a66",
            type: "#e5c07b",
            function: "#61afef"
        })
    readonly property string codeFontFamily: "monospace"
    readonly property alias slash: slashController
    readonly property alias table: tableController
    readonly property alias code: codeController
    property var _decorations: null
    property string _decorationsKey: ""
    property var _tasks: []
    property var _rules: []
    property var _quotes: []
    property string _frontMatter: ""
    property int _plainAfterFormatPos: -1
    property int _emptyHeadingPos: -1
    property int _emptyHeadingLevel: 0
    property bool _loading: false
    property bool _flattening: false
    property string imageBaseDir: ""
    property real imageMaxHeight: 480
    property var images: []
    property var _imageSources: ({})
    property var _imageSizes: ({})
    property var _imageIds: ({})
    property int _imageNextId: 1
    property real _imageLayoutWidth: 0
    readonly property int blockGap: Math.round(textMetrics.height * 0.5)
    readonly property real imageMaxWidth: width > 0 ? Math.max(64, width - leftPadding - rightPadding - 2) : 480
    readonly property int historyLimit: 200
    readonly property bool undoAvailable: _undoStack.length > 0 || _groupOpen
    readonly property bool redoAvailable: _redoStack.length > 0 && !_groupOpen
    property var _undoStack: []
    property var _redoStack: []
    property var _committed: ({
            md: "",
            start: 0,
            end: 0
        })
    property bool _groupOpen: false
    property string _groupKind: ""
    property bool _restoring: false
    property int _groupCaret: -1

    signal edited
    onEdited: _noteChange()
    signal rewriteStarted
    signal rewriteFinished
    signal imageActivated(int pos, string url, string src, string alt)
    signal imagePasteRequested
    signal imageFilesPasted(var paths)
    signal imageRequested

    textFormat: sourceMode ? TextEdit.PlainText : TextEdit.MarkdownText
    wrapMode: TextEdit.Wrap
    selectByMouse: true
    persistentSelection: true
    selectedTextColor: Qt.rgba(selectionTextColor.r, selectionTextColor.g, selectionTextColor.b + (_repaintFlip ? (selectionTextColor.b > 0.5 ? -1 : 1) / 255 : 0), selectionTextColor.a)
    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
    tabStopDistance: Math.max(1, monoMetrics.advanceWidth)
    cursorDelegate: Rectangle {
        z: 10
        width: 2
        color: root.color
        visible: root.activeFocus && root._caretOn
    }

    property bool _caretOn: true

    TextMetrics {
        id: monoMetrics
        font.family: root.codeFontFamily
        font.pixelSize: root.font.pixelSize
        text: " ".repeat(Code.TAB_SIZE)
    }

    TextEdit {
        id: plainClipboard
        visible: false
        textFormat: TextEdit.PlainText
    }

    TextEdit {
        id: markdownClipboard
        visible: false
        textFormat: TextEdit.MarkdownText
    }

    FontMetrics {
        id: textMetrics
        font: root.font
    }

    Image {
        id: imageProbe
        visible: false
        asynchronous: false
        cache: false
    }

    Timer {
        id: imageLayoutTimer
        interval: 150
        onTriggered: root._relayoutImages()
    }

    Timer {
        id: historyTimer
        interval: 1000
        onTriggered: root._closeGroup()
    }

    Timer {
        id: caretTimer
        interval: 530
        repeat: true
        running: root.activeFocus
        onTriggered: root._caretOn = !root._caretOn
    }

    onTextChanged: {
        if (_flattening)
            return;
        if (!sourceMode)
            _flattenCells();
        revision++;
        if (sourceMode) {
            markdownText = Md.keepBlankLines(text);
        } else {
            const plainText = plain();
            markdownText = _frontMatter + Md.unpadTrailingRule(Md.repairEmptyHeadings(Images.repair(Code.repair(Tables.repair(text, plainText, tableLayouts)), _imageSources), plainText));
        }
        decorationTimer.restart();
        if (markdownText.indexOf("```") >= 0 || codeController.blocks.length > 0)
            codeController.measure();
        slashController.refresh();
        tableController.refresh();
        if (!_loading)
            edited();
    }
    onCursorPositionChanged: {
        _caretOn = true;
        caretTimer.restart();
        if (!_loading)
            Qt.callLater(codeController.clampCursor);
        slashController.refresh();
        tableController.refresh();
    }
    onSelectionStartChanged: repaintTimer.restart()
    onSelectionEndChanged: repaintTimer.restart()
    onWidthChanged: {
        decorationTimer.restart();
        if (images.length > 0)
            imageLayoutTimer.restart();
    }
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

    CodeController {
        id: codeController
        editor: root
    }

    Timer {
        id: decorationTimer
        interval: 30
        onTriggered: root.refreshDecorations()
    }

    Timer {
        id: repaintTimer
        interval: 60
        onTriggered: root.repaintTables()
    }

    Repeater {
        model: root._rules
        delegate: RuleDecoration {
            editor: root
        }
    }

    Repeater {
        model: root._quotes
        delegate: QuoteDecoration {
            editor: root
        }
    }

    Repeater {
        model: root._tasks
        delegate: TaskDecoration {
            editor: root
        }
    }

    Repeater {
        model: codeController.blocks
        delegate: CodeDecoration {
            editor: root
        }
    }

    Repeater {
        model: root.images
        delegate: ImageDecoration {
            editor: root
        }
    }

    function refreshDecorations() {
        const d = decorations();
        _tasks = d ? d.tasks : [];
        _rules = d ? d.rules : [];
        _quotes = d ? d.quotes : [];
        tableController.refresh();
        tableController.measure();
        codeController.measure();
        _measureImages();
        repaintTimer.restart();
    }

    function _imageSize(src) {
        const url = Images.resolve(src, imageBaseDir);
        if (url in _imageSizes)
            return _imageSizes[url];
        let size = null;
        if (/^file:\/\//.test(url)) {
            imageProbe.source = url;
            if (imageProbe.status === Image.Ready)
                size = {
                    width: imageProbe.implicitWidth,
                    height: imageProbe.implicitHeight
                };
            imageProbe.source = "";
        } else {
            size = {
                width: 640,
                height: 360
            };
        }
        _imageSizes[url] = size;
        return size;
    }

    function _imageRegistry() {
        return {
            idOf: src => {
                if (!(src in root._imageIds))
                    root._imageIds[src] = root._imageNextId++;
                return root._imageIds[src];
            }
        };
    }

    function _prepareImages(md) {
        const result = Images.prepare(md, src => _imageSize(src), imageMaxWidth, imageMaxHeight, _imageRegistry(), blockGap);
        _imageSources = result.sources;
        _imageLayoutWidth = imageMaxWidth;
        return result.text;
    }

    function _measureImages() {
        const list = sourceMode || markdownText.indexOf("![") < 0 ? [] : Images.list(markdownText);
        if (list.length === 0) {
            if (images.length > 0)
                images = [];
            return;
        }
        const plainText = plain();
        const out = [];
        let pos = -1;
        for (const img of list) {
            pos = plainText.indexOf("\ufffc", pos + 1);
            if (pos < 0)
                break;
            const natural = _imageSize(img.src);
            const size = Images.fit(natural, _imageLayoutWidth || imageMaxWidth, imageMaxHeight) || Images.MISSING;
            const r = positionToRectangle(pos);
            out.push({
                pos: pos,
                x: r.x,
                y: r.height > size.height ? Math.max(r.y + blockGap, r.y + r.height - textMetrics.descent - size.height - blockGap) : r.y,
                width: size.width,
                height: size.height,
                url: Images.resolve(img.src, imageBaseDir),
                src: img.src,
                alt: img.alt,
                missing: natural === null
            });
        }
        if (JSON.stringify(out) !== JSON.stringify(images))
            images = out;
    }

    function _relayoutImages() {
        if (sourceMode || images.length === 0 || Math.abs(imageMaxWidth - _imageLayoutWidth) < 1)
            return;
        const start = selectionStart;
        const end = selectionEnd;
        replaceMarkdown(markdownText, () => {
            const max = length;
            if (end > start)
                select(Math.min(start, max), Math.min(end, max));
            else
                cursorPosition = Math.min(start, max);
        });
    }

    function insertImages(sources) {
        if (sourceMode || sources.length === 0)
            return false;
        _removeSelection();
        const pos = cursorPosition;
        if (codeController.at(pos) || tableController.locate(pos))
            return false;
        const frag = sources.map(src => Images.markdownFor(src, "")).join("\n\n");
        return rewriteAt(pos, (lines, found, shift) => {
            const idx = Md.joinParagraph(lines, found);
            const marker = lines[idx].indexOf(Md.MARKER);
            const at = shift ? Paste.blockPrefix(lines[idx].replace(Md.MARKER, "")).length : marker;
            return Paste.splice(lines, idx, at, frag, true).join("\n");
        }, true);
    }

    function retargetImages(fromPrefix, toPrefix) {
        const md = markdownText;
        const found = Images.list(md).filter(img => img.src.indexOf(fromPrefix) === 0);
        if (found.length === 0)
            return false;
        const lines = md.split("\n");
        for (let k = found.length - 1; k >= 0; k--) {
            const img = found[k];
            const line = lines[img.line];
            const src = toPrefix + img.src.substring(fromPrefix.length);
            lines[img.line] = line.substring(0, img.index) + "![" + img.alt + "](" + src + img.title + ")" + line.substring(img.index + img.length);
        }
        const start = selectionStart;
        const move = state => ({
                md: state.md.split("](" + fromPrefix).join("](" + toPrefix),
                start: state.start,
                end: state.end
            });
        _closeGroup();
        _restoring = true;
        replaceMarkdown(lines.join("\n"), () => cursorPosition = Math.min(start, length));
        _restoring = false;
        _undoStack = _undoStack.map(move);
        _redoStack = _redoStack.map(move);
        _committed = _state();
        return true;
    }

    function removeImageAt(pos) {
        if (plain().charAt(pos) !== "\ufffc")
            return false;
        _closeGroup();
        _markBefore();
        _loading = true;
        remove(pos, pos + 1);
        _loading = false;
        cursorPosition = pos;
        edited();
        _closeGroup();
        return true;
    }

    function _state() {
        return {
            md: markdown(),
            start: selectionStart,
            end: selectionEnd
        };
    }

    function _markBefore() {
        if (_groupOpen || _restoring)
            return;
        _committed.start = selectionStart;
        _committed.end = selectionEnd;
    }

    function _noteChange() {
        if (_restoring || _loading)
            return;
        if (!_groupOpen) {
            if (_committed.md === markdown())
                return;
            _undoStack = _undoStack.concat([_committed]).slice(-historyLimit);
            _redoStack = [];
            _groupOpen = true;
        }
        historyTimer.restart();
        Qt.callLater(_trackCaret);
    }

    function _trackCaret() {
        if (_groupOpen)
            _groupCaret = cursorPosition;
    }

    function _closeGroup() {
        if (_restoring)
            return;
        historyTimer.stop();
        _groupKind = "";
        if (_groupOpen) {
            _groupOpen = false;
            _committed = _state();
        } else if (_committed.md !== markdown()) {
            _undoStack = _undoStack.concat([_committed]).slice(-historyLimit);
            _redoStack = [];
            _committed = _state();
        }
    }

    function _groupAs(kind) {
        const moved = selectionStart !== selectionEnd || cursorPosition !== _groupCaret;
        if (_groupOpen && (moved || (_groupKind !== "" && _groupKind !== kind && !(_groupKind === "space" && kind === "insert"))))
            _closeGroup();
        _markBefore();
        _groupKind = kind;
    }

    function _restore(state) {
        slashController.close();
        rewriteStarted();
        _restoring = true;
        _loading = true;
        _assign(state.md);
        const max = length;
        if (state.end > state.start)
            select(Math.min(state.start, max), Math.min(state.end, max));
        else
            cursorPosition = Math.min(state.start, max);
        _loading = false;
        _committed = _state();
        edited();
        _restoring = false;
        rewriteFinished();
    }

    function undo() {
        _closeGroup();
        if (_undoStack.length === 0)
            return false;
        const target = _undoStack[_undoStack.length - 1];
        _undoStack = _undoStack.slice(0, -1);
        _redoStack = _redoStack.concat([_state()]);
        _restore(target);
        return true;
    }

    function redo() {
        _closeGroup();
        if (_redoStack.length === 0)
            return false;
        const target = _redoStack[_redoStack.length - 1];
        _redoStack = _redoStack.slice(0, -1);
        _undoStack = _undoStack.concat([_state()]).slice(-historyLimit);
        _restore(target);
        return true;
    }

    function resetHistory() {
        historyTimer.stop();
        _groupOpen = false;
        _groupKind = "";
        _undoStack = [];
        _redoStack = [];
        _committed = _state();
    }

    function historyState() {
        _closeGroup();
        return {
            undo: _undoStack,
            redo: _redoStack,
            committed: _committed
        };
    }

    function restoreHistory(state) {
        if (!state || !state.committed || state.committed.md !== markdown())
            return false;
        _undoStack = state.undo;
        _redoStack = state.redo;
        _committed = _state();
        return true;
    }

    function repaintTables() {
        if (!sourceMode && tableController.geometries.length > 0)
            _repaintFlip = !_repaintFlip;
    }

    function decorations() {
        if (sourceMode)
            return null;
        const plainText = plain();
        const key = revision + "\n" + plainText;
        if (key !== _decorationsKey) {
            _decorationsKey = key;
            _decorations = Md.decorations(markdownText.substring(_frontMatter.length), plainText);
        }
        return _decorations;
    }

    function _flattenCells() {
        const breaks = tableController.lineBreaks();
        if (breaks.length === 0)
            return;
        _flattening = true;
        for (let i = breaks.length - 1; i >= 0; i--) {
            const p = breaks[i];
            remove(p, p + 1);
            insert(p, Md.MARKER + " " + Md.MARKER);
            remove(p + 2, p + 3);
            remove(p, p + 1);
        }
        _flattening = false;
    }

    function _assign(md) {
        const parts = sourceMode ? {
            head: "",
            body: md
        } : Md.splitFrontMatter(md);
        _frontMatter = parts.head;
        if (parts.body !== "") {
            if (sourceMode) {
                text = md;
                return;
            }
            const prepared = Tables.prepare(Code.prepare(_prepareImages(Md.padTrailingRule(parts.body))), {
                border: tableBorderColor.toString(),
                margin: blockGap
            });
            tableLayouts = prepared.layouts;
            text = prepared.text;
            return;
        }
        tableLayouts = [];
        text = Md.MARKER;
        remove(0, length);
    }

    function load(md, keepHistory) {
        slashController.close();
        if (keepHistory)
            _closeGroup();
        _imageSizes = {};
        _loading = true;
        _assign(md);
        _loading = false;
        cursorPosition = 0;
        if (!keepHistory) {
            resetHistory();
        } else if (_committed.md !== markdown()) {
            _undoStack = _undoStack.concat([_committed]).slice(-historyLimit);
            _redoStack = [];
            _committed = _state();
        }
    }

    function markdown() {
        return markdownText.replace(/\uE000/g, "");
    }

    function setSourceMode(on) {
        if (on === sourceMode)
            return;
        slashController.close();
        _closeGroup();
        const md = markdownText;
        const pos = cursorPosition;
        _loading = true;
        if (on) {
            text = Md.MARKER;
            cursorPosition = 1;
        } else {
            text = "";
        }
        sourceMode = on;
        _assign(md);
        _loading = false;
        cursorPosition = on ? 0 : Math.min(pos, length);
        _committed = _state();
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
        _closeGroup();
        _markBefore();
        slashController.close();
        rewriteStarted();
        _loading = true;
        _assign(md);
        placeCursor();
        _loading = false;
        rewriteFinished();
        edited();
        _closeGroup();
    }

    function _dropMarker() {
        const p = plain().indexOf(Md.MARKER);
        if (p >= 0)
            remove(p, p + 1);
        return p;
    }

    function rewriteLineAt(pos, fn) {
        return rewriteAt(pos, (lines, found) => {
            const idx = Md.joinParagraph(lines, found);
            const result = fn(lines[idx], Md.parseLine(lines[idx]));
            if (result === null || result === undefined)
                return null;
            lines[idx] = result;
            return lines.join("\n");
        });
    }

    function rewriteAt(pos, fn, exact) {
        const block = blockRange(pos);
        const shift = (pos === block.start && block.text.length > 0) ? 1 : 0;
        const before = {
            start: selectionStart,
            end: selectionEnd
        };
        slashController.close();
        _loading = true;
        insert(pos + shift, Md.MARKER);
        const lines = markdownText.split("\n");
        const found = lines.findIndex(l => l.indexOf(Md.MARKER) >= 0);
        const md = found < 0 ? null : fn(lines, found, shift);
        if (md === null || md === undefined) {
            _dropMarker();
            cursorPosition = pos;
            _loading = false;
            return false;
        }
        _closeGroup();
        if (!_restoring) {
            _committed.start = before.start;
            _committed.end = before.end;
        }
        rewriteStarted();
        _assign(md);
        const p = _dropMarker();
        if (p >= 0)
            cursorPosition = Math.max(0, exact ? p : p - shift);
        _loading = false;
        rewriteFinished();
        edited();
        _closeGroup();
        return true;
    }

    function _clipboard(helper) {
        helper.text = "";
        helper.paste();
        return helper.text;
    }

    function copyPlain(value) {
        if (value === "")
            return false;
        plainClipboard.text = value;
        plainClipboard.selectAll();
        plainClipboard.copy();
        plainClipboard.text = "";
        return true;
    }

    function _removeSelection() {
        if (selectionStart === selectionEnd)
            return;
        const start = selectionStart;
        _loading = true;
        remove(start, selectionEnd);
        _loading = false;
        cursorPosition = start;
    }

    function insertInCode(text) {
        _removeSelection();
        return rewriteAt(cursorPosition, (lines, idx, shift) => {
            const at = lines[idx].indexOf(Md.MARKER) - shift;
            return Paste.insertInline(lines, idx, at, text).join("\n");
        }, true);
    }

    function pasteClipboard(plainOnly) {
        if (sourceMode)
            return false;
        const plainText = Paste.normalize(_clipboard(plainClipboard));
        const editable = !codeController.at(cursorPosition) && !tableController.locate(cursorPosition);
        if (plainText.trim() === "") {
            if (editable)
                imagePasteRequested();
            return true;
        }
        const files = editable && !plainOnly ? Images.filesFrom(plainText) : [];
        if (files.length > 0) {
            imageFilesPasted(files);
            return true;
        }
        _removeSelection();
        const pos = cursorPosition;
        if (codeController.at(pos))
            return insertInCode(Paste.forCode(plainText));
        if (tableController.locate(pos)) {
            const text = Paste.forCell(plainText);
            return rewriteAt(pos, (lines, idx, shift) => {
                const marker = lines[idx].indexOf(Md.MARKER);
                return Paste.insertInline(lines, idx, shift ? Paste.cellStart(lines[idx], marker) : marker, text).join("\n");
            }, true);
        }
        const frag = Paste.fragment(plainText, plainOnly ? "" : _clipboard(markdownClipboard), plainOnly);
        if (frag === "")
            return true;
        return rewriteAt(pos, (lines, found, shift) => {
            const idx = Md.joinParagraph(lines, found);
            const marker = lines[idx].indexOf(Md.MARKER);
            const at = shift ? Paste.blockPrefix(lines[idx].replace(Md.MARKER, "")).length : marker;
            return Paste.splice(lines, idx, at, frag).join("\n");
        }, true);
    }

    function tryBlockShortcut() {
        const block = currentBlock();
        const prefix = plain().substring(block.start, cursorPosition);
        if (!/^(#{1,3}|[-*+]|\d+[.)]|>|\[ ?\]|\[[xX]\])$/.test(prefix))
            return false;
        const ok = rewriteLineAt(cursorPosition, (line, p) => {
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
                return _quoteLine(after);
            return "- [" + state + "] " + after;
        });
        _armEmptyHeading(ok && /^#{1,3}$/.test(prefix) ? prefix.length : 0);
        return ok;
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
        if (block.text === Md.BLANK)
            cursorPosition = block.end;
        if (cursorPosition !== block.end)
            return false;
        if (/^(---|\*\*\*|___)$/.test(block.text))
            return rewriteLineAt(cursorPosition, (line, p) => p.list ? null : "---\n\n" + Md.MARKER);
        if (block.text === "```")
            return rewriteLineAt(cursorPosition, (line, p) => p.list ? null : "```\n" + Md.MARKER + "\n```");
        if (block.text === "" || block.text === Md.BLANK) {
            const blank = codeController.blankLine(cursorPosition);
            const next = blank && blank.needed ? Md.BLANK + Md.MARKER : Md.MARKER;
            return rewriteLineAt(cursorPosition, (line, p) => p.list || /^(#{1,6}\s|>)/.test(line) ? "\n" + Md.MARKER : Md.BLANK + "\n\n" + next);
        }
        return rewriteLineAt(cursorPosition, line => {
            if (/^#{1,6}\s/.test(line))
                return line.replace(Md.MARKER, "") + "\n\n" + Md.MARKER;
            if (/^>/.test(line) && !/^>[ \t]*(([-*+]|\d+[.)])[ \t]|#)/.test(line))
                return line.replace(Md.MARKER, "") + "\n>\n" + _quoteLine(Md.MARKER);
            return null;
        });
    }

    function clearBlankLine() {
        const block = currentBlock();
        if (block.text !== Md.BLANK)
            return;
        removeText(block.start, block.end);
    }

    function tryDeleteShortcut() {
        const block = currentBlock();
        if (block.text.length === 1 && block.text !== Md.BLANK && cursorPosition === block.start && _quoteAt(block.start))
            return _blankQuote(block);
        const blank = codeController.blankLine(cursorPosition);
        if (!blank)
            return false;
        if (blank.needed || blank.last)
            return true;
        _loading = true;
        if (blank.after)
            remove(blank.start - 1, blank.end);
        else
            remove(blank.start, blank.end + 1);
        _loading = false;
        edited();
        return true;
    }

    function tryBackspaceShortcut() {
        const block = currentBlock();
        if (block.text.length === 1 && _quoteAt(block.start)) {
            if (block.text === Md.BLANK)
                return rewriteLineAt(cursorPosition, line => /^>/.test(line) ? Md.stripBlockPrefix(line) : null);
            if (cursorPosition === block.end)
                return _blankQuote(block);
        }
        const blank = codeController.blankLine(cursorPosition);
        if (blank && blank.last && blank.afterRule && !blank.before) {
            const rule = blockRange(blank.start - 1).start;
            _loading = true;
            remove(rule, blank.start);
            _loading = false;
            cursorPosition = rule;
            edited();
            return true;
        }
        if (blank && blank.before) {
            const target = blank.before.contentEnd;
            if (!blank.needed) {
                _loading = true;
                remove(blank.start - 1, blank.end);
                _loading = false;
                edited();
            }
            cursorPosition = target;
            return true;
        }
        if (blank && blank.needed)
            return true;
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

    function _quoteLine(rest) {
        return "> " + (rest.replace(Md.MARKER, "").trim() === "" ? Md.BLANK + Md.MARKER : rest);
    }

    function _quoteAt(pos) {
        const d = decorations();
        return d !== null && d.quotes.some(q => pos >= q.start && pos <= q.end);
    }

    function _blankQuote(block) {
        _loading = true;
        remove(block.start, block.end);
        insert(block.start, Md.BLANK);
        _loading = false;
        cursorPosition = block.start + 1;
        edited();
        return true;
    }

    function _clearQuoteSelection() {
        const block = blockRange(selectionStart);
        if (selectionStart !== block.start || selectionEnd !== block.end || block.text === Md.BLANK || !_quoteAt(block.start))
            return false;
        return _blankQuote(block);
    }

    function _armEmptyHeading(level) {
        _emptyHeadingLevel = level;
        _emptyHeadingPos = level > 0 && currentBlock().text === "" ? cursorPosition : -1;
    }

    function _typeIntoEmptyHeading(ch) {
        const pos = cursorPosition;
        insert(pos, "#".repeat(_emptyHeadingLevel) + " " + Md.escape(ch));
        cursorPosition = pos + 1;
        return true;
    }

    function _typeIntoBlankHeading(ch) {
        const block = currentBlock();
        if (block.text !== Md.BLANK || positionToRectangle(block.start).height <= textMetrics.height + 2)
            return false;
        return rewriteAt(cursorPosition, (lines, found) => {
            const m = lines[found].match(/^(#{1,6})[ \t]/);
            if (!m)
                return null;
            lines[found] = m[1] + " " + Md.escape(ch) + Md.MARKER;
            return lines.join("\n");
        }, true);
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
        if (sourceMode || selectionStart === selectionEnd || codeController.containsSelection())
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
        if (sourceMode || tableController.locate(cursorPosition) || codeController.at(cursorPosition))
            return false;
        const ok = rewriteLineAt(cursorPosition, (line, p) => {
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
                return _quoteLine(rest);
            default:
                return rest;
            }
        });
        _armEmptyHeading(ok && /^h[1-3]$/.test(type) ? Number(type.charAt(1)) : 0);
        return ok;
    }

    function runCommand(id) {
        switch (id) {
        case "table":
            return tableController.insert();
        case "rule":
            return insertRule();
        case "code":
            return insertCodeBlock();
        case "image":
            imageRequested();
            return true;
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
        case "fullWidth":
            return tableController.toggleFullWidth();
        case "equalize":
            return tableController.equalize();
        case "density":
            return tableController.cycleDensity();
        default:
            return setBlockType(id, false);
        }
    }

    function toggleTaskAt(pos) {
        if (sourceMode || tableController.locate(pos) || codeController.at(pos))
            return false;
        return rewriteLineAt(pos, (line, p) => {
            if (!p.list || !p.task)
                return null;
            return p.indent + p.bullet + " [" + (/x/i.test(p.task) ? " " : "x") + "] " + p.rest;
        });
    }

    function isMarkerHit(x, y) {
        const pos = positionAt(x, y);
        if (tableController.locate(pos) || codeController.at(pos))
            return -1;
        const block = blockRange(pos);
        const r = positionToRectangle(block.start);
        if (y < r.y || y > r.y + r.height || x >= r.x - 2)
            return -1;
        return block.start;
    }

    function _isFormatKey(key) {
        return [Qt.Key_B, Qt.Key_I, Qt.Key_E, Qt.Key_1, Qt.Key_2, Qt.Key_3, Qt.Key_0, Qt.Key_L, Qt.Key_O].indexOf(key) >= 0;
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
        if ((slashController.active && event.key === Qt.Key_Escape) || _isUndoKey(event))
            event.accepted = true;
    }

    function _isUndoKey(event) {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const alt = (event.modifiers & Qt.AltModifier) !== 0;
        return ctrl && !alt && (event.key === Qt.Key_Z || event.key === Qt.Key_Y);
    }

    function _trackHistory(event, ctrl, alt, printable) {
        const key = event.key;
        if (printable)
            _groupAs(event.text === " " ? "space" : "insert");
        else if (key === Qt.Key_Backspace || key === Qt.Key_Delete)
            _groupAs(ctrl ? "word" : (key === Qt.Key_Backspace ? "backspace" : "delete"));
        else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Tab || key === Qt.Key_Backtab || (ctrl && !alt && (key === Qt.Key_X || key === Qt.Key_V))) {
            _closeGroup();
            _markBefore();
        } else if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down, Qt.Key_Home, Qt.Key_End, Qt.Key_PageUp, Qt.Key_PageDown].indexOf(key) >= 0)
            _closeGroup();
        else
            _markBefore();
    }

    Keys.onReleased: _trackCaret()

    Keys.onPressed: event => {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const alt = (event.modifiers & Qt.AltModifier) !== 0;
        const collapsed = selectionStart === selectionEnd;
        const printable = !ctrl && !alt && event.text.length === 1 && event.text.charCodeAt(0) >= 32;

        if (_isUndoKey(event)) {
            slashController.close();
            if (event.key === Qt.Key_Y || shift)
                redo();
            else
                undo();
            event.accepted = true;
            return;
        }
        _trackHistory(event, ctrl, alt, printable);
        if (sourceMode)
            return;

        if (slashController.active && slashController.handleKey(event)) {
            event.accepted = true;
            return;
        }

        if (_emptyHeadingPos >= 0) {
            const armed = _emptyHeadingPos;
            _emptyHeadingPos = -1;
            if (printable && collapsed && event.text !== "/" && cursorPosition === armed && currentBlock().text === "" && _typeIntoEmptyHeading(event.text)) {
                event.accepted = true;
                return;
            }
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

        if ((ctrl && !alt && event.key === Qt.Key_V) || (shift && !ctrl && event.key === Qt.Key_Insert)) {
            event.accepted = pasteClipboard(ctrl && shift);
            return;
        }

        const code = codeController.at(cursorPosition);

        if (ctrl && !alt) {
            if (code)
                event.accepted = codeController.handleKey(event, code) || _isFormatKey(event.key);
            else
                event.accepted = _handleCtrl(event.key, shift);
            return;
        }

        if (code || codeController.containsSelection()) {
            if (code && codeController.handleKey(event, code))
                event.accepted = true;
            return;
        }

        const cell = tableController.locateSelection();
        if (cell && tableController.handleKey(event, cell)) {
            event.accepted = true;
            return;
        }
        const enter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
        if (enter && !cell && (tableController.contains(selectionStart) || tableController.contains(selectionEnd))) {
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Space && !alt) {
            if (collapsed && !cell && tryBlockShortcut())
                event.accepted = true;
            return;
        }

        if (printable && collapsed) {
            if (event.text !== "/" && _typeIntoBlankHeading(event.text)) {
                event.accepted = true;
                return;
            }
            clearBlankLine();
            if (event.text === "/" && slashController.canOpenAt(cursorPosition))
                slashController.open(cursorPosition);
        }

        if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) && !alt && !collapsed && _clearQuoteSelection()) {
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Backspace && !alt && collapsed) {
            if (!cell && tryBackspaceShortcut())
                event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Delete && !alt && collapsed) {
            if (!cell && tryDeleteShortcut())
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
