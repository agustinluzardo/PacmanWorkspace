pragma Singleton
import QtQuick
QtObject {
    property bool isHyprland: true
    property bool isNiri: false
    property bool compositorDetected: true
    function getScreenScale(screen) { return 1 }
}
