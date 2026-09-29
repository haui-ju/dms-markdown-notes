import QtQuick
import QtTest
import "../src/editor"
import "../src/editor/logic/tables.js" as Tables

Item {
    width: 500
    height: 600

    MarkdownEditor {
        id: subject
        anchors.fill: parent
        focus: true
    }

    EditorTestCase {
        name: "TablesBreak"
        editor: subject

        readonly property string sample: "| A | B |\n| --- | --- |\n| 1 | 2 |\n"

        function stable(markdown) {
            editor.load(markdown);
            const first = editor.markdown();
            editor.load(first);
            compare(editor.markdown(), first);
            return first;
        }

        function test_escaped_pipe_survives_ops() {
            editor.load("| a \\| b | c |\n| --- | --- |\n| 1 | 2 |\n");
            compare(cellText(0, 0), "a | b");
            placeInCell(0, 2);
            verify(editor.table.addRow());
            compare(table()[0], ["a \\| b", "c"]);
            compare(cellText(0, 0), "a | b");
        }

        function test_inline_format_in_cells_survives_ops() {
            editor.load("| **neg** | `code` |\n| --- | --- |\n| *cur* | ~~no~~ |\n");
            placeInCell(0, 3);
            verify(editor.table.addColumn());
            const t = table();
            compare(t[0][0], "neg");
            compare(t[0][1], "code");
            compare(t[1][0], "*cur*");
            compare(t[1][1], "~~no~~");
            compare(t[1][2], "");
        }

        function test_emoji_and_accents() {
            editor.load("| año | 😀 |\n| --- | --- |\n| ñandú | 🚀x |\n");
            placeInCell(0, 3);
            verify(editor.table.addRow());
            compare(table(), [["año", "😀"], ["ñandú", "🚀x"], ["", ""]]);
            placeInCell(0, 1);
            keyClick(Qt.Key_Tab);
            type("z");
            compare(table()[1][0], "ñandúz");
        }

        function test_long_cell_wraps_and_navigates() {
            const long = "palabra ".repeat(30).trim();
            editor.load("| " + long + " | b |\n| --- | --- |\n| c | d |\n");
            placeInCell(0, 0);
            keyClick(Qt.Key_Tab);
            type("x");
            compare(table()[0][1], "bx");
            compare(table()[0][0], long);
        }

        function test_two_tables_ops_hit_the_right_one() {
            editor.load(sample + "\nMedio\n\n" + sample);
            placeInCell(1, 2);
            verify(editor.table.addRow());
            compare(tables()[0], [["A", "B"], ["1", "2"]]);
            compare(tables()[1], [["A", "B"], ["1", "2"], ["", ""]]);
            placeInCell(0, 0);
            verify(editor.table.remove());
            compare(tables().length, 1);
            compare(tables()[0].length, 3);
        }

        function test_table_in_code_fence_is_ignored() {
            editor.load("```\n| a | b |\n| - | - |\n```\n\n" + sample);
            placeInCell(0, 3);
            verify(editor.table.addRow());
            verify(/```\n\| a \| b \|\n\| - \| - \|\n```/.test(md()), md());
            compare(tables()[0].length, 3);
        }

        function test_table_at_document_start_and_end() {
            editor.load(sample);
            placeInCell(0, 0);
            verify(editor.table.addRow());
            compare(tables()[0].length, 3);
            placeInCell(0, 5);
            keyClick(Qt.Key_Return);
            type("fin");
            verify(/fin$/.test(md()));
            compare(tables()[0].length, 3);
        }

        function test_table_right_after_heading() {
            editor.load("## Titulo\n" + sample);
            verify(editor.table.locate(cellAt(0, 0).start) !== null);
            placeInCell(0, 0);
            verify(editor.table.addColumn());
            verify(/^## Titulo\n/.test(md()), md());
            compare(tables()[0][0].length, 3);
        }

        function test_table_glued_to_paragraph_does_not_crash() {
            editor.load("texto\n| a | b |\n| --- | --- |\n| 1 | 2 |\n");
            for (let i = 0; i <= editor.length; i++)
                editor.table.locate(i);
            editor.cursorPosition = editor.length;
            type("x");
            verify(md().length > 0);
        }

        function test_table_in_quote_does_not_crash() {
            editor.load("> | a | b |\n> | --- | --- |\n> | 1 | 2 |\n");
            for (let i = 0; i <= editor.length; i++)
                editor.table.locate(i);
            editor.cursorPosition = editor.length;
            type("x");
            verify(md().length > 0);
        }

        function test_ragged_rows() {
            editor.load("| a | b | c |\n| - | - | - |\n| 1 |\n");
            placeInCell(0, 3);
            const info = editor.table.info;
            verify(info !== null);
            compare(info.cols, 3);
            verify(editor.table.addRow());
            compare(table(), [["a", "b", "c"], ["1", "", ""], ["", "", ""]]);
        }

        function test_alignment_delimiter() {
            editor.load("| a | b |\n| :--- | ---: |\n| 1 | 2 |\n");
            placeInCell(0, 3);
            verify(editor.table.addRow());
            compare(table().length, 3);
        }

        function test_header_only_table() {
            editor.load("| a | b |\n| --- | --- |\n");
            placeInCell(0, 1);
            verify(editor.table.info !== null);
            keyClick(Qt.Key_Tab);
            type("n");
            compare(table(), [["a", "b"], ["n", ""]]);
        }

        function test_removing_rows_never_leaves_header_only() {
            editor.load("Antes\n\n" + sample + "\nFin\n");
            placeInCell(0, 0);
            verify(editor.table.removeRow());
            compare(table(), [["1", "2"], ["", ""]]);
            verify(editor.table.removeRow());
            compare(table(), [["", ""], ["", ""]]);
            verify(/^Antes\n+\|[\s\S]*\|\n+Fin$/.test(md()), md());
        }

        function test_empty_cells_survive_reload() {
            editor.load("| a | b | c |\n| --- | --- | --- |\n| 1 |  |  |\n| 2 |  | 3 |\n");
            compare(Tables.scan(editor.plain())[0].cells.length, 9);
            const once = editor.markdown();
            editor.load(once);
            compare(Tables.scan(editor.plain())[0].cells.length, 9);
            placeInCell(0, 3);
            keyClick(Qt.Key_Tab);
            type("x");
            compare(table()[1], ["1", "x", ""]);
        }

        function test_typing_into_blank_cell() {
            editor.load(sample);
            placeInCell(0, 2);
            verify(editor.table.addColumn());
            placeInCell(0, 4);
            compare(cellText(0, 4), "");
            type("z");
            compare(cellText(0, 4), "z");
        }

        function test_pipe_typed_in_cell_survives_save() {
            editor.load(sample);
            placeInCell(0, 2);
            type(" | x");
            compare(table()[1], ["1 \\| x", "2"]);
            editor.load(editor.markdown());
            compare(cellText(0, 2), "1 | x");
            compare(table()[1].length, 2);
        }

        function test_table_after_code_block_reloads_clean() {
            const out = stable("```\nx\n```\n\n" + sample);
            verify(/```\s*\n[\s\S]*\| ?A ?\| ?B ?\|/.test(out), out);
            compare(tables().length, 1);
            verify(out.indexOf("|```") < 0, out);
        }

        function test_table_after_quote_reloads_clean() {
            stable("> cita\n\n" + sample);
            compare(table(), [["A", "B"], ["1", "2"]]);
        }

        function test_adjacent_tables_keep_a_gap() {
            stable(sample + "\n" + sample);
            compare(tables().length, 2);
            placeInCell(0, 3);
            keyClick(Qt.Key_Return);
            type("medio");
            compare(tables().length, 2);
            verify(/\|\n+medio\n[\s\u00a0]*\|/.test(md()), md());
        }

        function test_can_type_above_leading_table() {
            editor.load(sample);
            editor.cursorPosition = 0;
            type("arriba");
            verify(/^arriba\n+\|/.test(md()), md());
            compare(table(), [["A", "B"], ["1", "2"]]);
        }

        function test_grow_and_shrink_columns() {
            editor.load(sample);
            placeInCell(0, 0);
            for (let i = 0; i < 5; i++)
                verify(editor.table.addColumn());
            compare(table()[0].length, 7);
            for (let i = 0; i < 6; i++)
                verify(editor.table.removeColumn());
            compare(table()[0].length, 1);
            verify(editor.table.removeColumn());
            compare(tables().length, 0);
        }

        function test_block_shortcuts_inside_cell_do_nothing() {
            editor.load(sample);
            for (const seq of ["# ", "- ", "[] ", "> ", "1. "]) {
                placeInCell(0, 2);
                const before = cellText(0, 2);
                type(seq);
                compare(tables().length, 1);
                compare(cellText(0, 2), before + seq);
            }
            compare(table().length, 2);
            verify(!/^#/m.test(md()), md());
        }

        function test_rule_and_fence_text_in_cell_is_literal() {
            editor.load(sample);
            placeInCell(0, 2);
            type("---\n");
            compare(tables().length, 1);
            compare(editor.table.info, null);
            placeInCell(0, 3);
            type("```");
            compare(cellText(0, 3), "2```");
        }

        function test_backspace_at_cell_start_keeps_table() {
            editor.load(sample);
            for (let k = 0; k < 4; k++) {
                editor.cursorPosition = cellAt(0, k).start;
                keyClick(Qt.Key_Backspace);
                compare(tables().length, 1);
                compare(table().length, 2);
            }
        }

        function test_delete_at_cell_end_keeps_table() {
            editor.load(sample);
            for (let k = 0; k < 4; k++) {
                placeInCell(0, k);
                keyClick(Qt.Key_Delete);
                compare(tables().length, 1);
                compare(table().length, 2);
            }
        }

        function test_backspace_on_empty_cell_keeps_table() {
            type("/tabla\n\t\t\t");
            for (let i = 0; i < 3; i++)
                keyClick(Qt.Key_Backspace);
            compare(tables().length, 1);
            compare(table().length, 3);
        }

        function test_ctrl_shortcuts_in_cell_are_ignored() {
            editor.load(sample);
            placeInCell(0, 2);
            const before = md();
            keyClick(Qt.Key_1, Qt.ControlModifier);
            keyClick(Qt.Key_L, Qt.ControlModifier);
            keyClick(Qt.Key_L, Qt.ControlModifier | Qt.ShiftModifier);
            compare(md(), before);
        }

        function test_ctrl_b_inside_cell() {
            editor.load("| a | b |\n| --- | --- |\n| hola mundo | 2 |\n");
            const c = cellAt(0, 2);
            editor.select(c.start + 5, c.end);
            keyClick(Qt.Key_B, Qt.ControlModifier);
            compare(table()[1][0], "hola **mundo**");
            compare(table().length, 2);
        }

        function test_inline_shortcut_inside_cell() {
            editor.load(sample);
            placeInCell(0, 2);
            type(" **neg** ok");
            compare(table()[1][0], "1 **neg** ok");
        }

        function test_selection_across_cells_blocks_wrap() {
            editor.load(sample);
            editor.select(cellAt(0, 0).start, cellAt(0, 1).end);
            keyClick(Qt.Key_B, Qt.ControlModifier);
            compare(table()[0], ["A", "B"]);
        }

        function test_marker_click_in_cell_is_ignored() {
            editor.load(sample);
            const r = editor.positionToRectangle(cellAt(0, 1).start);
            compare(editor.isMarkerHit(r.x - 3, r.y + r.height / 2), -1);
            compare(editor.toggleTaskAt(cellAt(0, 1).start), false);
        }

        function test_select_whole_table_and_delete() {
            editor.load("Antes\n\n" + sample + "\nDespues\n");
            editor.select(0, editor.length);
            keyClick(Qt.Key_Backspace);
            compare(tables().length, 0);
            compare(editor.table.info, null);
            type("nuevo");
            compare(md(), "nuevo");
        }

        function test_source_mode_roundtrip_keeps_table() {
            editor.load("Antes\n\n" + sample);
            const before = table();
            editor.setSourceMode(true);
            compare(editor.table.locate(3), null);
            editor.setSourceMode(false);
            compare(table(), before);
        }

        function test_reload_is_stable() {
            const out = stable("Hola\n\n| a \\| x | **b** |\n| :-- | --: |\n| 1 |  |\n\n- [ ] tarea\n\nFin\n");
            verify(out.indexOf("|") >= 0);
        }

        function test_tasks_decorated_next_to_table() {
            editor.load("- [ ] uno\n\n" + sample + "\n- [x] dos\n\n---\n\nfin\n");
            const d = editor.decorations();
            verify(d !== null);
            compare(d.tasks.length, 2);
            compare(editor.getText(d.tasks[1].start, d.tasks[1].end), "dos");
            compare(d.rules.length, 1);
        }

        function test_tasks_decorated_with_empty_cells() {
            editor.load("| Columna 1 |  |\n| --- | --- |\n|  |  |\n\n- [ ] uno\n");
            const d = editor.decorations();
            verify(d !== null);
            compare(d.tasks.length, 1);
            compare(editor.getText(d.tasks[0].start, d.tasks[0].end), "uno");
        }

        function test_slash_escape_inside_table() {
            editor.load(sample);
            placeInCell(0, 2);
            type(" /");
            verify(editor.slash.inTable);
            keyClick(Qt.Key_Escape);
            verify(!editor.slash.active);
            compare(table()[1][0], "1 /");
        }

        function test_slash_remove_table_command() {
            editor.load("Antes\n\n" + sample + "\nFin\n");
            placeInCell(0, 2);
            type(" /eliminar tabla\n");
            compare(tables().length, 0);
            compare(md(), "Antes\n\nFin");
        }

        function test_table_command_never_nests() {
            editor.load(sample);
            placeInCell(0, 2);
            verify(!editor.table.insert());
            compare(tables().length, 1);
        }

        function test_tab_outside_table_does_not_crash() {
            type("hola\t");
            verify(md().indexOf("hola") === 0);
        }

        function test_enter_then_new_table_below_first() {
            editor.load(sample);
            placeInCell(0, 3);
            keyClick(Qt.Key_Return);
            type("/tabla\n");
            compare(tables().length, 2);
            compare(tables()[0], [["A", "B"], ["1", "2"]]);
        }
    
        function test_tab_right_after_creation_keeps_header() {
            type("/tabla\n\t");
            compare(table()[0], ["Columna 1", "Columna 2", "Columna 3"]);
            compare(editor.selectedText, "Columna 2");
        }

        function test_enter_right_after_creation_moves_down() {
            type("/tabla\n\nx");
            compare(table()[0][0], "Columna 1");
            compare(table()[1][0], "x");
        }

        function test_shift_enter_in_cell_moves_down() {
            editor.load(sample);
            placeInCell(0, 0);
            keyClick(Qt.Key_Return, Qt.ShiftModifier);
            type("y");
            compare(table(), [["A", "B"], ["1y", "2"]]);
        }

        function test_multiline_insert_in_cell_keeps_table_shape() {
            editor.load(sample);
            placeInCell(0, 2);
            editor.insert(editor.cursorPosition, "x\n\ny");
            editor.load(editor.markdown());
            compare(tables().length, 1);
            compare(table()[0], ["A", "B"]);
        }

        function test_undo_after_typing_in_cell() {
            editor.load(sample);
            placeInCell(0, 2);
            type("abc");
            keyClick(Qt.Key_Z, Qt.ControlModifier);
            compare(tables().length, 1);
            compare(table()[0], ["A", "B"]);
        }

        function test_slash_in_empty_cell() {
            editor.load("| A | B |\n| --- | --- |\n|  | 2 |\n");
            placeInCell(0, 2);
            type("/fila\n");
            compare(table(), [["A", "B"], ["", "2"], ["", ""]]);
        }

        function test_tab_with_selection_inside_cell_navigates() {
            editor.load(sample);
            const c = cellAt(0, 2);
            editor.select(c.start, c.end);
            keyClick(Qt.Key_Tab);
            compare(table(), [["A", "B"], ["1", "2"]]);
            compare(editor.cursorPosition, cellAt(0, 3).end);
        }
    }
}
