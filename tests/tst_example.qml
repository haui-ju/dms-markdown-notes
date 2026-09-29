import QtQuick
import QtTest
import "../src/editor"
import "../src/editor/logic/tables.js" as Tables

Item {
    width: 600
    height: 800

    MarkdownEditor {
        id: subject
        anchors.fill: parent
        focus: true
        imageBaseDir: Qt.resolvedUrl("../examples").toString().replace(/^file:\/\//, "")
    }

    EditorTestCase {
        name: "Example"
        editor: subject

        function read(name) {
            const xhr = new XMLHttpRequest();
            xhr.open("GET", Qt.resolvedUrl("../examples/" + name), false);
            xhr.send();
            return xhr.responseText;
        }

        function test_example_is_saved_as_written() {
            const source = read("Ejemplo completo.md");
            verify(source.length > 1000);
            subject.load(source);
            compare(subject.markdown(), source);
            const plain = subject.plain();
            subject.load(subject.markdown());
            compare(subject.plain(), plain);
            compare(subject.markdown(), source);
        }

        function test_example_shows_every_feature() {
            subject.load(read("Ejemplo completo.md"));
            subject.refreshDecorations();
            const md = subject.markdown();
            verify(md.indexOf("---\ntitle: Ejemplo completo\ntags: [ejemplo, markdown-notes]") === 0);
            verify(subject.plain().indexOf("title:") < 0);
            compare(subject._tasks.length, 4);
            compare(subject._tasks.filter(t => t.checked).length, 2);
            compare(subject._quotes.length, 1);
            compare(subject._rules.length, 1);
            compare(subject._links.map(l => l.label), ["Otra nota", "con otro texto", "Otra nota#Sección", "Otra nota"]);
            verify(subject._links.every(l => l.target === "Otra nota"));
            const tags = subject._tags.map(t => t.tag);
            for (const tag of ["ejemplo", "proyecto/release", "idea"])
                verify(tags.indexOf(tag) >= 0, tag);
            compare(Tables.scan(subject.plain()).length, 2);
            compare(subject.tableLayouts.filter(l => l && l.width === 100).length, 1);
            compare(subject.code.blocks.map(b => b.lang), ["python", "bash", "json"]);
            compare(subject.images.length, 1);
            verify(!subject.images[0].missing, JSON.stringify(subject.images[0]));
        }

        function test_linked_note_is_stable() {
            const source = read("Otra nota.md");
            subject.load(source);
            compare(subject.markdown(), source);
        }
    }
}
