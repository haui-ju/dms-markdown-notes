pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import qs.Widgets
import "../components"
import "../store"
import "../store/search.js" as Search

PopupSurface {
    id: root

    property alias dir: search.dir
    property int currentIndex: 0
    readonly property var results: search.results
    readonly property string status: {
        if (search.tooShort)
            return "Escribe al menos " + Search.MIN_QUERY + " letras";
        if (search.busy && search.resultsQuery !== search.query.trim())
            return "Buscando…";
        if (results.length === 0)
            return search.listingTags ? "No hay etiquetas" : "Sin resultados";
        return "";
    }

    signal picked(string path, int line, string query)

    height: field.height + Theme.spacingS * 3 + Math.min(list.contentHeight, 320) + (status !== "" ? hint.implicitHeight + Theme.spacingS : 0)

    function open(text) {
        if (text !== undefined)
            field.text = text;
        field.forceActiveFocus();
        if (text === undefined)
            field.selectAll();
        else
            field.cursorPosition = field.text.length;
        search.refresh();
    }

    function move(step) {
        if (results.length > 0)
            currentIndex = (currentIndex + step + results.length) % results.length;
    }

    function pick(index) {
        const item = results[index];
        if (!item)
            return;
        if (item.tag !== undefined)
            open("#" + item.tag);
        else
            picked(item.path, item.line, search.resultsQuery);
    }

    onResultsChanged: currentIndex = 0

    NoteSearch {
        id: search
    }

    Item {
        id: keys
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                root.move(event.key === Qt.Key_Down ? 1 : -1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.pick(root.currentIndex);
                event.accepted = true;
            }
        }
    }

    DankTextField {
        id: field
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingS
        leftIconName: "search"
        placeholderText: "Buscar en las notas (# para etiquetas)"
        showClearButton: true
        keyForwardTargets: [keys]
        onTextChanged: search.search(text)
    }

    StyledText {
        id: hint
        visible: root.status !== ""
        anchors.top: field.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingS
        horizontalAlignment: Text.AlignHCenter
        text: root.status
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    ListView {
        id: list
        anchors.top: field.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingS
        clip: true
        visible: root.status === ""
        model: root.results
        currentIndex: root.currentIndex
        highlightFollowsCurrentItem: false
        boundsBehavior: Flickable.StopAtBounds
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool active: index === root.currentIndex || mouse.containsMouse

            width: list.width
            height: column.implicitHeight + Theme.spacingS * 2
            radius: Theme.cornerRadius
            color: active ? Theme.primaryHoverLight : "transparent"

            Column {
                id: column
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                spacing: 2

                StyledText {
                    width: parent.width
                    text: row.modelData.tag !== undefined ? "#" + row.modelData.tag : (row.modelData.folder ? row.modelData.folder + "/" : "") + row.modelData.title
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: row.modelData.tag !== undefined ? Theme.primary : Theme.surfaceText
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    visible: row.modelData.tag !== undefined
                    text: row.modelData.count + (row.modelData.count === 1 ? " nota" : " notas")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    width: parent.width
                    visible: row.modelData.tag === undefined
                    textFormat: Text.StyledText
                    text: visible ? Search.highlight(row.modelData.text, search.resultsQuery, Theme.primary.toString(), 60) : ""
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pick(row.index)
            }
        }
    }
}
