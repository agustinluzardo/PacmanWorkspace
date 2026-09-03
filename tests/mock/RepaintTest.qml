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

    // The focus has to settle before the move back, or the two changes coalesce
    // into one and nothing has moved backwards at all.
    Timer {
        interval: 150
        running: true
        onTriggered: harness.setFocus([1, 2, 3, 4], 4)
    }

    // Reports whether the pointer actually reached a cell, so a test that thinks
    // it is exercising hover cannot quietly be exercising nothing.
    function hoveredCells(node, out) {
        for (let i = 0; i < node.children.length; i++) {
            const c = node.children[i];
            if (c.hovered === true)
                out.push(c.index);
            harness.hoveredCells(c, out);
        }
        return out;
    }

    Timer {
        interval: 800
        running: true
        onTriggered: console.log("hovered cells:", JSON.stringify(harness.hoveredCells(widget, [])))
    }

    Timer {
        interval: 500
        running: true
        onTriggered: {
            harness.setFocus([1, 2, 3, 4], 3);   // moved back -> frightened, slots 0,1 are ghosts
            console.log("frightenedEnabled =", widget.frightenedEnabled,
                        " previousFocusedId =", widget.previousFocusedId,
                        " focusedWorkspaceId =", widget.focusedWorkspaceId,
                        " frightened =", widget.frightened,
                        " ghosts =", widget.visibleGhostCount);
        }
    }
}
