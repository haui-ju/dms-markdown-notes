import QtQuick
import QtTest
import "../src/editor/logic/tags.js" as Tags

TestCase {
    name: "Tags"

    function names(text) {
        return Tags.parse(text).map(t => t.tag);
    }

    function test_parse_positions() {
        const r = Tags.parse("hola #idea y #proyecto/sub.");
        compare(r.map(t => [t.start, t.end, t.tag]), [[5, 10, "idea"], [13, 26, "proyecto/sub"]]);
    }

    function test_parse_boundaries() {
        compare(names("#uno (#dos) **#tres** |#cuatro| *#cinco* ~~#seis~~ _#siete \uFDD0#celda \u2029#parrafo"), ["uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "celda", "parrafo"]);
        compare(names("x#no http://a.com/#no [[n#no]] `#no` ##no # no"), []);
    }

    function test_parse_rules() {
        compare(names("#123 #1a #año #日本 #a-b_c #a/ #/x #tag, #fin."), ["1a", "año", "日本", "a-b_c", "a", "tag", "fin"]);
    }

    function test_at() {
        const tags = Tags.parse("x #a y");
        compare(Tags.at(tags, 1), null);
        compare(Tags.at(tags, 2).tag, "a");
        compare(Tags.at(tags, 3).tag, "a");
        compare(Tags.at(tags, 4), null);
    }

    function test_from_query() {
        compare(Tags.fromQuery(" #Idea "), "Idea");
        compare(Tags.fromQuery("#a/b"), "a/b");
        compare(Tags.fromQuery("#12"), "");
        compare(Tags.fromQuery("# idea"), "");
        compare(Tags.fromQuery("#a b"), "");
        compare(Tags.fromQuery("idea"), "");
    }

    function test_unescape_leading_hash() {
        const cases = [["\\#tag x", "#tag x"], ["- \\#t", "- #t"], ["1.  \\#t", "1.  #t"], ["- [ ] \\#t", "- [ ] #t"], ["> \\#t", "> #t"], ["  * \\#t", "  * #t"], ["|\\#b|\\#c |", "|#b|#c |"], ["\\# no", "\\# no"], ["\\##x", "\\##x"], ["a \\#b", "a \\#b"], ["\\#123", "#123"]];
        for (const c of cases)
            compare(Tags.unescape(c[0]), c[1], c[0]);
        compare(Tags.unescape("```\n\\#x\n```\n\\#y"), "```\n\\#x\n```\n#y");
    }

    function test_match_markdown_drops_code_spans() {
        compare(Tags.matchMarkdown(Tags.parse("usa #x y #y"), "usa `#x` y #y").map(t => t.tag), ["y"]);
        compare(Tags.matchMarkdown(Tags.parse("usa #x y #x"), "usa `` #x `` y #x").length, 1);
        compare(Tags.matchMarkdown(Tags.parse("#a"), "```\n#a\n```").length, 0);
        compare(Tags.matchMarkdown(Tags.parse("#A #b"), "#a #B").length, 2);
    }

    function test_parse_list_merges_and_sorts() {
        const r = Tags.parseList("idea\t2\nAño\t1\nIdea\t1\n123\t4\nbasura\nzeta\t1\n");
        compare(r, [{
                tag: "idea",
                count: 3
            }, {
                tag: "Año",
                count: 1
            }, {
                tag: "zeta",
                count: 1
            }]);
    }

    function test_commands_are_safe_for_find() {
        const search = Tags.searchCommand("/n", "Idea/", 20);
        compare(search.slice(0, 2), ["find", "/n"]);
        compare(search.slice(-2), ["{}", "+"]);
        verify(search.indexOf("want=idea") > 0);
        verify(search.indexOf("max=20") > 0);
        const list = Tags.listCommand("/n");
        for (const cmd of [search, list])
            compare(cmd.filter(a => a.indexOf("{}") >= 0).length, 1);
    }
}
