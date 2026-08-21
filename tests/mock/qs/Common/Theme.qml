pragma Singleton
import QtQuick
QtObject {
    readonly property int shortDuration: 150
    readonly property int mediumDuration: 250
    readonly property int standardEasing: Easing.OutCubic
    readonly property color surfaceText: "#e6e8ec"
    readonly property color surfaceVariantText: "#8b919c"
    readonly property color surfaceTextHover: Qt.rgba(0.9, 0.91, 0.93, 0.08)
    readonly property color outline: "#3a3f4a"
    readonly property real fontScale: 1.0
    readonly property real fontSizeSmall: Math.round(fontScale * 12)
    readonly property real fontSizeMedium: Math.round(fontScale * 14)
    readonly property real fontSizeLarge: Math.round(fontScale * 16)
    readonly property real spacingXS: 4
    readonly property real spacingS: 8
    readonly property real spacingM: 12
    readonly property real cornerRadius: 12
    function snap(value, dpr) { const s = dpr || 1; return Math.round(value * s) / s }
    function hoverTint(base) { return Qt.lighter(base, 1.2) }
    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
}
