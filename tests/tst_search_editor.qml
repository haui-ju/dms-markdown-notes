import QtQuick
import QtTest
import "../src/editor"
import "../src/store/search.js" as Search

Item {
    width: 500
    height: 600

    MarkdownEditor {
        id: subject
        anchors.fill: parent
    }

    TestCase {
        name: "SearchEditor"
        when: windowShown

        function selectMatch(md, line, query) {
            subject.load(md);
            const k = Search.occurrence(subject.markdown(), line, query);
            const pos = k < 0 ? -1 : Search.find(subject.plain(), query, k);
            if (pos >= 0)
                subject.select(pos, pos + query.length);
            return subject.selectedText;
        }

        function test_match_in_formatted_note() {
            const md = "# Plan del **viaje**\n\n- comprar pan\n- Viaje a Lima\n\n> el viaje fue largo\n";
            compare(selectMatch(md, 1, "viaje"), "viaje");
            compare(subject.selectionStart, subject.plain().indexOf("viaje"));
            selectMatch(md, 4, "viaje");
            compare(subject.selectionStart, subject.plain().indexOf("Viaje"));
            selectMatch(md, 6, "viaje");
            compare(subject.selectionStart, subject.plain().lastIndexOf("viaje"));
        }

        function test_match_in_table_and_code() {
            const md = "texto\n\n| a | clave |\n|---|---|\n| b | otra clave |\n\n```\nclave = 1\n```\n";
            selectMatch(md, 5, "clave");
            compare(subject.selectedText, "clave");
            const first = subject.plain().indexOf("clave");
            compare(subject.selectionStart, subject.plain().indexOf("clave", first + 1));
            selectMatch(md, 8, "clave");
            compare(subject.selectionStart, subject.plain().lastIndexOf("clave"));
        }

        function test_match_below_front_matter() {
            const md = "---\ntags: hola\n---\n\nhola mundo\n";
            compare(selectMatch(md, 5, "hola"), "hola");
            compare(subject.selectionStart, 0);
        }

        function test_source_mode_offset() {
            subject.load("# Uno\n\ndos Tres\n");
            subject.setSourceMode(true);
            const pos = Search.lineOffset(subject.text, 3, "tres");
            subject.select(pos, pos + 4);
            compare(subject.selectedText, "Tres");
            subject.setSourceMode(false);
        }
    }
}
