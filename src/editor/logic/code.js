.pragma library

var BLANK = "\u00A0";
var TAB_SIZE = 4;

var LANGUAGES = [
    {
        id: "",
        label: "Texto plano",
        aliases: ["text", "plain", "txt", "plaintext"]
    },
    {
        id: "bash",
        label: "Bash",
        aliases: ["sh", "shell", "zsh", "console"]
    },
    {
        id: "c",
        label: "C",
        aliases: ["h"]
    },
    {
        id: "cpp",
        label: "C++",
        aliases: ["c++", "cc", "hpp", "cxx"]
    },
    {
        id: "css",
        label: "CSS",
        aliases: ["scss", "less"]
    },
    {
        id: "go",
        label: "Go",
        aliases: ["golang"]
    },
    {
        id: "html",
        label: "HTML",
        aliases: ["xml", "svg", "vue"]
    },
    {
        id: "java",
        label: "Java",
        aliases: ["kotlin", "kt"]
    },
    {
        id: "javascript",
        label: "JavaScript",
        aliases: ["js", "jsx", "mjs", "cjs"]
    },
    {
        id: "json",
        label: "JSON",
        aliases: ["jsonc"]
    },
    {
        id: "markdown",
        label: "Markdown",
        aliases: ["md"]
    },
    {
        id: "python",
        label: "Python",
        aliases: ["py"]
    },
    {
        id: "qml",
        label: "QML",
        aliases: []
    },
    {
        id: "rust",
        label: "Rust",
        aliases: ["rs"]
    },
    {
        id: "sql",
        label: "SQL",
        aliases: ["postgres", "mysql", "sqlite"]
    },
    {
        id: "typescript",
        label: "TypeScript",
        aliases: ["ts", "tsx"]
    },
    {
        id: "yaml",
        label: "YAML",
        aliases: ["yml", "toml"]
    }
];

function _words(s) {
    const set = {};
    for (const w of s.split(" "))
        set[w] = true;
    return set;
}

var JS_KEYWORDS = "async await break case catch class const continue debugger default delete do else export extends finally for from function if import in instanceof let new of return static super switch this throw try typeof var void while with yield";
var C_KEYWORDS = "auto break case char const continue default do double else enum extern float for goto if inline int long register return short signed sizeof static struct switch typedef union unsigned void volatile while";

