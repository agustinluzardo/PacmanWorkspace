pragma Singleton
import QtQuick

// Mirrors the shape of Quickshell's Hyprland singleton closely enough to
// exercise every binding in the widget: ObjectModel-ish `values` lists that
// emit valuesChanged, a rawEvent signal, and refresh* invokables.
QtObject {
    id: hypr

    property QtObject workspaces: QtObject { property var values: [] }
    property QtObject monitors:   QtObject { property var values: [] }
    property QtObject toplevels:  QtObject { property var values: [] }

    property var focusedWorkspace: null
    property var focusedMonitor: null

    signal rawEvent(var event)

    property int refreshWorkspacesCalls: 0
    property int refreshMonitorsCalls: 0
    property int refreshToplevelsCalls: 0

    function refreshWorkspaces() { refreshWorkspacesCalls++ }
    function refreshMonitors() { refreshMonitorsCalls++ }
    function refreshToplevels() { refreshToplevelsCalls++ }
    function dispatch(req) { console.log("MOCK dispatch", req) }
}
