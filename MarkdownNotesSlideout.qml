import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    property var pluginData: ({})
    readonly property int panelWidth: Math.max(280, Number(pluginData.panelWidth) || 500)
    readonly property bool fromLeft: (pluginData.side || "left") === "left"
    readonly property real edgeGap: {
        const g = SettingsData.notepadEffectiveEdgeGap;
        return typeof g === "number" ? g : Theme.spacingS;
    }

    property bool isVisible: false
    property bool mapped: false
    property bool sourceMode: false
    property bool confirmDelete: false

    function show(screenName) {
        const target = Quickshell.screens.find(s => s.name === screenName) || CompositorService.getFocusedScreen();
        if (target && !mapped)
            screen = target;
        mapped = true;
        isVisible = true;
        if (!store.currentPath)
            store.openMostRecent();
        Qt.callLater(() => editor.forceActiveFocus());
    }

    function hide() {
        flushSave();
        confirmDelete = false;
        isVisible = false;
    }

    function toggle(screenName) {
        if (isVisible)
            hide();
        else
            show(screenName);
    }

    function newNote() {
        flushSave();
        if (!isVisible)
            show("");
        store.create();
        Qt.callLater(() => editor.forceActiveFocus());
    }

    function flushSave() {
        if (saveTimer.running) {
            saveTimer.stop();
            store.save(editor.markdown());
        }
    }

    visible: mapped
    color: "transparent"

    anchors.top: true
    anchors.bottom: true
    anchors.left: fromLeft
    anchors.right: !fromLeft

    implicitWidth: panelWidth + edgeGap * 2

    WlrLayershell.namespace: "dms:plugin:markdown-notes"
    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: isVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        item: surface
    }

    NotesStore {
        id: store
        notesDir: root.pluginData.notesDir || "~/Notes"
        onNoteLoaded: content => {
            editor.load(content);
            root.confirmDelete = false;
        }
        onExternalChange: content => {
            if (saveTimer.running)
                return;
            const pos = editor.cursorPosition;
            editor.load(content);
            editor.cursorPosition = Math.min(pos, editor.length);
        }
    }

    Timer {
        id: saveTimer
        interval: 700
        onTriggered: store.save(editor.markdown())
    }

    Shortcut {
        sequence: "Ctrl+N"
        onActivated: root.newNote()
    }

    Shortcut {
        sequence: "Ctrl+S"
        onActivated: {
            saveTimer.stop();
            store.save(editor.markdown());
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+M"
        onActivated: sourceButton.clicked()
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.hide()
    }

    Item {
        id: slideArea
        anchors.fill: parent
        anchors.margins: root.edgeGap
        clip: true

        Rectangle {
            id: surface

            property real offset: root.isVisible ? 0 : (root.fromLeft ? -width - root.edgeGap : width + root.edgeGap)

            width: parent.width
            height: parent.height
            x: offset
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainer, Theme.notepadTransparency)
            border.width: 0

            // Ease without overshoot so the panel never bounces back into view.
            Behavior on offset {
                NumberAnimation {
                    id: slideAnim
                    duration: 260
                    easing.type: root.isVisible ? Easing.OutCubic : Easing.InCubic
                    onRunningChanged: {
                        if (!running && !root.isVisible)
                            root.mapped = false;
                    }
                }
            }

            Column {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingS

                Row {
                    width: parent.width
                    height: 32

                    StyledText {
                        width: parent.width - buttons.width
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Notas"
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    Row {
                        id: buttons
                        spacing: Theme.spacingXS

                        DankActionButton {
                            iconName: "add"
                            tooltipText: "Nueva nota (Ctrl+N)"
                            onClicked: root.newNote()
                        }

                        DankActionButton {
                            id: sourceButton
                            iconName: root.sourceMode ? "visibility" : "code"
                            tooltipText: root.sourceMode ? "Ver formateado (Ctrl+Shift+M)" : "Ver Markdown (Ctrl+Shift+M)"
                            onClicked: {
                                root.sourceMode = !root.sourceMode;
                                editor.setSourceMode(root.sourceMode);
                                editor.forceActiveFocus();
                            }
                        }

                        DankActionButton {
                            iconName: "folder_open"
                            tooltipText: "Abrir carpeta de notas"
                            onClicked: Quickshell.execDetached(["xdg-open", store.dir])
                        }

                        DankActionButton {
                            iconName: "close"
                            tooltipText: "Cerrar (Esc)"
                            onClicked: root.hide()
                        }
                    }
                }

                ListView {
                    id: tabs
                    width: parent.width
                    height: 30
                    orientation: ListView.Horizontal
                    spacing: Theme.spacingXS
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: store.model

                    delegate: Rectangle {
                        required property string fileName
                        required property string fileBaseName
                        required property string filePath

                        readonly property bool active: filePath === store.currentPath

                        height: tabs.height
                        width: Math.min(160, tabLabel.implicitWidth + Theme.spacingM * 2)
                        radius: height / 2
                        color: active ? Theme.withAlpha(Theme.primary, 0.22) : (tabMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent")
                        border.width: 1
                        border.color: active ? Theme.withAlpha(Theme.primary, 0.5) : Theme.withAlpha(Theme.surfaceText, 0.12)

                        StyledText {
                            id: tabLabel
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.width - Theme.spacingM * 2)
                            elide: Text.ElideRight
                            text: fileBaseName
                            font.pixelSize: Theme.fontSizeSmall
                            color: active ? Theme.primary : Theme.surfaceText
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (active)
                                    return;
                                root.flushSave();
                                store.open(filePath);
                                editor.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: editorFrame
                anchors.top: header.bottom
                anchors.bottom: footer.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingL
                anchors.topMargin: Theme.spacingM
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceText, 0.03)
                border.width: 1
                border.color: Theme.withAlpha(Theme.surfaceText, 0.08)

                Flickable {
                    id: flick
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    contentWidth: width
                    contentHeight: editor.contentHeight + Theme.spacingL
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    property real savedY: 0

                    function ensureVisible(r) {
                        if (contentY >= r.y)
                            contentY = r.y;
                        else if (contentY + height <= r.y + r.height)
                            contentY = r.y + r.height - height;
                    }

                    MarkdownEditor {
                        id: editor
                        width: flick.width
                        height: Math.max(flick.height, contentHeight)
                        focus: true
                        color: Theme.surfaceText
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.background
                        font.family: SettingsData.notepadUseMonospace ? SettingsData.monoFontFamily : (SettingsData.notepadFontFamily || SettingsData.fontFamily)
                        font.pixelSize: (SettingsData.notepadFontSize || 14) * (SettingsData.fontScale || 1)
                        onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                        onEdited: saveTimer.restart()
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
                            text: "Escribe…  # título, - lista, [] tarea, **negrita**"
                            color: Theme.surfaceVariantText
                            font.pixelSize: editor.font.pixelSize
                            opacity: 0.6
                        }
                    }
                }
            }

            Row {
                id: footer
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingL
                height: 32
                spacing: Theme.spacingS

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - deleteRow.width - parent.spacing
                    elide: Text.ElideMiddle
                    text: {
                        const state = saveTimer.running ? "Sin guardar" : "Guardado";
                        return store.currentName + "  ·  " + state;
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: saveTimer.running ? Theme.warning : Theme.surfaceVariantText
                }

                Row {
                    id: deleteRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    StyledText {
                        visible: root.confirmDelete
                        anchors.verticalCenter: parent.verticalCenter
                        text: "¿Mover a la papelera?"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.error
                    }

                    DankActionButton {
                        visible: root.confirmDelete
                        iconName: "check"
                        iconColor: Theme.error
                        tooltipText: "Sí, borrar"
                        onClicked: {
                            root.confirmDelete = false;
                            saveTimer.stop();
                            store.trash(store.currentPath);
                        }
                    }

                    DankActionButton {
                        visible: root.confirmDelete
                        iconName: "close"
                        tooltipText: "Cancelar"
                        onClicked: root.confirmDelete = false
                    }

                    DankActionButton {
                        visible: !root.confirmDelete
                        iconName: "delete"
                        tooltipText: "Borrar nota"
                        enabled: store.currentPath !== ""
                        onClicked: root.confirmDelete = true
                    }
                }
            }
        }
    }
}
