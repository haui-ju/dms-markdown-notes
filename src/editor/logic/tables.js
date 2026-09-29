.pragma library

var BLANK = "\u00A0";
var CELL = 0xFDD0;
var TABLE_END = 0xFDD1;
var DEFAULT_ROWS = 3;
var DEFAULT_COLUMNS = 3;
var DENSITIES = ["compacto", "normal", "amplio"];
var NEW_TABLE_DENSITY = "amplio";
var PADDING = {
    compacto: 2,
    normal: 5,
    amplio: 10
};
var MIN_COLUMN = 5;
var MIN_WIDTH = 15;

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
    const code = /(`+)(?!`)[\s\S]*?[^`]\1(?!`)/g;
    const outside = s => s.replace(/(\\*)\|/g, (m, slashes) => slashes.length % 2 === 0 ? slashes + "\\|" : m);
    let out = "";
    let last = 0;
    let m;
    while ((m = code.exec(text)) !== null) {
        out += outside(text.substring(last, m.index)) + m[0].replace(/(^|[^\\])\|/g, "$1\\|").replace(/(^|[^\\])\|/g, "$1\\|");
        last = m.index + m[0].length;
    }
    return out + outside(text.substring(last));
}

function _norm(s, escaped) {
    return (escaped ? s.replace(/\\(.)/g, "$1") : s).replace(/[*_`~\s\u00A0\uE000]+/g, "");
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
    const line = r => "| " + r.join(" | ") + " |";
    const body = rows.length > 1 ? rows.slice(1) : [rows[0].map(() => "")];
    return [line(rows[0]), "| " + rows[0].map(() => "---").join(" | ") + " |"].concat(body.map(line));
}

function defaultLayout(cols) {
    return {
        cols: cols || 0,
        width: 0,
        columns: [],
        density: "normal"
    };
}

function copyLayout(layout) {
    return {
        cols: layout.cols,
        width: layout.width,
        columns: layout.columns.slice(),
        density: layout.density
    };
}

function isDefaultLayout(layout) {
    return !layout.width && layout.columns.length === 0 && layout.density === "normal";
}

function isLayoutLine(line) {
    return /^\s*<!--\s*tabla:.*-->\s*$/.test(line);
}

function normalizeColumns(values) {
    const total = values.reduce((a, b) => a + b, 0);
    const out = values.map(v => Math.max(1, Math.round(v / total * 100)));
    const widest = out.indexOf(Math.max(...out));
    out[widest] += 100 - out.reduce((a, b) => a + b, 0);
    return out;
}

function equalColumns(cols) {
    return normalizeColumns(Array(cols).fill(1));
}

function parseLayout(line, cols) {
    const layout = defaultLayout(cols);
    const body = line.replace(/^\s*<!--\s*tabla:/, "").replace(/-->\s*$/, "").trim();
    for (const part of body.split(/\s+/)) {
        const eq = part.indexOf("=");
        const key = part.substring(0, eq);
        const value = part.substring(eq + 1);
        if (key === "ancho") {
            const n = Math.round(Number(value));
            if (n >= MIN_WIDTH && n <= 100)
                layout.width = n;
        } else if (key === "columnas") {
            const values = value.split(",").map(Number);
            if (values.length === cols && values.every(n => n > 0))
                layout.columns = normalizeColumns(values);
        } else if (key === "alto" && DENSITIES.indexOf(value) >= 0) {
            layout.density = value;
        }
    }
    return layout;
}

function layoutLine(layout) {
    const parts = [];
    if (layout.width)
        parts.push("ancho=" + layout.width);
    if (layout.columns.length)
        parts.push("columnas=" + layout.columns.join(","));
    if (layout.density !== "normal")
        parts.push("alto=" + layout.density);
    return "<!-- tabla: " + parts.join(" ") + " -->";
}

function layoutInsertColumn(layout, at) {
    const next = copyLayout(layout);
    next.cols++;
    if (next.columns.length) {
        next.columns.splice(Math.max(0, Math.min(at, next.columns.length)), 0, 100 / layout.cols);
        next.columns = normalizeColumns(next.columns);
    }
    return next;
}

function layoutRemoveColumn(layout, at) {
    const next = copyLayout(layout);
    next.cols--;
    if (next.columns.length) {
        next.columns.splice(at, 1);
        next.columns = next.columns.length ? normalizeColumns(next.columns) : [];
    }
    return next;
}

function nextDensity(density) {
    return DENSITIES[(DENSITIES.indexOf(density) + 1) % DENSITIES.length];
}

function _escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

function inlineHtml(text) {
    const saved = [];
    const keep = html => "\uE001" + (saved.push(html) - 1) + "\uE002";
    let s = text.replace(/(`+)(?!`)([\s\S]*?[^`])\1(?!`)/g, (m, fence, code) => keep("<code>" + _escapeHtml(/^ .*[^ ].* $/.test(code) ? code.slice(1, -1) : code) + "</code>"));
    s = s.replace(/\\([\\`*_{}\[\]()#+\-.!|>~<])/g, (m, ch) => keep(_escapeHtml(ch)));
    s = _escapeHtml(s);
    s = s.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (m, label, url) => "<a href=\"" + url + "\">" + label + "</a>");
    s = s.replace(/\*\*(.+?)\*\*/g, "<b>$1</b>").replace(/__(.+?)__/g, "<b>$1</b>");
    s = s.replace(/~~(.+?)~~/g, "<s>$1</s>");
    s = s.replace(/\*(.+?)\*/g, "<i>$1</i>").replace(/(^|\W)_(.+?)_(?=\W|$)/g, "$1<i>$2</i>");
    return s.replace(/\uE001(\d+)\uE002/g, (m, i) => saved[Number(i)]);
}

