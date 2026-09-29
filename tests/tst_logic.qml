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
        compare(lines, ["| h1 | h2 |", "| --- | --- |", "| a |  |", "|  | b |"]);
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
        compare(ids(Slash.filter(Slash.TABLE, "fila")), ["rowAdd", "rowRemove", "density"]);
        compare(ids(Slash.filter(Slash.TABLE, "eliminar col")), ["columnRemove"]);
        compare(ids(Slash.filter(Slash.TABLE, "equilibrar")), ["equalize"]);
        compare(ids(Slash.filter(Slash.TABLE, "ancho")), ["fullWidth", "equalize"]);
    }

    function test_serialize_header_only_gets_body_row() {
        compare(Tables.serialize([["a", "b"]]), ["| a | b |", "| --- | --- |", "|  |  |"]);
    }

    readonly property var style: ({
            border: "#888888"
        })
    readonly property string open: "<table border=\"1\" cellspacing=\"0\" cellpadding=\"5\" style=\"border-collapse: collapse; border-color: #888888\">"

    function test_prepare_converts_tables_to_html() {
        const out = Tables.prepare("Hola\n\n| a | b | c |\n|---|---|---|\n| 1 |  |\n", style);
        compare(out.text, "Hola\n\n" + open + "<tr><th align=\"left\">a</th><th align=\"left\">b</th><th align=\"left\">c</th></tr><tr><td>1</td><td></td><td></td></tr></table>\n\n");
        compare(out.layouts, [Tables.defaultLayout(3)]);
    }

    function test_prepare_table_margin() {
        const out = Tables.prepare("x\n\n| a |\n|-|\n| 1 |\n", {
            border: "#888888",
            margin: 9
        }).text;
        verify(out.indexOf("border-color: #888888; margin-top: 9px; margin-bottom: 9px\"") > 0, out);
    }

    function test_prepare_empty_header_cells_get_nbsp() {
        const out = Tables.prepare("x\n\n|  | b |\n|-|-|\n|  |  |\n", style).text;
        verify(out.indexOf("<th align=\"left\">&nbsp;</th>") > 0, out);
        verify(out.indexOf("<td></td><td></td>") > 0, out);
    }

    function test_prepare_header_only_gets_body_row() {
        const out = Tables.prepare("x\n\n| a |\n|-|\n", style).text;
        verify(out.indexOf("<tr><td></td></tr></table>") > 0, out);
    }

    function test_prepare_separates_only_start_and_adjacent_tables() {
        const t = "| a |\n| - |\n| 1 |";
        verify(Tables.prepare(t, style).text.startsWith("\u00a0\n\n<table"));
        verify(Tables.prepare("```\nx\n```\n" + t, style).text.startsWith("```\nx\n```\n\n<table"));
        verify(Tables.prepare("> q\n\n" + t, style).text.startsWith("> q\n\n<table"));
        const two = Tables.prepare("x\n\n" + t + "\n\n" + t, style).text.split("\n").filter(l => l !== "");
        compare(two.length, 4);
        compare(two[2], "\u00a0");
    }

    function test_prepare_ignores_fenced_tables() {
        const src = "```\n| a |\n| - |\n```";
        compare(Tables.prepare(src, style).text, src);
        compare(Tables.prepare("sin tablas", style), {
            text: "sin tablas",
            layouts: []
        });
    }

    function test_prepare_reads_and_strips_layout() {
        const out = Tables.prepare("x\n\n<!-- tabla: ancho=100 columnas=40,30,30 alto=compacto -->\n| a | b | c |\n|-|-|-|\n| 1 | 2 | 3 |\n", style);
        compare(out.layouts, [{
                cols: 3,
                width: 100,
                columns: [40, 30, 30],
                density: "compacto"
            }]);
        verify(out.text.indexOf("<!--") < 0);
        verify(out.text.indexOf("cellpadding=\"2\"") > 0);
        verify(out.text.indexOf(" width=\"100%\"") > 0);
        verify(out.text.indexOf("<th align=\"left\" width=\"40%\">a</th>") > 0, out.text);
    }

    function test_parse_layout_rejects_garbage() {
        compare(Tables.parseLayout("<!-- tabla: columnas=10,90 -->", 3).columns, []);
        compare(Tables.parseLayout("<!-- tabla: columnas=a,b -->", 2).columns, []);
        compare(Tables.parseLayout("<!-- tabla: columnas=0,10 -->", 2).columns, []);
        compare(Tables.parseLayout("<!-- tabla: ancho=5 -->", 2).width, 0);
        compare(Tables.parseLayout("<!-- tabla: ancho=300 -->", 2).width, 0);
        compare(Tables.parseLayout("<!-- tabla: alto=raro -->", 2).density, "normal");
        compare(Tables.parseLayout("<!-- tabla: -->", 2), Tables.defaultLayout(2));
        compare(Tables.parseLayout("<!-- tabla: columnas=1,1,2 -->", 3).columns, [25, 25, 50]);
        verify(!Tables.isLayoutLine("<!-- otra cosa -->"));
        verify(Tables.isLayoutLine("  <!-- tabla: ancho=50 -->  "));
    }

    function test_layout_line_roundtrip() {
        const layout = {
            cols: 2,
            width: 60,
            columns: [30, 70],
            density: "amplio"
        };
        const line = Tables.layoutLine(layout);
        compare(line, "<!-- tabla: ancho=60 columnas=30,70 alto=amplio -->");
        compare(Tables.parseLayout(line, 2), layout);
        verify(Tables.isDefaultLayout(Tables.parseLayout(Tables.layoutLine(Tables.defaultLayout(2)), 2)));
    }

    function test_normalize_columns_sums_100() {
        for (const values of [[1, 1, 1], [1, 2], [7, 7, 7, 7, 7, 7, 7], [0.1, 99.9], [50, 50, 1]]) {
            const out = Tables.normalizeColumns(values);
            compare(out.reduce((a, b) => a + b, 0), 100);
            verify(out.every(n => n >= 1), JSON.stringify(out));
        }
        compare(Tables.equalColumns(4), [25, 25, 25, 25]);
    }

    function test_layout_column_ops() {
        const layout = {
            cols: 2,
            width: 100,
            columns: [30, 70],
            density: "normal"
        };
        const added = Tables.layoutInsertColumn(layout, 1);
        compare(added.cols, 3);
        compare(added.columns.length, 3);
        compare(added.columns.reduce((a, b) => a + b, 0), 100);
        compare(layout.columns, [30, 70]);
        compare(Tables.layoutRemoveColumn(layout, 0).columns, [100]);
        compare(Tables.layoutInsertColumn(Tables.defaultLayout(2), 0).columns, []);
        compare(Tables.nextDensity("normal"), "amplio");
        compare(Tables.nextDensity("amplio"), "compacto");
        compare(Tables.nextDensity("compacto"), "normal");
    }

    function test_inline_html() {
        compare(Tables.inlineHtml("**b** *i* ~~s~~ `c|<` [l](u)"), "<b>b</b> <i>i</i> <s>s</s> <code>c|&lt;</code> <a href=\"u\">l</a>");
        compare(Tables.inlineHtml("a \\| b <x> & \\*no\\*"), "a | b &lt;x&gt; &amp; *no*");
        compare(Tables.inlineHtml("snake_case_name"), "snake_case_name");
        compare(Tables.inlineHtml("[x](u\"onclick)"), "<a href=\"u&quot;onclick\">x</a>");
    }

    function test_repair_reinjects_layout_above_table() {
        const layout = Tables.parseLayout("<!-- tabla: ancho=100 -->", 2);
        const md = "x\n\n| a | b |\n|-|-|\n| 1 | 2 |\n";
        const out = Tables.repair(md, "x\u2029\uFDD0a\uFDD0b\uFDD01\uFDD02\uFDD1", [layout]);
        compare(out, "x\n\n<!-- tabla: ancho=100 -->\n| a | b |\n|-|-|\n| 1 | 2 |\n");
    }

    function test_repair_aligns_layouts_by_columns() {
        const two = Tables.parseLayout("<!-- tabla: ancho=50 -->", 2);
        const three = Tables.parseLayout("<!-- tabla: alto=amplio -->", 3);
        const md = "| a | b | c |\n|-|-|-|\n| 1 | 2 | 3 |\n";
        const plain = "\uFDD0a\uFDD0b\uFDD0c\uFDD01\uFDD02\uFDD03\uFDD1";
        compare(Tables.repair(md, plain, [two, three]).split("\n")[0], "<!-- tabla: alto=amplio -->");
        compare(Tables.repair(md, plain, [two]).split("\n")[0], "| a | b | c |");
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

    function test_unescape_code_spans_from_qt() {
        compare(Md.unescapeCodeSpans("`\\# x` y `a\\\\b` `\\*q*` \\*fuera\\*"), "`# x` y `a\\b` `*q*` \\*fuera\\*");
        compare(Md.unescapeCodeSpans("|`a\\\\b` `\\-` `x\\|y`|"), "|`a\\b` `-` `x\\|y`|");
        compare(Md.unescapeCodeSpans("x `a\\|b`"), "x `a|b`");
        compare(Md.unescapeCodeSpans("texto\n\n```\n`\\# x`\n```"), "texto\n\n```\n`\\# x`\n```");
    }

    function test_unescape_code_spans_with_backticks() {
        compare(Md.unescapeCodeSpans("x (````\\```python````) y"), "x (```` ```python ````) y");
        compare(Md.unescapeCodeSpans("(```` \\```python```` ) o"), "(```` ```python ````) o");
        compare(Md.unescapeCodeSpans("``\\`a`` y"), "`` `a `` y");
        compare(Md.unescapeCodeSpans("|`` \\`t```  , x|"), "|`` `t` `` , x|");
        compare(Md.unescapeCodeSpans("|```` ```````  \\+ x|"), "|```` ``` ```` \\+ x|");
        compare(Md.unescapeCodeSpans("``a`b`` y ` sin cerrar"), "``a`b`` y ` sin cerrar");
    }

    function test_unescape_code_spans_across_wrapped_lines() {
        compare(Md.unescapeCodeSpans("uno `\\#\nx` dos"), "uno `#\nx` dos");
    }

    function test_repair_wrapping_moves_openers() {
        compare(Md.repairWrapping("aaa **\nAbrir** b"), "aaa\n**Abrir** b");
        compare(Md.repairWrapping("- a *\n  b* c"), "- a\n  *b* c");
        compare(Md.repairWrapping("(reinicia `\ndms.service` si"), "(reinicia\n`dms.service` si");
        compare(Md.repairWrapping("x ~~\ny~~"), "x\n~~y~~");
    }

    function test_repair_wrapping_joins_punctuation_after_closers() {
        compare(Md.repairWrapping("en `x`\n, crea"), "en `x`, crea");
        compare(Md.repairWrapping("(`# `, `- `\n, tablas)"), "(`# `, `- `, tablas)");
        compare(Md.repairWrapping("**negrita**\n. Fin"), "**negrita**. Fin");
    }

    function test_repair_wrapping_leaves_the_rest() {
        const same = ["(`# `, `- `\nsigue", "- *\n  x", "a \\*\nb", "```\na **\nb\n```", "texto,\nsigue", "| a **\n| b |", "a `x `\nsigue"];
        for (const md of same)
            compare(Md.repairWrapping(md), md);
    }

    function test_repair_escaped_code() {
        const cases = [["`\\\\\\#` y `\\#`", "`#` y `#`", 2], ["`\\\\\\\\\\\\\\- x`", "`- x`", 1], ["`\\\\#`", "`\\\\#`", 0], ["`a\\\\\\\\b` `a\\\\b` `a\\b` `c:\\\\`", "`a\\b` `a\\b` `a\\b` `c:\\`", 3], ["\\\\\\# `x` fuera", "\\\\\\# `x` fuera", 0], ["|`x\\\\\\|y` `\\#`|b|", "|`x\\|y` `#`|b|", 2], ["```\n`\\#`\n```", "```\n`\\#`\n```", 0], ["---\na: `\\#`\n---\n`\\#`", "---\na: `\\#`\n---\n`#`", 1], ["texto sin nada", "texto sin nada", 0]];
        for (const c of cases) {
            const r = Md.repairEscapedCode(c[0]);
            compare(r.md, c[1], c[0]);
            compare(r.count, c[2], c[0]);
        }
    }

    function test_repair_escaped_code_is_idempotent() {
        const once = Md.repairEscapedCode("`\\\\\\\\\\\\\\# t` y `a\\\\\\\\b`").md;
        compare(Md.repairEscapedCode(once).count, 0);
    }
}
