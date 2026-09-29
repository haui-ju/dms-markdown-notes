import QtQuick
import QtTest
import "../src/editor"
import "../src/editor/logic/paste.js" as Paste

Item {
    width: 500
    height: 600

    MarkdownEditor {
        id: subject
        width: 500
        height: 500
        focus: true
    }

    TextEdit {
        id: richSource
        visible: false
        textFormat: TextEdit.RichText
    }

    TextEdit {
        id: plainSource
        visible: false
        textFormat: TextEdit.PlainText
    }

    EditorTestCase {
        name: "Paste"
        editor: subject

        readonly property string webPage: "<h2>Titulo web</h2>"
            + "<p style=\"font-family:Arial;color:red;background-color:yellow;font-size:26px\">texto <b>negrita</b> "
            + "<a href=\"http://x.com\">link</a></p><ul><li>uno</li><li>dos</li></ul>"
            + "<pre>code\n  x</pre><table border=1><tr><th>A</th><th>B</th></tr>"
            + "<tr><td>1</td><td>2<br>3</td></tr></table><p>fin</p>"

        function copyHtml(html) {
            richSource.text = html;
            richSource.selectAll();
            richSource.copy();
        }

        function copyText(text) {
            plainSource.text = text;
            plainSource.selectAll();
            plainSource.copy();
        }

        function paste(plainOnly) {
            keyClick(Qt.Key_V, plainOnly ? Qt.ControlModifier | Qt.ShiftModifier : Qt.ControlModifier);
        }

        function stable() {
            const saved = subject.markdown();
            subject.load(saved);
            compare(subject.markdown(), saved);
            return saved;
        }

        function test_web_page_keeps_structure_without_styles() {
            subject.load("antes\n\ndespues");
            subject.cursorPosition = 5;
            copyHtml(webPage);
            paste();
            const md = stable();
            verify(/^antes\n\n/.test(md), JSON.stringify(md));
            verify(md.indexOf("**negrita**") > 0);
            verify(md.indexOf("[link](http://x.com)") > 0);
            verify(/- uno\n- dos/.test(md));
            verify(md.indexOf("```\ncode\n  x\n```") > 0, JSON.stringify(md));
            verify(/\|1\s*\|2 3\s*\|/.test(md), JSON.stringify(md));
            verify(/fin\n+despues/.test(md));
            compare(subject.getText(0, subject.length).indexOf("\uE000"), -1);
        }

        function test_paste_inside_code_is_plain_and_stays_inside() {
            subject.load("```\nabc\n```\n\nfin\n");
            subject.cursorPosition = subject.plain().indexOf("abc") + 3;
            copyHtml(webPage);
            paste();
            stable();
            compare(subject.code.codes().length, 1);
            verify(subject.code.text(0).indexOf("abcTitulo web\n") === 0, JSON.stringify(subject.code.text(0)));
            verify(/fin$/.test(md()));
        }

        function test_multiline_text_inside_code() {
            subject.load("```\nabc\n```\n\nfin\n");
            subject.cursorPosition = subject.plain().indexOf("abc") + 3;
            copyText("l1\n  l2\n```\nl3");
            paste();
            compare(subject.cursorPosition, subject.code.at(subject.cursorPosition).contentEnd);
            stable();
            compare(subject.code.codes().length, 1);
            compare(subject.code.text(0), "abcl1\n  l2\n\u200b```\nl3");
        }

        function test_paste_at_code_line_start() {
            subject.load("```\nabc\n```\n\nfin\n");
            subject.cursorPosition = subject.plain().indexOf("abc");
            copyText("X");
            paste();
            compare(subject.code.text(0), "Xabc");
        }

        function test_paste_into_cell_stays_single_line() {
            subject.load("| a | b |\n| --- | --- |\n| 1 | 2 |\n");
            placeInCell(0, 2);
            copyText("x\ny|z");
            paste();
            stable();
            compare(table().length, 2);
            compare(table()[1][0], "1x y\\|z");
            compare(table()[1][1], "2");
        }

        function test_rich_paste_into_cell() {
            subject.load("| a | b |\n| --- | --- |\n| 1 | 2 |\n");
            placeInCell(0, 2);
            copyHtml(webPage);
            paste();
            stable();
            compare(tables().length, 1);
            compare(table()[0].length, 2);
            compare(table()[1][1], "2");
        }

        function test_plain_markdown_is_converted() {
            subject.load("hola");
            subject.cursorPosition = 4;
            copyText("# Titulo\n\n- a\n- b\n\n```py\nx=1\n```");
            paste();
            const md = stable();
            verify(/^hola\n\n# Titulo\n\n- a\n- b\n\n```py\nx=1\n```/.test(md), JSON.stringify(md));
            compare(subject.code.codes()[0].lang, "py");
        }

        function test_single_line_is_literal() {
            subject.load("hola");
            subject.cursorPosition = 4;
            copyText(" # no es titulo *ni cursiva*");
            paste();
            compare(subject.plain(), "hola # no es titulo *ni cursiva*");
            compare(subject.cursorPosition, subject.length);
        }

        function test_plain_lines_become_paragraphs() {
            subject.load("");
            copyText("uno\r\ndos\u2028tres\n\n\ncuatro");
            paste();
            compare(md(), "uno\n\ndos\n\ntres\n\n\u00a0\n\ncuatro");
        }

        function test_paste_in_middle_splits_paragraph() {
            subject.load("antesdespues");
            subject.cursorPosition = 5;
            copyText("# T\n\n- x");
            paste();
            compare(md(), "antes\n\n# T\n\n- x\n\ndespues");
        }

        function test_paste_at_heading_start() {
            subject.load("# Titulo");
            subject.cursorPosition = 0;
            copyText("Mi ");
            paste();
            compare(md(), "# Mi Titulo");
        }

        function test_paste_replaces_selection() {
            subject.load("uno dos tres");
            subject.select(4, 7);
            copyText("DOS");
            paste();
            compare(md(), "uno DOS tres");
        }

        function test_ctrl_shift_v_pastes_plain() {
            subject.load("");
            copyHtml("<p><b>fuerte</b> y <i>cursiva</i></p>");
            paste(true);
            compare(md(), "fuerte y cursiva");
        }

        function test_code_from_editor_becomes_block() {
            subject.load("");
            copyHtml("<pre>def f():\n    return 1\n\nprint(f())</pre>");
            paste();
            stable();
            compare(subject.code.codes().length, 1);
            compare(subject.code.text(0), "def f():\n    return 1\n\nprint(f())");
        }

        function test_pasted_block_at_end_leaves_cursor_below() {
            subject.load("hola");
            subject.cursorPosition = 4;
            copyText("a\n\n```\nx\n```");
            paste();
            compare(subject.code.at(subject.cursorPosition), null);
            type("fin");
            verify(/```\n+fin$/.test(md()), JSON.stringify(md()));
        }

        function test_empty_clipboard_does_nothing() {
            subject.load("hola");
            subject.cursorPosition = 4;
            copyText("  \n\t\n ");
            paste();
            compare(md(), "hola");
        }
    }

    TestCase {
        name: "PasteLogic"

        function test_normalize() {
            compare(Paste.normalize("a\r\nb\rc\u2028d\uE000"), "a\nb\nc\nd");
        }

        function test_looks_like_markdown() {
            verify(Paste.looksLikeMarkdown("# T\n\ntexto\n- a"));
            verify(!Paste.looksLikeMarkdown("uno\ndos\ntres"));
            verify(!Paste.looksLikeMarkdown("# comentario\nx = 1;\ny = 2;\nz();"));
        }

        function test_merge_code_runs() {
            compare(Paste.mergeCodeRuns("p\n\n`a`\n\n`  b`\n\nq"), "p\n\n```\na\n  b\n```\n\nq");
            compare(Paste.mergeCodeRuns("`` x`y ``"), "```\nx`y\n```");
        }

        function test_broken_table_rows_are_joined() {
            compare(Paste.normalizeMarkdown("|a|b|\n|-|-|\n|1|2\n3|"), "|a|b|\n|-|-|\n|1|2 3|");
        }

        function test_block_prefix_and_cell_start() {
            compare(Paste.blockPrefix("- [ ] tarea"), "- [ ] ");
            compare(Paste.blockPrefix("## Titulo"), "## ");
            compare(Paste.blockPrefix("texto"), "");
            compare(Paste.cellStart("| uno | d\uE000os |", 9), 8);
        }
    }
}
