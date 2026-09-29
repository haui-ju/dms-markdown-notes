import QtQuick
import "logic/tables.js" as Tables
import "logic/markdown.js" as Md

QtObject {
    id: root

    required property var editor
    property var info: null
    property var geometries: []
    property string _geometryKey: ""
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

    function _context(m, tableIndex, cell) {
        const range = m.ranges[tableIndex];
        const rows = Tables.parse(m.lines, range);
        const cols = rows[0].length;
        const span = m.spans[tableIndex];
        if (span.cells.length !== rows.length * cols)
            return null;
        const hasLayout = range.start > 0 && Tables.isLayoutLine(m.lines[range.start - 1]);
        return {
            table: tableIndex,
            cell: cell,
            row: Math.floor(cell / cols),
            col: cell % cols,
            rows: rows,
            cols: cols,
            span: span,
            range: range,
            lines: m.lines,
            layoutStart: hasLayout ? range.start - 1 : range.start,
            layout: hasLayout ? Tables.parseLayout(m.lines[range.start - 1], cols) : Tables.defaultLayout(cols)
        };
    }

    function contextOf(tableIndex) {
        if (editor.sourceMode)
            return null;
        const m = model();
        if (!m.ok || tableIndex < 0 || tableIndex >= m.spans.length)
            return null;
        return _context(m, tableIndex, 0);
    }

    function locate(pos) {
        if (editor.sourceMode)
            return null;
        const m = model();
        if (!m.ok || m.spans.length === 0)
            return null;
        const hit = Tables.locate(m.spans, pos);
        return hit ? _context(m, hit.table, hit.cell) : null;
    }

    function contains(pos) {
        return !editor.sourceMode && Tables.locate(model().spans, pos) !== null;
    }

    function lineBreaks() {
        const plain = editor.plain();
        if (plain.indexOf(String.fromCharCode(Tables.CELL)) < 0)
            return [];
        const found = [];
        for (const span of Tables.scan(plain)) {
            for (const cell of span.cells) {
                for (let i = cell.start; i < cell.end; i++) {
                    const code = plain.charCodeAt(i);
                    if (code === 0x2028 || code === 0x2029)
                        found.push(i);
                }
            }
        }
        return found;
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
            bottom: last.y + last.height,
            fullWidth: ctx.layout.width === 100,
            density: ctx.layout.density
        };
    }

    function _measureTable(m, t) {
        const ctx = _context(m, t, 0);
        if (!ctx)
            return null;
        const span = ctx.span;
        const n = ctx.cols;
        const pad = Tables.PADDING[ctx.layout.density] + 1;
        const lefts = [];
        for (let c = 0; c < n; c++)
            lefts.push(editor.positionToRectangle(span.cells[c].start).x - pad);
        let bottom = 0;
        let contentRight = 0;
        span.cells.forEach((cell, k) => {
            const r = editor.positionToRectangle(cell.end);
            bottom = Math.max(bottom, r.y + r.height);
            if (k % n === n - 1)
                contentRight = Math.max(contentRight, r.x);
        });
        const available = Math.max(1, editor.width - 2 * lefts[0]);
        const layout = ctx.layout;
        let right = contentRight + pad;
        if (layout.width)
            right = lefts[0] + available * layout.width / 100;
        else if (layout.columns.length === n && n > 1)
            right = lefts[0] + (lefts[n - 1] - lefts[0]) * 100 / (100 - layout.columns[n - 1]);
        return {
            table: t,
            top: editor.positionToRectangle(span.cells[0].start).y - pad,
            bottom: bottom + pad,
            edges: lefts.concat([Math.max(right, lefts[n - 1] + pad * 2)]),
            available: available
        };
    }

    function measure() {
        const m = editor.sourceMode ? null : model();
        const out = [];
        if (m && m.ok) {
            for (let t = 0; t < m.spans.length; t++) {
                const g = _measureTable(m, t);
                if (g)
                    out.push(g);
            }
        }
        const key = JSON.stringify(out);
        if (key === _geometryKey)
            return;
        _geometryKey = key;
        geometries = out;
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

    function _splice(ctx, rows, layout) {
        const lines = ctx.lines.slice();
        const block = rows ? (Tables.isDefaultLayout(layout) ? [] : [Tables.layoutLine(layout)]).concat(Tables.serialize(rows)) : [];
        lines.splice(ctx.layoutStart, ctx.range.end - ctx.layoutStart, ...block);
        return lines.join("\n");
    }

    function _commit(ctx, rows, row, col, layout) {
        const anchor = ctx.span.start;
        editor.replaceMarkdown(_splice(ctx, rows, layout || ctx.layout), () => {
            if (rows)
                focusCell(ctx.table, row * rows[0].length + col, true);
            else
                editor.cursorPosition = Math.min(anchor, editor.length);
        });
        return true;
    }

    function _commitLayout(ctx, layout) {
        const start = editor.selectionStart;
        const end = editor.selectionEnd;
        editor.replaceMarkdown(_splice(ctx, ctx.rows, layout), () => {
            const max = editor.length;
            if (end > start)
                editor.select(Math.min(start, max), Math.min(end, max));
            else
                editor.cursorPosition = Math.min(start, max);
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
        return _withContext(ctx => _commit(ctx, Tables.insertColumn(ctx.rows, ctx.col + 1), ctx.row, ctx.col + 1, Tables.layoutInsertColumn(ctx.layout, ctx.col + 1)));
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
            return _commit(ctx, rows, ctx.row, rows ? Math.min(ctx.col, rows[0].length - 1) : 0, rows ? Tables.layoutRemoveColumn(ctx.layout, ctx.col) : null);
        });
    }

    function remove() {
        return _withContext(ctx => _commit(ctx, null, 0, 0));
    }

    function toggleFullWidth() {
        return _withContext(ctx => {
            const layout = Tables.copyLayout(ctx.layout);
            layout.width = layout.width === 100 ? 0 : 100;
            if (!layout.width)
                layout.columns = [];
            return _commitLayout(ctx, layout);
        });
    }

    function equalize() {
        return _withContext(ctx => {
            const layout = Tables.copyLayout(ctx.layout);
            layout.columns = Tables.equalColumns(ctx.cols);
            layout.width = layout.width || 100;
            return _commitLayout(ctx, layout);
        });
    }

    function cycleDensity() {
        return _withContext(ctx => {
            const layout = Tables.copyLayout(ctx.layout);
            layout.density = Tables.nextDensity(layout.density);
            return _commitLayout(ctx, layout);
        });
    }

    function _percent(px, available) {
        return Math.max(Tables.MIN_WIDTH, Math.min(100, Math.round(px / available * 100)));
    }

    function resize(tableIndex, edge, x) {
        const ctx = contextOf(tableIndex);
        const g = geometries.find(item => item.table === tableIndex);
        if (!ctx || !g || edge < 1 || edge >= g.edges.length)
            return false;
        const edges = g.edges.slice();
        const last = edges.length - 1;
        const widths = () => Tables.normalizeColumns(edges.slice(1).map((e, i) => Math.max(1, e - edges[i])));
        const layout = Tables.copyLayout(ctx.layout);
        if (edge === last) {
            layout.width = _percent(x - edges[0], g.available);
            if (!layout.columns.length)
                layout.columns = widths();
        } else {
            const min = (edges[last] - edges[0]) * Tables.MIN_COLUMN / 100;
            edges[edge] = Math.max(edges[edge - 1] + min, Math.min(edges[edge + 1] - min, x));
            layout.columns = widths();
            if (!layout.width)
                layout.width = _percent(edges[last] - edges[0], g.available);
        }
        return _commitLayout(ctx, layout);
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
