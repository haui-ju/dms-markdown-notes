import QtQuick
import "logic/tables.js" as Tables
import "logic/markdown.js" as Md

QtObject {
    id: root

    required property var editor
    property var info: null
    property int _revision: -1
    property string _plain: ""
    property var _model: null

    function model() {
        const plain = editor.plain();
        if (_model && _revision === editor.revision && _plain === plain)
            return _model;
        const lines = editor.markdownText.split("\n");
        const ranges = Tables.find(lines);
        const spans = Tables.scan(plain);
        _model = {
            lines: lines,
            ranges: ranges,
            spans: spans,
            ok: ranges.length === spans.length
        };
        _revision = editor.revision;
        _plain = plain;
        return _model;
    }

    function locate(pos) {
        if (editor.sourceMode)
            return null;
        const m = model();
        if (!m.ok || m.spans.length === 0)
            return null;
        const hit = Tables.locate(m.spans, pos);
        if (!hit)
            return null;
        const range = m.ranges[hit.table];
        const rows = Tables.parse(m.lines, range);
        const cols = rows[0].length;
        const span = m.spans[hit.table];
        if (span.cells.length !== rows.length * cols)
            return null;
        return {
            table: hit.table,
            cell: hit.cell,
            row: Math.floor(hit.cell / cols),
            col: hit.cell % cols,
            rows: rows,
            cols: cols,
            span: span,
            range: range,
            lines: m.lines
        };
    }

    function locateSelection() {
        const ctx = locate(editor.selectionStart);
        if (!ctx || editor.selectionEnd > ctx.span.cells[ctx.cell].end)
            return null;
        return ctx;
    }

    function refresh() {
        const ctx = locate(editor.cursorPosition);
        if (!ctx) {
            info = null;
            return;
        }
        const first = editor.positionToRectangle(ctx.span.cells[0].start);
        const last = editor.positionToRectangle(ctx.span.end);
        info = {
            row: ctx.row,
            col: ctx.col,
            rows: ctx.rows.length,
            cols: ctx.cols,
            top: first.y,
            bottom: last.y + last.height
        };
    }

    function focusCell(tableIndex, cellIndex, selectPlaceholder) {
        const span = model().spans[tableIndex];
        if (!span)
            return false;
        const cell = span.cells[Math.max(0, Math.min(cellIndex, span.cells.length - 1))];
        if (selectPlaceholder && Tables.isPlaceholder(editor.getText(cell.start, cell.end)))
            editor.select(cell.start, cell.end);
        else
            editor.cursorPosition = cell.end;
        return true;
    }

    function _commit(ctx, rows, row, col) {
        const lines = ctx.lines.slice();
        lines.splice(ctx.range.start, ctx.range.end - ctx.range.start, ...(rows ? Tables.serialize(rows) : []));
        const anchor = ctx.span.start;
        editor.replaceMarkdown(lines.join("\n"), () => {
            if (rows)
                focusCell(ctx.table, row * rows[0].length + col, true);
            else
                editor.cursorPosition = Math.min(anchor, editor.length);
        });
        return true;
    }

    function _withContext(fn) {
        const ctx = locate(editor.cursorPosition);
        return ctx ? fn(ctx) : false;
    }

    function insert() {
        if (locate(editor.cursorPosition))
            return false;
        const block = editor.currentBlock();
        if (block.text.length > 0)
            editor.cursorPosition = block.end;
        const lines = Tables.serialize(Tables.create(Tables.DEFAULT_ROWS, Tables.DEFAULT_COLUMNS));
        lines[0] = lines[0].replace(Tables.headerLabel(0), Tables.headerLabel(0) + Md.MARKER);
        const ok = editor.rewriteLineAt(editor.cursorPosition, (line, parsed) => {
            const keep = Md.blockContent(line, parsed).trim() !== "" ? line.replace(Md.MARKER, "") + "\n\n" : "";
            return keep + lines.join("\n") + "\n";
        });
        const ctx = ok ? locate(editor.cursorPosition) : null;
        if (ctx)
            focusCell(ctx.table, 0, true);
        return ok;
    }

    function addRow() {
        return _withContext(ctx => _commit(ctx, Tables.insertRow(ctx.rows, ctx.row + 1), ctx.row + 1, ctx.col));
    }

    function addColumn() {
        return _withContext(ctx => _commit(ctx, Tables.insertColumn(ctx.rows, ctx.col + 1), ctx.row, ctx.col + 1));
    }

    function removeRow() {
        return _withContext(ctx => {
            const rows = Tables.removeRow(ctx.rows, ctx.row);
            return _commit(ctx, rows, rows ? Math.min(ctx.row, rows.length - 1) : 0, ctx.col);
        });
    }

    function removeColumn() {
        return _withContext(ctx => {
            const rows = Tables.removeColumn(ctx.rows, ctx.col);
            return _commit(ctx, rows, ctx.row, rows ? Math.min(ctx.col, rows[0].length - 1) : 0);
        });
    }

    function remove() {
        return _withContext(ctx => _commit(ctx, null, 0, 0));
    }

    function move(ctx, delta) {
        const target = ctx.cell + delta;
        if (target < 0)
            return true;
        if (target >= ctx.span.cells.length)
            return _commit(ctx, Tables.insertRow(ctx.rows, ctx.rows.length), ctx.rows.length, 0);
        return focusCell(ctx.table, target, true);
    }

    function enter(ctx) {
        if (ctx.row + 1 < ctx.rows.length)
            return focusCell(ctx.table, ctx.cell + ctx.cols, false);
        editor.cursorPosition = Math.min(editor.length, ctx.span.end + 1);
        return true;
    }

    function handleKey(event, ctx) {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && shift))
            return move(ctx, -1);
        if (event.key === Qt.Key_Tab)
            return move(ctx, 1);
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            return enter(ctx);
        return false;
    }
}
