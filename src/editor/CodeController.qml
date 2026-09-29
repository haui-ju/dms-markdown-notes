import QtQuick
import "logic/code.js" as Code
import "logic/markdown.js" as Md

QtObject {
    id: root

    required property var editor
    property var blocks: []
    property string _key: ""

    function codes() {
        const d = editor.decorations();
        return d ? d.codes : [];
    }

    function at(pos) {
        if (editor.sourceMode)
            return null;
        const list = codes();
        for (let k = 0; k < list.length; k++) {
            const lines = list[k].lines;
            if (pos < lines[0].start || pos > lines[lines.length - 1].end)
                continue;
            let li = 0;
            while (li + 1 < lines.length && lines[li + 1].start <= pos)
                li++;
            const content = lines.map((l, i) => i).filter(i => !lines[i].pad);
            const first = content.length > 0 ? content[0] : 0;
            const last = content.length > 0 ? content[content.length - 1] : lines.length - 1;
            return {
                index: k,
                code: list[k],
                line: li,
                pad: !!lines[li].pad,
                start: lines[li].start,
                end: lines[li].end,
                text: editor.plain().substring(lines[li].start, lines[li].end),
                first: li === first,
                last: li === last,
                single: first === last,
                empty: content.every(i => lines[i].start === lines[i].end),
                contentStart: lines[first].start,
                contentEnd: lines[last].end,
                blockStart: lines[0].start,
                blockEnd: lines[lines.length - 1].end
            };
        }
        return null;
    }

    function blankLine(pos) {
        const block = editor.blockRange(pos);
        if (block.text !== Md.BLANK)
            return null;
        const before = block.start > 0 ? at(block.start - 1) : null;
        const after = block.end < editor.length ? at(block.end + 1) : null;
        return {
            start: block.start,
            end: block.end,
            before: before,
            after: after,
            last: block.end >= editor.length,
            needed: (before !== null && (after !== null || block.end >= editor.length)) || (after !== null && block.start === 0)
        };
    }

    function containsSelection() {
        return at(editor.selectionStart) !== null || at(editor.selectionEnd) !== null;
    }

    function measure() {
        const list = editor.sourceMode ? [] : codes();
        const plain = editor.plain();
        const colors = editor.codeColors;
        const out = list.map((c, k) => {
            const tokens = Code.tokenize(c.lines.map(l => plain.substring(l.start, l.end)), c.lang);
            const lines = c.lines.map((l, i) => {
                const r = editor.positionToRectangle(l.start);
                return {
                    start: l.start,
                    end: l.end,
                    x: r.x,
                    y: r.y,
                    height: r.height,
                    html: Code.toHtml(tokens[i], colors)
                };
            });
            const last = lines[lines.length - 1];
            return {
                index: k,
                lang: c.lang,
                label: Code.label(c.lang),
                padded: c.lines[0].pad,
                top: lines[0].y,
                bottom: last.y + last.height,
                lines: lines
            };
        });
        const key = JSON.stringify(out);
        if (key === _key)
            return;
        _key = key;
        blocks = out;
    }

    function _fence(index) {
        const lines = editor.markdownText.split("\n");
        return {
            lines: lines,
            fence: Code.fences(lines)[index]
        };
    }

    function text(index) {
        const f = _fence(index);
        return f.fence ? f.lines.slice(f.fence.start + 1, f.fence.end).join("\n") : "";
    }

    function copy(index) {
        return editor.copyPlain(text(index));
    }

    function _keepCursor(md) {
        const start = editor.selectionStart;
        const end = editor.selectionEnd;
        editor.replaceMarkdown(md, () => {
            const max = editor.length;
            if (end > start)
                editor.select(Math.min(start, max), Math.min(end, max));
            else
                editor.cursorPosition = Math.min(start, max);
        });
        return true;
    }

    function setLanguage(index, lang) {
        const f = _fence(index);
        if (!f.fence)
            return false;
        f.lines[f.fence.start] = f.lines[f.fence.start].replace(/^(\s*```+)\s*[^\s`]*.*$/, "$1" + lang);
        return _keepCursor(f.lines.join("\n"));
    }

    function remove(index) {
        const f = _fence(index);
        const block = blocks.find(b => b.index === index);
        if (!f.fence)
            return false;
        const anchor = block ? block.lines[0].start : editor.cursorPosition;
        f.lines.splice(f.fence.start, f.fence.end - f.fence.start + 1);
        editor.replaceMarkdown(f.lines.join("\n"), () => editor.cursorPosition = Math.max(0, Math.min(anchor - 1, editor.length)));
        return true;
    }

    function _around(ctx, fn) {
        return editor.rewriteAt(ctx.end, (lines, idx) => {
            const f = Code.fences(lines).find(item => idx > item.start && idx < item.end);
            return f ? fn(lines, idx, f) : null;
        });
    }

    function exit(ctx) {
        return _around(ctx, (lines, idx, f) => {
            const drop = lines[idx].replace(Md.MARKER, "").trim() === "" && idx === f.end - 1;
            let next = f.end + 1;
            while (next < lines.length && lines[next] === "")
                next++;
            if (lines[next] === Md.BLANK)
                lines[next] = Md.BLANK + Md.MARKER;
            else
                lines.splice(f.end + 1, 0, "", Md.MARKER, "");
            if (drop)
                lines.splice(idx, 1);
            else
                lines[idx] = lines[idx].replace(Md.MARKER, "");
            return lines.join("\n");
        });
    }

    function unwrap(ctx) {
        return _around(ctx, (lines, idx, f) => {
            const before = lines.slice(0, f.start);
            const after = lines.slice(f.end + 1);
            const edge = part => {
                const filled = part.filter(l => l !== "");
                return filled.length === 1 && filled[0] === Md.BLANK ? [] : part;
            };
            return edge(before).concat("", Md.MARKER, "", edge(after)).join("\n");
        });
    }

    function clampCursor() {
        if (editor.selectionStart !== editor.selectionEnd)
            return;
        const ctx = at(editor.cursorPosition);
        if (ctx && ctx.pad)
            editor.cursorPosition = ctx.line === 0 ? ctx.contentStart : ctx.contentEnd;
    }

    function _leave(ctx, forward) {
        const pos = forward ? ctx.blockEnd + 1 : ctx.blockStart - 1;
        if (pos >= 0 && pos <= editor.length)
            editor.cursorPosition = pos;
        else if (forward)
            exit(ctx);
        return true;
    }

    function handleKey(event, ctx) {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (ctrl)
                return exit(ctx);
            return shift ? editor.insertInCode("\n") : false;
        }
        const plain = (event.modifiers & (Qt.ShiftModifier | Qt.AltModifier | Qt.ControlModifier)) === 0;
        const pos = editor.cursorPosition;
        if (editor.selectionStart !== editor.selectionEnd || !plain)
            return false;
        switch (event.key) {
        case Qt.Key_Backspace:
            if (pos !== ctx.start)
                return false;
            return ctx.empty ? unwrap(ctx) : ctx.first;
        case Qt.Key_Delete:
            return pos === ctx.contentEnd;
        case Qt.Key_Up:
            return ctx.first ? _leave(ctx, false) : false;
        case Qt.Key_Down:
            return ctx.last ? _leave(ctx, true) : false;
        case Qt.Key_Left:
            return pos === ctx.contentStart ? _leave(ctx, false) : false;
        case Qt.Key_Right:
            return pos === ctx.contentEnd ? _leave(ctx, true) : false;
        }
        return false;
    }
}
