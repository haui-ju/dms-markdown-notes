pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Common
import qs.Modals.Common
import qs.Widgets
import "../components"

DankModal {
    id: root

    property string url: ""
    property string title: ""
    property int position: -1
    property bool removable: false
    property bool confirmRemove: false
    readonly property string path: url.indexOf("file://") === 0 ? decodeURIComponent(url.substring(7)) : ""
    readonly property real headerHeight: 48
    property size naturalSize: Qt.size(640, 400)
    readonly property real maxWidth: screenWidth * 0.9
    readonly property real maxHeight: screenHeight * 0.9 - headerHeight
    readonly property real fitScale: Math.min(1, maxWidth / naturalSize.width, maxHeight / naturalSize.height)

    signal removeRequested(int position, string path)

    function show(pos, imageUrl, label, canRemove) {
        position = pos;
        url = imageUrl;
        title = label;
        removable = canRemove;
        confirmRemove = false;
        open();
    }

    layerNamespace: "dms:markdown-notes-image"
    allowStacking: true
    useOverlayLayer: true
    modalWidth: Math.max(360, naturalSize.width * fitScale + Theme.spacingM * 2)
    modalHeight: naturalSize.height * fitScale + headerHeight + Theme.spacingM
    onBackgroundClicked: close()
    onOpened: Qt.callLater(() => modalFocusScope.forceActiveFocus())

    content: Component {
        Item {
            anchors.fill: parent

            Item {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.headerHeight

                DankIcon {
                    id: headerIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    name: "image"
                    size: Theme.iconSize - 2
                    color: Theme.primary
                }

                StyledText {
                    anchors.left: headerIcon.right
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: actions.left
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.title
                    elide: Text.ElideMiddle
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                Row {
                    id: actions
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    IconButton {
                        visible: root.path !== ""
                        iconName: "open_in_new"
                        tooltipText: "Abrir con otra aplicación"
                        onClicked: {
                            Quickshell.execDetached(["xdg-open", root.path]);
                            root.close();
                        }
                    }

                    IconButton {
                        visible: root.path !== ""
                        iconName: "folder_open"
                        tooltipText: "Abrir carpeta"
                        onClicked: {
                            Quickshell.execDetached(["xdg-open", root.path.substring(0, root.path.lastIndexOf("/"))]);
                            root.close();
                        }
                    }

                    IconButton {
                        visible: root.removable
                        iconName: root.confirmRemove ? "delete_forever" : "delete"
                        iconColor: Theme.error
                        tooltipText: root.confirmRemove ? "Pulsa otra vez para eliminar" : "Eliminar imagen"
                        onClicked: {
                            if (!root.confirmRemove) {
                                root.confirmRemove = true;
                                return;
                            }
                            root.removeRequested(root.position, root.path);
                            root.close();
                        }
                    }

                    IconButton {
                        iconName: "close"
                        tooltipText: "Cerrar"
                        onClicked: root.close()
                    }
                }
            }

            Image {
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.spacingM
                anchors.topMargin: 0
                source: root.url
                fillMode: Image.PreserveAspectFit
                asynchronous: false
                onStatusChanged: {
                    if (status === Image.Ready && implicitWidth > 0 && implicitHeight > 0)
                        root.naturalSize = Qt.size(implicitWidth, implicitHeight);
                }
                smooth: true
                mipmap: true
            }
        }
    }
}
