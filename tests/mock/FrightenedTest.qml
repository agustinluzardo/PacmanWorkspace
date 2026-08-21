import QtQuick
import Quickshell.Hyprland

// Drives the real widget through a full frightened-mode lifecycle in real time.
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
                "perMonitor": false,
                "animations": true,
                "frightenedGhosts": true
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
        console.log((ok ? "PASS " : "FAIL ") + label + " = " + actual + (ok ? "" : " (expected " + wanted + ")"));
    }

    property var steps: [
        {
            "at": 0,
            "run": () => {
                harness.setFocus([1, 2, 3], 3);
                harness.setFocus([1, 2, 3], 2); // moved back -> frightened
                harness.expect("t=0.0  frightened after moving back", widget.frightened, true);
                harness.expect("t=0.0  not flashing yet", widget.frightenedFlash, false);
            }
        },
        {
            "at": 1200,
            "run": () => {
                harness.expect("t=1.2  still frightened", widget.frightened, true);
                harness.expect("t=1.2  still not flashing", widget.frightenedFlash, false);
            }
        },
        {
            "at": 3400,
            "run": () => {
                harness.expect("t=3.4  flashing near the end", widget.frightenedFlash, true);
                harness.expect("t=3.4  still frightened", widget.frightened, true);
            }
        },
        {
            "at": 5600,
            "run": () => {
                harness.expect("t=5.6  effect has worn off", widget.frightened, false);
                harness.expect("t=5.6  flash cleared", widget.frightenedFlash, false);
            }
        },
        {
            "at": 6200,
            "run": () => {
                harness.setFocus([1, 2, 3], 3); // forward
                harness.expect("t=6.2  moving forward does NOT frighten", widget.frightened, false);
            }
        },
        {
            "at": 6800,
            "run": () => {
                harness.setFocus([1, 2, 3], 1); // back again
                harness.expect("t=6.8  re-triggers on a new backwards move", widget.frightened, true);
            }
        },
        // A refresh can leave the compositor state momentarily unreadable. The
        // widget must not read that as "you walked back to workspace 1".
        {
            "at": 12600,
            "run": () => {
                harness.setFocus([1, 2, 3, 4, 5], 5);
                harness.expect("t=12.6 settled on ws5, not frightened", widget.frightened, false);
            }
        },
        {
            "at": 13000,
            "run": () => {
                Hyprland.focusedWorkspace = null; // transient: state unreadable
                harness.expect("t=13.0 focus holds at 5 during a blip", widget.focusedWorkspaceId, 5);
                harness.expect("t=13.0 a blip does NOT frighten", widget.frightened, false);
            }
        },
        {
            "at": 13400,
            "run": () => {
                harness.setFocus([1, 2, 3, 4, 5], 5); // state comes back, same ws
                harness.expect("t=13.4 still not frightened after recovery", widget.frightened, false);
                console.log("=== " + harness.checks + " checks, " + (harness.failures === 0 ? "ALL PASS" : harness.failures + " FAILURES") + " ===");
            }
        }
    ]

    property int stepIndex: 0

    Timer {
        id: runner
        interval: 1
        repeat: false
        onTriggered: {
            const s = harness.steps[harness.stepIndex];
            s.run();
            harness.stepIndex++;
            const next = harness.steps[harness.stepIndex];
            if (next) {
                runner.interval = next.at - s.at;
                runner.start();
            }
        }
    }

    Component.onCompleted: {
        console.log("=== frightened mode lifecycle ===");
        runner.start();
    }
}