var SPECS = {
    "": null,
    bash: {
        line: ["#"],
        block: [],
        strings: ["\"", "'", "`"],
        keywords: _words("if then else elif fi case esac for while until do done in function return local export echo exit source alias sudo cd set unset"),
        literals: _words("true false"),
        variables: true
    },
    c: {
        line: ["//"],
        block: [["/*", "*/"]],
        strings: ["\"", "'"],
        keywords: _words(C_KEYWORDS + " #include #define #ifdef #ifndef #endif #pragma"),
        literals: _words("NULL true false"),
        types: true
    },
    cpp: {
        line: ["//"],
        block: [["/*", "*/"]],
        strings: ["\"", "'"],
        keywords: _words(C_KEYWORDS + " class namespace template typename public private protected virtual override new delete using try catch throw constexpr auto nullptr bool this operator friend #include #define #ifdef #ifndef #endif #pragma"),
        literals: _words("nullptr true false NULL"),
        types: true
    },
    css: {
        line: [],
        block: [["/*", "*/"]],
        strings: ["\"", "'"],
        keywords: _words("@media @import @keyframes @font-face @supports !important"),
        literals: _words(""),
        css: true
    },
    go: {
        line: ["//"],
        block: [["/*", "*/"]],
        strings: ["\"", "'", "`"],
        multiline: ["`"],
        keywords: _words("break case chan const continue default defer else fallthrough for func go goto if import interface map package range return select struct switch type var"),
        literals: _words("true false nil iota"),
        types: true
    },
    html: {
        line: [],
        block: [["<!--", "-->"]],
        strings: ["\"", "'"],
        keywords: _words(""),
        literals: _words(""),
        tags: true
    },
    java: {
        line: ["//"],
        block: [["/*", "*/"]],
        strings: ["\"", "'"],
        keywords: _words("abstract assert break case catch class const continue default do else enum extends final finally for if implements import instanceof interface native new package private protected public return static super switch synchronized this throw throws try void volatile while var val fun when object override"),
        literals: _words("true false null"),
        types: true
    },
    javascript: {
        line: ["//"],
        block: [["/*", "*/"]],
        strings: ["\"", "'", "`"],
        multiline: ["`"],
        keywords: _words(JS_KEYWORDS),
        literals: _words("true false null undefined NaN Infinity"),
        types: true
    },
    json: {
        line: ["//"],
        block: [["/*", "*/"]],
        strings: ["\""],
        keywords: _words(""),
        literals: _words("true false null"),
        keys: true
    },
    markdown: {
        markdown: true
    },
    python: {
        line: ["#"],
        block: [],
        strings: ["\"\"\"", "'''", "\"", "'"],
        multiline: ["\"\"\"", "'''"],
        keywords: _words("and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield match case print self"),
        literals: _words("True False None"),
        types: true
    },
    qml: {
        line: ["//"],
        block: [["/*", "*/"]],
        strings: ["\"", "'", "`"],
        keywords: _words(JS_KEYWORDS + " property alias signal readonly required component pragma on"),
        literals: _words("true false null undefined"),
        types: true
    },
    rust: {
        line: ["//"],
        block: [["/*", "*/"]],
        strings: ["\""],
        keywords: _words("as async await break const continue crate dyn else enum extern fn for if impl in let loop match mod move mut pub ref return self Self static struct super trait type unsafe use where while"),
        literals: _words("true false None Some Ok Err"),
        types: true
    },
    sql: {
        line: ["--"],
        block: [["/*", "*/"]],
        strings: ["'", "\""],
        keywords: _words("select from where and or not insert into values update set delete create table drop alter add join left right inner outer on group by order having limit offset as distinct union all primary key foreign references index view if exists null is like in between case when then else end returning"),
        literals: _words("true false null"),
        caseInsensitive: true
    },
    typescript: {
        line: ["//"],
        block: [["/*", "*/"]],
        strings: ["\"", "'", "`"],
        multiline: ["`"],
        keywords: _words(JS_KEYWORDS + " interface type enum implements private public protected readonly abstract declare namespace keyof as is satisfies"),
        literals: _words("true false null undefined"),
        types: true
    },
    yaml: {
        line: ["#"],
        block: [],
        strings: ["\"", "'"],
        keywords: _words(""),
        literals: _words("true false null yes no on off"),
        keys: true
    }
};

function resolve(lang) {
    const key = (lang || "").trim().toLowerCase();
    for (const l of LANGUAGES) {
        if (l.id === key || l.aliases.indexOf(key) >= 0)
            return l.id;
    }
    return null;
}

function label(lang) {
    const id = resolve(lang);
    if (id === null)
        return lang;
    return LANGUAGES.find(l => l.id === id).label;
}

function fenceLang(line) {
    const m = line.match(/^\s*```+\s*([^\s`]*)/);
    return m ? m[1] : "";
}

