.pragma library

var BLANK = "\u00A0";
var CELL = 0xFDD0;
var TABLE_END = 0xFDD1;
var DEFAULT_ROWS = 3;
var DEFAULT_COLUMNS = 3;

function isRow(line) {
    return /^\s*\|/.test(line);
}

function isDelimiter(line) {
    return isRow(line) && /-/.test(line) && /^[\s|:\-]+$/.test(line);
}

function splitRaw(line) {
    const s = line.trim();
    const cells = [];
    let cur = "";
    let trailingPipe = false;
    for (let i = 0; i < s.length; i++) {
        const ch = s[i];
        if (ch === "\\" && i + 1 < s.length) {
            cur += ch + s[i + 1];
            i++;
            continue;
        }
        if (ch === "|") {
            cells.push(cur);
            cur = "";
            trailingPipe = i === s.length - 1;
            continue;
        }
        cur += ch;
    }
    if (!trailingPipe)
        cells.push(cur);
    if (s[0] === "|")
        cells.shift();
    return cells;
}

function splitRow(line) {
    return splitRaw(line).map(c => c.trim());
}

function escapePipes(text) {
    return text.replace(/(^|[^\\])\|/g, "$1\\|").replace(/(^|[^\\])\|/g, "$1\\|");
}

function _norm(s) {
    return s.replace(/\\(.)/g, "$1").replace(/[*_`~\s\u00A0\uE000]+/g, "");
}

function find(lines) {
    const found = [];
    let fence = false;
    for (let i = 0; i < lines.length; i++) {
        if (/^\s*```/.test(lines[i])) {
            fence = !fence;
            continue;
        }
        if (fence || !isRow(lines[i]) || isDelimiter(lines[i]) || i + 1 >= lines.length || !isDelimiter(lines[i + 1]))
            continue;
        let end = i + 2;
        while (end < lines.length && isRow(lines[end]))
            end++;
        found.push({
            start: i,
            end: end
        });
        i = end - 1;
    }
    return found;
}

function normalize(rows) {
    const cols = Math.max(1, ...rows.map(r => r.length));
    return rows.map(r => {
        const row = r.slice(0, cols);
        while (row.length < cols)
            row.push("");
        return row;
    });
}

function parse(lines, range) {
    const rows = [splitRow(lines[range.start])];
    for (let i = range.start + 2; i < range.end; i++)
        rows.push(splitRow(lines[i]));
    return normalize(rows);
}

function serialize(rows) {
    const line = r => "| " + r.map(c => c === "" ? BLANK : c).join(" | ") + " |";
    const body = rows.length > 1 ? rows.slice(1) : [rows[0].map(() => "")];
    return [line(rows[0]), "| " + rows[0].map(() => "---").join(" | ") + " |"].concat(body.map(line));
}

function _isBlank(line) {
    return /^[ \t]*$/.test(line);
}

function _needsSeparator(previous, afterFence) {
    return previous === null || afterFence || /^\s*>/.test(previous) || isRow(previous);
}

function prepare(md) {
    if (md.indexOf("|") < 0)
        return md;
    const lines = md.split("\n");
    const ranges = find(lines);
    if (ranges.length === 0)
        return md;
    const out = [];
    let cursor = 0;
    for (const range of ranges) {
        let previous = null;
        let closedFence = false;
        let fence = false;
        for (let i = 0; i < range.start; i++) {
            if (/^\s*```/.test(lines[i]))
                fence = !fence;
            if (!_isBlank(lines[i])) {
                previous = lines[i];
                closedFence = !fence && /^\s*```/.test(lines[i]);
            }
        }
        out.push(...lines.slice(cursor, range.start));
        if (_needsSeparator(previous, closedFence)) {
            _gap(out);
            out.push(BLANK);
        }
        _gap(out);
        out.push(...serialize(parse(lines, range)));
        if (range.end < lines.length && !_isBlank(lines[range.end]))
            out.push("");
        cursor = range.end;
    }
    out.push(...lines.slice(cursor));
    return out.join("\n");
}

function _gap(out) {
    if (out.length > 0 && !_isBlank(out[out.length - 1]))
        out.push("");
}

