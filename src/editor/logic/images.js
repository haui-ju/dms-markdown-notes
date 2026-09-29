.pragma library
.import "code.js" as Code

var PATTERN = /!\[([^\]\n]*)\]\(\s*(<[^>\n]*>|[^)\s]+)((?:\s+"[^"\n]*")?)\s*\)/g;
var EXTENSIONS = /\.(png|jpe?g|gif|webp|bmp|svg)$/i;
var PLACEHOLDER_PREFIX = "data:image/svg+xml,";
var QT_ALT = "imagen";
var MISSING = {
    width: 220,
    height: 64
};

function _codeLines(lines) {
    const inCode = new Array(lines.length).fill(false);
    for (const f of Code.fences(lines)) {
        for (let i = f.start; i <= f.end; i++)
            inCode[i] = true;
    }
    return inCode;
}

function _inInlineCode(line, index) {
    return (line.substring(0, index).match(/`/g) || []).length % 2 === 1;
}

function unwrap(src) {
    return /^<.*>$/.test(src) ? src.substring(1, src.length - 1) : src;
}

function find(md) {
    const lines = md.split("\n");
    const inCode = _codeLines(lines);
    const out = [];
    lines.forEach((line, i) => {
        if (inCode[i] || line.indexOf("![") < 0 || /^\s*\|/.test(line))
            return;
        PATTERN.lastIndex = 0;
        let m;
        while ((m = PATTERN.exec(line)) !== null) {
            if ((m.index > 0 && line.charAt(m.index - 1) === "\\") || _inInlineCode(line, m.index))
                continue;
            out.push({
                line: i,
                index: m.index,
                length: m[0].length,
                alt: m[1],
                raw: m[2],
                src: unwrap(m[2]),
                title: m[3]
            });
        }
    });
    return out;
}

function fit(size, maxWidth, maxHeight) {
    if (!size || size.width <= 0 || size.height <= 0)
        return null;
    const scale = Math.min(1, maxWidth / size.width, maxHeight / size.height);
    return {
        width: Math.max(1, Math.round(size.width * scale)),
        height: Math.max(1, Math.round(size.height * scale))
    };
}

function placeholder(size, id) {
    return PLACEHOLDER_PREFIX + encodeURIComponent("<svg width=\"" + size.width + "\" height=\"" + size.height + "\" id=\"i" + id + "\"/>");
}

function isPlaceholder(url) {
    return url.indexOf(PLACEHOLDER_PREFIX) === 0;
}

function prepare(md, sizeOf, maxWidth, maxHeight, registry, gap) {
    const found = find(md);
    const result = {
        text: md,
        images: [],
        sources: {}
    };
    if (found.length === 0)
        return result;
    const lines = md.split("\n");
    for (let k = found.length - 1; k >= 0; k--) {
        const img = found[k];
        if (isPlaceholder(img.src))
            continue;
        const natural = sizeOf(img.src);
        const size = fit(natural, maxWidth, maxHeight) || MISSING;
        const url = placeholder({
            width: size.width,
            height: size.height + 2 * (gap || 0)
        }, registry.idOf(img.src + "\n" + img.alt));
        result.sources[url] = {
            alt: img.alt,
            raw: img.raw
        };
        result.images.unshift({
            src: img.src,
            alt: img.alt,
            width: size.width,
            height: size.height,
            missing: natural === null
        });
        const line = lines[img.line];
        lines[img.line] = line.substring(0, img.index) + "![" + (img.alt || QT_ALT) + "](" + url + img.title + ")" + line.substring(img.index + img.length);
    }
    result.text = lines.join("\n");
    return result;
}

function _escape(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function repair(md, sources) {
    if (md.indexOf(PLACEHOLDER_PREFIX) < 0)
        return md;
    let out = md;
    for (const url in sources) {
        if (out.indexOf(url) < 0)
            continue;
        const image = "(!\\[[^\\]\\n]*\\]\\()" + _escape(url);
        const tail = _escape(url) + "((?:\\s+\"[^\"\\n]*\")?\\))[ \\t]*\\n[ \\t]*(?=(?![-*+]\\s|\\d+[.)]\\s|>|#)\\S)";
        out = out.replace(new RegExp("([^\\n])[ \\t]*\\n[ \\t]*" + image, "g"), (all, before, open) => before + " " + open + url);
        out = out.replace(new RegExp("(^|\\n)\\n" + image, "g"), (all, lead, open) => lead + open + url);
        out = out.replace(new RegExp(tail, "g"), (all, close) => url + close + " ");
        out = out.replace(new RegExp("!\\[[^\\]\\n]*\\]\\(" + _escape(url), "g"), () => "![" + sources[url].alt + "](" + sources[url].raw);
    }
    return out;
}

function list(md) {
    return find(md).filter(img => !isPlaceholder(img.src));
}

function resolve(src, baseDir) {
    if (/^[a-z][a-z0-9+.-]*:/i.test(src))
        return src;
    let path;
    try {
        path = decodeURI(src);
    } catch (e) {
        path = src;
    }
    if (path.charAt(0) !== "/")
        path = (baseDir || "").replace(/\/+$/, "") + "/" + path;
    return "file://" + encodeURI(path);
}

function localPath(url) {
    if (!/^file:\/\//.test(url))
        return "";
    try {
        return decodeURI(url.replace(/^file:\/\//, ""));
    } catch (e) {
        return url.replace(/^file:\/\//, "");
    }
}

function filesFrom(text) {
    const lines = text.split("\n").map(l => l.trim()).filter(l => l !== "");
    if (lines.length === 0)
        return [];
    const paths = lines.map(l => /^file:\/\//.test(l) ? localPath(l) : l);
    return paths.every(p => p.charAt(0) === "/" && EXTENSIONS.test(p)) ? paths : [];
}

function encodePath(relative) {
    return encodeURI(relative).replace(/\(/g, "%28").replace(/\)/g, "%29");
}

function markdownFor(relative, alt) {
    return "![" + (alt || "").replace(/[\[\]]/g, "") + "](" + encodePath(relative) + ")";
}
