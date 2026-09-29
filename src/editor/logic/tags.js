.pragma library

var STOP = "\\s#,.;:!?()\\[\\]{}\"'`|<>*~=+\\\\&@$%^\\uFDD0\\uFDD1\\uFFFC\\u2028\\u2029\\uE000";
var TAG = new RegExp("(^|[\\s(|*_~\\uFDD0\\uFDD1\\uFFFC\\u2028\\u2029])#([^" + STOP + "]+)", "g");
var QUERY = new RegExp("^#([^" + STOP + "]+)$");
var AWK_STOP = "[^ \\t#,.;:!?()\\[\\]}{\"'`|<>*~=+\\\\&@$%^]";

function valid(tag) {
    return /[^0-9]/.test(tag) && tag.charAt(0) !== "/";
}

function parse(plain) {
    const out = [];
    TAG.lastIndex = 0;
    let m;
    while ((m = TAG.exec(plain)) !== null) {
        const start = m.index + m[1].length;
        const tag = m[2].replace(/\/+$/, "");
        if (valid(tag))
            out.push({
                start: start,
                end: start + 1 + tag.length,
                tag: tag
            });
        TAG.lastIndex = start + 1 + m[2].length;
    }
    return out;
}

function at(tags, pos) {
    for (const tag of tags) {
        if (pos >= tag.start && pos < tag.end)
            return tag;
    }
    return null;
}

function _withoutCode(md) {
    let fence = null;
    return md.split("\n").map(line => {
        const f = line.match(/^\s*(`{3,}|~{3,})/);
        if (f)
            fence = fence === null ? f[1].charAt(0) : (f[1].charAt(0) === fence ? null : fence);
        return f || fence !== null ? "" : line;
    }).join("\n").replace(/(`+)(?!`)[\s\S]*?[^`]\1(?!`)/g, " ");
}

function matchMarkdown(tags, md) {
    const left = {};
    for (const t of parse(_withoutCode(md))) {
        const key = t.tag.toLowerCase();
        left[key] = (left[key] || 0) + 1;
    }
    return tags.filter(t => {
        const key = t.tag.toLowerCase();
        if (!left[key])
            return false;
        left[key]--;
        return true;
    });
}

function fromQuery(query) {
    const m = query.trim().match(QUERY);
    return m && valid(m[1]) ? m[1] : "";
}

function unescape(md) {
    if (md.indexOf("\\#") < 0)
        return md;
    const escaped = new RegExp("^(\\s*(?:>\\s?)*(?:(?:[-*+]|\\d+[.)])\\s+(?:\\[[ xX]\\]\\s+)?)?)\\\\#(?=[^" + STOP + "])");
    const cell = new RegExp("(\\|\\s*)\\\\#(?=[^" + STOP + "])", "g");
    let fence = null;
    return md.split("\n").map(line => {
        const f = line.match(/^\s*(`{3,}|~{3,})/);
        if (f) {
            if (fence === null)
                fence = f[1].charAt(0);
            else if (f[1].charAt(0) === fence)
                fence = null;
            return line;
        }
        if (fence !== null)
            return line;
        return /^\s*\|/.test(line) ? line.replace(cell, "$1#") : line.replace(escaped, "$1#");
    }).join("\n");
}

function _awk(program) {
    return "function norm(s) { sub(/^#/, \"\", s); sub(/\\/+$/, \"\", s); return tolower(s) }\n" + "function ok(s) { return s ~ /[^0-9]/ && substr(s, 1, 1) != \"/\" }\n" + "FNR == 1 { fm = ($0 == \"---\"); fence = 0; intags = 0; hits = 0; if (fm) next }\n" + "fm { if ($0 == \"---\" || $0 == \"...\") { fm = 0; next }\n" + "  if ($0 ~ /^tags?:/) { intags = 1; v = $0; sub(/^tags?:[ \\t]*/, \"\", v) }\n" + "  else if (intags && $0 ~ /^[ \\t]*-/) { v = $0; sub(/^[ \\t]*-[ \\t]*/, \"\", v) }\n" + "  else { intags = 0; next }\n" + "  gsub(/[\\[\\]\"',]/, \" \", v); k = split(v, parts, /[ \\t]+/)\n" + "  for (p = 1; p <= k; p++) if (parts[p] != \"\" && ok(norm(parts[p]))) found(norm(parts[p]), parts[p])\n" + "  next }\n" + "/^[ \\t]*(```|~~~)/ { fence = !fence; next }\n" + "fence { next }\n" + "{ s = $0\n" + "  while (match(s, /(^|[ \\t(|*_~])#" + AWK_STOP + "+/)) {\n" + "    raw = substr(s, RSTART, RLENGTH); anchor = substr(raw, 1, 1) == \"(\" && RSTART > 1 && substr(s, RSTART - 1, 1) == \"]\"\n" + "    sub(/^[ \\t(|*_~]/, \"\", raw)\n" + "    if (!anchor && ok(norm(raw))) found(norm(raw), substr(raw, 2))\n" + "    s = substr(s, RSTART + RLENGTH) } }\n" + program;
}

function searchCommand(dir, tag, perFile) {
    const program = "function found(t, name) { if ((t == want || index(t, want \"/\") == 1) && hits < max && last != FILENAME \":\" FNR) { print FILENAME \":\" FNR \":\" $0; hits++; last = FILENAME \":\" FNR } }\n";
    return ["find", dir, "-mindepth", "1", "-name", ".*", "-prune", "-o", "-type", "f", "-iname", "*.md", "-exec", "awk", "-v", "want=" + tag.toLowerCase().replace(/\/+$/, ""), "-v", "max=" + perFile, _awk(program), "{}", "+"];
}

function listCommand(dir) {
    const program = "function found(t, name) { sub(/^#/, \"\", name); sub(/\\/+$/, \"\", name); if (!(t in label)) label[t] = name; key = FILENAME SUBSEP t; if (!(key in seen)) { seen[key] = 1; count[t]++ } }\n" + "END { for (t in count) print label[t] \"\\t\" count[t] }\n";
    return ["find", dir, "-mindepth", "1", "-name", ".*", "-prune", "-o", "-type", "f", "-iname", "*.md", "-exec", "awk", _awk(program), "{}", "+"];
}

function parseList(output) {
    const byKey = {};
    for (const line of output.split("\n")) {
        const m = line.match(/^(.+)\t(\d+)$/);
        if (!m || !valid(m[1]))
            continue;
        const key = m[1].toLowerCase();
        if (key in byKey)
            byKey[key].count += Number(m[2]);
        else
            byKey[key] = {
                tag: m[1],
                count: Number(m[2])
            };
    }
    const out = Object.keys(byKey).map(k => byKey[k]);
    return out.sort((a, b) => b.count - a.count || a.tag.localeCompare(b.tag));
}
