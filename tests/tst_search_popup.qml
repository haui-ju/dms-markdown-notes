import QtQuick
import QtTest
import Quickshell.Io
import "../src/panel"

Item {
    width: 500
    height: 600

    SearchPopup {
        id: popup
        width: 400
        dir: "/n"
        onPicked: (path, line, query) => spy.last = {
            path: path,
            line: line,
            query: query
        }
    }

    QtObject {
        id: spy
        property var last: null
    }

    TestCase {
        name: "SearchPopup"
        when: windowShown

        readonly property var proc: Processes.last
        readonly property string output: "/n/uno.md:3:hola mundo\n/n/sub/dos.md:1:# Hola <b>\n"

        function init() {
            popup.open();
            keyClick(Qt.Key_A, Qt.ControlModifier);
            keyClick(Qt.Key_Backspace);
            wait(250);
            if (proc.running)
                proc.finish(0, output);
            wait(50);
            compare(popup.results.length, 0);
            spy.last = null;
        }

        function test_reopen_refreshes_last_query() {
            typeQuery("hola");
            proc.finish(0, output);
            const starts = proc.starts;
            popup.open();
            compare(proc.starts, starts + 1);
            compare(proc.command.slice(-2), ["hola", "/n"]);
            proc.finish(0, output);
        }

        function typeQuery(text) {
            for (const ch of text)
                keyClick(ch);
            tryVerify(() => proc.running, 1000);
        }

        function test_short_query_does_not_run() {
            const before = proc.starts;
            keyClick("h");
            wait(250);
            compare(proc.starts, before);
            verify(popup.status.indexOf("al menos") >= 0);
        }

        function test_results_and_keyboard_pick() {
            typeQuery("hola");
            compare(proc.command.slice(-2), ["hola", "/n"]);
            compare(popup.status, "Buscando…");
            proc.finish(0, output);
            compare(popup.results.length, 2);
            compare(popup.status, "");
            keyClick(Qt.Key_Down);
            compare(popup.currentIndex, 1);
            keyClick(Qt.Key_Down);
            compare(popup.currentIndex, 0);
            keyClick(Qt.Key_Up);
            keyClick(Qt.Key_Return);
            compare(spy.last.path, "/n/sub/dos.md");
            compare(spy.last.line, 1);
            compare(spy.last.query, "hola");
        }

        function test_no_matches() {
            typeQuery("zzz");
            proc.finish(1, "");
            compare(popup.results.length, 0);
            compare(popup.status, "Sin resultados");
            keyClick(Qt.Key_Return);
            compare(spy.last, null);
        }

        function test_typing_while_running_reruns_latest() {
            typeQuery("ho");
            const starts = proc.starts;
            keyClick("l");
            keyClick("a");
            wait(250);
            compare(proc.starts, starts);
            proc.finish(0, "/n/viejo.md:1:ho\n");
            tryVerify(() => proc.running, 1000);
            compare(proc.command.slice(-2), ["hola", "/n"]);
            compare(popup.results.length, 0);
            proc.finish(0, output);
            compare(popup.results.length, 2);
        }

        function test_hash_lists_tags_and_picks_one() {
            keyClick("#");
            tryVerify(() => proc.running, 1000);
            compare(proc.command[0], "find");
            verify(proc.command.indexOf("want=") < 0);
            proc.finish(0, "idea\t2\nAño\t1\nidea\t1\n");
            compare(popup.results.map(r => r.tag + ":" + r.count), ["idea:3", "Año:1"]);
            compare(popup.status, "");
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Return);
            tryVerify(() => proc.running, 1000);
            verify(proc.command.indexOf("want=año") > 0);
            compare(spy.last, null);
            proc.finish(0, "/n/a.md:3:texto #Año\n");
            compare(popup.results.length, 1);
            keyClick(Qt.Key_Return);
            compare(spy.last.path, "/n/a.md");
            compare(spy.last.query, "#Año");
        }

        function test_no_tags() {
            keyClick("#");
            tryVerify(() => proc.running, 1000);
            proc.finish(0, "");
            compare(popup.status, "No hay etiquetas");
        }

        function test_numeric_hash_is_text_search() {
            typeQuery("#1");
            compare(proc.command[0], "grep");
            proc.finish(1, "");
        }

        function test_open_with_tag_prefills() {
            popup.open("#idea");
            compare(proc.command[0], "find");
            verify(proc.command.indexOf("want=idea") > 0);
            proc.finish(0, "");
            popup.open();
            verify(proc.command.indexOf("want=idea") > 0);
            proc.finish(0, "");
        }

        function test_grep_error_clears() {
            typeQuery("hola");
            proc.finish(2, "grep: /n: No such file or directory\n");
            compare(popup.results.length, 0);
            compare(popup.status, "Sin resultados");
        }
    }
}
