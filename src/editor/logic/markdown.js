.pragma library
.import "tables.js" as Tables

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
    const out = [];
    let fence = false;
    let para = null;
    for (let index = 0; index < lines.length; index++) {
        const line = lines[index];
        if (/^\s*```/.test(line)) {
            fence = !fence;
            para = null;
            continue;
        }
        if (fence) {
            out.push({
                type: "code",
                text: line
            });
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
                text: line.replace(/^#{1,6}\s+/, "")
            });
            para = null;
            continue;
        }
        if (para) {
            para.text += " " + line.trim().replace(/^>\s?/, "");
            continue;
        }
        para = {
            type: "para",
            text: line.replace(/^>\s?/, "")
        };
        out.push(para);
    }
    return out;
}

function norm(s) {
    return s.replace(/!?\[([^\]]*)\]\([^)]*\)/g, "$1").replace(/\\(.)/g, "$1").replace(/[*_`~\u00A0\s\uE000]+/g, "");
}

function decorations(md, plain) {
    const list = blocks(md);
    const tasks = [];
    const rules = [];
    let j = 0;
    let start = 0;
    for (let i = 0; i <= plain.length; i++) {
        if (i < plain.length && !isBoundary(plain.charCodeAt(i)))
            continue;
        const text = plain.substring(start, i);
        const b = list[j];
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
            j++;
        } else if (text.trim() !== "") {
            return null;
        }
        start = i + 1;
    }
    return {
        tasks: tasks,
        rules: rules
    };
}
