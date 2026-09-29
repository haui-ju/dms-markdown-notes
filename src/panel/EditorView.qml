import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import "../editor"

Rectangle {
    id: root

    readonly property alias editor: editor

    signal edited

    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceText, 0.03)
    border.width: 1
    border.color: Theme.outlineMedium

    Flickable {
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
        contentWidth: width
        contentHeight: editor.contentHeight + Theme.spacingL
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        MarkdownEditor {
            id: editor
            width: flick.width
            height: Math.max(flick.height, contentHeight)
            focus: true
            color: Theme.surfaceText
            selectionColor: Theme.primary
            selectedTextColor: Theme.background
            decorationBackground: Qt.tint(Theme.surfaceContainer, root.color)
            tableBorderColor: Qt.tint(decorationBackground, Theme.withAlpha(Theme.outline, 0.75))
            accentColor: Theme.primary
            checkMarkColor: Theme.background
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
        }
    }

    SlashMenu {
        editor: editor
        caret: {
            flick.contentY;
            const r = editor.cursorRectangle;
            return editor.mapToItem(root, r.x, r.y, r.width, r.height);
        }
    }
}
