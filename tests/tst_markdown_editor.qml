import QtQuick
import QtTest
import "../"

Item {
    width: 500
    height: 600

    MarkdownEditor {
        id: editor
        anchors.fill: parent
        focus: true
    }

    TestCase {
        name: "MarkdownEditor"
        when: windowShown

        function init() {
            editor.setSourceMode(false);
            editor.load("");
            editor.forceActiveFocus();
        }

        function type(str) {
            for (const ch of str) {
                if (ch === " ")
                    keyClick(Qt.Key_Space);
                else if (ch === "\n")
                    keyClick(Qt.Key_Return);
                else
                    keyClick(ch);
                wait(0);
            }
        }

        function md() {
            return editor.markdown().replace(/\n+$/, "");
        }

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

        function test_literal_hash_mid_line_untouched() {
            type("issue #3 ok");
            compare(md(), "issue #3 ok");
        }
    }
}
