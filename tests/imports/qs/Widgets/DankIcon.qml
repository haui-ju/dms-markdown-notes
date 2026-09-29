import QtQuick

Text {
    property string name
    property real size: 12

    text: name
    font.pixelSize: size
}
