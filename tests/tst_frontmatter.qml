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

    EditorTestCase {
        name: "FrontMatter"
        editor: subject

        readonly property string header: "---\ntitle: Hola\ntags: [a, b]\n---\n"

        function test_roundtrip_hidden() {
            subject.load(header + "\n# Nota\n\ntexto");
            compare(md(), header + "\n# Nota\n\ntexto");
            compare(subject.plain().indexOf("title"), -1);
            subject.refreshDecorations();
            compare(subject._rules.length, 0);
        }

        function test_header_without_blank_line() {
            subject.load(header + "texto");
            compare(md(), header + "\ntexto");
        }

        function test_rewrites_keep_header() {
            subject.load(header + "\ntexto");
            subject.cursorPosition = subject.length;
            type("\n# Titulo\n/tabla\n");
            compare(tables().length, 1);
            verify(md().indexOf(header + "\ntexto\n\n# Titulo") === 0, md());
        }

        function test_undo_keeps_header() {
            subject.load(header + "\ntexto");
            subject.cursorPosition = subject.length;
            type(" mas");
            keyClick(Qt.Key_Z, Qt.ControlModifier);
            compare(md(), header + "\ntexto");
        }

        function test_header_does_not_leak_into_next_note() {
            subject.load(header + "\nuno");
            subject.load("dos");
            compare(md(), "dos");
            subject.load(header + "\nuno");
            subject.load("");
            compare(md(), "");
        }

        function test_decorations_work_below_header() {
            subject.load(header + "\n- [ ] tarea\n\n---\n\n```js\nx\n```\n\n> cita\n\nfin");
            const d = subject.decorations();
            verify(d !== null);
            compare(d.tasks.length, 1);
            compare(d.rules.length, 1);
            compare(d.codes.length, 1);
            compare(d.quotes.length, 1);
        }

        function test_source_mode_shows_header() {
            subject.load(header + "\ntexto");
            subject.setSourceMode(true);
            verify(subject.plain().indexOf("title: Hola") >= 0);
            subject.setSourceMode(false);
            compare(md(), header + "\ntexto");
            compare(subject.plain().indexOf("title"), -1);
        }

        function test_header_only_note() {
            subject.load(header);
            compare(subject.markdown().trim(), header.trim());
            compare(subject.plain(), "");
            subject.cursorPosition = 0;
            type("hola");
            compare(md(), header + "\nhola");
        }
    }
}
