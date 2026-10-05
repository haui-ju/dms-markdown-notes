.pragma library
.import "code.js" as Code

var PATTERN = /!\[([^\]\n]*)\]\(\s*(<[^>\n]*>|[^)\s]+)((?:\s+"[^"\n]*")?)\s*\)/g;
var EXTENSIONS = /\.(png|jpe?g|gif|webp|bmp|svg)$/i;
var PLACEHOLDER_PREFIX = "data:image/svg+xml,";
var QT_ALT = "imagen";
var MINI_SIZE = 50;
var GALLERY_HEAD_LEGACY = /<!--\s*imagen:\s*mini\s*-->/;
var GALLERY_MINI_LEGACY = /<!--\s*imagenes:\s*mini\s*-->/;
var GALLERY_HEAD_OLD = /<!--\s*imagenes:\s*[^>]+-->/;
var GALLERY_OPEN = /<!--\s*img:\s*ancho=[^>]+inicio\s*-->/;
var GALLERY_CLOSE = /<!--\s*img:\s*ancho=[^>]+fin\s*-->/;

function galleryOpenLine(size) {
    const s = size || MINI_SIZE;
    return "<!-- img: ancho=" + s + " inicio -->";
}

function galleryCloseLine(size) {
    const s = size || MINI_SIZE;
    return "<!-- img: ancho=" + s + " fin -->";
}

function galleryLayoutLine(size) {
    return galleryOpenLine(size);
}

var GALLERY_HEAD_LINE = galleryOpenLine(MINI_SIZE);

function parseGallerySize(line) {
    if (GALLERY_HEAD_LEGACY.test(line) || GALLERY_MINI_LEGACY.test(line))
        return MINI_SIZE;
    let m = line.match(/ancho\s*=\s*(\d+)(?:x\d+)?/i);
    if (m)
        return Math.max(16, Number(m[1]));
    m = line.match(/tamano\s*=\s*(\d+)/);
    return m ? Math.max(16, Number(m[1])) : MINI_SIZE;
}
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

function isGalleryClose(line) {
    return GALLERY_CLOSE.test(line);
}

function isEnvelopeOpen(line) {
    return GALLERY_OPEN.test(line);
}

function isGalleryOpen(line) {
    return isEnvelopeOpen(line) || GALLERY_HEAD_OLD.test(line) || GALLERY_HEAD_LEGACY.test(line);
}

function isGalleryHead(line) {
    return isGalleryOpen(line);
}

function _lastImageLine(lines, from, to) {
    let end = from - 1;
    for (let j = from; j <= to; j++) {
        if (lines[j] && lines[j].indexOf("![") >= 0)
            end = j;
    }
    return end;
}

function galleries(lines) {
    const out = [];
    for (let i = 0; i < lines.length; i++) {
        if (!isGalleryOpen(lines[i]))
            continue;
        const open = i;
        const envelope = isEnvelopeOpen(lines[i]);
        let close = -1;
        let end = open;
        if (envelope) {
            let j = open + 1;
            while (j < lines.length && !isGalleryClose(lines[j])) {
                if (lines[j].indexOf("![") >= 0)
                    end = j;
                j++;
            }
            if (j < lines.length && isGalleryClose(lines[j]))
                close = j;
        } else {
            let j = open + 1;
            while (j < lines.length) {
                const t = lines[j].trim();
                if (t === "" || t.indexOf("![") < 0)
                    break;
                end = j;
                j++;
            }
        }
        const start = open + 1;
        if (end < start)
            end = start - 1;
        out.push({
            head: open,
            open: open,
            start: start,
            end: end,
            close: close
        });
        i = close >= 0 ? close : (end >= start ? end : open);
    }
    return out;
}

function galleryAt(lines, line) {
    const all = galleries(lines);
    for (let g = 0; g < all.length; g++) {
        const gal = all[g];
        if (line === gal.head || line === gal.close || line >= gal.start && line <= gal.end)
            return gal;
    }
    return null;
}

function isGalleryImageLine(lines, line) {
    const gal = galleryAt(lines, line);
    return gal && line >= gal.start && line <= gal.end;
}

function miniRowStart(lines, line) {
    const gal = galleryAt(lines, line);
    return gal ? gal.head : line;
}

function isMini(img) {
    return !!img.mini;
}

function captionText(alt) {
    if (!alt || alt === QT_ALT)
        return "";
    return alt;
}

function _imagesOnLine(line) {
    const out = [];
    PATTERN.lastIndex = 0;
    let m;
    while ((m = PATTERN.exec(line)) !== null) {
        if ((m.index > 0 && line.charAt(m.index - 1) === "\\") || _inInlineCode(line, m.index))
            continue;
        out.push({
            index: m.index,
            length: m[0].length,
            text: m[0],
            alt: m[1],
            raw: m[2],
            src: unwrap(m[2]),
            title: m[3] || ""
        });
    }
    return out;
}

function _srcInGalleryLayouts(src, galleryLayouts) {
    if (!galleryLayouts || !src)
        return false;
    for (let g = 0; g < galleryLayouts.length; g++) {
        const block = galleryLayouts[g];
        if (!block || !block.sources)
            continue;
        if (block.sources.indexOf(src) >= 0)
            return true;
    }
    return false;
}

function _isMiniImage(src, line, miniLines, miniBySrc, galleryLayouts, inGal) {
    return inGal || !!(miniLines && miniLines[line]) || !!(miniBySrc && miniBySrc[src]) || _srcInGalleryLayouts(src, galleryLayouts);
}

function find(md, miniLines, miniBySrc, galleryLayouts) {
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
            const gal = galleryAt(lines, i);
            const inGal = !!(gal && i >= gal.start && i <= gal.end);
            const src = unwrap(m[2]);
            out.push({
                line: i,
                index: m.index,
                length: m[0].length,
                alt: m[1],
                raw: m[2],
                src: src,
                title: m[3] || "",
                mini: _isMiniImage(src, i, miniLines, miniBySrc, galleryLayouts, inGal),
                galleryHead: gal ? gal.head : -1
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

function _serialize(img, alt) {
    const safeAlt = (alt || "").replace(/[\[\]]/g, "");
    return "![" + safeAlt + "](" + img.raw + (img.title || "") + ")";
}

function replaceImage(md, ordinal, patch) {
    const items = list(md);
    if (ordinal < 0 || ordinal >= items.length)
        return md;
    const img = items[ordinal];
    const alt = patch.alt !== undefined ? patch.alt : img.alt;
    const lines = md.split("\n");
    const line = lines[img.line];
    const inner = _serialize({ raw: img.raw, title: img.title }, alt);
    lines[img.line] = line.substring(0, img.index) + inner + line.substring(img.index + img.length);
    return lines.join("\n");
}

function _lineWithoutImage(line, img) {
    return (line.substring(0, img.index) + line.substring(img.index + img.length)).replace(/[ \t]{2,}/g, " ").trim();
}

function _galleryHasImages(lines, gal) {
    for (let L = gal.start; L <= gal.end; L++) {
        if (lines[L] && lines[L].indexOf("![") >= 0)
            return true;
    }
    return false;
}

function _removeGalleryShell(lines, gal) {
    if (gal.close >= 0)
        lines.splice(gal.open, gal.close - gal.open + 1);
    else if (gal.end >= gal.start)
        lines.splice(gal.head, gal.end - gal.head + 1);
    else
        lines.splice(gal.head, 1);
}

function _galleryInsertAfter(lines, gal) {
    if (gal.close >= 0)
        return gal.close + 1;
    return gal.end >= gal.start ? gal.end + 1 : gal.head + 1;
}

function wrapAsGallery(lines, lineIndex, token) {
    lines.splice(lineIndex, 1, galleryOpenLine(MINI_SIZE), token, galleryCloseLine(MINI_SIZE));
}

function addToGallery(md, ordinal) {
    const items = list(md);
    if (ordinal < 0 || ordinal >= items.length)
        return md;
    const img = items[ordinal];
    const lines = md.split("\n");
    const row = img.line;
    const gal = galleryAt(lines, row);
    if (gal && row >= gal.start && row <= gal.end)
        return md;
    const line = lines[row];
    const token = line.substring(img.index, img.index + img.length);
    const rest = _lineWithoutImage(line, img);
    const prevGal = row > 0 ? galleryAt(lines, row - 1) : null;
    const nextGal = row + 1 < lines.length ? galleryAt(lines, row + 1) : null;
    if (prevGal && (prevGal.end === row - 1 || prevGal.close === row - 1)) {
        if (rest.indexOf("![") >= 0)
            lines[row] = rest;
        else
            lines.splice(row, 1);
        const at = prevGal.close >= 0 ? prevGal.close : prevGal.end + 1;
        lines.splice(at, 0, token);
        return lines.join("\n");
    }
    if (nextGal && (nextGal.head === row + 1 || nextGal.start === row + 1)) {
        if (rest.indexOf("![") >= 0)
            lines[row] = rest;
        else
            lines.splice(row, 1);
        lines.splice(nextGal.start, 0, token);
        return lines.join("\n");
    }
    if (rest.indexOf("![") >= 0) {
        lines[row] = rest;
        lines.splice(row + 1, 0, galleryOpenLine(MINI_SIZE), token, galleryCloseLine(MINI_SIZE));
    } else {
        wrapAsGallery(lines, row, token);
    }
    return lines.join("\n");
}

function setImageMini(md, ordinal, mini, miniBySrc, galleryLayouts) {
    const items = list(md, null, miniBySrc, galleryLayouts);
    if (ordinal < 0 || ordinal >= items.length)
        return md;
    if (!mini)
        return expandMiniToFullWidth(md, ordinal, miniBySrc, galleryLayouts);
    return addToGallery(md, ordinal);
}

function expandMiniToFullWidth(md, ordinal, miniBySrc, galleryLayouts) {
    const items = list(md, null, miniBySrc, galleryLayouts);
    if (ordinal < 0 || ordinal >= items.length)
        return md;
    const img = items[ordinal];
    const lines = md.split("\n");
    const row = img.line;
    let gal = galleryAt(lines, row);
    const line = lines[row];
    const token = line.substring(img.index, img.index + img.length);
    if (!gal && _srcInGalleryLayouts(img.src, galleryLayouts)) {
        const rest = _lineWithoutImage(line, img);
        if (rest.indexOf("![") >= 0)
            lines[row] = rest;
        else
            lines.splice(row, 1);
        lines.splice(row, 0, token);
        return lines.join("\n");
    }
    if (gal && gal.start <= row && row <= gal.end) {
        const rest = _lineWithoutImage(line, img);
        if (rest.indexOf("![") >= 0)
            lines[row] = rest;
        else
            lines.splice(row, 1);
        let insertAt = row;
        const next = galleries(lines);
        for (let g = 0; g < next.length; g++) {
            const gg = next[g];
            if (gg.head === gal.head) {
                if (!_galleryHasImages(lines, gg)) {
                    _removeGalleryShell(lines, gg);
                    insertAt = gg.head;
                } else
                    insertAt = _galleryInsertAfter(lines, gg);
                break;
            }
        }
        lines.splice(insertAt, 0, token);
        return lines.join("\n");
    }
    const rest = _lineWithoutImage(line, img);
    lines[row] = rest;
    if (rest.indexOf("![") >= 0) {
        lines.splice(row + 1, 0, token);
        return lines.join("\n");
    }
    lines[row] = token;
    return lines.join("\n");
}

function setImageCaption(md, ordinal, caption) {
    return replaceImage(md, ordinal, { alt: caption || "" });
}

function prepare(md, sizeOf, maxWidth, maxHeight, registry, gap, miniLines, miniBySrc, galleryLayouts, captionReserve) {
    const found = find(md, miniLines, miniBySrc, galleryLayouts);
    const result = {
        text: md,
        images: [],
        sources: {}
    };
    if (found.length === 0)
        return result;
    const g = gap || 0;
    const lines = md.split("\n");
    for (let k = found.length - 1; k >= 0; k--) {
        const img = found[k];
        if (isPlaceholder(img.src))
            continue;
        const natural = sizeOf(img.src);
        const mini = img.mini;
        let box;
        if (mini) {
            box = { width: MINI_SIZE, height: MINI_SIZE };
        } else {
            const sized = fit(natural, maxWidth, maxHeight) || MISSING;
            box = { width: sized.width, height: sized.height };
        }
        let ph = box.height;
        if (!mini) {
            ph += 2 * g;
            if (captionReserve)
                ph += captionReserve(img.alt) || 0;
        }
        const url = placeholder({
            width: box.width,
            height: mini ? box.height : ph
        }, registry.idOf(img.src + "\n" + img.alt + "\n" + img.line + "\n" + img.index + "\n" + (mini ? "mini" : "")));
        result.sources[url] = {
            alt: img.alt,
            raw: img.raw,
            title: img.title || "",
            mini: mini
        };
        result.images.unshift({
            src: img.src,
            alt: img.alt,
            mini: mini,
            width: box.width,
            height: box.height,
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
        const meta = sources[url];
        const image = "(!\\[[^\\]\\n]*\\]\\()" + _escape(url);
        const tail = _escape(url) + "((?:\\s+\"[^\"\\n]*\")?\\))[ \\t]*\\n[ \\t]*(?=(?![-*+]\\s|\\d+[.)]\\s|>|#)\\S)";
        out = out.replace(new RegExp("([^\\n])[ \\t]*\\n[ \\t]*" + image, "g"), (all, before, open) => before + " " + open + url);
        out = out.replace(new RegExp("(^|\\n)\\n" + image, "g"), (all, lead, open) => lead + open + url);
        out = out.replace(new RegExp(tail, "g"), (all, close) => url + close + " ");
        out = out.replace(new RegExp("!\\[[^\\]\\n]*\\]\\(" + _escape(url), "g"), () => "![" + meta.alt + "](" + meta.raw + (meta.title || ""));
    }
    return out;
}

function list(md, miniLines, miniBySrc, galleryLayouts) {
    return find(md, miniLines, miniBySrc, galleryLayouts).filter(img => !isPlaceholder(img.src));
}

function galleryForLine(lines, lineIndex) {
    return galleryAt(lines, lineIndex);
}

function appendToGalleryLines(lines, gal, tokens) {
    const at = gal.close >= 0 ? gal.close : _galleryInsertAfter(lines, gal);
    for (let i = tokens.length - 1; i >= 0; i--)
        lines.splice(at, 0, tokens[i]);
}

function _ensureGalleryEnvelope(lines, gal) {
    const size = parseGallerySize(lines[gal.open]);
    let changed = false;
    const wantOpen = galleryOpenLine(size);
    const wantClose = galleryCloseLine(size);
    if (lines[gal.open] !== wantOpen) {
        lines[gal.open] = wantOpen;
        changed = true;
    }
    if (gal.close < 0) {
        const at = gal.end >= gal.start ? gal.end + 1 : gal.open + 1;
        lines.splice(at, 0, wantClose);
        changed = true;
    } else if (lines[gal.close] !== wantClose) {
        lines[gal.close] = wantClose;
        changed = true;
    }
    return changed;
}

function normalizeGalleries(md) {
    let lines = md.split("\n");
    let changed = false;
    for (let pass = 0; pass < 2; pass++) {
        const gals = galleries(lines);
        for (let g = gals.length - 1; g >= 0; g--) {
            if (_ensureGalleryEnvelope(lines, gals[g]))
                changed = true;
        }
    }
    for (let i = lines.length - 1; i >= 0; i--) {
        if (!isGalleryOpen(lines[i]))
            continue;
        let j = i + 1;
        while (j < lines.length) {
            if (isGalleryClose(lines[j]))
                break;
            const t = lines[j].trim();
            if (!isEnvelopeOpen(lines[i]) && (t === "" || t.indexOf("![") < 0))
                break;
            const parts = _imagesOnLine(lines[j]);
            if (parts.length > 1) {
                lines.splice(j, 1, ...parts.map(p => p.text));
                changed = true;
                j += parts.length;
            } else
                j++;
        }
    }
    return changed ? lines.join("\n") : md;
}

function _linesBlankBetween(lines, fromLine, toLine) {
    for (let L = fromLine + 1; L < toLine; L++) {
        if (lines[L] && lines[L].trim() !== "")
            return false;
    }
    return true;
}

function _miniLineGroups(md, miniLines, miniBySrc) {
    const lines = md.split("\n");
    const items = find(md, miniLines).map(im => ({
        line: im.line,
        mini: im.mini || !!(miniBySrc && miniBySrc[im.src])
    })).filter(im => im.mini);
    const groups = [];
    let g = null;
    for (let i = 0; i < items.length; i++) {
        const im = items[i];
        if (!g || im.line > g.last + 1 && !_linesBlankBetween(lines, g.last, im.line)) {
            g = {
                first: im.line,
                last: im.line,
                size: MINI_SIZE
            };
            groups.push(g);
        } else
            g.last = im.line;
    }
    return groups;
}

function galleryLayoutsFromMd(md) {
    const lines = md.split("\n");
    const out = [];
    for (let g = 0; g < galleries(lines).length; g++) {
        const gal = galleries(lines)[g];
        const sources = [];
        for (let L = gal.start; L <= gal.end; L++) {
            const parts = _imagesOnLine(lines[L] || "");
            for (let p = 0; p < parts.length; p++)
                sources.push(parts[p].src);
        }
        if (sources.length)
            out.push({
                size: parseGallerySize(lines[gal.head]),
                sources: sources
            });
    }
    return out;
}

function setSourceInLayouts(layouts, src, mini, size) {
    let next = layouts ? layouts.slice().map(b => ({
        size: b.size || MINI_SIZE,
        sources: b.sources.slice()
    })) : [];
    if (!mini) {
        next = next.map(b => ({
            size: b.size,
            sources: b.sources.filter(s => s !== src)
        })).filter(b => b.sources.length > 0);
        return next;
    }
    for (let i = 0; i < next.length; i++) {
        if (next[i].sources.indexOf(src) >= 0)
            return next;
    }
    const s = size || MINI_SIZE;
    if (next.length && next[next.length - 1].size === s) {
        const last = next[next.length - 1];
        next[next.length - 1] = {
            size: last.size,
            sources: last.sources.concat([src])
        };
    } else {
        next.push({
            size: s,
            sources: [src]
        });
    }
    return next;
}

function appendSourcesToLastLayout(layouts, sources, size) {
    if (!sources || sources.length === 0)
        return layouts || [];
    let next = layouts ? layouts.slice().map(b => ({
        size: b.size || MINI_SIZE,
        sources: b.sources.slice()
    })) : [];
    const s = size || MINI_SIZE;
    if (next.length === 0) {
        next.push({ size: s, sources: sources.slice() });
        return next;
    }
    const last = next[next.length - 1];
    const merged = last.sources.slice();
    for (let i = 0; i < sources.length; i++) {
        if (merged.indexOf(sources[i]) < 0)
            merged.push(sources[i]);
    }
    next[next.length - 1] = { size: last.size, sources: merged };
    return next;
}

function _removeImageBySrc(lines, src) {
    for (let i = 0; i < lines.length; i++) {
        const parts = _imagesOnLine(lines[i]);
        for (let p = 0; p < parts.length; p++) {
            if (parts[p].src !== src)
                continue;
            const token = parts[p].text;
            const rest = (lines[i].substring(0, parts[p].index) + lines[i].substring(parts[p].index + parts[p].length)).replace(/[ \t]{2,}/g, " ").trim();
            if (rest.indexOf("![") >= 0)
                lines[i] = rest;
            else
                lines.splice(i, 1);
            return { token: token, index: i };
        }
    }
    return null;
}

function _pruneGalleryComments(lines) {
    for (let i = lines.length - 1; i >= 0; i--) {
        if (!isGalleryOpen(lines[i]))
            continue;
        let j = i + 1;
        let hasImg = false;
        while (j < lines.length && !isGalleryClose(lines[j])) {
            if (lines[j].indexOf("![") >= 0)
                hasImg = true;
            j++;
        }
        if (!hasImg) {
            const end = j < lines.length && isGalleryClose(lines[j]) ? j : i;
            lines.splice(i, end - i + 1);
        }
    }
}

function applyGalleryLayouts(md, layouts) {
    if (!layouts || !layouts.length)
        return md;
    const blocks = layouts.filter(b => b.sources && b.sources.length);
    if (!blocks.length)
        return md;
    const items = list(md);
    const ranked = blocks.map(block => {
        let minLine = items.length;
        for (let s = 0; s < block.sources.length; s++) {
            for (let k = 0; k < items.length; k++) {
                if (items[k].src === block.sources[s])
                    minLine = Math.min(minLine, items[k].line);
            }
        }
        return {
            block: block,
            minLine: minLine === items.length ? 0 : minLine
        };
    }).sort((a, b) => b.minLine - a.minLine);
    let lines = md.split("\n");
    _pruneGalleryComments(lines);
    for (let g = 0; g < ranked.length; g++) {
        const block = ranked[g].block;
        const tokens = [];
        let insertAt = -1;
        for (let s = 0; s < block.sources.length; s++) {
            const hit = _removeImageBySrc(lines, block.sources[s]);
            if (!hit)
                continue;
            tokens.push(hit.token);
            if (insertAt < 0 || hit.index < insertAt)
                insertAt = hit.index;
        }
        if (tokens.length === 0)
            continue;
        if (insertAt < 0)
            insertAt = 0;
        const size = block.size || MINI_SIZE;
        lines.splice(insertAt, 0, galleryOpenLine(size), ...tokens, galleryCloseLine(size));
    }
    return lines.join("\n");
}

function exportMarkdown(md, miniLines, miniBySrc, galleryLayouts) {
    let out = normalizeGalleries(md);
    if (galleryLayouts && galleryLayouts.length)
        return applyGalleryLayouts(out, galleryLayouts);
    const lines = out.split("\n");
    const groups = _miniLineGroups(out, miniLines, miniBySrc);
    let changed = out !== md;
    for (let t = groups.length - 1; t >= 0; t--) {
        const grp = groups[t];
        const gal = galleryAt(lines, grp.first);
        if (gal && gal.start <= grp.first && grp.last <= gal.end) {
            if (_ensureGalleryEnvelope(lines, gal))
                changed = true;
            continue;
        }
        lines.splice(grp.last + 1, 0, galleryCloseLine(grp.size));
        lines.splice(grp.first, 0, galleryOpenLine(grp.size));
        changed = true;
    }
    return changed ? lines.join("\n") : out;
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
