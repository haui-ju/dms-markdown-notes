.pragma library
.import "../editor/logic/markdown.js" as Md

var MIN_QUERY = 2;
var MAX_RESULTS = 100;
var PER_FILE = 20;

function command(dir, query) {
    return ["grep", "-rinIF", "--include=*.md", "-m", String(PER_FILE), "--", query, dir];
}

function titleOf(path) {
    return path.split("/").pop().replace(/\.md$/i, "");
}

function clean(line) {
    return line.replace(/^\s*(#{1,6}\s+|>\s?|[-*+]\s+(\[[ xX]\]\s+)?|\d+[.)]\s+)/, "").replace(/\s*\|\s*/g, " · ").replace(/^ · | · $/g, "").replace(/\s+/g, " ").trim();
}

function parse(output, dir) {
    const out = [];
    const prefix = dir.replace(/\/+$/, "") + "/";
    for (const line of output.split("\n")) {
        const m = line.match(/^(.+?\.md):(\d+):(.*)$/i);
        if (!m)
            continue;
        const rel = m[1].indexOf(prefix) === 0 ? m[1].substring(prefix.length) : m[1];
        if (rel.split("/").some(part => part.charAt(0) === "."))
            continue;
        const text = clean(m[3]);
        if (text === "" || /^\s*<!--\s*tabla:/.test(m[3]))
            continue;
        out.push({
            path: m[1],
            title: titleOf(m[1]),
            folder: rel.indexOf("/") >= 0 ? rel.substring(0, rel.lastIndexOf("/")) : "",
            line: Number(m[2]),
            text: text
        });
        if (out.length >= MAX_RESULTS)
            break;
    }
    return out;
}

function _escape(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function highlight(text, query, color, radius) {
    const at = text.toLowerCase().indexOf(query.toLowerCase());
    if (at < 0 || query === "")
        return _escape(text);
    const keep = radius || 60;
    const start = Math.max(0, at - keep);
    const end = Math.min(text.length, at + query.length + keep);
    return (start > 0 ? "…" : "") + _escape(text.substring(start, at)) + "<b><font color=\"" + color + "\">" + _escape(text.substring(at, at + query.length)) + "</font></b>" + _escape(text.substring(at + query.length, end)) + (end < text.length ? "…" : "");
}

function _count(text, needle) {
    let n = 0;
    let i = text.indexOf(needle);
    while (i >= 0) {
        n++;
        i = text.indexOf(needle, i + needle.length);
    }
    return n;
}

function occurrence(md, line, query) {
    const needle = query.toLowerCase();
    const lines = md.split("\n");
    const head = Md.splitFrontMatter(md).head;
    const skip = head === "" ? 0 : head.replace(/\n+$/, "").split("\n").length;
    if (line <= skip || line > lines.length || needle === "")
        return -1;
    let k = 0;
    for (let i = skip; i < line - 1; i++)
        k += _count(lines[i].toLowerCase(), needle);
    return k;
}

function lineOffset(text, line, query) {
    const lines = text.split("\n");
    if (line < 1 || line > lines.length)
        return -1;
    const start = lines.slice(0, line - 1).reduce((n, l) => n + l.length + 1, 0);
    const at = lines[line - 1].toLowerCase().indexOf(query.toLowerCase());
    return start + Math.max(0, at);
}

function find(plain, query, k) {
    const hay = plain.toLowerCase();
    const needle = query.toLowerCase();
    if (needle === "")
        return -1;
    let pos = hay.indexOf(needle);
    const first = pos;
    for (let i = 0; i < k && pos >= 0; i++)
        pos = hay.indexOf(needle, pos + needle.length);
    return pos >= 0 ? pos : first;
}
