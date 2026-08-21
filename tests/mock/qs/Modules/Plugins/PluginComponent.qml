import QtQuick

// Stand-in for the DMS PluginComponent: exposes the same injected properties
// and actually instantiates the horizontal pill so the delegates render.
Item {
    id: root

    property var axis: null
    property string section: "center"
    property var parentScreen: null
    property real widgetThickness: 30
    property real barThickness: 48
    property real barSpacing: 4
    property var barConfig: null
    property var blurBarWindow: null
    property string pluginId: ""
    property var pluginService: null
    property var pluginData: ({})
    property var variants: []

    property Component horizontalBarPill: null
    property Component verticalBarPill: null
    property Component popoutContent: null
    property real popoutWidth: 400
    property real popoutHeight: 0
    property var pillClickAction: null
    property var pillRightClickAction: null

    readonly property bool isVertical: axis?.isVertical ?? false
    readonly property int iconSize: Math.round((barThickness / 48) * (24 - 4))
    readonly property int iconSizeLarge: Math.round((barThickness / 48) * 28)
    readonly property bool effectiveVisible: true

    readonly property alias pillItem: pillLoader.item
    readonly property alias verticalPillItem: vPillLoader.item

    width: pillLoader.item ? pillLoader.item.implicitWidth : 0
    height: pillLoader.item ? pillLoader.item.implicitHeight : 0

    Loader {
        id: pillLoader
        sourceComponent: root.horizontalBarPill
    }

    Loader {
        id: vPillLoader
        visible: false
        sourceComponent: root.verticalBarPill
    }
}
