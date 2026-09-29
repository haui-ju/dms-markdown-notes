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
        name: "MarkdownEditor"
        editor: subject

        function test_heading() {
            type("# Titulo");
            compare(md(), "# Titulo");
        }

        function test_heading_levels() {
            type("### Sub");
            compare(md(), "### Sub");
        }

        function test_bullet_list() {
            type("- uno\ndos");
            compare(md(), "- uno\n- dos");
        }

        function test_numbered_list() {
            type("1. uno");
            compare(md().replace(/^1\.\s+/, "1. "), "1. uno");
        }

        function test_task_from_brackets() {
            type("[] tarea");
            compare(md(), "- [ ] tarea");
        }

        function test_task_from_bullet() {
            type("- [] tarea");
            compare(md(), "- [ ] tarea");
        }

        function test_new_task_unchecked() {
            editor.load("- [x] hecha\n");
            editor.cursorPosition = editor.length;
            type("\nnueva");
            compare(md(), "- [x] hecha\n- [ ] nueva");
        }

        function test_enter_on_empty_item_ends_list() {
            type("- uno\n\nfin");
            compare(md(), "- uno\n\nfin");
        }

        function test_quote() {
            type("> cita");
            compare(md(), "> cita");
        }

        function test_rule() {
            type("---\ntexto");
            verify(/^(---|- - -)\n+texto$/.test(md()), md());
        }

        function test_bold_inline_then_plain() {
            type("hola **neg** fin");
            compare(md(), "hola **neg** fin");
        }

        function test_italic_inline() {
            type("a *cur* b");
            compare(md(), "a *cur* b");
        }

        function test_code_inline() {
            type("usa `ls` ya");
            compare(md(), "usa `ls` ya");
        }

        function test_toggle_task() {
            editor.load("- [ ] tarea\n");
            verify(editor.toggleTaskAt(0));
            compare(md(), "- [x] tarea");
            verify(editor.toggleTaskAt(0));
            compare(md(), "- [ ] tarea");
        }

        function test_marker_click_toggles() {
            editor.load("- [ ] tarea\n");
            const r = editor.positionToRectangle(0);
            const hit = editor.isMarkerHit(r.x - 8, r.y + r.height / 2);
            compare(hit, 0);
            verify(editor.toggleTaskAt(hit));
            compare(md(), "- [x] tarea");
        }

        function test_ctrl_b_wraps_selection() {
            editor.load("hola mundo\n");
            editor.select(5, 10);
            keyClick(Qt.Key_B, Qt.ControlModifier);
            compare(md(), "hola **mundo**");
        }

        function test_ctrl_1_heading_on_long_paragraph() {
            const long = "palabra ".repeat(20).trim();
            editor.load(long + "\n");
            editor.cursorPosition = 3;
            keyClick(Qt.Key_1, Qt.ControlModifier);
            compare(md().replace(/\n/g, " "), "# " + long);
            verify(md().indexOf("\n") < 0, md());
        }

        function test_ctrl_l_task_toggle_type() {
            editor.load("comprar pan\n");
            keyClick(Qt.Key_L, Qt.ControlModifier);
            compare(md(), "- [ ] comprar pan");
        }

        function test_source_mode_roundtrip() {
            editor.load("# T\n\n- [ ] a\n");
            editor.setSourceMode(true);
            compare(editor.text.replace(/\n+$/, ""), "# T\n\n- [ ] a");
            editor.setSourceMode(false);
            compare(md(), "# T\n\n- [ ] a");
        }

        function test_source_mode_roundtrip_keeps_blank_lines() {
            editor.load("# T\n\nuno\n\n\u00a0\n\n\u00a0\n\ndos\n\n| A | B |\n| --- | --- |\n| 1 |  |\n\n\u00a0\n\nfin\n");
            const before = md();
            for (let i = 0; i < 3; i++) {
                editor.setSourceMode(true);
                compare(editor.markdown().replace(/\n+$/, ""), before);
                editor.setSourceMode(false);
                compare(md(), before);
            }
            compare(before.split("\n").filter(l => l === "\u00a0").length, 3);
        }

        function test_source_mode_edit_keeps_blank_lines_and_code_spaces() {
            editor.load("uno\n\n\u00a0\n\ndos\n");
            editor.setSourceMode(true);
            editor.text = "uno\n\n \n\ndos\n\n```\n  \n```\n";
            verify(editor.markdown().indexOf("\n\u00a0\n") > 0);
            verify(editor.markdown().indexOf("```\n  \n```") > 0);
            editor.setSourceMode(false);
            compare(md().split("\n").filter(l => l === "\u00a0").length, 1);
        }

        function test_enter_after_heading_starts_paragraph() {
            type("# Titulo\ntexto");
            compare(md(), "# Titulo\n\ntexto");
        }

        function test_heading_then_subheading() {
            type("# Titulo\n## Sub\n### Mini\nfin");
            compare(md(), "# Titulo\n\n## Sub\n\n### Mini\n\nfin");
        }

        function test_hash_hash_on_new_line() {
            type("hola\n## Sub");
            compare(md(), "hola\n\n## Sub");
        }

        function test_backspace_removes_heading() {
            type("# Titulo");
            editor.cursorPosition = 0;
            keyClick(Qt.Key_Backspace);
            compare(md(), "Titulo");
        }

        function test_backspace_removes_list_marker() {
            type("- item");
            editor.cursorPosition = 0;
            keyClick(Qt.Key_Backspace);
            compare(md(), "item");
        }

        function test_blank_lines_survive_list() {
            type("hola\n\n\n- item");
            compare(md(), "hola\n\n\u00a0\n\n\u00a0\n\n- item");
        }

        function test_blank_lines_survive_rule() {
            type("hola\n\n\n---\nfin");
            verify(/^hola\n\n\u00a0\n\n\u00a0\n\n(---|- - -)\n+fin$/.test(md()), JSON.stringify(md()));
        }

        function test_typing_on_blank_line_drops_nbsp() {
            type("a\n\n");
            editor.cursorPosition = 2;
            type("b");
            compare(md(), "a\n\nb");
        }

        function test_backspace_removes_blank_line() {
            type("a\n\n\nb");
            editor.cursorPosition = 3;
            keyClick(Qt.Key_Backspace);
            compare(md(), "a\n\n\u00a0\n\nb");
        }

        function test_decorations_map_tasks_and_rules() {
            editor.load("Texto\n\n\u00a0\n\n- [ ] uno\n- [x] dos\n\n- - -\nfin\n");
            const d = editor.decorations();
            verify(d !== null);
            compare(d.tasks.length, 2);
            compare(d.tasks[0].checked, false);
            compare(d.tasks[1].checked, true);
            compare(editor.getText(d.tasks[0].start, d.tasks[0].end), "uno");
            compare(d.rules.length, 1);
        }

        function test_decorations_leading_rule() {
            editor.load("- - -\nFIS:\n\n- uno\n");
            const d = editor.decorations();
            verify(d !== null);
            compare(d.rules.length, 1);
            compare(d.rules[0], 1);
        }

        function test_strike_inline() {
            type("a ~~no~~ b");
            compare(md(), "a ~~no~~ b");
        }

        function test_code_fence() {
            type("```\nx = 1");
            verify(/^```\s*\nx = 1\n```$/.test(md()), md());
        }

        function test_bold_inside_list_item_keeps_list() {
            type("- **neg** fin");
            compare(md(), "- **neg** fin");
        }

        function test_empty_load_resets_heading_format() {
            type("# Titulo");
            editor.load("");
            type("x");
            compare(md(), "x");
        }

        function test_literal_hash_mid_line_untouched() {
            type("issue #3 ok");
            compare(md(), "issue #3 ok");
        }
    }
}
