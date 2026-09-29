import QtQuick
import QtTest
import "../src/editor"
import "../src/editor/logic/code.js" as Code

Item {
    width: 500
    height: 600

    MarkdownEditor {
        id: subject
        anchors.fill: parent
        focus: true
    }

    TextEdit {
        id: clipboardReader
        visible: false
        textFormat: TextEdit.PlainText
    }

    EditorTestCase {
        name: "CodeBlocks"
        editor: subject

        function block() {
            return subject.code.at(subject.cursorPosition);
        }

        function stable(source) {
            subject.load(source);
            const first = subject.markdown();
            subject.load(first);
            compare(subject.markdown(), first);
            return first;
        }

        function test_fence_then_typing_stays_inside() {
            type("```\nx = 1\ny = 2");
            compare(subject.code.text(0), "x = 1\ny = 2");
            verify(block() !== null);
        }

        function test_enter_never_exits() {
            type("```\na\n\n\ndentro");
            compare(subject.code.text(0), "a\n\n\ndentro");
            verify(block() !== null);
        }

        function test_ctrl_enter_exits() {
            type("```\na");
            keyClick(Qt.Key_Return, Qt.ControlModifier);
            compare(block(), null);
            type("fuera");
            compare(subject.code.text(0), "a");
            verify(/```\n+fuera$/.test(md()), JSON.stringify(md()));
        }

        function test_ctrl_enter_drops_trailing_empty_line() {
            type("```\na\n");
            keyClick(Qt.Key_Return, Qt.ControlModifier);
            type("fuera");
            compare(subject.code.text(0), "a");
        }

        function test_ctrl_enter_before_following_text() {
            stable("```\na\n```\n\nsigue\n");
            subject.cursorPosition = subject.plain().indexOf("a") + 1;
            keyClick(Qt.Key_Return, Qt.ControlModifier);
            type("nuevo");
            verify(/```\n+nuevo\n\nsigue$/.test(md()), JSON.stringify(md()));
        }

        function test_down_on_last_line_exits() {
            type("```\na");
            keyClick(Qt.Key_Down);
            compare(block(), null);
        }

        function test_shift_enter_adds_line_and_keeps_blocks() {
            stable("```js\nuno\n```\n\ntexto\n\n```py\ndos\n```\n");
            subject.cursorPosition = subject.plain().indexOf("uno") + 3;
            keyClick(Qt.Key_Return, Qt.ShiftModifier);
            type("tres");
            compare(subject.code.text(0), "uno\ntres");
            compare(subject.code.codes().length, 2);
            compare(subject.code.text(1), "dos");
            subject.code.measure();
            compare(subject.code.blocks.length, 2);
            compare(subject.plain().indexOf("\u2028"), -1);
            const saved = subject.markdown();
            subject.load(saved);
            compare(subject.markdown(), saved);
        }

        function test_shift_enter_in_list_keeps_code_decorations() {
            stable("hola\n\n- item\n\n```py\ndos\n```\n\nfin\n");
            subject.cursorPosition = subject.plain().indexOf("item") + 2;
            keyClick(Qt.Key_Return, Qt.ShiftModifier);
            verify(subject.decorations() !== null);
            compare(subject.code.text(0), "dos");
            compare(subject.code.codes().length, 1);
        }

        function test_shift_enter_in_paragraph_keeps_code_decorations() {
            stable("hola mundo\n\n```js\nuno\n```\n\nfin\n");
            subject.cursorPosition = 4;
            keyClick(Qt.Key_Return, Qt.ShiftModifier);
            verify(subject.decorations() !== null);
            compare(subject.code.codes().length, 1);
        }

        function test_shift_enter_in_middle_of_line() {
            stable("```\nabcd\n```\n\nfin\n");
            subject.cursorPosition = subject.plain().indexOf("abcd") + 2;
            keyClick(Qt.Key_Return, Qt.ShiftModifier);
            compare(subject.code.text(0), "ab\ncd");
            compare(subject.cursorPosition, subject.plain().indexOf("cd"));
        }

        function test_enter_in_middle_keeps_blank_line() {
            type("```\na\nb");
            subject.cursorPosition = block().contentStart + 1;
            type("\n\n");
            compare(subject.code.text(0), "a\n\n\nb");
        }

        function test_single_empty_line_enter_adds_line() {
            type("```\n\nb");
            compare(subject.code.text(0), "\nb");
        }

        function test_backspace_in_empty_block_unwraps() {
            type("```\n");
            keyClick(Qt.Key_Backspace);
            compare(subject.markdown().indexOf("```"), -1);
            type("hola");
            compare(md(), "hola");
        }

        function test_backspace_at_first_line_start_is_swallowed() {
            type("```\nabc");
            subject.cursorPosition = block().contentStart;
            keyClick(Qt.Key_Backspace);
            compare(subject.code.text(0), "abc");
        }

        function test_delete_at_content_end_is_swallowed() {
            stable("```\nabc\n```\n\nfin\n");
            subject.cursorPosition = subject.code.at(subject.plain().indexOf("abc")).contentEnd;
            keyClick(Qt.Key_Delete);
            compare(subject.code.text(0), "abc");
            verify(/fin$/.test(md()));
        }

        function test_arrows_leave_block() {
            stable("antes\n\n```\nabc\n```\n\ndespues\n");
            subject.cursorPosition = subject.plain().indexOf("abc");
            keyClick(Qt.Key_Up);
            compare(block(), null);
            verify(subject.cursorPosition < subject.plain().indexOf("abc"));
            subject.cursorPosition = subject.plain().indexOf("abc") + 3;
            keyClick(Qt.Key_Down);
            compare(block(), null);
            verify(subject.cursorPosition > subject.plain().indexOf("abc"));
            subject.cursorPosition = subject.plain().indexOf("abc") + 3;
            keyClick(Qt.Key_Right);
            compare(block(), null);
            subject.cursorPosition = subject.plain().indexOf("abc");
            keyClick(Qt.Key_Left);
            compare(block(), null);
        }

        function test_cursor_never_rests_on_pad() {
            stable("antes\n\n```\nabc\n```\n\ndespues\n");
            const ctx = subject.code.at(subject.plain().indexOf("abc"));
            subject.cursorPosition = ctx.blockStart;
            wait(0);
            compare(subject.cursorPosition, ctx.contentStart);
            subject.cursorPosition = ctx.blockEnd;
            wait(0);
            compare(subject.cursorPosition, ctx.contentEnd);
        }

        function test_formatting_keys_do_nothing_inside() {
            type("```\nabc");
            subject.select(block().contentStart, block().contentEnd);
            keyClick(Qt.Key_B, Qt.ControlModifier);
            keyClick(Qt.Key_1, Qt.ControlModifier);
            compare(subject.code.text(0), "abc");
            verify(md().indexOf("**") < 0);
        }

        function test_markdown_shortcuts_ignored_inside() {
            type("```\n# no\n- no\n**no** ");
            compare(subject.code.text(0), "# no\n- no\n**no** ");
        }

        function test_slash_menu_closed_inside() {
            type("```\n/");
            verify(!subject.slash.active);
        }

        function test_round_trips_are_stable() {
            stable("x\n\n```js\nconst a = 1;\n\n  if (a) {}\n```\n\ny\n");
            stable("```\n\na\n\n```\n");
            stable("```py\nb\n```\n");
            stable("x\n\n```\n```\n");
            stable("```\na\n```\n\n```py\nb\n```\n");
            stable("```\n    indent\n```\n\n| a |\n| --- |\n| 1 |\n");
        }

        function test_blank_lines_after_list_not_doubled() {
            stable("- a\n- b\n\n```\n\nx\n\n\ny\n\n```\n\nfin\n");
            compare(subject.code.text(0), "\nx\n\n\ny\n");
            stable("1. uno\n\n```py\n```\n");
            compare(subject.code.text(0), "");
        }

        function test_blank_lines_inside_preserved() {
            stable("```\n\na\n\n\nb\n\n```\n\nfin\n");
            compare(subject.code.text(0), "\na\n\n\nb\n");
        }

        function test_adjacent_blocks_keep_language() {
            stable("```js\na\n```\n```py\nb\n```\n");
            compare(subject.code.codes().map(c => c.lang), ["js", "py"]);
            compare(subject.code.text(1), "b");
        }

        function test_empty_block_persists() {
            stable("x\n\n```\n```\n");
            compare(subject.code.codes().length, 1);
            compare(subject.code.text(0), "");
        }

        function test_set_language_and_remove() {
            stable("antes\n\n```\nabc\n```\n\nfin\n");
            verify(subject.code.setLanguage(0, "python"));
            compare(subject.code.codes()[0].lang, "python");
            verify(subject.markdown().indexOf("```python\nabc\n```") >= 0);
            verify(subject.code.setLanguage(0, ""));
            verify(subject.markdown().indexOf("```\nabc\n```") >= 0);
            subject.code.measure();
            verify(subject.code.remove(0));
            compare(subject.markdown().indexOf("abc"), -1);
            verify(/antes/.test(md()) && /fin$/.test(md()));
        }

        function test_copy_puts_code_in_clipboard() {
            stable("antes\n\n```py\na = 1\n\n  b\n```\n\nfin\n");
            verify(subject.code.copy(0));
            clipboardReader.text = "";
            clipboardReader.paste();
            compare(clipboardReader.text, "a = 1\n\n  b");
            compare(subject.markdown().indexOf("```py\na = 1\n\n  b\n```") >= 0, true);
        }

        function test_code_command_places_cursor_inside() {
            type("/codigo\n");
            verify(block() !== null);
            type("print(1)");
            compare(subject.code.text(0), "print(1)");
        }

        function test_measure_matches_lines() {
            stable("antes\n\n```js\nconst a = 1;\n// hola\n```\n\nfin\n");
            subject.code.measure();
            compare(subject.code.blocks.length, 1);
            const b = subject.code.blocks[0];
            compare(b.lang, "js");
            compare(b.label, "JavaScript");
            verify(b.padded);
            verify(b.bottom > b.top);
            const htmls = b.lines.map(l => l.html).join("\n");
            verify(htmls.indexOf(subject.codeColors.keyword) >= 0);
            verify(htmls.indexOf(subject.codeColors.comment) >= 0);
        }

        function test_source_mode_shows_plain_fence() {
            stable("```js\nx\n```\n\nfin\n");
            subject.setSourceMode(true);
            verify(subject.text.indexOf("```js\nx\n```") >= 0);
            subject.setSourceMode(false);
            compare(subject.code.text(0), "x");
        }

        function test_tab_indents_inside() {
            type("```\nif x:\n\ty");
            verify(/^if x:\n(\t|    )y$/.test(subject.code.text(0)), JSON.stringify(subject.code.text(0)));
            const saved = subject.markdown();
            subject.load(saved);
            compare(subject.code.codes().length, 1);
        }

        function test_typing_over_selection_across_block_keeps_document_valid() {
            stable("antes\n\n```\nabc\n```\n\ndespues\n");
            subject.select(2, subject.plain().indexOf("abc") + 1);
            type("Z");
            const saved = subject.markdown();
            subject.load(saved);
            compare(subject.markdown(), saved);
            verify(saved.indexOf("Z") >= 0);
        }

        function test_unclosed_fence_closes_on_load() {
            subject.load("```\nsuelto");
            compare(subject.code.codes().length, 1);
            compare(subject.code.text(0), "suelto");
        }

        function test_typing_fence_in_paragraph_is_text_until_enter() {
            type("```");
            compare(subject.code.codes().length, 0);
            compare(block(), null);
        }
    }

    TestCase {
        name: "CodeLogic"

        function kinds(line, lang) {
            return Code.tokenize([line], lang)[0].filter(t => t.kind !== "plain").map(t => t.kind + ":" + t.text);
        }

        function test_resolve_aliases() {
            compare(Code.resolve("js"), "javascript");
            compare(Code.resolve("PY"), "python");
            compare(Code.resolve("sh"), "bash");
            compare(Code.resolve("nada"), null);
            compare(Code.label("nada"), "nada");
            compare(Code.label("ts"), "TypeScript");
            compare(Code.label(""), "Texto plano");
        }

        function test_fences() {
            const f = Code.fences(["a", "```js", "x", "```", "```", "sin cerrar"]);
            compare(f.length, 1);
            compare(f[0].start, 1);
            compare(f[0].end, 3);
            compare(f[0].lang, "js");
        }

        function test_prepare_pads_and_separates() {
            compare(Code.prepare("x\n\n```js\na\n```\n\ny"), "x\n\n```js\n\na\n\n```\n\ny");
            compare(Code.prepare("```\na\n```"), "\u00a0\n\n```\n\na\n\n```\n\n\u00a0");
            compare(Code.repair("```\n\na\n```"), "```\na\n```");
            compare(Code.prepare("sin código"), "sin código");
        }

        function test_tokenize_javascript() {
            const k = kinds("const s = \"a // b\"; // fin", "js");
            compare(k, ["keyword:const", "string:\"a // b\"", "comment:// fin"]);
        }

        function test_tokenize_multiline_comment() {
            const t = Code.tokenize(["x /* a", "b */ y"], "c");
            verify(t[0].some(tok => tok.kind === "comment" && tok.text === "/* a"));
            verify(t[1].some(tok => tok.kind === "comment" && tok.text === "b */"));
        }

        function test_tokenize_python_numbers_functions() {
            const k = kinds("def f(x): return 0x1F + 2.5", "python");
            verify(k.indexOf("keyword:def") >= 0);
            verify(k.indexOf("function:f") >= 0);
            verify(k.indexOf("number:0x1F") >= 0);
            verify(k.indexOf("number:2.5") >= 0);
        }

        function test_plain_language_has_no_colors() {
            compare(kinds("const x = 1 // hola", ""), []);
        }

        function test_html_escapes() {
            const html = Code.toHtml(Code.tokenize(["a < b && \"<i>\""], "js")[0], {
                keyword: "#111111",
                string: "#222222",
                comment: "#333333",
                number: "#444444",
                type: "#555555",
                function: "#666666"
            });
            compare(html.indexOf("<i>"), -1);
            verify(html.indexOf("&lt;") >= 0);
            verify(html.indexOf("&amp;&amp;") >= 0);
        }

        function test_expand_tabs() {
            compare(Code.expandTabs("\ta\tb"), "    a   b");
        }
    }
}
