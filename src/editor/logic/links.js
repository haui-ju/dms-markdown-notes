.pragma library

var LINK = /\[\[([^\[\]\n\u2029\u2028]+?)\]\]/g;

function targetOf(inner) {
    return inner.split("|")[0].split("#")[0].trim().replace(/\.md$/i, "");
}

function labelOf(inner) {
    const bar = inner.indexOf("|");
    return (bar >= 0 ? inner.substring(bar + 1) : inner).trim();
}

function parse(plain) {
    const out = [];
    LINK.lastIndex = 0;
    let m;
    while ((m = LINK.exec(plain)) !== null) {
        const target = targetOf(m[1]);
        if (target !== "")
            out.push({
                start: m.index,
                end: m.index + m[0].length,
                target: target,
                label: labelOf(m[1])
            });
    }
    return out;
}

function at(links, pos) {
    for (const link of links) {
        if (pos >= link.start && pos < link.end)
            return link;
    }
    return null;
}

function unescape(md) {
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
        return fence === null ? line.replace(/\\\[\[([^\[\]\n]+?)\]\]/g, "[[$1]]") : line;
    }).join("\n");
}

function safeTarget(target) {
    const parts = target.split("/").map(p => p.trim()).filter(p => p !== "" && p !== "." && p !== "..");
    return parts.join("/");
}

function findCommand(dir, target) {
    const base = safeTarget(target).split("/").pop().replace(/[\\*?[\]]/g, "\\$&");
    return ["find", dir, "-type", "f", "-iname", base + ".md"];
}

function _parent(path) {
    return path.substring(0, path.lastIndexOf("/"));
}

function pick(output, dir, target, fromPath) {
    const root = dir.replace(/\/+$/, "") + "/";
    const tail = "/" + safeTarget(target).toLowerCase() + ".md";
    const here = _parent(fromPath || "");
    const found = output.split("\n").filter(p => {
        if (p.indexOf(root) !== 0 || !p.toLowerCase().endsWith(tail))
            return false;
        return !p.substring(root.length).split("/").some(part => part.charAt(0) === ".");
    });
    if (found.length === 0)
        return "";
    found.sort((a, b) => {
        const near = (_parent(b) === here) - (_parent(a) === here);
        return near !== 0 ? near : a.split("/").length - b.split("/").length || a.localeCompare(b);
    });
    return found[0];
}

function newPath(dir, target) {
    const safe = safeTarget(target);
    return safe === "" ? "" : dir.replace(/\/+$/, "") + "/" + safe + ".md";
}
