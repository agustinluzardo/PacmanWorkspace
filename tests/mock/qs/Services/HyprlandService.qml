pragma Singleton
import QtQuick
QtObject {
    property var lastFocused: null
    function focusWorkspace(w) { lastFocused = w; console.log("MOCK focusWorkspace", w) }
}