function _padRanges(lines, ranges) {
    for (let t = ranges.length - 1; t >= 0; t--) {
        const range = ranges[t];
        if (range.end < lines.length && !_isBlank(lines[range.end]))
            lines.splice(range.end, 0, "");
        if (range.start > 0 && !_isBlank(lines[range.start - 1]))
            lines.splice(range.start, 0, "");
    }
    return lines;
}

function _rejoin(segments, expected) {
    const cells = [];
    let i = 0;
    for (let c = 0; c < expected.length; c++) {
        let acc = segments[i++] || "";
        const target = _norm(expected[c]);
        while (_norm(acc) !== target && i < segments.length - (expected.length - 1 - c))
            acc += "|" + segments[i++];
        cells.push(escapePipes(acc.trim()));
    }
    return cells;
}

function repair(md, plain) {
    if (md.indexOf("|") < 0)
        return md;
    const lines = md.split("\n");
    const ranges = find(lines);
    const spans = scan(plain);
    if (ranges.length === 0 || ranges.length !== spans.length)
        return md;
    ranges.forEach((range, t) => {
        const cols = splitRaw(lines[range.start + 1]).length;
        const rowLines = [range.start];
        for (let i = range.start + 2; i < range.end; i++)
            rowLines.push(i);
        if (spans[t].cells.length !== rowLines.length * cols)
            return;
        rowLines.forEach((lineIndex, r) => {
            const segments = splitRaw(lines[lineIndex]);
            if (segments.length === cols)
                return;
            const expected = spans[t].cells.slice(r * cols, r * cols + cols).map(cell => plain.substring(cell.start, cell.end));
            lines[lineIndex] = "| " + _rejoin(segments, expected).join(" | ") + " |";
        });
    });
    return _padRanges(lines, ranges).join("\n");
}

function headerLabel(index) {
    return "Columna " + (index + 1);
}

function isPlaceholder(text) {
    return /^Columna \d+$/.test(text);
}

function create(rowCount, colCount) {
    const rows = [];
    for (let r = 0; r < rowCount; r++) {
        const row = [];
        for (let c = 0; c < colCount; c++)
            row.push(r === 0 ? headerLabel(c) : "");
        rows.push(row);
    }
    return rows;
}

function insertRow(rows, at) {
    const next = rows.map(r => r.slice());
    next.splice(Math.max(1, Math.min(at, next.length)), 0, rows[0].map(() => ""));
    return next;
}

function insertColumn(rows, at) {
    const cols = rows[0].length;
    const pos = Math.max(0, Math.min(at, cols));
    return rows.map((r, i) => {
        const row = r.slice();
        row.splice(pos, 0, i === 0 ? headerLabel(cols) : "");
        return row;
    });
}

function removeRow(rows, at) {
    const next = rows.map(r => r.slice());
    next.splice(at, 1);
    if (next.length === 0)
        return null;
    if (next.length === 1)
        next.push(next[0].map(() => ""));
    return next;
}

function removeColumn(rows, at) {
    if (rows[0].length <= 1)
        return null;
    return rows.map(r => {
        const row = r.slice();
        row.splice(at, 1);
        return row;
    });
}

function scan(text) {
    const tables = [];
    let cur = null;
    for (let i = 0; i < text.length; i++) {
        const code = text.charCodeAt(i);
        if (code === CELL) {
            if (cur)
                cur.cells[cur.cells.length - 1].end = i;
            else
                cur = {
                    start: i,
                    end: -1,
                    cells: []
                };
            cur.cells.push({
                start: i + 1,
                end: -1
            });
        } else if (code === TABLE_END && cur) {
            cur.cells[cur.cells.length - 1].end = i;
            cur.end = i;
            tables.push(cur);
            cur = null;
        }
    }
    return tables;
}

function locate(tables, pos) {
    for (let t = 0; t < tables.length; t++) {
        const table = tables[t];
        if (pos < table.cells[0].start || pos > table.end)
            continue;
        let cell = 0;
        while (cell + 1 < table.cells.length && table.cells[cell + 1].start <= pos)
            cell++;
        return {
            table: t,
            cell: cell
        };
    }
    return null;
}
