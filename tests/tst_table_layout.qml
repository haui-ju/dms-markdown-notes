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
        tableBorderColor: "#777777"
    }

    EditorTestCase {
        name: "TableLayout"
        editor: subject

        readonly property string two: "Antes\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n\nFin\n"
        readonly property string three: "Antes\n\n| A | B | C |\n| --- | --- | --- |\n| 1 | 2 | 3 |\n\nFin\n"

        function layoutLine() {
            return md().split("\n").find(l => Tables.isLayoutLine(l)) || "";
        }

        function layout(cols) {
            return Tables.parseLayout(layoutLine(), cols);
        }

        function geometry() {
            editor.refreshDecorations();
            return editor.table.geometries[0];
        }

        function test_full_width_toggles_comment() {
            editor.load(two);
            placeInCell(0, 2);
            verify(editor.runCommand("fullWidth"));
            compare(layoutLine(), "<!-- tabla: ancho=100 -->");
            verify(/^Antes\n+<!-- tabla: ancho=100 -->\n\|\s*A\s*\|/.test(md()), md());
            verify(editor.table.info.fullWidth);
            verify(editor.runCommand("fullWidth"));
            compare(layoutLine(), "");
            verify(!editor.table.info.fullWidth);
        }

        function test_equalize_sets_equal_columns_and_full_width() {
            editor.load(three);
            placeInCell(0, 0);
            verify(editor.runCommand("equalize"));
            compare(layout(3).columns, [34, 33, 33]);
            compare(layout(3).width, 100);
        }

        function test_equalize_keeps_custom_width() {
            editor.load("Antes\n\n<!-- tabla: ancho=60 columnas=20,80 -->\n| A | B |\n| --- | --- |\n| 1 | 2 |\n");
            placeInCell(0, 0);
            verify(editor.runCommand("equalize"));
            compare(layoutLine(), "<!-- tabla: ancho=60 columnas=50,50 -->");
        }

        function test_density_cycles() {
            editor.load(two);
            placeInCell(0, 0);
            verify(editor.runCommand("density"));
            compare(layout(2).density, "amplio");
            compare(editor.table.info.density, "amplio");
            verify(editor.runCommand("density"));
            compare(layout(2).density, "compacto");
            verify(editor.runCommand("density"));
            compare(layoutLine(), "");
        }

        function test_layout_commands_outside_table_do_nothing() {
            editor.load(two);
            editor.cursorPosition = 1;
            verify(!editor.runCommand("fullWidth"));
            verify(!editor.runCommand("equalize"));
            verify(!editor.runCommand("density"));
            compare(layoutLine(), "");
        }

        function test_layout_command_keeps_cursor_and_selection() {
            editor.load(two);
            placeInCell(0, 3);
            const pos = editor.cursorPosition;
            verify(editor.runCommand("density"));
            compare(editor.cursorPosition, pos);
            const c = cellAt(0, 0);
            editor.select(c.start, c.end);
            verify(editor.runCommand("fullWidth"));
            compare(editor.selectedText, "A");
        }

        function test_layout_survives_typing_and_reload() {
            editor.load(three);
            placeInCell(0, 4);
            verify(editor.runCommand("equalize"));
            verify(editor.runCommand("density"));
            placeInCell(0, 4);
            type("xy");
            const saved = md();
            verify(/<!-- tabla: ancho=100 columnas=34,33,33 alto=amplio -->\n\|\s*A\s*\|/.test(saved), saved);
            compare(table()[1], ["1", "2xy", "3"]);
            editor.load(saved);
            compare(md(), saved);
        }

        function test_layout_survives_row_ops() {
            editor.load(two);
            placeInCell(0, 2);
            verify(editor.runCommand("equalize"));
            verify(editor.table.addRow());
            verify(editor.table.removeRow());
            verify(editor.table.removeRow());
            compare(layoutLine(), "<!-- tabla: ancho=100 columnas=50,50 -->");
        }

        function test_column_ops_rebalance_widths() {
            editor.load("Antes\n\n<!-- tabla: ancho=100 columnas=30,70 -->\n| A | B |\n| --- | --- |\n| 1 | 2 |\n");
            placeInCell(0, 0);
            verify(editor.table.addColumn());
            const added = layout(3).columns;
            compare(added.length, 3);
            compare(added.reduce((a, b) => a + b, 0), 100);
            verify(editor.table.removeColumn());
            verify(editor.table.removeColumn());
            compare(layout(1).columns, [100]);
            compare(layout(1).width, 100);
        }

        function test_remove_table_removes_comment() {
            editor.load(two);
            placeInCell(0, 0);
            verify(editor.runCommand("fullWidth"));
            verify(editor.table.remove());
            verify(md().indexOf("<!--") < 0, md());
            compare(tables().length, 0);
        }

        function test_deleting_table_by_selection_does_not_leak_layout() {
            editor.load("Antes\n\n<!-- tabla: ancho=50 -->\n| A | B |\n| --- | --- |\n| 1 | 2 |\n\nMedio\n\n| X | Y | Z |\n| --- | --- | --- |\n| 1 | 2 | 3 |\n");
            const first = Tables.scan(editor.plain())[0];
            editor.select(first.start, first.end + 1);
            keyClick(Qt.Key_Delete);
            compare(tables().length, 1);
            compare(table()[0], ["X", "Y", "Z"]);
            verify(md().indexOf("<!--") < 0, md());
        }

        function test_second_table_keeps_its_own_layout() {
            editor.load("Antes\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n\nMedio\n\n<!-- tabla: alto=compacto -->\n| X | Y | Z |\n| --- | --- | --- |\n| 1 | 2 | 3 |\n");
            placeInCell(0, 0);
            verify(editor.runCommand("fullWidth"));
            const lines = md().split("\n").filter(l => Tables.isLayoutLine(l));
            compare(lines, ["<!-- tabla: ancho=100 -->", "<!-- tabla: alto=compacto -->"]);
            placeInCell(1, 0);
            verify(!editor.table.info.fullWidth);
            compare(editor.table.info.density, "compacto");
        }

        function test_adjacent_tables_with_layouts_stay_separate() {
            const src = "<!-- tabla: ancho=100 -->\n| A |\n| --- |\n| 1 |\n\n<!-- tabla: alto=amplio -->\n| B |\n| --- |\n| 2 |\n";
            editor.load(src);
            compare(tables().length, 2);
            const once = editor.markdown();
            editor.load(once);
            compare(editor.markdown(), once);
            compare(md().split("\n").filter(l => Tables.isLayoutLine(l)).length, 2);
        }

        function test_invalid_comment_is_dropped() {
            editor.load("Antes\n\n<!-- tabla: columnas=10,90 alto=raro -->\n| A | B | C |\n| --- | --- | --- |\n| 1 | 2 | 3 |\n");
            compare(tables().length, 1);
            verify(md().indexOf("<!--") < 0, md());
        }

        function test_source_mode_shows_and_keeps_layout() {
            editor.load(two);
            placeInCell(0, 0);
            verify(editor.runCommand("equalize"));
            const saved = md();
            editor.setSourceMode(true);
            verify(editor.text.indexOf("<!-- tabla: ancho=100 columnas=50,50 -->") >= 0);
            editor.setSourceMode(false);
            compare(md(), saved);
        }

        function test_decorations_work_with_layout() {
            editor.load("<!-- tabla: ancho=100 -->\n| A | B |\n| --- | --- |\n| 1 | 2 |\n\n- [ ] tarea\n\n---\n\nFin\n");
            const d = editor.decorations();
            verify(d !== null);
            compare(d.tasks.length, 1);
            compare(d.rules.length, 1);
        }

        function test_formatting_in_cells_round_trips() {
            const src = "Antes\n\n| **A** | B |\n| --- | --- |\n| *i* `c` | [l](http://x) ~~s~~ |\n";
            editor.load(src);
            compare(table()[1], ["*i* `c`", "[l](http://x) ~~s~~"]);
            editor.load(editor.markdown());
            compare(table()[1], ["*i* `c`", "[l](http://x) ~~s~~"]);
        }

        function test_html_characters_in_cells_are_text() {
            editor.load("Antes\n\n| A | B |\n| --- | --- |\n| <b>x</b> | a & b |\n");
            compare(cellText(0, 2), "<b>x</b>");
            compare(cellText(0, 3), "a & b");
        }

        function test_empty_column_survives() {
            editor.load("Antes\n\n|  | B |\n| --- | --- |\n|  | 2 |\n");
            compare(table(), [["", "B"], ["", "2"]]);
            placeInCell(0, 0);
            type("h");
            compare(table()[0], ["h", "B"]);
            editor.load(editor.markdown());
            compare(table(), [["h", "B"], ["", "2"]]);
        }

        function test_all_empty_table_survives() {
            editor.load("Antes\n\n|  |  |\n| --- | --- |\n|  |  |\n");
            compare(table(), [["", ""], ["", ""]]);
            editor.load(editor.markdown());
            compare(table(), [["", ""], ["", ""]]);
        }

        function test_geometry_full_width_equal_columns() {
            editor.load(two);
            placeInCell(0, 0);
            verify(editor.runCommand("equalize"));
            const g = geometry();
            verify(g !== undefined);
            compare(g.edges.length, 3);
            const left = g.edges[0];
            const right = g.edges[2];
            verify(Math.abs(right - (editor.width - left)) < 8, JSON.stringify(g));
            verify(Math.abs(g.edges[1] - (left + right) / 2) < 8, JSON.stringify(g));
            verify(g.bottom > g.top);
        }

        function test_geometry_auto_table() {
            editor.load(three);
            const g = geometry();
            compare(g.edges.length, 4);
            for (let i = 1; i < g.edges.length; i++)
                verify(g.edges[i] > g.edges[i - 1], JSON.stringify(g));
            verify(g.edges[3] < editor.width / 2, JSON.stringify(g));
        }

        function test_resize_inner_edge() {
            editor.load(two);
            placeInCell(0, 0);
            verify(editor.runCommand("equalize"));
            let g = geometry();
            verify(editor.table.resize(0, 1, g.edges[0] + (g.edges[2] - g.edges[0]) * 0.25));
            const cols = layout(2).columns;
            verify(Math.abs(cols[0] - 25) <= 3, JSON.stringify(cols));
            compare(layout(2).width, 100);
            g = geometry();
            verify(Math.abs(g.edges[1] - (g.edges[0] + (g.edges[2] - g.edges[0]) * 0.25)) < 8, JSON.stringify(g));
        }

        function test_resize_auto_table_freezes_width() {
            editor.load(three);
            const g = geometry();
            verify(editor.table.resize(0, 1, g.edges[1] + 20));
            const l = layout(3);
            compare(l.columns.length, 3);
            verify(l.width >= Tables.MIN_WIDTH && l.width < 100, JSON.stringify(l));
        }

        function test_resize_right_edge() {
            editor.load(two);
            const g = geometry();
            verify(editor.table.resize(0, 2, g.edges[0] + g.available * 0.5));
            const l = layout(2);
            verify(Math.abs(l.width - 50) <= 2, JSON.stringify(l));
            compare(l.columns.length, 2);
            verify(editor.table.resize(0, 2, 99999));
            compare(layout(2).width, 100);
            verify(editor.table.resize(0, 2, -99999));
            compare(layout(2).width, Tables.MIN_WIDTH);
        }

        function test_resize_clamps_columns() {
            editor.load(three);
            placeInCell(0, 0);
            verify(editor.runCommand("equalize"));
            const g = geometry();
            verify(editor.table.resize(0, 1, 99999));
            const cols = layout(3).columns;
            verify(cols.every(c => c >= Tables.MIN_COLUMN - 1), JSON.stringify(cols));
            verify(editor.table.resize(0, 1, -99999));
            verify(layout(3).columns[0] >= Tables.MIN_COLUMN - 1, layoutLine());
        }

        function test_resize_rejects_bad_input() {
            editor.load(two);
            geometry();
            verify(!editor.table.resize(0, 0, 10));
            verify(!editor.table.resize(0, 9, 10));
            verify(!editor.table.resize(5, 1, 10));
            compare(layoutLine(), "");
        }

        function test_resize_keeps_text_and_cursor() {
            editor.load(two);
            placeInCell(0, 3);
            const pos = editor.cursorPosition;
            const g = geometry();
            verify(editor.table.resize(0, 1, g.edges[1] + 15));
            compare(editor.cursorPosition, pos);
            compare(table(), [["A", "B"], ["1", "2"]]);
            verify(/^Antes\n+<!-- tabla:/.test(md()), md());
            verify(md().endsWith("Fin"), md());
        }

        function test_geometry_cleared_in_source_mode() {
            editor.load(two);
            verify(geometry() !== undefined);
            editor.setSourceMode(true);
            editor.refreshDecorations();
            compare(editor.table.geometries.length, 0);
            editor.setSourceMode(false);
        }
    }
}
