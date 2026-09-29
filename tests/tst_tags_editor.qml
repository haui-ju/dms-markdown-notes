import QtQuick
import QtTest
import "../src/editor"

Item {
    width: 500
    height: 600

    MarkdownEditor {
        id: subject
        anchors.fill: parent
        focus: true
    }

    SignalSpy {
        id: activated
        target: subject
        signalName: "tagActivated"
    }

    EditorTestCase {
        name: "TagsEditor"
        editor: subject

        function tags(md) {
            subject.load(md);
            subject.refreshDecorations();
            return subject._tags.map(t => t.tag);
        }

        function center(tag) {
            const a = subject.positionToRectangle(tag.start + 1);
            return Qt.point(a.x + 2, a.y + a.height / 2);
        }

        function test_roundtrip_keeps_leading_hash() {
            const cases = ["#idea al inicio", "- #lista x", "1.  #numerada", "- [ ] #tarea", "> #cita", "#a\n\n#b y #c", "texto #medio"];
            for (const c of cases) {
                subject.load(c);
                compare(md(), c);
                subject.load(md());
                compare(md(), c);
            }
        }

        function test_roundtrip_in_table_and_code() {
            subject.load("| a | b |\n|---|---|\n| #celda | x #otra |");
            verify(md().indexOf("|#celda|x #otra|") > 0, md());
            subject.load("a\n\n```\n\\#x #y\n```");
            verify(md().indexOf("```\n\\#x #y\n```") > 0);
        }

        function test_typing_tag_at_start_is_saved_unescaped() {
            type("#tarea pendiente");
            compare(md(), "#tarea pendiente");
            subject.refreshDecorations();
            compare(subject._tags.map(t => t.tag), ["tarea"]);
        }

        function test_heading_is_not_a_tag() {
            compare(tags("# Titulo\n\n## Otro"), []);
        }

        function test_decorations_skip_code_links_and_front_matter() {
            compare(tags("---\ntags: [x]\n---\n#a `#b` [[n#c]] #d\n\n```\n#e\n```"), ["a", "d"]);
        }

        function test_decorations_in_table_and_list() {
            compare(tags("- #uno\n\n| a |\n|---|\n| #dos |"), ["uno", "dos"]);
        }

        function test_source_mode_has_no_tags() {
            tags("#a");
            subject.setSourceMode(true);
            subject.refreshDecorations();
            compare(subject._tags.length, 0);
            compare(subject.tagAt(10, 10), null);
            subject.setSourceMode(false);
        }

        function test_activate_by_position() {
            tags("ver #proyecto/sub ahora");
            const t = subject._tags[0];
            activated.clear();
            const p = center(t);
            verify(subject.activateTagAt(p.x, p.y));
            compare(activated.count, 1);
            compare(activated.signalArguments[0][0], "proyecto/sub");
            const r = subject.positionToRectangle(1);
            verify(!subject.activateTagAt(r.x, r.y + r.height / 2));
            compare(activated.count, 1);
        }

        function test_decoration_follows_edits() {
            tags("#a");
            subject.cursorPosition = 0;
            type("xx ");
            subject.refreshDecorations();
            compare(subject._tags[0].start, 3);
            subject.cursorPosition = 4;
            keyClick(Qt.Key_Backspace);
            subject.refreshDecorations();
            compare(subject._tags.length, 0);
        }

        function test_repair_escaped_code_is_undoable() {
            const broken = "usa `\\\\\\#` y `C:\\\\\\\\dir` fin";
            subject.load(broken);
            compare(subject.escapedCodeCount(), 2);
            compare(subject.repairEscapedCode(), 2);
            compare(md(), "usa `#` y `C:\\dir` fin");
            compare(subject.escapedCodeCount(), 0);
            compare(subject.repairEscapedCode(), 0);
            subject.load(md());
            compare(md(), "usa `#` y `C:\\dir` fin");
            subject.load(broken);
            subject.repairEscapedCode();
            keyClick(Qt.Key_Z, Qt.ControlModifier);
            compare(md(), broken);
        }

        function test_repair_in_table_keeps_toolbar() {
            subject.load("| a | b |\n|---|---|\n| `\\\\\\#` | `x\\\\\\|y` |");
            compare(subject.repairEscapedCode(), 2);
            verify(/\|\s*`#`\s*\|\s*`x\\\|y`\s*\|/.test(md()), md());
            subject.cursorPosition = subject.plain().indexOf("#") + 1;
            subject.table.refresh();
            verify(subject.table.info !== null);
        }
    }
}
