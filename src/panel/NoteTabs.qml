pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import "../components"
import "./logic/tab_order.js" as TabOrder

Item {
    id: root

    required property var store
    property bool dirty: false
    property int editingIndex: -1
    property Item dragHost: null
    property int dragSourceIndex: -1
    property int dragTargetIndex: -1
    property bool dragActive: false
    property bool suppressTabClick: false
    property int pressIndex: -1
    property bool vertical: false
    property int navWidth: 188
    property bool overflowOpen: false

    readonly property int horizontalSlots: TabOrder.visibleSlotCount(store.tabs.length)
    readonly property var shownTabs: vertical ? store.tabs : store.tabs.slice(0, horizontalSlots)
    readonly property var overflowTabs: vertical ? [] : store.tabs.slice(horizontalSlots)

    signal switchRequested(int index)
    signal closeRequested(int index)
    signal renameRequested(int index, string title)
    signal newRequested
    signal editingFinished

    readonly property real tabWidth: {
        if (vertical)
            return Math.max(120, tabScroll.width - Theme.spacingS * 2);
        const slots = horizontalSlots;
        const raw = (tabScroll.width - (slots - 1) * Theme.spacingXS) / slots;
        return Math.max(72, raw);
    }

    width: vertical ? navWidth : undefined
    height: vertical ? undefined : 36
    z: 0
    clip: vertical && !dragActive

    onVerticalChanged: {
        if (vertical)
            overflowOpen = false;
    }

    onDragActiveChanged: {
        if (dragActive && !vertical)
            overflowOpen = true;
    }

    function cancelTabDrag() {
        dragActive = false;
        dragSourceIndex = -1;
        dragTargetIndex = -1;
        pressIndex = -1;
        suppressTabClick = false;
    }

    function dropIndexAt(rootX, rootY) {
        const n = store.tabs.length;
        if (n <= 1)
            return -1;
        const spacing = Theme.spacingXS;
        const th = 32;
        if (vertical) {
            const pt = vertTabColumn.mapFromItem(root, rootX, rootY);
            if (pt.y >= 0 && pt.y < vertTabColumn.height + spacing)
                return TabOrder.stripDropIndex(pt.x, pt.y, true, n, tabWidth, th, spacing);
            return -1;
        }
        const inScroll = tabScroll.mapFromItem(root, rootX, rootY);
        if (inScroll.x >= 0 && inScroll.y >= 0 && inScroll.x < tabScroll.width && inScroll.y < tabScroll.height) {
            const ptRow = horizTabRow.mapFromItem(root, rootX, rootY);
            return TabOrder.stripDropIndex(ptRow.x, ptRow.y, false, n, tabWidth, th, spacing);
        }
        if (!overflowOpen || n <= horizontalSlots)
            return -1;
        const stripTL = tabScroll.mapToItem(root, 0, 0);
        const popupTL = overflowPopup.mapToItem(root, 0, 0);
        const listTL = overflowColumn.mapToItem(root, 0, 0);
        return TabOrder.pickDropIndex({
            tabCount: n,
            px: rootX,
            py: rootY,
            vertical: false,
            tabWidth: tabWidth,
            tabHeight: th,
            spacing: spacing,
            horizontalSlots: horizontalSlots,
            strip: { x: stripTL.x, y: stripTL.y, w: tabScroll.width, h: tabScroll.height },
            overflow: {
                open: true,
                x: popupTL.x,
                y: popupTL.y,
                w: overflowPopup.width,
                h: overflowPopup.height,
                listY: listTL.y
            }
        });
    }

    function startTabDrag(index) {
        if (editingIndex >= 0)
            return;
        dragActive = true;
        dragSourceIndex = index;
        dragTargetIndex = index;
        pressIndex = index;
    }

    function handleDragMove(rootX, rootY) {
        if (!dragActive || dragSourceIndex < 0)
            return;
        const target = dropIndexAt(rootX, rootY);
        if (target >= 0)
            dragTargetIndex = target;
    }

    function endTabDrag(rootX, rootY) {
        const wasDrag = dragActive;
        if (wasDrag && dragSourceIndex >= 0) {
            if (rootX !== undefined && rootY !== undefined)
                handleDragMove(rootX, rootY);
            if (dragTargetIndex >= 0 && dragTargetIndex !== dragSourceIndex)
                store.moveTab(dragSourceIndex, dragTargetIndex);
        }
        suppressTabClick = wasDrag;
        dragActive = false;
        dragSourceIndex = -1;
        dragTargetIndex = -1;
        pressIndex = -1;
    }

    component TabChrome: Item {
        id: chrome

        required property string path
        required property int storeIndex
        property bool inOverflow: false

        readonly property bool isActive: root.store.currentIndex === storeIndex
        readonly property bool editing: root.editingIndex === storeIndex
        readonly property bool isPinned: root.store.pinned.indexOf(path) >= 0
        readonly property bool isDragging: root.dragActive && root.dragSourceIndex === storeIndex
        readonly property bool isDropHint: root.dragActive && root.dragTargetIndex === storeIndex && !isDragging
        property bool contextOpen: false

        width: inOverflow ? parent.width : root.tabWidth
        height: 32
        opacity: isDragging ? 0.45 : 1

        Rectangle {
            id: bg
            anchors.fill: parent
            radius: Theme.cornerRadius
            color: chrome.isActive ? Theme.primaryPressed : (bodyMouse.containsMouse && !closeMouse.containsMouse ? Theme.primaryHoverLight : "transparent")
            border.width: chrome.isDropHint ? 2 : (chrome.isActive ? 0 : 1)
            border.color: chrome.isDropHint ? Theme.primary : Theme.outlineMedium
            z: 0
        }

        Row {
            id: body
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            spacing: Theme.spacingXS
            z: 1

            StyledText {
                visible: !chrome.editing
                width: parent.width - closeButton.width - Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                text: (chrome.isActive && root.dirty ? "● " : "") + root.store.labelOf(chrome.path)
                font.pixelSize: Theme.fontSizeSmall
                font.weight: chrome.isActive ? Font.Medium : Font.Normal
                color: chrome.isActive ? Theme.primary : Theme.surfaceText
                elide: Text.ElideMiddle
                maximumLineCount: 1
                wrapMode: Text.NoWrap
            }

            DankTextField {
                id: renameField
                visible: chrome.editing
                enabled: chrome.editing
                width: parent.width - closeButton.width - Theme.spacingXS
                height: parent.height
                font.pixelSize: Theme.fontSizeSmall
                textColor: Theme.primary
                backgroundColor: "transparent"
                borderWidth: 0
                focusedBorderWidth: 0
                topPadding: 0
                bottomPadding: 0
                onEditingFinished: {
                    if (root.editingIndex === chrome.storeIndex)
                        root.renameRequested(chrome.storeIndex, text);
                    root.editingIndex = -1;
                    root.editingFinished();
                }
                onVisibleChanged: {
                    if (!visible)
                        return;
                    text = root.store.titleOf(chrome.path);
                    renameFocus.restart();
                }

                Timer {
                    id: renameFocus
                    interval: 20
                    onTriggered: {
                        renameField.forceActiveFocus();
                        renameField.selectAll();
                    }
                }
            }

            Rectangle {
                id: closeButton
                width: 20
                height: 20
                radius: Theme.cornerRadius
                anchors.verticalCenter: parent.verticalCenter
                visible: !chrome.editing
                color: closeMouse.containsMouse ? Theme.surfaceTextHover : "transparent"

                DankIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 14
                    color: Theme.surfaceTextMedium
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    z: 10
                    onClicked: root.closeRequested(chrome.storeIndex)
                }
            }
        }

        MouseArea {
            id: bodyMouse
            anchors.fill: parent
            anchors.rightMargin: closeButton.width + Theme.spacingM
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            enabled: !chrome.editing && !root.dragActive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            z: 2
            property real pressX: 0
            property real pressY: 0

            onClicked: mouse => {
                if (root.suppressTabClick) {
                    root.suppressTabClick = false;
                    return;
                }
                if (mouse.button === Qt.RightButton) {
                    chrome.contextOpen = true;
                    return;
                }
                if (!chrome.isActive)
                    root.switchRequested(chrome.storeIndex);
                if (chrome.inOverflow)
                    root.overflowOpen = false;
            }
            onDoubleClicked: {
                if (!chrome.isActive)
                    root.switchRequested(chrome.storeIndex);
                root.editingIndex = chrome.storeIndex;
            }
            onPressed: mouse => {
                if (mouse.button === Qt.RightButton)
                    return;
                pressX = mouse.x;
                pressY = mouse.y;
                root.pressIndex = chrome.storeIndex;
            }
            onPositionChanged: mouse => {
                if ((mouse.buttons & Qt.LeftButton) === 0)
                    return;
                if (root.pressIndex !== chrome.storeIndex || root.dragActive)
                    return;
                if (Math.hypot(mouse.x - pressX, mouse.y - pressY) < 8)
                    return;
                root.startTabDrag(chrome.storeIndex);
                const p = chrome.mapToItem(root, mouse.x, mouse.y);
                root.handleDragMove(p.x, p.y);
            }
            onReleased: {
                if (!root.dragActive)
                    root.pressIndex = -1;
            }
        }

        PopupSurface {
            visible: chrome.contextOpen
            x: 0
            y: chrome.height + Theme.spacingXS
            width: 190
            height: contextColumn.implicitHeight + Theme.spacingS * 2
            z: 20

            Column {
                id: contextColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingXS
                MenuRow {
                    width: parent.width
                    icon: "push_pin"
                    label: chrome.isPinned ? "Desfijar" : "Fijar a la izquierda"
                    onTriggered: {
                        root.store.togglePinned(chrome.path);
                        chrome.contextOpen = false;
                    }
                }
            }
        }
    }

    MouseArea {
        id: dragLayer
        parent: root.dragHost ? root.dragHost : root
        anchors.fill: parent
        enabled: root.dragActive
        z: 500
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        preventStealing: true
        propagateComposedEvents: false
        onPositionChanged: mouse => {
            const p = dragLayer.mapToItem(root, mouse.x, mouse.y);
            root.handleDragMove(p.x, p.y);
        }
        onReleased: mouse => {
            const p = dragLayer.mapToItem(root, mouse.x, mouse.y);
            root.endTabDrag(p.x, p.y);
        }
        onCanceled: root.endTabDrag()
    }

    ScrollView {
        id: tabScroll
        x: 0
        y: 0
        width: vertical ? parent.width : parent.width - newTabButton.width
            - (moreButton.visible ? moreButton.width + Theme.spacingXS : 0) - Theme.spacingXS
        height: vertical ? parent.height - newTabButton.height - Theme.spacingXS : parent.height
        clip: true
        ScrollBar.horizontal.visible: false
        ScrollBar.vertical.visible: vertical

        Column {
            id: vertTabColumn
            visible: vertical
            width: tabScroll.width
            spacing: Theme.spacingXS
            Repeater {
                model: root.shownTabs
                delegate: TabChrome {
                    required property int index
                    required property string modelData
                    path: modelData
                    storeIndex: root.store.tabs.indexOf(modelData)
                }
            }
        }

        Row {
            id: horizTabRow
            visible: !vertical
            spacing: Theme.spacingXS
            height: tabScroll.height
            Repeater {
                model: root.shownTabs
                delegate: TabChrome {
                    required property int index
                    required property string modelData
                    path: modelData
                    storeIndex: root.store.tabs.indexOf(modelData)
                }
            }
        }
    }

    Rectangle {
        id: moreButton
        visible: !root.vertical && root.store.tabs.length > 3
        width: 38
        height: 32
        x: parent.width - newTabButton.width - width - Theme.spacingXS
        y: 0
        radius: Theme.cornerRadius
        color: moreMouse.containsMouse ? Theme.surfaceTextHover : "transparent"

        StyledText {
            anchors.centerIn: parent
            text: "+" + root.overflowTabs.length
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
        }

        MouseArea {
            id: moreMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.overflowOpen = !root.overflowOpen
        }
    }

    MouseArea {
        visible: root.overflowOpen && !root.vertical && !root.dragActive
        anchors.fill: parent
        z: 25
        onClicked: root.overflowOpen = false
    }

    PopupSurface {
        id: overflowPopup
        visible: root.overflowOpen && !root.vertical
        x: Math.max(Theme.spacingS, parent.width - width - Theme.spacingS)
        y: moreButton.y + moreButton.height + Theme.spacingXS
        width: Math.min(280, parent.width - Theme.spacingS * 2)
        height: Math.min(320, overflowColumn.implicitHeight + Theme.spacingS * 2)
        color: Theme.surfaceContainer
        z: dragActive ? 520 : 30

        Column {
            id: overflowColumn
            width: parent.width - Theme.spacingS * 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingXS
            spacing: Theme.spacingXS
            Repeater {
                model: root.overflowTabs
                delegate: TabChrome {
                    required property int index
                    required property string modelData
                    width: overflowColumn.width
                    path: modelData
                    storeIndex: root.store.tabs.indexOf(modelData)
                    inOverflow: true
                }
            }
        }
    }

    IconButton {
        id: newTabButton
        x: vertical ? 0 : parent.width - width
        y: vertical ? parent.height - height : 0
        iconName: "add"
        tooltipText: "Nueva nota (Ctrl+N)"
        onClicked: root.newRequested()
    }
}