function fences(lines) {
    const out = [];
    let open = -1;
    for (let i = 0; i < lines.length; i++) {
        if (!/^\s*```/.test(lines[i]))
            continue;
        if (open < 0) {
            open = i;
        } else {
            out.push({
                start: open,
                end: i,
                lang: fenceLang(lines[open])
            });
            open = -1;
        }
    }
    return out;
}

function _isBlank(line) {
    return /^[ \t]*$/.test(line);
}

function prepare(md) {
    if (md.indexOf("```") < 0)
        return md;
    const lines = md.split("\n");
    const found = fences(lines);
    if (found.length === 0)
        return md;
    const out = [];
    let cursor = 0;
    let lastFenceEnd = -1;
    for (const f of found) {
        const before = lines.slice(cursor, f.start);
        out.push(...before);
        const previous = _lastContent(out);
        if (previous === null || (lastFenceEnd >= 0 && before.every(_isBlank) && _isFence(previous))) {
            if (out.length > 0 && !_isBlank(out[out.length - 1]))
                out.push("");
            out.push(BLANK, "");
        }
        const body = lines.slice(f.start + 1, f.end);
        out.push(lines[f.start], "", ...(body.length ? body : [""]), "", lines[f.end]);
        cursor = f.end + 1;
        lastFenceEnd = out.length - 1;
    }
    const tail = lines.slice(cursor);
    out.push(...tail);
    if (tail.every(_isBlank))
        out.push("", BLANK);
    return out.join("\n");
}

function _isFence(line) {
    return /^\s*```/.test(line);
}

function _lastContent(out) {
    for (let i = out.length - 1; i >= 0; i--) {
        if (!_isBlank(out[i]))
            return out[i];
    }
    return null;
}

function repair(md) {
    if (md.indexOf("```") < 0)
        return md;
    const lines = md.split("\n");
    const found = fences(lines);
    for (let k = found.length - 1; k >= 0; k--) {
        const f = found[k];
        let body = lines.slice(f.start + 1, f.end);
        if (_afterList(lines, f.start))
            body = _halveBlankRuns(body);
        if (body.length > 0 && _isBlank(body[0]))
            body.shift();
        lines.splice(f.start + 1, f.end - f.start - 1, ...body);
    }
    return lines.join("\n");
}

function _afterList(lines, start) {
    let i = start - 1;
    while (i >= 0 && _isBlank(lines[i]))
        i--;
    return i >= 0 && /^\s*([-*+]|\d+[.)])\s/.test(lines[i]);
}

function _halveBlankRuns(body) {
    const out = [];
    let run = 0;
    const flush = () => {
        for (let i = 0; i < Math.ceil(run / 2); i++)
            out.push("");
        run = 0;
    };
    for (const line of body) {
        if (_isBlank(line)) {
            run++;
            continue;
        }
        flush();
        out.push(line);
    }
    flush();
    return out;
}

function expandTabs(text) {
    if (text.indexOf("\t") < 0)
        return text;
    let out = "";
    for (const ch of text) {
        if (ch === "\t")
            out += " ".repeat(TAB_SIZE - out.length % TAB_SIZE);
        else
            out += ch;
    }
    return out;
}

function _startsAt(text, i, token) {
    return token.length > 0 && text.substr(i, token.length) === token;
}

function _scanString(text, i, quote) {
    return _scanClose(text, i + quote.length, quote);
}

function _scanClose(text, from, quote) {
    let j = from;
    while (j < text.length) {
        if (text[j] === "\\" && quote.length === 1) {
            j += 2;
            continue;
        }
        if (_startsAt(text, j, quote))
            return {
                end: j + quote.length,
                closed: true
            };
        j++;
    }
    return {
        end: text.length,
        closed: false
    };
}

function _nextNonSpace(text, i) {
    while (i < text.length && (text[i] === " " || text[i] === "\t"))
        i++;
    return text[i] || "";
}

function _tokenizeMarkdown(text) {
    if (/^\s*#{1,6}\s/.test(text))
        return [{
                text: text,
                kind: "keyword"
            }];
    if (/^\s*([-*+]|\d+[.)])\s/.test(text)) {
        const m = text.match(/^(\s*([-*+]|\d+[.)]))(.*)$/);
        return [{
                text: m[1],
                kind: "keyword"
            }, {
                text: m[3],
                kind: "plain"
            }];
    }
    if (/^\s*>/.test(text))
        return [{
                text: text,
                kind: "comment"
            }];
    return [{
            text: text,
            kind: "plain"
        }];
}

