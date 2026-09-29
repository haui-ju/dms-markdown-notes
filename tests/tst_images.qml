import QtQuick
import QtTest
import "../src/editor"
import "../src/editor/logic/images.js" as Images

Item {
    width: 1700
    height: 1000

    readonly property string dir: "/"

    Rectangle {
        id: bigSwatch
        width: 1600
        height: 900
        color: "#3366aa"
        visible: false
    }

    Rectangle {
        id: smallSwatch
        width: 120
        height: 60
        color: "#aed500"
        visible: false
    }

    MarkdownEditor {
        id: subject
        width: 520
        height: 700
        focus: true
        imageBaseDir: dir
    }

    EditorTestCase {
        id: test
        name: "Images"
        editor: subject

        property bool made: false

        function initTestCase() {
            bigSwatch.visible = true;
            smallSwatch.visible = true;
            wait(50);
            grabImage(bigSwatch).save("/tmp/dmsnotes-big.png");
            grabImage(smallSwatch).save("/tmp/dmsnotes-small.png");
            grabImage(smallSwatch).save("/tmp/dmsnotes con espacio.png");
            bigSwatch.visible = false;
            smallSwatch.visible = false;
        }

        function init() {
            subject.imageBaseDir = dir;
            subject.setSourceMode(false);
            subject.load("");
            subject.forceActiveFocus();
        }

        function measured() {
            subject.refreshDecorations();
            return subject.images;
        }

        function test_round_trip_keeps_real_path() {
            subject.load("antes\n\n![logo](tmp/dmsnotes-small.png)\n\ndespues\n");
            compare(md(), "antes\n\n![logo](tmp/dmsnotes-small.png)\n\ndespues");
            verify(subject.markdownText.indexOf("data:") < 0);
        }

        function test_large_image_fits_editor_width() {
            subject.load("![](tmp/dmsnotes-big.png)\n");
            const imgs = measured();
            compare(imgs.length, 1);
            verify(imgs[0].width <= subject.imageMaxWidth, imgs[0].width);
            verify(imgs[0].height <= subject.imageMaxHeight);
            compare(Math.round(imgs[0].width / imgs[0].height * 100), Math.round(1600 / 900 * 100));
            verify(subject.contentHeight < 600, subject.contentHeight);
        }

        function test_small_image_keeps_size() {
            subject.load("![](tmp/dmsnotes-small.png)\n");
            const imgs = measured();
            compare(imgs[0].width, 120);
            compare(imgs[0].height, 60);
            compare(imgs[0].missing, false);
            compare(imgs[0].url, "file:///tmp/dmsnotes-small.png");
        }

        function test_overlay_sits_on_image_rect() {
            subject.load("texto\n\n![](tmp/dmsnotes-small.png)\n\nfin\n");
            const img = measured()[0];
            const r = subject.positionToRectangle(img.pos);
            compare(img.x, r.x);
            verify(img.y >= r.y && img.y + img.height <= r.y + r.height + 1, JSON.stringify([img, r]));
        }

        function test_image_has_gap_around_it() {
            subject.load("texto\n\n![](tmp/dmsnotes-small.png)\n\nfin\n");
            const img = measured()[0];
            const r = subject.positionToRectangle(img.pos);
            verify(subject.blockGap > 0);
            compare(img.y - r.y, subject.blockGap);
            verify(r.y + r.height - (img.y + img.height) >= subject.blockGap);
        }

        function test_missing_image_shows_placeholder() {
            subject.load("![](tmp/dmsnotes-no-existe.png)\n");
            const imgs = measured();
            compare(imgs.length, 1);
            compare(imgs[0].missing, true);
            compare(md(), "![](tmp/dmsnotes-no-existe.png)");
        }

        function test_encoded_space_path() {
            subject.load("![](tmp/dmsnotes%20con%20espacio.png)\n");
            const imgs = measured();
            compare(imgs[0].missing, false);
            compare(md(), "![](tmp/dmsnotes%20con%20espacio.png)");
        }

        function test_typing_after_image_keeps_link() {
            subject.load("![](tmp/dmsnotes-small.png)\n\nfin\n");
            subject.cursorPosition = subject.length;
            type(" mas texto");
            compare(md(), "![](tmp/dmsnotes-small.png)\n\nfin mas texto");
        }

        function test_image_between_text_in_paragraph() {
            subject.load("hola ![a](tmp/dmsnotes-small.png) mundo\n");
            compare(md(), "hola ![a](tmp/dmsnotes-small.png) mundo");
            subject.cursorPosition = subject.length;
            type("!");
            compare(md(), "hola ![a](tmp/dmsnotes-small.png) mundo!");
        }

        function test_backspace_removes_image() {
            subject.load("antes\n\n![](tmp/dmsnotes-small.png)\n\nfin\n");
            subject.cursorPosition = subject.plain().indexOf("\ufffc") + 1;
            keyClick(Qt.Key_Backspace);
            verify(md().indexOf("![") < 0, md());
            compare(measured().length, 0);
        }

        function test_image_in_code_is_text() {
            subject.load("```\n![](tmp/dmsnotes-small.png)\n```\n");
            compare(measured().length, 0);
            compare(subject.code.text(0), "![](tmp/dmsnotes-small.png)");
        }

        function test_insert_images_as_blocks() {
            subject.load("hola\n");
            subject.cursorPosition = subject.length;
            subject.insertImages(["tmp/dmsnotes-small.png", "tmp/dmsnotes-big.png"]);
            compare(md(), "hola\n\n![](tmp/dmsnotes-small.png)\n\n![](tmp/dmsnotes-big.png)\n\n\u00a0");
            compare(measured().length, 2);
            type("fin");
            verify(/!\[\]\(tmp\/dmsnotes-big\.png\)\n\nfin$/.test(md()), JSON.stringify(md()));
        }

        function test_insert_image_in_middle_of_paragraph_splits_it() {
            subject.load("antesdespues\n");
            subject.cursorPosition = 5;
            subject.insertImages(["tmp/dmsnotes-small.png"]);
            compare(md(), "antes\n\n![](tmp/dmsnotes-small.png)\n\ndespues");
        }

        function test_insert_image_encodes_spaces() {
            subject.load("");
            subject.insertImages(["tmp/dmsnotes con espacio.png"]);
            verify(md().indexOf("![](tmp/dmsnotes%20con%20espacio.png)") === 0, md());
            compare(measured()[0].missing, false);
        }

        function test_retarget_images_after_rename() {
            subject.load("![a](nota/small.png)\n\ntexto ![b](otra/x.png)\n");
            verify(subject.retargetImages("nota/", "nueva/"));
            compare(md(), "![a](nueva/small.png)\n\ntexto ![b](otra/x.png)");
        }

        function test_source_mode_shows_real_path() {
            subject.load("![](tmp/dmsnotes-small.png)\n");
            subject.setSourceMode(true);
            compare(subject.text.indexOf("data:"), -1);
            verify(subject.text.indexOf("![](tmp/dmsnotes-small.png)") >= 0);
            subject.setSourceMode(false);
            compare(md(), "![](tmp/dmsnotes-small.png)");
            compare(measured().length, 1);
        }

        function test_click_emits_activation() {
            subject.load("![alt](tmp/dmsnotes-small.png)\n");
            measured();
            wait(50);
            spy.clear();
            const area = findArea(subject);
            verify(area);
            mouseClick(area);
            compare(spy.count, 1);
            compare(spy.signalArguments[0][0], 0);
            compare(spy.signalArguments[0][2], "tmp/dmsnotes-small.png");
            compare(spy.signalArguments[0][3], "alt");
        }

        function findArea(item) {
            if (item.objectName === "imageArea")
                return item;
            for (const child of item.children) {
                const hit = findArea(child);
                if (hit)
                    return hit;
            }
            return null;
        }

        function test_relayout_on_width_change() {
            subject.load("![](tmp/dmsnotes-big.png)\n\nfin\n");
            const before = measured()[0].width;
            subject.width = 300;
            wait(250);
            const after = measured()[0].width;
            verify(after < before, before + " -> " + after);
            compare(md(), "![](tmp/dmsnotes-big.png)\n\nfin");
            subject.width = 520;
            wait(250);
        }

        function test_empty_clipboard_requests_image_paste() {
            pasteSpy.clear();
            subject.copyPlain("  \n ");
            subject.load("hola\n");
            subject.cursorPosition = subject.length;
            keyClick(Qt.Key_V, Qt.ControlModifier);
            compare(pasteSpy.count, 1);
            compare(md(), "hola");
        }

        function test_pasting_image_file_paths() {
            filesSpy.clear();
            subject.copyPlain("file:///tmp/dmsnotes-small.png\n/tmp/dmsnotes-big.png");
            keyClick(Qt.Key_V, Qt.ControlModifier);
            compare(filesSpy.count, 1);
            compare(filesSpy.signalArguments[0][0], ["/tmp/dmsnotes-small.png", "/tmp/dmsnotes-big.png"]);
            compare(md(), "");
        }

        function test_pasting_non_image_path_is_text() {
            filesSpy.clear();
            subject.copyPlain("/etc/hosts");
            keyClick(Qt.Key_V, Qt.ControlModifier);
            compare(filesSpy.count, 0);
            compare(md(), "/etc/hosts");
        }

        function test_slash_image_requests_picker() {
            requestSpy.clear();
            type("/imagen");
            keyClick(Qt.Key_Return);
            compare(requestSpy.count, 1);
            compare(md(), "");
        }
    }

    SignalSpy {
        id: spy
        target: subject
        signalName: "imageActivated"
    }

    SignalSpy {
        id: pasteSpy
        target: subject
        signalName: "imagePasteRequested"
    }

    SignalSpy {
        id: filesSpy
        target: subject
        signalName: "imageFilesPasted"
    }

    SignalSpy {
        id: requestSpy
        target: subject
        signalName: "imageRequested"
    }

    TestCase {
        name: "ImagesLogic"

        function test_find_skips_code_escapes_and_tables() {
            const md = "![a](x.png)\n\n`![b](y.png)`\n\n\\![c](z.png)\n\n| ![d](w.png) |\n\n```\n![e](v.png)\n```\n\ntexto ![f](<con espacio.png> \"titulo\")";
            const found = Images.find(md);
            compare(found.map(f => f.src), ["x.png", "con espacio.png"]);
            compare(found[1].title, " \"titulo\"");
        }

        function test_fit() {
            compare(Images.fit({width: 1600, height: 900}, 400, 480), {width: 400, height: 225});
            compare(Images.fit({width: 500, height: 2000}, 400, 480), {width: 120, height: 480});
            compare(Images.fit({width: 100, height: 50}, 400, 480), {width: 100, height: 50});
            compare(Images.fit(null, 400, 480), null);
        }

        function test_repair_unwraps_qt_soft_breaks() {
            const url = Images.placeholder({width: 10, height: 10}, 1);
            const sources = {};
            sources[url] = {
                alt: "x",
                raw: "a.png"
            };
            compare(Images.repair("\n![x](" + url + ")\n\n", sources), "![x](a.png)\n\n");
            compare(Images.repair("hola \n![x](" + url + ")\nfin\n\n", sources), "hola ![x](a.png) fin\n\n");
            compare(Images.repair("antes\n\n\n![x](" + url + ")\n\nfin", sources), "antes\n\n![x](a.png)\n\nfin");
            compare(Images.repair("- ![x](" + url + ")\n- otro", sources), "- ![x](a.png)\n- otro");
        }

        function test_repair_restores_empty_alt() {
            const url = Images.placeholder({width: 10, height: 10}, 2);
            const sources = {};
            sources[url] = {
                alt: "",
                raw: "b.png"
            };
            compare(Images.repair("![imagen](" + url + ")", sources), "![](b.png)");
        }

        function test_files_from() {
            compare(Images.filesFrom("file:///home/u/a%20b.png\n/home/u/c.JPG"), ["/home/u/a b.png", "/home/u/c.JPG"]);
            compare(Images.filesFrom("/home/u/doc.pdf"), []);
            compare(Images.filesFrom("relativa.png"), []);
            compare(Images.filesFrom("hola mundo"), []);
        }

        function test_markdown_for() {
            compare(Images.markdownFor("nota/a b(1).png", "x"), "![x](nota/a%20b%281%29.png)");
        }

        function test_resolve() {
            compare(Images.resolve("nota/a%20b.png", "/home/u/Notes"), "file:///home/u/Notes/nota/a%20b.png");
            compare(Images.resolve("/abs/x.png", "/home"), "file:///abs/x.png");
            compare(Images.resolve("https://x.org/a.png", "/home"), "https://x.org/a.png");
        }
    }
}
