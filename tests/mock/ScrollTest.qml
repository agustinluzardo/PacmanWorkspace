import QtQuick
import Quickshell.Hyprland
import qs.Services

// The wheel used to debit a notch from its accumulator and then throw the step
// away if it landed inside a 160ms cooldown, so spinning the wheel quickly moved
// one workspace and lost the rest.
Rectangle {
    id: harness
    width: 300
    height: 80
    color: "#12141a"

    property int failures: 0
    property int checks: 0

    PacmanWorkspacesUT {
        id: widget
        anchors.centerIn: parent
        barThickness: 48
        pluginData: ({
                "workspaceCount": 5,
                "perMonitor": false
            })
    }

    function setFocus(ids, focused) {
        Hyprland.workspaces.values = ids.map(i => ({
                    "id": i,
                    "name": String(i),
                    "urgent": false,
                    "monitor": {
                        "name": "DP-1"
                    }
                }));
        Hyprland.monitors.values = [
            {
                "name": "DP-1",
                "activeWorkspace": {
                    "id": focused
                }
            }
        ];
        Hyprland.focusedWorkspace = {
            "id": focused
        };
    }

    function expect(label, actual, wanted) {
        harness.checks++;
        const ok = actual === wanted;
        if (!ok)
            harness.failures++;
        console.log((ok ? "PASS " : "FAIL ") + label + " = " + JSON.stringify(actual) + (ok ? "" : " (expected " + JSON.stringify(wanted) + ")"));
    }

    Component.onCompleted: {
        console.log("=== scrolling ===");
        harness.setFocus([1, 2, 3, 4, 5], 1);

        // Three notches faster than the compositor can answer. Every one has to
        // land, and each has to step from the one before rather than from the
        // stale focus the compositor is still reporting.
        HyprlandService.focusCalls = [];
        widget.stepWorkspace(1);
        widget.stepWorkspace(1);
        widget.stepWorkspace(1);
        harness.expect("three quick notches make three moves", HyprlandService.focusCalls.length, 3);
        harness.expect("and they walk forward one at a time", JSON.stringify(HyprlandService.focusCalls), "[2,3,4]");

        // Reversing mid-spin steps back from where we were heading.
        widget.stepWorkspace(-1);
        harness.expect("scrolling back steps from the pending target", HyprlandService.lastFocused, 3);

        // The compositor catches up to somewhere else entirely (a keybind, say).
        // Once it confirms a workspace we are not heading to, the pending target
        // must not keep overriding reality forever.
        HyprlandService.focusCalls = [];
        widget.pendingFocusNum = 0;
        harness.setFocus([1, 2, 3, 4, 5], 5);
        widget.stepWorkspace(-1);
        harness.expect("with nothing pending it steps from the real focus", HyprlandService.lastFocused, 4);

        // The ends of the strip are walls, not wraps.
        widget.pendingFocusNum = 0;
        harness.setFocus([1, 2, 3, 4, 5], 1);
        HyprlandService.focusCalls = [];
        widget.stepWorkspace(-1);
        harness.expect("no move before the first slot", HyprlandService.focusCalls.length, 0);

        widget.pendingFocusNum = 0;
        harness.setFocus([1, 2, 3, 4, 5], 5);
        HyprlandService.focusCalls = [];
        widget.stepWorkspace(1);
        harness.expect("no move past the last slot", HyprlandService.focusCalls.length, 0);

        console.log("=== " + harness.checks + " checks, " + (harness.failures === 0 ? "ALL PASS" : harness.failures + " FAILURES") + " ===");
    }
}
