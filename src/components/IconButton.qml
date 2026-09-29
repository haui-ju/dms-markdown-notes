import QtQuick
import qs.Common
import qs.Widgets

DankActionButton {
    property bool highlighted: false

    iconSize: Theme.iconSize - 4
    iconColor: highlighted ? Theme.primary : Theme.surfaceText
}
