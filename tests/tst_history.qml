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
        imageBaseDir: "/"
    }

    EditorTestCase {
        name: "History"
        editor: subject

        function undo() {
            keyClick(Qt.Key_Z, Qt.ControlModifier);
            wait(0);
        }

        function redo() {
            keyClick(Qt.Key_Y, Qt.ControlModifier);
            wait(0);
        }

        function undoAll() {
            for (let i = 0; i < 50 && subject.canUndo; i++)
                undo();
        }

        function redoAll() {
            for (let i = 0; i < 50 && subject.canRedo; i++)
                redo();
        }

        function test_undo_word_by_word() {
            type("hola mundo cruel");
            undo();
            compare(md(), "hola mundo");
            undo();
            compare(md(), "hola");
            undo();
            compare(md(), "");
            redo();
            compare(md(), "hola");
            redoAll();
            compare(md(), "hola mundo cruel");
        }

        function test_click_elsewhere_closes_group() {
            type("abc def");
            mouseClick(subject, 2, 5);
            subject.cursorPosition = 0;
            type("X");
            undo();
            compare(md(), "abc def");
        }

        function test_trailing_space_group_boundary() {
            type("uno dos");
            undo();
            compare(md(), "uno");
            type(" tres");
            compare(md(), "uno tres");
        }

        function test_pause_closes_group() {
            type("uno");
            wait(1100);
            type("dos");
            undo();
            compare(md(), "uno");
        }

        function test_cursor_restored() {
            type("abc def");
            subject.cursorPosition = 2;
            type("X");
            compare(md(), "abXc def");
            undo();
            compare(md(), "abc def");
            compare(subject.cursorPosition, 2);
            redo();
            compare(md(), "abXc def");
            compare(subject.cursorPosition, 3);
        }

        function test_heading_shortcut_undo() {
            type("# Titulo");
            compare(md(), "# Titulo");
            undo();
            verify(md().indexOf("Titulo") < 0, md());
            undo();
            compare(subject.plain(), "#");
            undoAll();
            compare(md(), "");
            redoAll();
            compare(md(), "# Titulo");
        }

        function test_inline_format_undo() {
            type("a **negrita**");
            compare(md(), "a **negrita**");
            undo();
            verify(md() !== "a **negrita**", md());
            undoAll();
            compare(md(), "");
            redoAll();
            compare(md(), "a **negrita**");
        }

        function test_backspace_grouped() {
            type("hola mundo");
            wait(1100);
            for (let i = 0; i < 5; i++)
                keyClick(Qt.Key_Backspace);
            compare(md(), "hola ");
            undo();
            compare(md(), "hola mundo");
        }

        function test_typing_after_delete_is_separate() {
            type("hola");
            keyClick(Qt.Key_Backspace);
            type("x");
            compare(md(), "holx");
            undo();
            compare(md(), "hol");
            undo();
            compare(md(), "hola");
        }

        function test_ctrl_shift_z_redoes() {
            type("uno dos");
            undo();
            keyClick(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier);
            compare(md(), "uno dos");
        }

        function test_new_edit_clears_redo() {
            type("uno dos");
            undo();
            type("tres");
            verify(!subject.canRedo);
            redo();
            compare(md(), "unotres");
        }

        function test_empty_history_is_noop() {
            verify(!subject.canUndo);
            undo();
            redo();
            compare(md(), "");
            type("a");
            undo();
            undo();
            compare(md(), "");
        }

        function test_table_undo_redo() {
            type("antes\n/tabla\n");
            compare(tables().length, 1);
            undo();
            compare(tables().length, 0);
            verify(md().indexOf("antes") === 0, md());
            redo();
            compare(tables().length, 1);
        }

        function test_table_row_undo() {
            type("/tabla\n");
            placeInCell(0, 0);
            const rows = table().length;
            subject.runCommand("rowAdd");
            compare(table().length, rows + 1);
            undo();
            compare(table().length, rows);
            redo();
            compare(table().length, rows + 1);
        }

        function test_code_block_undo() {
            type("```\nx = 1");
            compare(subject.code.text(0), "x = 1");
            undo();
            compare(subject.code.text(0), "x =");
            undo();
            undo();
            compare(subject.code.blocks.length, 1);
            compare(subject.code.text(0), "");
            undoAll();
            compare(subject.code.blocks.length, 0);
            compare(md(), "");
            redoAll();
            compare(subject.code.text(0), "x = 1");
        }

        function test_paste_undo() {
            type("inicio ");
            subject.copyPlain("# Pegado\n\n- a\n- b");
            keyClick(Qt.Key_V, Qt.ControlModifier);
            verify(md().indexOf("- b") >= 0, md());
            undo();
            compare(md(), "inicio");
        }

        function test_task_toggle_undo() {
            subject.load("- [ ] tarea");
            subject.toggleTaskAt(0);
            compare(md(), "- [x] tarea");
            undo();
            compare(md(), "- [ ] tarea");
        }

        function test_block_type_undo() {
            type("texto");
            keyClick(Qt.Key_1, Qt.ControlModifier);
            compare(md(), "# texto");
            undo();
            compare(md(), "texto");
        }

        function test_load_resets_history() {
            type("algo");
            subject.load("otra nota");
            verify(!subject.canUndo);
            undo();
            compare(md(), "otra nota");
        }

        function test_external_reload_is_undoable() {
            subject.load("uno");
            subject.load("dos", true);
            compare(md(), "dos");
            undo();
            compare(md(), "uno");
        }

        function test_history_state_roundtrip() {
            type("uno dos");
            const state = subject.historyState();
            subject.load("otra");
            subject.load("uno dos");
            verify(subject.restoreHistory(state));
            undo();
            compare(md(), "uno");
        }

        function test_history_state_rejects_other_content() {
            type("uno dos");
            const state = subject.historyState();
            subject.load("cambiado");
            verify(!subject.restoreHistory(state));
            verify(!subject.canUndo);
        }

        function test_source_mode_undo() {
            type("uno");
            subject.setSourceMode(true);
            subject.cursorPosition = 3;
            type(" dos");
            compare(subject.markdown().trim(), "uno dos");
            undo();
            compare(subject.markdown().trim(), "uno");
            undo();
            compare(subject.markdown().trim(), "");
        }

        function test_image_insert_and_retarget_undo() {
            type("texto");
            keyClick(Qt.Key_Return);
            subject.insertImages(["viejo/a.png"]);
            verify(md().indexOf("](viejo/a.png)") >= 0, md());
            verify(subject.retargetImages("viejo/", "nuevo/"));
            verify(md().indexOf("](nuevo/a.png)") >= 0, md());
            undo();
            verify(md().indexOf("a.png") < 0, md());
            redo();
            verify(md().indexOf("](nuevo/a.png)") >= 0, md());
        }

        function test_undo_with_slash_menu_open() {
            type("hola /ta");
            verify(subject.slash.active);
            undo();
            verify(!subject.slash.active);
            compare(md(), "hola");
        }

        function test_cut_undo() {
            type("uno dos");
            wait(1100);
            subject.select(0, 3);
            keyClick(Qt.Key_X, Qt.ControlModifier);
            compare(md(), " dos");
            undo();
            compare(md(), "uno dos");
        }

        function test_cell_typing_undo() {
            type("/tabla\n");
            placeInCell(0, 3);
            type("valor");
            compare(cellText(0, 3), "valor");
            undo();
            compare(cellText(0, 3), "");
            compare(tables().length, 1);
        }

        function test_image_remove_undo() {
            subject.insertImages(["img/a.png"]);
            const pos = subject.plain().indexOf("\ufffc");
            verify(pos >= 0);
            verify(subject.removeImageAt(pos));
            verify(md().indexOf("a.png") < 0, md());
            undo();
            verify(md().indexOf("](img/a.png)") >= 0, md());
        }

        function test_undo_does_not_emit_redo_group() {
            type("uno dos");
            undo();
            undo();
            compare(md(), "");
            verify(subject.canRedo);
            redo();
            redo();
            compare(md(), "uno dos");
            verify(!subject.canRedo);
        }
    }
}
