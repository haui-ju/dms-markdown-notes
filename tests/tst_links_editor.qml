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
        signalName: "wikiLinkActivated"
    }

    EditorTestCase {
        name: "LinksEditor"
        editor: subject

        function links(md) {
            subject.load(md);
            subject.refreshDecorations();
            return subject._links;
        }

        function center(link) {
            const a = subject.positionToRectangle(link.start + 1);
            return Qt.point(a.x + 2, a.y + a.height / 2);
        }

        function test_roundtrip_keeps_brackets() {
            const cases = ["Ver [[Nota uno]] y [[otra|alias]].", "- [[Lista]]", "# [[Titulo]]", "[[a]][[b]]", "> [[Cita]]"];
            for (const c of cases) {
                subject.load(c);
                compare(md(), c);
            }
        }

        function test_roundtrip_in_table_and_code() {
            subject.load("| a |\n|---|\n| [[Celda]] |");
            verify(md().indexOf("|[[Celda]]|") > 0);
            subject.load("a\n\n```\n\\[[x]] [[y]]\n```");
            verify(md().indexOf("```\n\\[[x]] [[y]]\n```") > 0);
        }

        function test_typing_link_is_saved_unescaped() {
            subject.load("");
            type("ir a [[Plan]]");
            compare(md(), "ir a [[Plan]]");
            subject.refreshDecorations();
            compare(subject._links.length, 1);
            compare(subject._links[0].target, "Plan");
        }

        function test_decorations_skip_code_and_source_mode() {
            compare(links("[[a]]\n\n```\n[[b]]\n```").map(l => l.target), ["a"]);
            subject.setSourceMode(true);
            subject.refreshDecorations();
            compare(subject._links.length, 0);
            compare(subject.wikiLinkAt(10, 10), null);
            subject.setSourceMode(false);
        }

        function test_activate_by_position() {
            const l = links("texto [[Destino|ver]] fin")[0];
            activated.clear();
            const p = center(l);
            verify(subject.activateWikiLinkAt(p.x, p.y));
            compare(activated.count, 1);
            compare(activated.signalArguments[0][0], "Destino");
            const r = subject.positionToRectangle(1);
            verify(!subject.activateWikiLinkAt(r.x, r.y + r.height / 2));
            const end = subject.positionToRectangle(subject.length);
            verify(!subject.activateWikiLinkAt(end.x + 40, end.y + end.height / 2));
            compare(activated.count, 1);
        }

        function test_decoration_follows_edits() {
            links("[[a]]");
            subject.cursorPosition = 0;
            type("xx ");
            subject.refreshDecorations();
            compare(subject._links[0].start, 3);
            subject.load("[[a]]");
            subject.cursorPosition = 2;
            keyClick(Qt.Key_Delete);
            subject.refreshDecorations();
            compare(subject._links.length, 0);
            compare(md(), "[[]]");
        }
    }
}