function tokenizeLine(text, spec, state) {
    const tokens = [];
    const push = (value, kind) => {
        if (value === "")
            return;
        const last = tokens[tokens.length - 1];
        if (last && last.kind === kind)
            last.text += value;
        else
            tokens.push({
                text: value,
                kind: kind
            });
    };
    if (!spec) {
        push(text, "plain");
        return tokens;
    }
    if (spec.markdown)
        return _tokenizeMarkdown(text);
    let i = 0;
    let inTag = false;
    while (i < text.length) {
        if (state.block) {
            const end = text.indexOf(state.block, i);
            const stop = end < 0 ? text.length : end + state.block.length;
            push(text.substring(i, stop), "comment");
            if (end >= 0)
                state.block = null;
            i = stop;
            continue;
        }
        if (state.string) {
            const r = _scanClose(text, i, state.string);
            push(text.substring(i, r.end), "string");
            if (r.closed)
                state.string = null;
            i = r.end;
            continue;
        }
        const rest = text.substring(i);
        const lineComment = spec.line.find(t => _startsAt(text, i, t) && (t !== "#" || !spec.variables || i === 0 || /\s/.test(text[i - 1])));
        if (lineComment) {
            push(rest, "comment");
            break;
        }
        const block = spec.block.find(b => _startsAt(text, i, b[0]));
        if (block) {
            const end = text.indexOf(block[1], i + block[0].length);
            const stop = end < 0 ? text.length : end + block[1].length;
            push(text.substring(i, stop), "comment");
            if (end < 0)
                state.block = block[1];
            i = stop;
            continue;
        }
        const quote = spec.strings.find(q => _startsAt(text, i, q));
        if (quote) {
            const r = _scanString(text, i, quote);
            push(text.substring(i, r.end), spec.keys && _nextNonSpace(text, r.end) === ":" ? "type" : "string");
            if (!r.closed && spec.multiline && spec.multiline.indexOf(quote) >= 0)
                state.string = quote;
            i = r.end;
            continue;
        }
        if (spec.tags && text[i] === "<") {
            const m = rest.match(/^<\/?[A-Za-z][\w:.-]*/);
            if (m) {
                push(m[0], "keyword");
                inTag = true;
                i += m[0].length;
                continue;
            }
        }
        if (spec.tags && inTag && (text[i] === ">" || _startsAt(text, i, "/>"))) {
            const t = text[i] === ">" ? ">" : "/>";
            push(t, "keyword");
            inTag = false;
            i += t.length;
            continue;
        }
        if (spec.variables && text[i] === "$") {
            const m = rest.match(/^\$(\{[^}]*\}|[A-Za-z_]\w*|[0-9@#?*!$-])/);
            if (m) {
                push(m[0], "type");
                i += m[0].length;
                continue;
            }
        }
        if (spec.css && text[i] === "#") {
            const m = rest.match(/^#[0-9A-Fa-f]{3,8}\b/);
            if (m) {
                push(m[0], "number");
                i += m[0].length;
                continue;
            }
        }
        const number = /^\d/.test(rest) && (i === 0 || !/[\w$]/.test(text[i - 1])) ? rest.match(/^(0x[\da-fA-F_]+|\d[\d_]*(\.\d+)?([eE][+-]?\d+)?)[a-zA-Z%]*/) : null;
        if (number) {
            push(number[0], "number");
            i += number[0].length;
            continue;
        }
        const word = rest.match(/^[#@!]?[A-Za-z_$][\w$-]*/);
        if (word && (i === 0 || !/[\w$]/.test(text[i - 1]))) {
            let value = word[0];
            if (!spec.css && !spec.tags)
                value = value.replace(/-.*$/, "");
            if (!spec.keywords[value] && /^[#@!]/.test(value) && !spec.css) {
                push(value[0], "plain");
                i += 1;
                continue;
            }
            const key = spec.caseInsensitive ? value.toLowerCase() : value;
            const next = _nextNonSpace(text, i + value.length);
            let kind = "plain";
            if (spec.keywords[key])
                kind = "keyword";
            else if (spec.literals[key])
                kind = "number";
            else if ((spec.css || spec.keys) && next === ":")
                kind = "type";
            else if (spec.tags && inTag && next === "=")
                kind = "type";
            else if (!spec.css && !spec.tags && next === "(")
                kind = "function";
            else if (spec.types && /^[A-Z][a-z]\w*$/.test(value))
                kind = "type";
            push(value, kind);
            i += value.length;
            continue;
        }
        push(text[i], "plain");
        i++;
    }
    return tokens;
}

function tokenize(lines, lang) {
    const id = resolve(lang);
    const spec = id === null ? null : SPECS[id];
    const state = {
        block: null,
        string: null
    };
    return lines.map(line => tokenizeLine(expandTabs(line), spec, state));
}

function _escape(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/ /g, "&nbsp;");
}

function toHtml(tokens, colors) {
    return tokens.map(t => {
        const color = colors[t.kind];
        const text = t.kind === "comment" ? "<i>" + _escape(t.text) + "</i>" : _escape(t.text);
        return color ? "<font color=\"" + color + "\">" + text + "</font>" : text;
    }).join("");
}
