import QtQuick
import qs.Common
import qs.Widgets
import "../editor"

Rectangle {
    id: root

    readonly property alias editor: editor

    signal edited

    function syntax(hue) {
        return Qt.tint(hue, Theme.withAlpha(Theme.primary, 0.12));
    }

    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceText, 0.03)
    border.width: 1
    border.color: Theme.outlineMedium

    DankFlickable {
        id: flick

        property real savedY: 0

        function ensureVisible(r) {
            if (contentY >= r.y)
                contentY = r.y;
            else if (contentY + height <= r.y + r.height)
                contentY = r.y + r.height - height;
        }

        anchors.fill: parent
        anchors.margins: Theme.spacingM
        anchors.leftMargin: Theme.spacingM - editor.leftPadding
        anchors.rightMargin: Theme.spacingM - editor.rightPadding
        contentWidth: width
        contentHeight: editor.contentHeight + Theme.spacingL
        clip: true

        MarkdownEditor {
            id: editor
            width: flick.width
            height: Math.max(flick.height, contentHeight)
            focus: true
            color: Theme.surfaceText
            selectionColor: Theme.primary
            selectionTextColor: Theme.background
            decorationBackground: Qt.tint(Theme.surfaceContainer, root.color)
            tableBorderColor: Qt.tint(decorationBackground, Theme.withAlpha(Theme.outline, 0.75))
            accentColor: Theme.primary
            checkMarkColor: Theme.background
            leftPadding: Theme.spacingS
            rightPadding: Theme.spacingS
            codeBackground: Qt.tint(decorationBackground, Theme.withAlpha(Theme.surfaceText, 0.05))
            codeColors: ({
                    keyword: root.syntax("#c792ea"),
                    string: root.syntax("#e5c07b"),
                    comment: Theme.outline,
                    number: root.syntax("#f78c6c"),
                    type: root.syntax("#56b6c2"),
                    function: root.syntax("#61afef")
                })
            font.family: sourceMode ? SettingsData.monoFontFamily : SettingsData.fontFamily
            font.pixelSize: (SettingsData.notepadFontSize || 14) * (SettingsData.fontScale || 1)
            onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
            onEdited: root.edited()
            onRewriteStarted: flick.savedY = flick.contentY
            onRewriteFinished: flick.contentY = Math.min(flick.savedY, Math.max(0, flick.contentHeight - flick.height))

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: eventPoint => {
                    const hit = editor.isMarkerHit(eventPoint.position.x, eventPoint.position.y);
                    if (hit >= 0)
                        editor.toggleTaskAt(hit);
                }
            }

            StyledText {
                x: editor.leftPadding
                visible: editor.length === 0 && !editor.sourceMode
                text: "Escribe… o / para insertar bloques"
                color: Theme.surfaceVariantText
                font.pixelSize: editor.font.pixelSize
                opacity: 0.6
            }

            TableResizeHandles {
                editor: editor
            }

            TableToolbar {
                editor: editor
            }

            Repeater {
                model: editor.code.blocks

                delegate: CodeBlockBar {
                    editor: root.editor
                    onLanguageRequested: (index, lang, anchor) => languageMenu.show(index, lang, anchor.mapToItem(root, 0, 0, anchor.width, anchor.height))
                }
            }
        }
    }

    CodeLanguageMenu {
        id: languageMenu
        editor: editor
    }

    SlashMenu {
        editor: editor
        caret: {
            if (!editor.slash.active)
                return Qt.rect(0, 0, 0, 0);
            flick.contentY;
            const r = editor.cursorRectangle;
            return editor.mapToItem(root, r.x, r.y, r.width, r.height);
        }
    }
}
