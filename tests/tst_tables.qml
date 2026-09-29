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
        name: "Tables"
        editor: subject

        readonly property string sample: "| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |\n"

        function test_slash_creates_3x3_table() {
            type("/tabla\n");
            compare(table(), [["Columna 1", "Columna 2", "Columna 3"], ["", "", ""], ["", "", ""]]);
            compare(editor.selectedText, "Columna 1");
            verify(editor.table.info !== null);
            compare(editor.table.info.rows, 3);
            compare(editor.table.info.cols, 3);
        }

        function test_typing_replaces_header_placeholder() {
            type("/tabla\nNombre");
            compare(table()[0][0], "Nombre");
        }

        function test_tab_walks_cells_and_selects_placeholders() {
            type("/tabla\nA\tB\tC\td\te");
            compare(table(), [["A", "B", "C"], ["d", "e", ""], ["", "", ""]]);
        }

        function test_shift_tab_goes_back() {
            type("/tabla\nA\tB");
            keyClick(Qt.Key_Backtab);
            type("x");
            compare(table()[0].slice(0, 2), ["Ax", "B"]);
        }

        function test_shift_tab_on_first_cell_stays() {
            type("/tabla\nA");
            keyClick(Qt.Key_Backtab);
            type("b");
            compare(table()[0][0], "Ab");
        }

        function test_tab_on_last_cell_adds_row() {
            editor.load(sample);
            placeInCell(0, 5);
            keyClick(Qt.Key_Tab);
            type("n");
            compare(table(), [["A", "B"], ["1", "2"], ["3", "4"], ["n", ""]]);
        }

        function test_enter_moves_down() {
            editor.load(sample);
            placeInCell(0, 0);
            keyClick(Qt.Key_Return);
            type("x");
            compare(table()[1], ["1x", "2"]);
        }

        function test_enter_on_last_row_leaves_table() {
            editor.load(sample);
            placeInCell(0, 5);
            keyClick(Qt.Key_Return);
            verify(editor.table.info === null);
            type("fin");
            verify(/\|\n\nfin$/.test(md()), md());
            compare(tables().length, 1);
        }

        function test_enter_on_last_row_with_text_below() {
            editor.load(sample + "\nFin\n");
            placeInCell(0, 5);
            keyClick(Qt.Key_Return);
            type("z");
            verify(/\|\n\nz\n\nFin$/.test(md()), md());
        }

        function test_add_row() {
            editor.load(sample);
            placeInCell(0, 2);
            verify(editor.table.addRow());
            compare(table(), [["A", "B"], ["1", "2"], ["", ""], ["3", "4"]]);
            compare(editor.table.info.row, 2);
        }

        function test_add_column() {
            editor.load(sample);
            placeInCell(0, 0);
            verify(editor.table.addColumn());
            compare(table(), [["A", "Columna 3", "B"], ["1", "", "2"], ["3", "", "4"]]);
            compare(editor.selectedText, "Columna 3");
        }

        function test_remove_row() {
            editor.load(sample);
            placeInCell(0, 3);
            verify(editor.table.removeRow());
            compare(table(), [["A", "B"], ["3", "4"]]);
        }

        function test_remove_header_promotes_next_row() {
            editor.load(sample);
            placeInCell(0, 1);
            verify(editor.table.removeRow());
            compare(table(), [["1", "2"], ["3", "4"]]);
        }

        function test_remove_column() {
            editor.load(sample);
            placeInCell(0, 1);
            verify(editor.table.removeColumn());
            compare(table(), [["A"], ["1"], ["3"]]);
        }

        function test_remove_last_column_removes_table() {
            editor.load("Antes\n\n| A |\n| --- |\n| 1 |\n\nDespues\n");
            placeInCell(0, 1);
            verify(editor.table.removeColumn());
            compare(tables().length, 0);
            compare(md(), "Antes\n\nDespues");
        }

        function test_remove_table() {
            editor.load("Antes\n\n" + sample + "\nDespues\n");
            placeInCell(0, 2);
            verify(editor.table.remove());
            compare(md(), "Antes\n\nDespues");
            verify(editor.table.info === null);
        }

        function test_slash_inside_table_offers_table_commands() {
            editor.load(sample);
            placeInCell(0, 2);
            type(" /fila");
            verify(editor.slash.active);
            verify(editor.slash.inTable);
            compare(editor.slash.items[0].id, "rowAdd");
            keyClick(Qt.Key_Return);
            compare(table(), [["A", "B"], ["1", "2"], ["", ""], ["3", "4"]]);
        }

        function test_slash_table_below_text() {
            type("hola /tabla\n");
            verify(/^hola\s*\n+\| ?Columna 1/.test(md()), md());
            compare(tables().length, 1);
        }

        function test_slash_table_from_start_of_text_line() {
            editor.load("hola\n");
            editor.cursorPosition = 0;
            type("/tabla\n");
            verify(/^hola\n+\| ?Columna 1/.test(md()), md());
        }

        function test_slash_table_inside_list_item_keeps_item() {
            type("- item /tabla\n");
            verify(/^- item\s*\n+\| ?Columna 1/.test(md()), md());
            compare(tables().length, 1);
        }

        function test_info_tracks_cursor() {
            editor.load("Texto\n\n" + sample);
            editor.cursorPosition = 2;
            verify(editor.table.info === null);
            placeInCell(0, 3);
            compare(editor.table.info.row, 1);
            compare(editor.table.info.col, 1);
            verify(editor.table.info.bottom > editor.table.info.top);
        }
    }
}