function htmlTable(rows, layout, style) {
    const widths = layout.columns.length === rows[0].length ? layout.columns : null;
    const pad = PADDING[layout.density] || PADDING.normal;
    const border = style && style.border ? style.border : "#808080";
    const margin = style && style.margin ? "; margin-top: " + style.margin + "px; margin-bottom: " + style.margin + "px" : "";
    const attrs = " border=\"1\" cellspacing=\"0\" cellpadding=\"" + pad + "\" style=\"border-collapse: collapse; border-color: " + border + margin + "\"" + (layout.width ? " width=\"" + layout.width + "%\"" : "");
    const head = rows[0].map((c, i) => "<th align=\"left\"" + (widths ? " width=\"" + widths[i] + "%\"" : "") + ">" + (c === "" ? "&nbsp;" : inlineHtml(c)) + "</th>").join("");
    const body = (rows.length > 1 ? rows.slice(1) : [rows[0].map(() => "")]).map(r => "<tr>" + r.map(c => "<td>" + inlineHtml(c) + "</td>").join("") + "</tr>").join("");
    return "<table" + attrs + "><tr>" + head + "</tr>" + body + "</table>";
}

function _isBlank(line) {
    return /^[ \t]*$/.test(line);
}

function _lastContent(out) {
    for (let i = out.length - 1; i >= 0; i--) {
        if (!_isBlank(out[i]))
            return out[i];
    }
    return null;
}

function prepare(md, style) {
    const layouts = [];
    if (md.indexOf("|") < 0)
        return {
            text: md,
            layouts: layouts
        };
    const lines = md.split("\n");
    const ranges = find(lines);
    const out = [];
    let cursor = 0;
    for (const range of ranges) {
        const rows = parse(lines, range);
        const hasLayout = range.start > cursor && isLayoutLine(lines[range.start - 1]);
        const layout = hasLayout ? parseLayout(lines[range.start - 1], rows[0].length) : defaultLayout(rows[0].length);
        layouts.push(layout);
        out.push(...lines.slice(cursor, hasLayout ? range.start - 1 : range.start));
        const previous = _lastContent(out);
        if (previous === null || /^<table[ >]/.test(previous)) {
            _gap(out);
            out.push(BLANK);
        }
        _gap(out);
        out.push(htmlTable(rows, layout, style), "");
        cursor = range.end;
    }
    out.push(...lines.slice(cursor));
    return {
        text: out.join("\n"),
        layouts: layouts
    };
}

function _gap(out) {
    if (out.length > 0 && !_isBlank(out[out.length - 1]))
        out.push("");
}

function _alignLayouts(layouts, colsList) {
    if (layouts.length === colsList.length && layouts.every((l, i) => l.cols === colsList[i]))
        return layouts;
    const out = [];
    let j = 0;
    colsList.forEach((cols, t) => {
        while (j < layouts.length && layouts[j].cols !== cols && layouts.length - j > colsList.length - t)
            j++;
        if (j < layouts.length && layouts[j].cols === cols)
            out.push(layouts[j++]);
        else
            out.push(defaultLayout(cols));
    });
    return out;
}

function _finishRanges(lines, ranges, layouts) {
    const aligned = _alignLayouts(layouts || [], ranges.map(r => splitRaw(lines[r.start + 1]).length));
    for (let t = ranges.length - 1; t >= 0; t--) {
        const range = ranges[t];
        if (range.end < lines.length && !_isBlank(lines[range.end]))
            lines.splice(range.end, 0, "");
        const insert = isDefaultLayout(aligned[t]) ? [] : [layoutLine(aligned[t])];
        if (range.start > 0 && !_isBlank(lines[range.start - 1]))
            insert.unshift("");
        lines.splice(range.start, 0, ...insert);
    }
    return lines;
}

function _rejoin(segments, expected) {
    const cells = [];
    let i = 0;
    for (let c = 0; c < expected.length; c++) {
        let acc = segments[i++] || "";
        const target = _norm(expected[c], false);
        while (_norm(acc, true) !== target && i < segments.length - (expected.length - 1 - c))
            acc += "|" + segments[i++];
        cells.push(escapePipes(acc.trim()));
    }
    return cells;
}

function repair(md, plain, layouts) {
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
    return _finishRanges(lines, ranges, layouts).join("\n");
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
