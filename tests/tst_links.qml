import QtQuick
import QtTest
import "../src/editor/logic/links.js" as Links

TestCase {
    name: "Links"

    function test_parse_targets_and_labels() {
        const r = Links.parse("ver [[Nota uno]], [[otra|alias]] y [[Plan#Fase 2]]");
        compare(r.length, 3);
        compare(r[0].target, "Nota uno");
        compare(r[0].start, 4);
        compare(r[0].end, 16);
        compare(r[1].target, "otra");
        compare(r[1].label, "alias");
        compare(r[2].target, "Plan");
    }

    function test_parse_rejects_broken_links() {
        compare(Links.parse("[[]] [[ ]] [[|x]] [[a\nb]] [[a\u2029b]] [a] [[[x]]]").map(l => l.target), ["x"]);
        compare(Links.parse("[[nota.md]]")[0].target, "nota");
    }

    function test_parse_adjacent() {
        compare(Links.parse("[[a]][[b]]").map(l => [l.start, l.end]), [[0, 5], [5, 10]]);
    }

    function test_at() {
        const links = Links.parse("x [[a]] y");
        compare(Links.at(links, 1), null);
        compare(Links.at(links, 2).target, "a");
        compare(Links.at(links, 6).target, "a");
        compare(Links.at(links, 7), null);
    }

    function test_unescape_outside_code_only() {
        const md = "Ver \\[[Nota]] y \\[[b|c]]\n\n```\n\\[[code]]\n```\n\n~~~\n\\[[t]]\n```\n~~~\n| \\[[Celda]] |";
        compare(Links.unescape(md), "Ver [[Nota]] y [[b|c]]\n\n```\n\\[[code]]\n```\n\n~~~\n\\[[t]]\n```\n~~~\n| [[Celda]] |");
        compare(Links.unescape("\\[a] \\[[x"), "\\[a] \\[[x");
    }

    function test_safe_target_blocks_escape() {
        compare(Links.safeTarget("../../etc/passwd"), "etc/passwd");
        compare(Links.safeTarget(" sub / nota "), "sub/nota");
        compare(Links.safeTarget("../.."), "");
    }

    function test_find_command_escapes_glob() {
        const cmd = Links.findCommand("/n", "sub/a*b?[c]");
        compare(cmd.slice(0, 3), ["find", "/n", "-type"]);
        compare(cmd[cmd.length - 1], "a\\*b\\?\\[c\\].md");
    }

    function test_pick_prefers_same_folder_then_shallow() {
        const out = "/n/deep/x/Nota.md\n/n/b/nota.md\n/n/nota.md\n";
        compare(Links.pick(out, "/n", "nota", "/n/b/actual.md"), "/n/b/nota.md");
        compare(Links.pick(out, "/n", "Nota", "/n/c/actual.md"), "/n/nota.md");
        compare(Links.pick(out, "/n", "x/nota", "/n/actual.md"), "/n/deep/x/Nota.md");
    }

    function test_pick_skips_hidden_foreign_and_partial() {
        const out = "/n/.trash/nota.md\n/otro/nota.md\n/n/minota.md\nfind: '/n/p': Permission denied\n";
        compare(Links.pick(out, "/n", "nota", ""), "");
        compare(Links.pick("/n/.oculta/x.md\n", "/n/", "x", ""), "");
    }

    function test_pick_allows_hidden_notes_dir() {
        compare(Links.pick("/h/.notas/a.md\n", "/h/.notas", "a", ""), "/h/.notas/a.md");
    }

    function test_new_path() {
        compare(Links.newPath("/n/", "Idea nueva"), "/n/Idea nueva.md");
        compare(Links.newPath("/n", "../x/y"), "/n/x/y.md");
        compare(Links.newPath("/n", ".."), "");
    }
}
