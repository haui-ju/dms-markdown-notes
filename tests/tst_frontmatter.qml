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
            compare(md(), header + "# Nota\n\ntexto");
            compare(subject.plain().indexOf("title"), -1);
            compare(subject._rules.length, 0);
        }

        function test_rewrites_keep_header() {
            subject.load(header + "\ntexto");
            subject.cursorPosition = subject.length;
            type("\n# Titulo\n/tabla\n");
            compare(tables().length, 1);
            verify(md().indexOf(header + "texto\n\n# Titulo") === 0, md());
        }

        function test_undo_keeps_header() {
            subject.load(header + "\ntexto");
            subject.cursorPosition = subject.length;
            type(" mas");
            keyClick(Qt.Key_Z, Qt.ControlModifier);
            compare(md(), header + "texto");
        }
    }
}
