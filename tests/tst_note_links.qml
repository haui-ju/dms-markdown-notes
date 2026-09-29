import QtQuick
import QtTest
import Quickshell.Io
import "../src/store"

Item {
    NoteLinks {
        id: links
        dir: "/n"
    }

    SignalSpy {
        id: resolved
        target: links
        signalName: "resolved"
    }

    SignalSpy {
        id: failed
        target: links
        signalName: "failed"
    }

    TestCase {
        name: "NoteLinks"

        readonly property var proc: Processes.last

        function init() {
            resolved.clear();
            failed.clear();
        }

        function test_existing_note_opens() {
            links.open("Plan", "/n/a/actual.md");
            compare(proc.command[0], "find");
            proc.finish(0, "/n/plan.md\n/n/a/Plan.md\n");
            compare(resolved.count, 1);
            compare(resolved.signalArguments[0][0], "/n/a/Plan.md");
        }

        function test_missing_note_is_created() {
            links.open("Idea nueva", "/n/actual.md");
            proc.finish(1, "");
            tryVerify(() => proc.running, 1000);
            compare(proc.command[0], "sh");
            compare(proc.command.slice(-2), ["/n/Idea nueva.md", "Idea nueva"]);
            compare(resolved.count, 0);
            proc.finish(0, "");
            compare(resolved.count, 1);
            compare(resolved.signalArguments[0][0], "/n/Idea nueva.md");
        }

        function test_create_failure_warns() {
            links.open("x", "");
            proc.finish(0, "");
            tryVerify(() => proc.running, 1000);
            proc.finish(1, "");
            compare(resolved.count, 0);
            compare(failed.count, 1);
        }

        function test_unsafe_or_busy_is_ignored() {
            const starts = proc.starts;
            links.open("../..", "");
            compare(proc.starts, starts);
            links.open("a", "");
            links.open("b", "");
            compare(proc.starts, starts + 1);
            compare(proc.command[proc.command.length - 1], "a.md");
            proc.finish(0, "/n/a.md\n");
            compare(resolved.signalArguments[0][0], "/n/a.md");
        }
    }
}
