import QtQuick
import Quickshell.Hyprland

// Frightened mode arming has to change what is actually on screen, not just the
// property behind it. A Shape rebuilds on a geometry change and a fillColor swap
// is not one, so a ghost standing still can keep its old colour while its value
// is already correct - which is exactly the bug this guards. run.sh renders this
// twice, before and after the effect arms, and reads the ghost's pixel.
Rectangle {
    id: harness
    width: 240
    height: 60
    color: "#000000"

    PacmanWorkspacesUT {
        id: widget
        x: 0
        y: 0
        barThickness: 48
        pluginData: ({
                "workspaceCount": 4,
                "perMonitor": false,
                "animations": true,
                "frightenedGhosts": true
            })
    }

    function setFocus(ids, focused) {
        Hyprland.workspaces.values = ids.map(i => ({
                    "id": i, "name": String(i), "urgent": false,
                    "monitor": { "name": "DP-1" }
                }));
        Hyprland.monitors.values = [{ "name": "DP-1", "activeWorkspace": { "id": focused } }];
        Hyprland.focusedWorkspace = { "id": focused };
    }

    // Start on ws3 so slots 1 and 2 are ghosts.
    Component.onCompleted: setFocus([1, 2, 3, 4], 3)

    // Ghost starts in its own colour, then the effect arms.
    Timer {
        interval: 500
        running: true
        onTriggered: {
            harness.setFocus([1, 2, 3, 4], 2);   // moved back -> frightened
            console.log("frightened =", widget.frightened,
                        " cellSize =", widget.cellSize);
        }
    }
}
