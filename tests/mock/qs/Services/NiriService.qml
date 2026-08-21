pragma Singleton
import QtQuick
QtObject {
    property var allWorkspaces: []
    property var windows: []
    function switchToWorkspace(id) { console.log("MOCK niri switchToWorkspace", id) }
}
