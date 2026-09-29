import QtQuick

// Rich Markdown editor: renders Markdown while typing and serializes back to
// Markdown through `markdown()`. Pure QtQuick so it can be unit-tested.
TextEdit {
    id: root

    property bool sourceMode: false
    readonly property string marker: "\uE000"

    signal edited
    signal rewriteStarted
    signal rewriteFinished

    property int _plainAfterFormatPos: -1
    property bool _loading: false

    textFormat: sourceMode ? TextEdit.PlainText : TextEdit.MarkdownText
    wrapMode: TextEdit.Wrap
    selectByMouse: true
    persistentSelection: true
    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

    onTextChanged: {
        if (!_loading)
            edited();
    }

    function load(md) {
        _loading = true;
        text = md;
        _loading = false;
        cursorPosition = 0;
    }

    function markdown() {
        return text.replace(/\uE000/g, "");
    }

    function setSourceMode(on) {
        if (on === sourceMode)
            return;
        const md = text;
        const pos = cursorPosition;
        _loading = true;
        sourceMode = on;
        text = md;
        _loading = false;
        cursorPosition = on ? 0 : Math.min(pos, length);
    }

    function plain() {
        return getText(0, length);
    }

    function blockRange(pos) {
        const all = plain();
        let s = pos;
        while (s > 0 && all.charCodeAt(s - 1) !== 0x2029)
            s--;
        let e = pos;
        while (e < all.length && all.charCodeAt(e) !== 0x2029)
            e++;
        return {
            start: s,
            end: e,
            text: all.substring(s, e)
        };
    }

    function escapeMarkdown(str) {
        return str.replace(/([\\`*_{}\[\]()#+\-.!|>~<])/g, "\\$1");
    }

    // Parses a serialized Markdown line into list prefix and content.
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

    function _isStructural(line) {
        return /^\s*([-*+]|\d+[.)])\s/.test(line) || /^#{1,6}\s/.test(line) || /^>/.test(line) || /^(```|---|- - -)/.test(line);
    }

    // Wrapped paragraphs span several serialized lines; merge them so a block
    // transform sees the whole paragraph.
    function _joinParagraph(lines, idx) {
        if (_isStructural(lines[idx]))
            return idx;
        let s = idx;
        while (s > 0 && lines[s - 1].trim() !== "" && !_isStructural(lines[s - 1]))
            s--;
        let e = idx;
        while (e + 1 < lines.length && lines[e + 1].trim() !== "" && !_isStructural(lines[e + 1]))
            e++;
        if (s === e)
            return idx;
        const joined = lines.slice(s, e + 1).map(l => l.trim()).join(" ");
        lines.splice(s, e - s + 1, joined);
        return s;
    }

    // Drops a marker at `pos`, lets `fn(line, parsed)` rewrite the serialized
    // Markdown line containing it, then reloads and restores the cursor.
    // `fn` returns the new line, or null to abort without changes.
    function rewriteLineAt(pos, fn) {
        // Inserting at the start of a non-empty block resets its block format.
        const b = blockRange(pos);
        const shift = (pos === b.start && b.text.length > 0) ? 1 : 0;
        _loading = true;
        insert(pos + shift, marker);
        const lines = text.split("\n");
        let idx = lines.findIndex(l => l.indexOf(marker) >= 0);
        if (idx < 0) {
            const p0 = plain().indexOf(marker);
            if (p0 >= 0)
                remove(p0, p0 + 1);
            _loading = false;
            return false;
        }
        idx = _joinParagraph(lines, idx);
        const result = fn(lines[idx], parseLine(lines[idx]));
        if (result === null || result === undefined) {
            const p1 = plain().indexOf(marker);
            remove(p1, p1 + 1);
            cursorPosition = pos;
            _loading = false;
            return false;
        }
        rewriteStarted();
        lines[idx] = result;
        text = lines.join("\n");
        const p = plain().indexOf(marker);
        if (p >= 0) {
            remove(p, p + 1);
            cursorPosition = Math.max(0, p - shift);
        }
        _loading = false;
        rewriteFinished();
        edited();
        return true;
    }

    function _afterMarker(parsed) {
        const i = parsed.rest.indexOf(marker);
        return parsed.rest.substring(i);
    }

    function _stripBlockPrefix(rest) {
        return rest.replace(/^(#{1,6}\s+|>\s?)/, "");
    }

    // Space after a block shortcut at the start of a line.
    function tryBlockShortcut() {
        const b = blockRange(cursorPosition);
        const prefix = plain().substring(b.start, cursorPosition);
        if (!/^(#{1,3}|[-*+]|\d+[.)]|>|\[ ?\]|\[[xX]\])$/.test(prefix))
            return false;
        return rewriteLineAt(cursorPosition, (line, p) => {
            const after = p.list ? _afterMarker(p) : line.substring(line.indexOf(marker));
            if (p.list) {
                if (p.task || !/^\[[ xX]?\]$/.test(prefix))
                    return null;
                const state = /x/i.test(prefix) ? "x" : " ";
                return p.indent + p.bullet + " [" + state + "] " + after;
            }
            if (/^#{1,3}$/.test(prefix))
                return prefix + " " + after;
            if (/^[-*+]$/.test(prefix))
                return "- " + after;
            if (/^\d+[.)]$/.test(prefix))
                return prefix.replace(")", ".") + " " + after;
            if (prefix === ">")
                return "> " + after;
            const state = /x/i.test(prefix) ? "x" : " ";
            return "- [" + state + "] " + after;
        });
    }

    // Enter: horizontal rule, code fence, ending empty list items.
    function tryEnterShortcut() {
        const b = blockRange(cursorPosition);
        if (cursorPosition !== b.end)
            return false;
        if (/^(---|\*\*\*|___)$/.test(b.text)) {
            return rewriteLineAt(cursorPosition, (line, p) => p.list ? null : "---\n\n" + marker);
        }
        if (b.text === "```") {
            return rewriteLineAt(cursorPosition, (line, p) => p.list ? null : "```\n" + marker + "\n```");
        }
        if (b.text === "") {
            return rewriteLineAt(cursorPosition, (line, p) => (p.list || /^(#{1,6}\s|>)/.test(line)) ? "\n" + marker : null);
        }
        // Qt keeps the heading format on the new block; Notion starts a paragraph.
        return rewriteLineAt(cursorPosition, line => /^#{1,6}\s/.test(line) ? line.replace(marker, "") + "\n\n" + marker : null);
    }

    // Backspace at the start of a heading, quote or list item drops the block format.
    function tryBackspaceShortcut() {
        const b = blockRange(cursorPosition);
        if (cursorPosition !== b.start)
            return false;
        return rewriteLineAt(cursorPosition, (line, p) => {
            if (p.list)
                return p.rest;
            if (/^(#{1,6}\s+|>\s?)/.test(line))
                return _stripBlockPrefix(line);
            return null;
        });
    }

    // Qt copies the checked state into the new item; new tasks start unchecked.
    function fixNewTaskItem() {
        const b = blockRange(cursorPosition);
        if (b.text !== "")
            return;
        rewriteLineAt(cursorPosition, (line, p) => {
            if (!p.list || !/x/i.test(p.task))
                return null;
            return p.indent + p.bullet + " [ ] " + _afterMarker(p);
        });
    }

    // Regex source matching `literal` as Qt serializes it (any char may be backslash-escaped).
    function _literalPattern(literal) {
        let src = "";
        for (const ch of literal)
            src += "\\\\?" + ch.replace(/[.*+?^${}()|[\]\\\/]/g, "\\$&");
        return src;
    }

    // Wraps the plain text `literal` that ends right at `pos` in `wrap` markers.
    function _wrapBefore(pos, literal, inner, wrap) {
        const re = new RegExp(_literalPattern(literal) + marker);
        const ok = rewriteLineAt(pos, line => {
            if (!re.test(line))
                return null;
            return line.replace(re, wrap + escapeMarkdown(inner) + wrap + marker);
        });
        return ok;
    }

    // Called before `typed` is inserted: closing **bold**, *italic*, `code`, ~~strike~~.
    function tryInlineShortcut(typed) {
        const b = blockRange(cursorPosition);
        const before = plain().substring(b.start, cursorPosition) + typed;
        const rules = [
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
        for (const r of rules) {
            const m = before.match(r.re);
            if (!m)
                continue;
            const inner = m[1];
            const literal = r.wrap + inner + r.wrap.substring(0, r.wrap.length - typed.length);
            if (!_wrapBefore(cursorPosition, literal, inner, r.wrap))
                return false;
            _plainAfterFormatPos = cursorPosition;
            return true;
        }
        return false;
    }

    function wrapSelection(wrap) {
        if (sourceMode || selectionStart === selectionEnd)
            return false;
        const s = selectionStart;
        const e = selectionEnd;
        const inner = getText(s, e);
        if (inner.indexOf("\u2029") >= 0)
            return false;
        deselect();
        if (!_wrapBefore(e, inner, inner, wrap))
            return false;
        select(cursorPosition - inner.length, cursorPosition);
        return true;
    }

    function _removeStrayMarker() {
        const p = plain().indexOf(marker);
        if (p < 0)
            return;
        const cur = cursorPosition;
        _loading = true;
        remove(p, p + 1);
        _loading = false;
        cursorPosition = cur > p ? cur - 1 : cur;
    }

    // type: "p" | "h1" | "h2" | "h3" | "bullet" | "number" | "task" | "quote"
    function setBlockType(type) {
        if (sourceMode)
            return false;
        return rewriteLineAt(cursorPosition, (line, p) => {
            const rest = _stripBlockPrefix(p.list ? p.rest : line);
            const indent = p.indent || "";
            switch (type) {
            case "h1":
                return "# " + rest;
            case "h2":
                return "## " + rest;
            case "h3":
                return "### " + rest;
            case "bullet":
                return indent + "- " + rest;
            case "number":
                return indent + "1. " + rest;
            case "task":
                if (p.list && p.task)
                    return indent + "- " + rest;
                return indent + "- [ ] " + rest;
            case "quote":
                return "> " + rest;
            default:
                return rest;
            }
        });
    }

    function toggleTaskAt(pos) {
        if (sourceMode)
            return false;
        return rewriteLineAt(pos, (line, p) => {
            if (!p.list || !p.task)
                return null;
            const checked = /x/i.test(p.task);
            return p.indent + p.bullet + " [" + (checked ? " " : "x") + "] " + p.rest;
        });
    }

    // True when (x, y) hits the list marker area of a block that starts at blockStart.
    function isMarkerHit(x, y) {
        const pos = positionAt(x, y);
        const b = blockRange(pos);
        const r = positionToRectangle(b.start);
        if (y < r.y || y > r.y + r.height)
            return -1;
        if (x >= r.x - 2)
            return -1;
        return b.start;
    }

    Keys.onPressed: event => {
        if (sourceMode)
            return;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const alt = (event.modifiers & Qt.AltModifier) !== 0;

        // Typing continues with the format of the previous char; an unformatted
        // placeholder right before the cursor makes text after **bold** plain.
        if (_plainAfterFormatPos >= 0) {
            const armedPos = _plainAfterFormatPos;
            _plainAfterFormatPos = -1;
            if (!ctrl && !alt && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && cursorPosition === armedPos && selectionStart === selectionEnd) {
                _loading = true;
                insert(armedPos, marker);
                cursorPosition = armedPos + 1;
                _loading = false;
                Qt.callLater(_removeStrayMarker);
                return;
            }
        }

        if (ctrl && !alt) {
            switch (event.key) {
            case Qt.Key_B:
                event.accepted = wrapSelection("**");
                return;
            case Qt.Key_I:
                event.accepted = wrapSelection("*");
                return;
            case Qt.Key_E:
                event.accepted = wrapSelection("`");
                return;
            case Qt.Key_1:
                event.accepted = setBlockType("h1");
                return;
            case Qt.Key_2:
                event.accepted = setBlockType("h2");
                return;
            case Qt.Key_3:
                event.accepted = setBlockType("h3");
                return;
            case Qt.Key_0:
                event.accepted = setBlockType("p");
                return;
            case Qt.Key_L:
                event.accepted = setBlockType(shift ? "bullet" : "task");
                return;
            case Qt.Key_O:
                if (shift) {
                    event.accepted = setBlockType("number");
                    return;
                }
                break;
            }
            return;
        }

        if (event.key === Qt.Key_Space && !alt) {
            if (selectionStart === selectionEnd && tryBlockShortcut())
                event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Backspace && !alt && selectionStart === selectionEnd) {
            if (tryBackspaceShortcut())
                event.accepted = true;
            return;
        }

        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !shift) {
            if (selectionStart === selectionEnd && tryEnterShortcut()) {
                event.accepted = true;
                return;
            }
            Qt.callLater(fixNewTaskItem);
            return;
        }

        if ((event.text === "*" || event.text === "`" || event.text === "~") && selectionStart === selectionEnd) {
            if (tryInlineShortcut(event.text))
                event.accepted = true;
        }
    }
}
