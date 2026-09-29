pragma Singleton
import QtQuick

QtObject {
    readonly property real spacingXS: 4
    readonly property real spacingS: 8
    readonly property real spacingM: 12
    readonly property real spacingL: 16
    readonly property real cornerRadius: 12
    readonly property real fontSizeSmall: 12
    readonly property real fontSizeLarge: 16
    readonly property int iconSize: 24
    readonly property color primary: "#aed500"
    readonly property color primaryHoverLight: "#20aed500"
    readonly property color background: "#12140c"
    readonly property color surfaceContainer: "#1e2016"
    readonly property color surfaceText: "#e2e4cf"
    readonly property color surfaceTextMedium: "#c6c8b4"
    readonly property color surfaceVariantText: "#c6c8b4"
    readonly property color outline: "#909380"
    readonly property color outlineMedium: "#454839"
    readonly property color error: "#ffb4ab"
    readonly property color floatingWindowNestedSurface: "#222418"

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
}
