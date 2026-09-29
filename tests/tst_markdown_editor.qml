import QtQuick
import QtTest
import "../src/editor"

Item {
    id: testRoot
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

        function test_decorations_follow_layout_after_moving_windows() {
            const editor = Qt.createQmlObject("import QtQuick; import \"../src/editor\"; MarkdownEditor { width: 200 }", testRoot, "moved");
            editor.parent = null;
            editor.load("Un párrafo bastante largo que se parte en varias líneas cuando el panel es estrecho, con #tag y [[Nota]].\n\n- [ ] tarea\n\n> cita\n\n---\n\nfin");
            editor.refreshDecorations();
            editor.parent = testRoot;
            editor.width = 480;
            wait(400);
            const items = [];
            for (let i = 0; i < editor.children.length; i++) {
                const c = editor.children[i];
                if (c.modelData !== undefined && (c.area !== undefined || c.first !== undefined))
                    items.push(c);
            }
            verify(items.length >= 5, items.length);
            for (const item of items) {
                const start = typeof item.modelData === "number" ? item.modelData : item.modelData.start;
                const rect = item.area !== undefined ? item.area : item.first;
                compare(rect.y, editor.positionToRectangle(start).y);
            }
            editor.destroy();
        }

        function test_heading() {
            type("# Titulo");
            compare(md(), "# Titulo");
        }

        function headingHeight(source) {
            subject.load(source);
            return subject.positionToRectangle(1).height;
        }

        function test_heading_formats_while_typing() {
            const expected = headingHeight("# Hola");
            const normal = headingHeight("Hola");
            verify(expected > normal);
            subject.load("");
            type("# Hola");
            compare(md(), "# Hola");
            compare(subject.positionToRectangle(1).height, expected);
            compare(subject.positionToRectangle(subject.length).height, expected);
        }

        function test_ctrl_heading_on_empty_line_formats_while_typing() {
            const expected = headingHeight("## Hola");
            subject.load("");
            keyClick(Qt.Key_2, Qt.ControlModifier);
            type("Hola");
            compare(md(), "## Hola");
            compare(subject.positionToRectangle(1).height, expected);
        }

        function test_heading_after_text_formats_while_typing() {
            const expected = headingHeight("### T");
            subject.load("texto");
            subject.cursorPosition = subject.length;
            type("\n### T");
            compare(md(), "texto\n\n### T");
            compare(subject.positionToRectangle(subject.length).height, expected);
        }

        function test_emptied_heading_does_not_swallow_next_block() {
            subject.load("a\n\n# x\n\nfin\n\n## y\n\n- item");
            let i = subject.plain().indexOf("x");
            subject.select(i, i + 1);
            keyClick(Qt.Key_Delete);
            i = subject.plain().indexOf("y");
            subject.select(i, i + 1);
            keyClick(Qt.Key_Delete);
            compare(md(), "a\n\n# \u00a0\n\nfin\n\n## \u00a0\n\n- item");
            subject.load(subject.markdown());
            compare(md(), "a\n\n# \u00a0\n\nfin\n\n## \u00a0\n\n- item");
        }

        function test_heading_shortcut_on_blank_line_keeps_next_blank() {
            subject.load("\u00a0\n\n\u00a0\n\n\u00a0\n\nfin");
            subject.cursorPosition = 2;
            type("# ");
            compare(md(), "\u00a0\n\n# \u00a0\n\n\u00a0\n\nfin");
        }

        function test_saved_empty_heading_formats_while_typing() {
            const expected = headingHeight("# Hola");
            subject.load("a\n\n# \u00a0\n\nfin");
            subject.cursorPosition = 2;
            type("Hola");
            compare(md(), "a\n\n# Hola\n\nfin");
            compare(subject.positionToRectangle(3).height, expected);
        }

        function test_blank_line_typing_stays_paragraph() {
            subject.load("a\n\n\u00a0\n\nfin");
            subject.cursorPosition = 2;
            type("b");
            compare(md(), "a\n\nb\n\nfin");
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

        function roundtrips(source, times) {
            let saved = source;
            let plain = "";
            for (let i = 0; i < times; i++) {
                editor.load(saved);
                if (i > 0)
                    compare(editor.plain(), plain);
                plain = editor.plain();
                saved = md();
            }
            return saved;
        }

        function test_inline_code_does_not_grow_backslashes() {
            const saved = roundtrips("usa `# `, `- [] `, `1. `, `**x**`, `C:\\dir\\` y `a|b`", 4);
            compare(saved.replace(/\s+/g, " "), "usa `# `, `- [] `, `1. `, `**x**`, `C:\\dir\\` y `a|b`");
        }

        function test_long_paragraph_keeps_bold_and_code_at_wrap_points() {
            const source = "`install.sh` enlaza el repo en `~/.config/DankMaterialShell/plugins/markdownNotes`, crea `~/Notes`, activa el plugin y añade el botón a la barra (reinicia `dms.service` si está corriendo). Pestañas, botón para ampliar/contraer el panel, **Guardar** (en notas sin nombre abre \"Guardar como\"), **Abrir** (cualquier `.md`), **Nuevo** y fin.";
            editor.load(source);
            const plain = editor.plain();
            verify(plain.indexOf("markdownNotes, crea") > 0);
            verify(plain.indexOf("(reinicia dms.service si") > 0);
            const saved = roundtrips(source, 4);
            compare(editor.plain(), plain);
            verify(saved.indexOf("\\") < 0, saved);
            compare(saved.split("**").length, 7);
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
            compare(md().split("\n").filter(l => l === "\u00a0").length, 2);
            verify(/```\n  \n```\n\u00a0$/.test(md()), JSON.stringify(md()));
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

        function test_source_mode_ignores_caret_format() {
            const normal = headingHeight("texto");
            for (const pos of [0, 3, 6]) {
                for (const source of ["# Hola\n\ntexto", "`codigo` y texto"]) {
                    editor.load(source);
                    editor.cursorPosition = pos;
                    editor.setSourceMode(true);
                    compare(editor.positionToRectangle(1).height, normal, source + " @" + pos);
                    compare(editor.positionToRectangle(editor.length).height, normal);
                    editor.load("# Otra nota");
                    compare(editor.positionToRectangle(1).height, normal);
                    editor.setSourceMode(false);
                }
            }
        }

        function test_decorations_map_quotes() {
            editor.load("> uno\n>\n> dos\n\ntexto\n\n> tres\nperezoso\n\notro texto\n\n> - item\n> - otro");
            const d = editor.decorations();
            verify(d !== null);
            compare(d.quotes.length, 3);
            compare(editor.getText(d.quotes[0].start, d.quotes[0].end), "uno\u2029dos");
            compare(editor.getText(d.quotes[1].start, d.quotes[1].end), "tres perezoso");
            compare(editor.getText(d.quotes[2].start, d.quotes[2].end), "item\u2029otro");
        }

        function test_quoted_heading_keeps_decorations() {
            editor.load("- [ ] tarea\n\n> # titulo\n> fin\n\n- - -\nfinal\n");
            const d = editor.decorations();
            verify(d !== null);
            compare(d.tasks.length, 1);
            compare(d.rules.length, 1);
            verify(d.quotes.length > 0);
        }

        function quotes() {
            editor.refreshDecorations();
            return editor._quotes.length;
        }

        function test_empty_quote_is_kept_and_visible() {
            editor.load("a");
            editor.cursorPosition = 1;
            type("\n> ");
            compare(md(), "a\n\n> \u00a0");
            compare(quotes(), 1);
            editor.load(md());
            compare(quotes(), 1);
            editor.cursorPosition = editor.length;
            type("hola");
            compare(md(), "a\n\n> hola");
            compare(quotes(), 1);
        }

        function test_slash_and_ctrl_quote_on_empty_line() {
            editor.load("a\n");
            editor.cursorPosition = 1;
            type("\n/cita\n");
            compare(md(), "a\n\n> \u00a0");
            compare(quotes(), 1);
            editor.load("a\n\n\u00a0");
            editor.cursorPosition = editor.length;
            editor.setBlockType("quote");
            compare(md(), "a\n\n> \u00a0");
        }

        function test_erasing_quote_keeps_it() {
            editor.load("a\n\n> ho\n\nb");
            editor.cursorPosition = 4;
            keyClick(Qt.Key_Backspace);
            keyClick(Qt.Key_Backspace);
            compare(md(), "a\n\n> \u00a0\n\nb");
            compare(quotes(), 1);
            type("x");
            compare(md(), "a\n\n> x\n\nb");
            editor.cursorPosition = 2;
            keyClick(Qt.Key_Delete);
            compare(md(), "a\n\n> \u00a0\n\nb");
        }

        function test_deleting_selected_quote_text_keeps_quote() {
            for (const key of [Qt.Key_Backspace, Qt.Key_Delete]) {
                editor.load("a\n\n> hola\n\nb");
                editor.select(2, 6);
                keyClick(key);
                compare(md(), "a\n\n> \u00a0\n\nb");
                compare(quotes(), 1);
            }
        }

        function test_cut_whole_quote_keeps_it_and_copies() {
            editor.load("a\n\n> hola\n\nb");
            editor.select(2, 6);
            keyClick(Qt.Key_X, Qt.ControlModifier);
            compare(md(), "a\n\n> \u00a0\n\nb");
            compare(quotes(), 1);
            editor.load("x");
            editor.selectAll();
            editor.deselect();
            editor.cursorPosition = 1;
            keyClick(Qt.Key_V, Qt.ControlModifier);
            compare(md(), "xhola");
        }

        function test_cut_partial_quote_is_normal() {
            editor.load("a\n\n> hola\n\nb");
            editor.select(2, 4);
            keyClick(Qt.Key_X, Qt.ControlModifier);
            compare(md(), "a\n\n> la\n\nb");
        }

        function test_empty_quote_undo_and_neighbours() {
            editor.load("| a |\n|---|\n| 1 |\n\n> cita\n\n```js\nx\n```\n\n![](nada.png)\n\n> otra");
            const d = editor.decorations();
            verify(d !== null);
            compare(d.quotes.length, 2);
            compare(d.codes.length, 1);
            editor.load("texto");
            editor.cursorPosition = editor.length;
            type("\n> ");
            compare(md(), "texto\n\n> \u00a0");
            keyClick(Qt.Key_Z, Qt.ControlModifier);
            verify(md().indexOf(">") < 0, md());
            keyClick(Qt.Key_Y, Qt.ControlModifier);
            compare(md(), "texto\n\n> \u00a0");
            compare(quotes(), 1);
        }

        function test_backspace_on_empty_quote_turns_it_into_text() {
            editor.load("a\n\n> \u00a0\n\nb");
            editor.cursorPosition = 3;
            keyClick(Qt.Key_Backspace);
            compare(md(), "a\n\n\u00a0\n\nb");
            compare(quotes(), 0);
        }

        function test_enter_continues_quote_then_exits() {
            editor.load("> uno");
            editor.cursorPosition = editor.length;
            keyClick(Qt.Key_Return);
            compare(md(), "> uno\n> \n> \u00a0");
            compare(quotes(), 1);
            type("dos");
            compare(md(), "> uno\n> \n> dos");
            keyClick(Qt.Key_Return);
            keyClick(Qt.Key_Return);
            type("fuera");
            compare(md(), "> uno\n> \n> dos\n\nfuera");
            compare(quotes(), 1);
        }

        function test_quote_decoration_covers_text() {
            editor.load("antes\n\n> una cita\n\ndespues");
            editor.refreshDecorations();
            compare(editor._quotes.length, 1);
            const r = editor.positionToRectangle(editor._quotes[0].start);
            const after = editor.positionToRectangle(editor.length);
            verify(r.x > editor.leftPadding + 16);
            verify(after.y > r.y + r.height);
        }

        function test_trailing_rule_is_kept() {
            for (const source of ["texto\n\n---", "texto\n\n- - -\n", "a\n\n***\n"]) {
                editor.load(source);
                verify(/\n(- - -|---|\*\*\*)$/.test(md()), JSON.stringify(md()));
                editor.refreshDecorations();
                compare(editor._rules.length, 1);
                editor.load(md());
                compare(editor._rules.length, 1);
            }
        }

        function test_typed_trailing_rule_is_kept_and_backspace_removes_it() {
            editor.load("texto");
            editor.cursorPosition = editor.length;
            type("\n---\n");
            compare(md(), "texto\n\n- - -");
            keyClick(Qt.Key_Backspace);
            compare(md(), "texto");
            type("sigue");
            verify(md().indexOf("sigue") > 0, md());
        }

        function test_typing_after_trailing_rule() {
            editor.load("texto\n\n---");
            editor.cursorPosition = editor.length;
            type("fin");
            compare(md(), "texto\n\n- - -\nfin");
            editor.refreshDecorations();
            compare(editor._rules.length, 1);
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
            verify(/^\u00a0\n\n```\s*\nx = 1\n```\n\u00a0$/.test(md()), JSON.stringify(md()));
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
