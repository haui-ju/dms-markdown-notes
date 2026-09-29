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
        name: "SlashMenu"
        editor: subject

        function test_opens_on_empty_line() {
            type("/");
            verify(editor.slash.active);
            compare(editor.slash.items.length, 11);
            compare(editor.slash.query, "");
        }

        function test_filters_while_typing() {
            type("/tab");
            verify(editor.slash.active);
            compare(editor.slash.query, "tab");
            compare(editor.slash.items[0].id, "table");
        }

        function test_does_not_open_mid_word() {
            type("a/b");
            verify(!editor.slash.active);
            compare(md(), "a/b");
        }

        function test_opens_after_space() {
            type("hola /");
            verify(editor.slash.active);
        }

        function test_escape_closes_and_keeps_text() {
            type("/ti");
            keyClick(Qt.Key_Escape);
            verify(!editor.slash.active);
            compare(md(), "/ti");
        }

        function test_backspace_over_slash_closes() {
            type("/");
            keyClick(Qt.Key_Backspace);
            verify(!editor.slash.active);
            compare(md(), "");
        }

        function test_no_results_closes() {
            type("/zzz");
            verify(!editor.slash.active);
            compare(md(), "/zzz");
        }

        function test_enter_after_no_results_is_normal_enter() {
            type("/zzz\nfin");
            compare(md(), "/zzz\n\nfin");
        }

        function test_heading_command() {
            type("/titulo\nHola");
            compare(md(), "# Hola");
        }

        function test_arrow_navigation_wraps() {
            type("/");
            keyClick(Qt.Key_Up);
            compare(editor.slash.index, editor.slash.items.length - 1);
            keyClick(Qt.Key_Down);
            compare(editor.slash.index, 0);
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Return);
            type("Grande");
            compare(md(), "# Grande");
        }

        function test_tab_accepts() {
            type("/tareas");
            keyClick(Qt.Key_Tab);
            type("hacer");
            compare(md(), "- [ ] hacer");
        }

        function test_command_on_line_with_text() {
            type("hola /titulo\n");
            compare(md().trim(), "# hola");
        }

        function test_task_command_on_task_keeps_task() {
            type("[] algo /tarea\n");
            compare(md().trim(), "- [ ] algo");
        }

        function test_list_commands() {
            type("/lista\nuno");
            compare(md(), "- uno");
            editor.load("");
            type("/numerada\nuno");
            compare(md().replace(/^1\.\s+/, "1. "), "1. uno");
            editor.load("");
            type("/cita\nx");
            compare(md(), "> x");
        }

        function test_rule_command_on_empty_line() {
            type("/separador\nfin");
            verify(/^(---|- - -)\n+fin$/.test(md()), md());
        }

        function test_rule_command_keeps_text_above() {
            type("hola /separador\nfin");
            verify(/^hola\s*\n+(---|- - -)\n+fin$/.test(md()), md());
        }

        function test_code_command() {
            type("/codigo\nx = 1");
            verify(/^\u00a0\n\n```\s*\nx = 1\n```\n\u00a0$/.test(md()), JSON.stringify(md()));
        }

        function test_click_elsewhere_closes() {
            editor.load("uno\n\ndos\n");
            editor.cursorPosition = editor.length;
            type(" /");
            verify(editor.slash.active);
            editor.cursorPosition = 1;
            verify(!editor.slash.active);
        }

        function test_slash_at_start_of_text_line() {
            editor.load("hola\n");
            editor.cursorPosition = 0;
            type("/titulo\n");
            compare(md(), "# hola");
        }

        function test_rewrite_closes_menu() {
            type("/");
            verify(editor.slash.active);
            editor.load("otra\n");
            verify(!editor.slash.active);
        }

        function test_source_mode_never_opens() {
            editor.setSourceMode(true);
            type("/");
            verify(!editor.slash.active);
            editor.setSourceMode(false);
        }
    }
}
