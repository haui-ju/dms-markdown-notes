import QtQuick
import QtTest
import "../src/editor/logic/tables.js" as Tables
import "../src/editor/logic/markdown.js" as Md
import "../src/editor/logic/slash.js" as Slash

TestCase {
    name: "Logic"

    function ids(list) {
        return list.map(c => c.id);
    }

    function test_split_row_basic() {
        compare(Tables.splitRow("| a | b |"), ["a", "b"]);
        compare(Tables.splitRow("|a|b|"), ["a", "b"]);
        compare(Tables.splitRow("| a |  |"), ["a", ""]);
    }

    function test_split_row_escaped_pipe() {
        compare(Tables.splitRow("| a \\| b | c |"), ["a \\| b", "c"]);
        compare(Tables.splitRow("| a | b \\|"), ["a", "b \\|"]);
    }

    function test_split_row_without_trailing_pipe() {
        compare(Tables.splitRow("| a | b"), ["a", "b"]);
    }

    function test_delimiter() {
        verify(Tables.isDelimiter("|---|---|"));
        verify(Tables.isDelimiter("| :--- | :---: | ---: |"));
        verify(!Tables.isDelimiter("| a | b |"));
        verify(!Tables.isDelimiter("| | |"));
    }

    function test_find_skips_fences_and_needs_delimiter() {
        const lines = ["```", "| a | b |", "| - | - |", "```", "", "| x | y |", "| --- | --- |", "| 1 | 2 |", "", "| no | delim |"];
        const found = Tables.find(lines);
        compare(found.length, 1);
        compare(found[0].start, 5);
        compare(found[0].end, 8);
    }

    function test_find_adjacent_tables() {
        const lines = ["| a |", "| - |", "| 1 |", "", "| b |", "| - |"];
        const found = Tables.find(lines);
        compare(found.length, 2);
        compare(found[1].start, 4);
        compare(found[1].end, 6);
    }

    function test_parse_pads_ragged_rows() {
        const lines = ["| a | b | c |", "|---|---|---|", "| 1 |", "| 1 | 2 | 3 | 4 |"];
        const rows = Tables.parse(lines, Tables.find(lines)[0]);
        compare(rows, [["a", "b", "c", ""], ["1", "", "", ""], ["1", "2", "3", "4"]]);
    }

    function test_serialize_roundtrip() {
        const rows = [["h1", "h2"], ["a", ""], ["", "b"]];
        const lines = Tables.serialize(rows);
        compare(lines, ["| h1 | h2 |", "| --- | --- |", "| a | \u00a0 |", "| \u00a0 | b |"]);
        compare(Tables.parse(lines, Tables.find(lines)[0]), rows);
    }

    function test_create_default() {
        const rows = Tables.create(3, 3);
        compare(rows.length, 3);
        compare(rows[0], ["Columna 1", "Columna 2", "Columna 3"]);
        compare(rows[2], ["", "", ""]);
        verify(Tables.isPlaceholder("Columna 12"));
        verify(!Tables.isPlaceholder("Columna"));
    }

    function test_insert_row_never_above_header() {
        const rows = [["a", "b"], ["1", "2"]];
        compare(Tables.insertRow(rows, 0), [["a", "b"], ["", ""], ["1", "2"]]);
        compare(Tables.insertRow(rows, 99), [["a", "b"], ["1", "2"], ["", ""]]);
        compare(rows, [["a", "b"], ["1", "2"]]);
    }

    function test_insert_column() {
        const rows = [["a", "b"], ["1", "2"]];
        compare(Tables.insertColumn(rows, 1), [["a", "Columna 3", "b"], ["1", "", "2"]]);
        compare(Tables.insertColumn(rows, 9), [["a", "b", "Columna 3"], ["1", "2", ""]]);
    }

    function test_remove_row_and_column() {
        const rows = [["a", "b"], ["1", "2"]];
        compare(Tables.removeRow(rows, 0), [["1", "2"], ["", ""]]);
        compare(Tables.removeRow(rows, 1), [["a", "b"], ["", ""]]);
        compare(Tables.removeRow([["a"]], 0), null);
        compare(Tables.removeColumn(rows, 0), [["b"], ["2"]]);
        compare(Tables.removeColumn([["a"], ["1"]], 0), null);
    }

    function test_scan_and_locate() {
        const text = "Hola\uFDD0a\uFDD0b\uFDD0\uFDD0d\uFDD1\u2029Fin";
        const spans = Tables.scan(text);
        compare(spans.length, 1);
        compare(spans[0].cells.length, 4);
        compare(text.substring(spans[0].cells[1].start, spans[0].cells[1].end), "b");
        compare(spans[0].cells[2].start, spans[0].cells[2].end);
        compare(Tables.locate(spans, 4), null);
        compare(Tables.locate(spans, 5).cell, 0);
        compare(Tables.locate(spans, 9).cell, 2);
        compare(Tables.locate(spans, spans[0].end).cell, 3);
        compare(Tables.locate(spans, spans[0].end + 1), null);
    }

    function test_blocks_include_table_cells() {
        const b = Md.blocks("Hola\n\n| a | b |\n| --- | --- |\n| c |  |\n\n- [ ] t\n");
        compare(b.map(x => x.type), ["para", "cell", "cell", "cell", "cell", "task"]);
        compare(b[4].text, "");
    }

    function test_block_range_stops_at_cells() {
        const text = "x\uFDD0abc\uFDD0de\uFDD1";
        const r = Md.blockRange(text, 3);
        compare(r.text, "abc");
    }

    function test_slash_filter_accents_and_order() {
        compare(Slash.filter(Slash.BLOCKS, "titulo")[0].id, "h1");
        compare(ids(Slash.filter(Slash.BLOCKS, "Título 2")), ["h2"]);
        compare(Slash.filter(Slash.BLOCKS, "codigo")[0].id, "code");
        compare(Slash.filter(Slash.BLOCKS, "código")[0].id, "code");
        compare(Slash.filter(Slash.BLOCKS, "tab")[0].id, "table");
        compare(ids(Slash.filter(Slash.BLOCKS, "lista tareas")), ["task"]);
        compare(Slash.filter(Slash.BLOCKS, "zzz"), []);
        compare(Slash.filter(Slash.BLOCKS, "").length, Slash.BLOCKS.length);
    }

    function test_slash_filter_table_commands() {
        compare(ids(Slash.filter(Slash.TABLE, "fila")), ["rowAdd", "rowRemove"]);
        compare(ids(Slash.filter(Slash.TABLE, "eliminar col")), ["columnRemove"]);
    }

    function test_serialize_header_only_gets_body_row() {
        compare(Tables.serialize([["a", "b"]]), ["| a | b |", "| --- | --- |", "| \u00a0 | \u00a0 |"]);
    }

    function test_prepare_fills_empty_cells_and_pads() {
        const out = Tables.prepare("Hola\n\n| a | b | c |\n|---|---|---|\n| 1 |  |\n");
        compare(out, "Hola\n\n| a | b | c |\n| --- | --- | --- |\n| 1 | \u00a0 | \u00a0 |\n");
    }

    function test_prepare_separates_tables_from_fences_quotes_tables_and_start() {
        const t = "| a |\n| - |\n| 1 |";
        compare(Tables.prepare(t), "\u00a0\n\n| a |\n| --- |\n| 1 |");
        compare(Tables.prepare("```\nx\n```\n\n" + t), "```\nx\n```\n\n\u00a0\n\n| a |\n| --- |\n| 1 |");
        compare(Tables.prepare("> q\n\n" + t), "> q\n\n\u00a0\n\n| a |\n| --- |\n| 1 |");
        const two = Tables.prepare("x\n\n" + t + "\n\n" + t);
        compare(two, "x\n\n| a |\n| --- |\n| 1 |\n\n\u00a0\n\n| a |\n| --- |\n| 1 |");
    }

    function test_prepare_is_idempotent() {
        const src = "```\nx\n```\n\n| a | b |\n| - | - |\n| 1 |  |\n\n> q\n\n| c |\n| - |\n";
        const once = Tables.prepare(src);
        compare(Tables.prepare(once), once);
    }

    function test_prepare_ignores_fenced_tables() {
        const src = "```\n| a |\n| - |\n```";
        compare(Tables.prepare(src), src);
    }

    function test_repair_rejoins_unescaped_pipes() {
        const md = "\n|a | b|c|\n|-----|-|\n|1    |2|\n";
        const plain = "\uFDD0a | b\uFDD0c\uFDD01\uFDD02\uFDD1";
        compare(Tables.repair(md, plain), "\n| a \\| b | c |\n|-----|-|\n|1    |2|\n");
    }

    function test_repair_keeps_formatting_while_rejoining() {
        const md = "| h | x |\n|-|-|\n|**a** | b|c|\n";
        const plain = "\uFDD0h\uFDD0x\uFDD0a | b\uFDD0c\uFDD1";
        compare(Tables.repair(md, plain).split("\n")[2], "| **a** \\| b | c |");
    }

    function test_repair_leaves_clean_tables_alone() {
        const md = "|a|b|\n|-|-|\n|1|2|\n";
        compare(Tables.repair(md, "\uFDD0a\uFDD0b\uFDD01\uFDD02\uFDD1"), md);
        compare(Tables.repair(md, "sin tablas"), md);
    }

    function test_blocks_ignore_pipe_paragraphs() {
        compare(Md.blocks("| no es tabla\n").map(x => x.type), ["para"]);
    }
}
