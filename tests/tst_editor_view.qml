import QtQuick
import QtTest
import "../src/panel"

Item {
    width: 520
    height: 620

    EditorView {
        id: view
        anchors.fill: parent
    }

    TextEdit {
        id: clipboardReader
        visible: false
        textFormat: TextEdit.PlainText
    }

    EditorTestCase {
        name: "EditorView"
        editor: view.editor

        function init() {
            failOnWarning(/TypeError|ReferenceError/);
            view.editor.load("");
            view.editor.forceActiveFocus();
        }

        function find(item, name) {
            if (!item)
                return null;
            if (item.objectName === name && item.visible !== false)
                return item;
            for (const child of item.children) {
                const hit = find(child, name);
                if (hit)
                    return hit;
            }
            return null;
        }

        function all(item, name, out) {
            out = out || [];
            if (item.objectName === name)
                out.push(item);
            for (const child of item.children)
                all(child, name, out);
            return out;
        }

        function button(name, index) {
            wait(50);
            const items = all(view, name).filter(b => b.parent && b.parent.parent && b.parent.parent.visible);
            return items[index || 0];
        }

        function test_copy_button_copies_code() {
            view.editor.load("antes\n\n```js\nconst a = 1;\nlet b = 2;\n```\n\nfin\n");
            const copy = button("codeCopyButton");
            verify(copy);
            mouseClick(copy);
            clipboardReader.text = "";
            clipboardReader.paste();
            compare(clipboardReader.text, "const a = 1;\nlet b = 2;");
            compare(copy.iconName, "check");
        }

        function test_delete_button_removes_block() {
            view.editor.load("antes\n\n```py\nuno\n```\n\nfin\n");
            const del = button("codeDeleteButton");
            verify(del);
            mouseClick(del);
            wait(50);
            compare(view.editor.code.blocks.length, 0);
            verify(md().indexOf("```") < 0);
            verify(md().indexOf("uno") < 0);
            verify(md().indexOf("antes") >= 0 && md().indexOf("fin") >= 0);
        }

        function test_delete_second_of_two_blocks() {
            view.editor.load("```py\nuno\n```\n\n```js\ndos\n```\n");
            compare(view.editor.code.blocks.length, 2);
            const del = button("codeDeleteButton", 1);
            mouseClick(del);
            wait(50);
            compare(view.editor.code.blocks.length, 1);
            compare(view.editor.code.text(0), "uno");
        }

        function test_language_chip_opens_menu_and_changes_language() {
            view.editor.load("```\nx\n```\n\nfin\n");
            const chip = button("codeLanguageChip");
            verify(chip);
            mouseClick(chip);
            wait(50);
            const menu = all(view, "codeLanguageMenu")[0];
            verify(menu && menu.open);
            menu.choose("python");
            wait(50);
            verify(md().indexOf("```python") >= 0 || md().indexOf("```py") >= 0);
        }
    }
}
