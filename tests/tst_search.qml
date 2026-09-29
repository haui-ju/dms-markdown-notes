import QtQuick
import QtTest
import "../src/store/search.js" as Search

TestCase {
    name: "Search"

    function test_command_is_literal_and_recursive() {
        const cmd = Search.command("/n", "-a.b");
        compare(cmd[0], "grep");
        verify(cmd.indexOf("-rinIF") > 0);
        verify(cmd.indexOf("--include=*.md") > 0);
        compare(cmd.slice(-3), ["--", "-a.b", "/n"]);
    }

    function test_parse_basic() {
        const out = "/n/uno.md:3:# Hola mundo\n/n/sub/dos.md:10:- [ ] comprar pan\n";
        const r = Search.parse(out, "/n");
        compare(r.length, 2);
        compare(r[0].path, "/n/uno.md");
        compare(r[0].title, "uno");
        compare(r[0].folder, "");
        compare(r[0].line, 3);
        compare(r[0].text, "Hola mundo");
        compare(r[1].folder, "sub");
        compare(r[1].text, "comprar pan");
    }

    function test_parse_path_with_colon_and_text_with_colon() {
        const r = Search.parse("/n/a:b.md:2:hora: 10:30\n", "/n/");
        compare(r.length, 1);
        compare(r[0].path, "/n/a:b.md");
        compare(r[0].line, 2);
        compare(r[0].text, "hora: 10:30");
    }

    function test_parse_skips_hidden_layout_and_empty() {
        const out = "/n/.git/x.md:1:hola\n/n/.trash/y.md:1:hola\n/n/a.md:1:<!-- tabla: alto=amplio -->\n/n/a.md:2:   \n/n/a.md:3:| a | b |\n";
        const r = Search.parse(out, "/n");
        compare(r.length, 1);
        compare(r[0].text, "a · b");
    }

    function test_parse_ignores_garbage_and_caps() {
        let out = "grep: /n/x: Permission denied\nnot a match\n";
        for (let i = 0; i < Search.MAX_RESULTS + 20; i++)
            out += "/n/a.md:" + (i + 1) + ":linea\n";
        compare(Search.parse(out, "/n").length, Search.MAX_RESULTS);
    }

    function test_clean_quote_and_numbered() {
        compare(Search.clean("> cita importante"), "cita importante");
        compare(Search.clean("12. paso"), "paso");
        compare(Search.clean("  -   [x]   hecho"), "hecho");
    }

    function test_highlight_escapes_and_marks() {
        const html = Search.highlight("a <b> & Hola", "hola", "#f00");
        compare(html, "a &lt;b&gt; &amp; <b><font color=\"#f00\">Hola</font></b>");
    }

    function test_highlight_trims_long_text() {
        const text = "x".repeat(100) + "clave" + "y".repeat(100);
        const html = Search.highlight(text, "clave", "#f00", 10);
        verify(html.indexOf("…") === 0);
        verify(html.lastIndexOf("…") === html.length - 1);
        verify(html.indexOf(">clave<") > 0);
    }

    function test_highlight_without_match() {
        compare(Search.highlight("a<b", "zz", "#f00"), "a&lt;b");
        compare(Search.highlight("a<b", "", "#f00"), "a&lt;b");
    }

    function test_occurrence_counts_previous_lines() {
        const md = "Hola hola\n\nnada\n\nHOLA aquí\n";
        compare(Search.occurrence(md, 1, "hola"), 0);
        compare(Search.occurrence(md, 5, "hola"), 2);
    }

    function test_occurrence_skips_front_matter() {
        const md = "---\ntitle: hola\n---\n\nhola\n";
        compare(Search.occurrence(md, 2, "hola"), -1);
        compare(Search.occurrence(md, 5, "hola"), 0);
    }

    function test_occurrence_out_of_range() {
        compare(Search.occurrence("a", 9, "a"), -1);
        compare(Search.occurrence("a", 1, ""), -1);
    }

    function test_find_kth_with_fallback() {
        const plain = "uno Dos\u2029dos\u2029DOS";
        compare(Search.find(plain, "dos", 0), 4);
        compare(Search.find(plain, "dos", 2), 12);
        compare(Search.find(plain, "dos", 7), 4);
        compare(Search.find(plain, "tres", 0), -1);
    }

    function test_line_offset() {
        const text = "abc\nde Fg\n";
        compare(Search.lineOffset(text, 2, "fg"), 7);
        compare(Search.lineOffset(text, 2, "zz"), 4);
        compare(Search.lineOffset(text, 9, "fg"), -1);
    }
}
