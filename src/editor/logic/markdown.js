.pragma library
.import "tables.js" as Tables
.import "code.js" as Code

var MARKER = "\uE000";
var BLANK = "\u00A0";
var PARAGRAPH = 0x2029;

var INLINE_RULES = [
    {
        re: /\*\*([^*\s](?:[^*]*[^*\s])?)\*\*$/,
        wrap: "**"
    },
    {
        re: /~~([^~\s](?:[^~]*[^~\s])?)~~$/,
        wrap: "~~"
    },
    {
        re: /`([^`]+)`$/,
        wrap: "`"
    },
    {
        re: /(?:^|[^*\\])\*([^*\s](?:[^*]*[^*\s])?)\*$/,
        wrap: "*"
    }
];

function isBoundary(code) {
    return code === PARAGRAPH || code === Tables.CELL || code === Tables.TABLE_END;
}

function blockRange(text, pos) {
    let start = pos;
    while (start > 0 && !isBoundary(text.charCodeAt(start - 1)))
        start--;
    let end = pos;
    while (end < text.length && !isBoundary(text.charCodeAt(end)))
        end++;
    return {
        start: start,
        end: end,
        text: text.substring(start, end)
    };
}

function keepBlankLines(md) {
    let fence = false;
    return md.split("\n").map(line => {
        if (/^\s*```/.test(line))
            fence = !fence;
        return !fence && /^[ \u00A0]+$/.test(line) ? BLANK : line;
    }).join("\n");
}

function escape(str) {
    return str.replace(/([\\`*_{}\[\]()#+\-.!|>~<])/g, "\\$1");
}

function parseLine(line) {
    const m = line.match(/^(\s*)([-*+]|\d+[.)])\s+(\[[ xX]\]\s+)?/);
    if (!m)
        return {
            list: false,
            indent: "",
            bullet: "",
            task: "",
            head: "",
            rest: line
        };
    return {
        list: true,
        indent: m[1],
        bullet: m[2],
        task: m[3] || "",
        head: m[0],
        rest: line.substring(m[0].length)
    };
}

function isStructural(line) {
    return /^\s*([-*+]|\d+[.)])\s/.test(line) || /^#{1,6}\s/.test(line) || /^>/.test(line) || /^(```|---|- - -)/.test(line) || Tables.isRow(line) || Tables.isLayoutLine(line);
}

function joinParagraph(lines, idx) {
    if (isStructural(lines[idx]))
        return idx;
    let s = idx;
    while (s > 0 && lines[s - 1].trim() !== "" && !isStructural(lines[s - 1]))
        s--;
    let e = idx;
    while (e + 1 < lines.length && lines[e + 1].trim() !== "" && !isStructural(lines[e + 1]))
        e++;
    if (s !== e)
        lines.splice(s, e - s + 1, lines.slice(s, e + 1).map(l => l.trim()).join(" "));
    return s;
}

function stripBlockPrefix(rest) {
    return rest.replace(/^(#{1,6}\s+|>\s?)/, "");
}

function blockContent(line, parsed) {
    return stripBlockPrefix(parsed.list ? parsed.rest : line).replace(MARKER, "");
}

function literalPattern(literal) {
    let src = "";
    for (const ch of literal)
        src += "\\\\?" + ch.replace(/[.*+?^${}()|[\]\\\/]/g, "\\$&");
    return src;
}

function findInline(before) {
    for (const rule of INLINE_RULES) {
        const m = before.match(rule.re);
        if (m)
            return {
                inner: m[1],
                wrap: rule.wrap
            };
    }
    return null;
}

function blocks(md) {
    const lines = md.split("\n");
    const tableLines = new Set();
    for (const range of Tables.find(lines))
        for (let i = range.start; i < range.end; i++)
            tableLines.add(i);
    const fences = Code.fences(lines);
    const out = [];
    let para = null;
    let code = 0;
    let group = 0;
    let quoted = false;
    for (let index = 0; index < lines.length; index++) {
        const line = lines[index];
        if (!/^[ \t]*>/.test(line) && !(para && para.quote && line.trim() !== ""))
            quoted = false;
        const f = fences[code];
        if (f && index >= f.start && index <= f.end) {
            para = null;
            out.push({
                type: "code",
                pad: index === f.start || index === f.end,
                fence: code,
                lang: f.lang,
                text: index === f.start || index === f.end ? "" : line
            });
            if (index === f.end)
                code++;
            continue;
        }
        if (Tables.isLayoutLine(line)) {
            para = null;
            continue;
        }
        if (tableLines.has(index)) {
            para = null;
            if (!Tables.isDelimiter(line))
                for (const cell of Tables.splitRow(line))
                    out.push({
                        type: "cell",
                        text: cell
                    });
            continue;
        }
        if (/^[ \t]*$/.test(line) || /^>[ \t]*$/.test(line)) {
            para = null;
            continue;
        }
        if (/^\s*(- - -|---+|\*\*\*+|___+)\s*$/.test(line)) {
            out.push({
                type: "rule",
                text: ""
            });
            para = null;
            continue;
        }
        const li = line.match(/^(\s*)([-*+]|\d+[.)])\s+(\[([ xX])\]\s+)?(.*)$/);
        if (li) {
            para = {
                type: li[3] ? "task" : "item",
                checked: li[4] ? /x/i.test(li[4]) : false,
                text: li[5]
            };
            out.push(para);
            continue;
        }
        if (/^#{1,6}\s/.test(line)) {
            out.push({
                type: "heading",
                line: index,
                text: line.replace(/^#{1,6}[ \t]+/, "")
            });
            para = null;
            continue;
        }
        const quote = /^[ \t]*>/.test(line);
        const inner = line.replace(/^([ \t]*>[ \t]?)+/, "");
        const opens = quote && /^(\s*([-*+]|\d+[.)])\s|#{1,6}[ \t])/.test(inner);
        if (para && !para.heading && (!quote || para.quote) && !opens) {
            para.text += " " + _quoteText(line.trim());
            continue;
        }
        if (quote && !quoted) {
            group++;
            quoted = true;
        }
        para = {
            type: "para",
            quote: quote,
            group: quote ? group : 0,
            heading: quote && /^#{1,6}[ \t]/.test(inner),
            text: _quoteText(line)
        };
        out.push(para);
    }
    return out;
}

function _quoteText(line) {
    if (!/^[ \t]*>/.test(line))
        return line;
    return line.replace(/^([ \t]*>[ \t]?)+/, "").replace(/^(\s*([-*+]|\d+[.)])\s+(\[[ xX]\]\s+)?|#{1,6}[ \t]+)/, "");
}

function norm(s) {
    return s.replace(/!?\[([^\]]*)\]\([^)]*\)/g, "$1").replace(/\\(.)/g, "$1").replace(/[*_`~\u00A0\s\uE000\uFFFC]+/g, "");
}

function decorations(md, plain) {
    const list = blocks(md);
    const tasks = [];
    const rules = [];
    const codes = [];
    const quotes = [];
    const addCode = (b, from, to) => {
        let c = codes[codes.length - 1];
        if (!c || c.fence !== b.fence) {
            c = {
                fence: b.fence,
                lang: b.lang,
                lines: []
            };
            codes.push(c);
        }
        c.lines.push({
            start: from,
            end: to,
            pad: b.pad === true
        });
    };
    let j = 0;
    let start = 0;
    for (let i = 0; i <= plain.length; i++) {
        if (i < plain.length && !isBoundary(plain.charCodeAt(i)))
            continue;
        const text = plain.substring(start, i);
        if (text === "" && start > 0 && plain.charCodeAt(start - 1) === Tables.TABLE_END) {
            start = i + 1;
            continue;
        }
        while (list[j] && list[j].pad && text !== "")
            j++;
        const b = list[j];
        if (b && b.type === "code") {
            if (b.pad || norm(b.text) === norm(text)) {
                addCode(b, start, i);
                j++;
                start = i + 1;
                continue;
            }
            return null;
        }
        if (b && b.type === "rule" && start === 0 && plain.charCodeAt(0) === PARAGRAPH && plain.charCodeAt(1) === PARAGRAPH) {
            start = i + 1;
            continue;
        }
        if (b && b.type === "rule" && text === "") {
            rules.push(start);
            j++;
        } else if (b && b.type !== "rule" && norm(b.text) === norm(text)) {
            if (b.type === "task")
                tasks.push({
                    start: start,
                    end: i,
                    checked: b.checked
                });
            if (b.quote) {
                const last = quotes[quotes.length - 1];
                if (last && last.group === b.group)
                    last.end = i;
                else
                    quotes.push({
                        group: b.group,
                        start: start,
                        end: i
                    });
            }
            j++;
        } else if (text.trim() !== "") {
            return null;
        }
        start = i + 1;
    }
    return {
        tasks: tasks,
        rules: rules,
        codes: codes,
        quotes: quotes
    };
}

function plainParts(plain) {
    const parts = [];
    let start = 0;
    for (let i = 0; i <= plain.length; i++) {
        if (i < plain.length && !isBoundary(plain.charCodeAt(i)))
            continue;
        if (i > start || start === 0 || plain.charCodeAt(start - 1) !== Tables.TABLE_END)
            parts.push(plain.substring(start, i));
        start = i + 1;
    }
    return parts;
}

function repairEmptyHeadings(md, plain) {
    if (!/^#{1,6}[ \t]/m.test(md))
        return md;
    const list = blocks(md);
    const parts = plainParts(plain);
    const fixes = [];
    let j = 0;
    for (let k = 0; k < parts.length; k++) {
        const text = parts[k];
        while (list[j] && list[j].pad && text !== "")
            j++;
        const b = list[j];
        if (!b)
            break;
        if (b.type === "code") {
            if (!b.pad && norm(b.text) !== norm(text))
                break;
            j++;
            continue;
        }
        if (b.type === "rule" && k === 0 && text === "" && parts.length > 1 && parts[1] === "")
            continue;
        if (b.type === "heading" && text === "" && b.text !== "" && k + 1 < parts.length) {
            const merged = blocks(b.text)[0];
            if (norm(merged ? merged.text : b.text) === norm(parts[k + 1])) {
                fixes.push(b);
                j++;
                k++;
                continue;
            }
        }
        if (b.type === "rule" ? text === "" : norm(b.text) === norm(text))
            j++;
        else if (text.trim() !== "")
            break;
    }
    if (fixes.length === 0)
        return md;
    const lines = md.split("\n");
    for (let f = fixes.length - 1; f >= 0; f--) {
        const line = lines[fixes[f].line];
        const level = line.match(/^#{1,6}/)[0];
        lines.splice(fixes[f].line, 1, level + " " + BLANK, "", line.replace(/^#{1,6}[ \t]+/, ""));
    }
    return lines.join("\n");
}
