.pragma library
.import "markdown.js" as Md
.import "tables.js" as Tables

var CODE_SPAN = /^(`+)(.*)\1$/;
var MARKDOWN_LINE = /^\s{0,3}(#{1,6}\s|[-*+]\s|\d+[.)]\s|>\s?|```|~~~|\|.*\|\s*$|- \[[ xX]\]\s)/;
var CODE_LINE = /[;{}]\s*$|^\s*(def|class|function|import|return|if|for|while|const|let|var)\b.*[:({=]/;

function normalize(text) {
    return (text || "").replace(/\r\n?/g, "\n").replace(/[\u2028\u2029]/g, "\n").replace(/[\uE000\uFDD0\uFDD1]/g, "");
}

function normalizeMarkdown(md) {
    const out = [];
    for (const line of normalize((md || "").replace(/\u2028/g, " ")).split("\n")) {
        const last = out.length - 1;
        if (last >= 0 && /^\s*\|/.test(out[last]) && !/[^\\]\|\s*$/.test(out[last]))
            out[last] += " " + line.trim();
        else
            out.push(line);
    }
    return out.join("\n");
}

function _strip(text) {
    return text.replace(/\\(.)/g, "$1").replace(/\s+/g, "");
}

function isRich(md, plain) {
    return _strip(normalizeMarkdown(md)) !== _strip(plain);
}

function looksLikeMarkdown(text) {
    const lines = text.split("\n").filter(l => l.trim() !== "");
    if (lines.length === 0)
        return false;
    const marked = lines.filter(l => MARKDOWN_LINE.test(l)).length;
    const code = lines.filter(l => CODE_LINE.test(l)).length;
    return marked > 0 && marked * 4 >= lines.length && code * 5 < lines.length;
}

function _codeSpan(paragraph) {
    if (paragraph.length !== 1)
        return null;
    const m = paragraph[0].match(CODE_SPAN);
    if (!m)
        return null;
    return m[1].length > 1 && /^ .* $/.test(m[2]) ? m[2].slice(1, -1) : m[2];
}

function _paragraphs(md) {
    const out = [];
    let current = [];
    for (const line of md.split("\n")) {
        if (line.trim() === "") {
            if (current.length > 0)
                out.push(current);
            current = [];
        } else {
            current.push(line);
        }
    }
    if (current.length > 0)
        out.push(current);
    return out;
}

function fence(text, lang) {
    return "```" + (lang || "") + "\n" + text.split("\n").map(safeCodeLine).join("\n") + "\n```";
}

function safeCodeLine(line) {
    return /^\s*```/.test(line) ? "\u200B" + line : line;
}

function mergeCodeRuns(md) {
    const out = [];
    let run = [];
    const flush = () => {
        if (run.length > 0)
            out.push(fence(run.join("\n")));
        run = [];
    };
    for (const paragraph of _paragraphs(normalizeMarkdown(md))) {
        const code = _codeSpan(paragraph);
        if (code !== null) {
            run.push(code);
            continue;
        }
        flush();
        out.push(paragraph.join("\n"));
    }
    flush();
    return out.join("\n\n");
}

function _isSingleFence(md) {
    const lines = md.split("\n");
    return lines.length >= 2 && /^```/.test(lines[0]) && lines[lines.length - 1] === "```" && lines.slice(1, -1).every(l => !/^```/.test(l));
}

function paragraphsFrom(text) {
    const out = [];
    for (const line of text.split("\n")) {
        if (line.trim() !== "")
            out.push(Md.escape(line.trim()));
        else if (out.length > 0 && out[out.length - 1] !== Md.BLANK)
            out.push(Md.BLANK);
    }
    while (out.length > 0 && out[out.length - 1] === Md.BLANK)
        out.pop();
    return out.join("\n\n");
}

function fragment(plain, md, plainOnly) {
    const text = normalize(plain).replace(/^\n+|\n+$/g, "");
    if (text.trim() === "")
        return "";
    if (plainOnly)
        return text.indexOf("\n") < 0 ? Md.escape(text) : paragraphsFrom(text);
    if (isRich(md, text)) {
        const merged = mergeCodeRuns(md).replace(/^\n+|\n+$/g, "");
        if (_isSingleFence(merged))
            return looksLikeMarkdown(text) ? text : fence(text);
        return merged;
    }
    if (text.indexOf("\n") < 0)
        return Md.escape(text);
    return looksLikeMarkdown(text) ? text : paragraphsFrom(text);
}

function forCode(plain) {
    return normalize(plain).split("\n").map(safeCodeLine).join("\n");
}

function forCell(plain) {
    return Tables.escapePipes(normalize(plain).replace(/\s*\n\s*/g, " ").trim());
}

function blockPrefix(line) {
    return line.match(/^\s*(#{1,6}\s+|>\s*|(?:[-*+]|\d+[.)])\s+(?:\[[ xX]\]\s+)?)?/)[0];
}

function cellStart(line, markerIndex) {
    let i = markerIndex - 1;
    while (i >= 0 && !(line[i] === "|" && line[i - 1] !== "\\"))
        i--;
    i++;
    while (i < markerIndex - 1 && line[i] === " ")
        i++;
    return i;
}

function _isEmptyHead(head) {
    return head.substring(blockPrefix(head).length).replace(Md.BLANK, "").trim() === "";
}

function insertInline(lines, idx, insertAt, text) {
    const line = lines[idx].replace(Md.MARKER, "");
    lines[idx] = line.substring(0, insertAt) + text + Md.MARKER + line.substring(insertAt);
    return lines;
}

function _endsBlock(line) {
    return Md.isStructural(line) && !Md.parseLine(line).list && !/^(#{1,6}\s|>)/.test(line);
}

function splice(lines, idx, insertAt, frag) {
    if (frag.indexOf("\n") < 0)
        return insertInline(lines, idx, insertAt, frag);
    const line = lines[idx].replace(Md.MARKER, "");
    const head = line.substring(0, insertAt);
    const tail = line.substring(insertAt);
    const body = frag.split("\n");
    const prefix = blockPrefix(head).replace(/^#{1,6}\s+/, "");
    const closed = _endsBlock(body[body.length - 1]);
    if (!closed)
        body[body.length - 1] += Md.MARKER;
    const out = _isEmptyHead(head) ? [""] : [head, ""];
    out.push(...body);
    if (tail.trim() !== "")
        out.push("", prefix + (closed ? Md.MARKER : "") + tail);
    else if (closed)
        out.push("", Md.BLANK + Md.MARKER);
    out.push("");
    lines.splice(idx, 1, ...out);
    return lines;
}
