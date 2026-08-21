import QtQuick
import Quickshell.Hyprland
import qs.Services

// Drives the real PacmanWorkspaces.qml (copied in as PacmanWorkspacesUT.qml,
// with preferredRendererType stripped because the local Qt is 6.4) against the
// exact scenarios reported as broken.
Rectangle {
    id: harness
    width: 460
    height: 260
    color: "#12141a"

    property int failures: 0
    property int checks: 0

    PacmanWorkspacesUT {
        id: widget
        anchors.centerIn: parent
        barThickness: 48
        pluginData: ({
                "workspaceCount": 5,
                "maxSlots": 10,
                "ghostMode": "behind",
                "ghostColorMode": "workspace",
                "perMonitor": false,
                "animations": true,
                "scrollToSwitch": true
            })
    }

    // ---- mock compositor drivers -----------------------------------------
    function ws(id, opts) {
        const o = opts || {};
        return {
            "id": id,
            "name": o.name ?? String(id),
            "urgent": o.urgent === true,
            "monitor": {
                "name": o.monitor ?? "DP-1"
            },
            "lastIpcObject": {
                "windows": o.ipcWindows ?? 0
            }
        };
    }

    function setState(ids, focused, opts) {
        const o = opts || {};
        Hyprland.workspaces.values = ids.map(i => harness.ws(i, (o.wsOpts && o.wsOpts[i]) || {}));
        Hyprland.monitors.values = [
            {
                "name": "DP-1",
                "activeWorkspace": {
                    "id": focused
                }
            }
        ];
        Hyprland.toplevels.values = (o.windowsOn || []).map(id => ({
                    "workspace": {
                        "id": id
                    }
                }));
        Hyprland.focusedWorkspace = {
            "id": focused
        };
    }

    // ---- readback ---------------------------------------------------------
    function strip() {
        const row = widget.pillItem;
        if (!row)
            return "<no pill>";
        const parts = [];
        for (let i = 0; i < row.children.length; i++) {
            const c = row.children[i];
            if (c.kind === undefined)
                continue;
            parts.push(c.info.num + ":" + c.kind + (c.info.focused ? "*" : "") + (c.info.occupied ? "+" : ""));
        }
        return parts.join(" ");
    }

    function check(label, wanted) {
        const got = harness.strip();
        harness.checks++;
        const ok = got === wanted;
        if (!ok)
            harness.failures++;
        console.log((ok ? "PASS " : "FAIL ") + label + "\n        got:  " + got + (ok ? "" : "\n        want: " + wanted));
    }

    function expect(label, actual, wanted) {
        harness.checks++;
        const ok = actual === wanted;
        if (!ok)
            harness.failures++;
        console.log((ok ? "PASS " : "FAIL ") + label + " = " + actual + (ok ? "" : " (expected " + wanted + ")"));
    }

    Component.onCompleted: {
        console.log("=== integration: real widget against mocked Hyprland ===");

        setState([1], 1);
        check("fresh session, on ws1", "1:pacman* 2:dot 3:dot 4:dot 5:dot");

        setState([1, 2], 2, {
            "windowsOn": [1]
        });
        check("moved to ws2 (ws1 has a window)", "1:ghost+ 2:pacman* 3:dot 4:dot 5:dot");

        // The reported bug: going past ws2 left Pac-Man stranded on slot 2.
        setState([2, 3], 3);
        check("REGRESSION ws3: Pac-Man follows", "1:ghost 2:ghost 3:pacman* 4:dot 5:dot");

        setState([4], 4);
        check("REGRESSION ws4: Pac-Man follows", "1:ghost 2:ghost 3:ghost 4:pacman* 5:dot");

        setState([5], 5);
        check("REGRESSION ws5: Pac-Man follows", "1:ghost 2:ghost 3:ghost 4:ghost 5:pacman*");

        setState([1, 7], 7, {
            "windowsOn": [1]
        });
        check("ws7 grows the strip", "1:ghost+ 2:ghost 3:ghost 4:ghost 5:ghost 6:ghost 7:pacman*");

        setState([1, 2, 3], 2, {
            "windowsOn": [1, 3, 3]
        });
        check("occupancy is real now (ws3 ahead has windows)", "1:ghost+ 2:pacman* 3:dot+ 4:dot 5:dot");

        setState([1, 2, 3], 1, {
            "wsOpts": {
                "3": {
                    "urgent": true
                }
            },
            "windowsOn": [3]
        });
        check("urgent workspace becomes a power pellet", "1:pacman* 2:dot 3:pellet+ 4:dot 5:dot");

        // ghostMode = occupied
        widget.pluginData = {
            "workspaceCount": 5,
            "maxSlots": 10,
            "ghostMode": "occupied",
            "perMonitor": false
        };
        setState([1, 2, 3], 2, {
            "windowsOn": [1, 3]
        });
        check("ghostMode=occupied", "1:ghost+ 2:pacman* 3:ghost+ 4:dot 5:dot");

        widget.pluginData = {
            "workspaceCount": 5,
            "maxSlots": 10,
            "ghostMode": "behind",
            "perMonitor": false
        };

        // Named/special workspaces must never take a slot.
        Hyprland.toplevels.values = [];
        Hyprland.workspaces.values = [harness.ws(1), harness.ws(2), {
                "id": -98,
                "name": "special:magic",
                "monitor": {
                    "name": "DP-1"
                }
            }, {
                "id": -1337,
                "name": "scratch",
                "monitor": {
                    "name": "DP-1"
                }
            }];
        Hyprland.focusedWorkspace = {
            "id": 2
        };
        check("special + named workspaces ignored", "1:ghost 2:pacman* 3:dot 4:dot 5:dot");

        // Clicking a slot must reach the compositor.
        setState([1, 2, 3], 1);
        widget.switchTo(widget.wsSlots[3]);
        expect("click dispatches to compositor", HyprlandService.lastFocused, 4);

        // Scroll steps one workspace at a time.
        setState([1, 2, 3], 2);
        widget.stepWorkspace(1);
        expect("scroll forward focuses next slot", HyprlandService.lastFocused, 3);

        // Facing: turns to follow travel, but faces right again at the first slot.
        setState([1], 1);
        harness.expect("starts facing right", widget.facingLeft, false);
        setState([1, 3], 3);
        harness.expect("moving forward faces right", widget.facingLeft, false);
        setState([1, 2, 3], 2);
        harness.expect("moving back faces left", widget.facingLeft, true);
        setState([1, 2], 1);
        harness.expect("faces right again at the first slot", widget.facingLeft, false);
        setState([1, 5], 5);
        harness.expect("forward again faces right", widget.facingLeft, false);
        setState([1, 4, 5], 4);
        harness.expect("back again faces left", widget.facingLeft, true);

        // Icon size must match the original 21px at the reference 48px bar.
        harness.expect("cell size matches the original at a 48px bar", widget.cellSize, 21);

        // Pellets must centre on a whole pixel at every icon size, or the small
        // ones sit visibly higher than the large ones.
        let offBy = [];
        for (let px = 10; px <= 48; px++) {
            widget.pluginData = {
                "autoIconSize": false,
                "iconSizeOverride": px,
                "perMonitor": false
            };
            const ds = [widget.pelletDiameter(widget.pelletFraction, 4), widget.pelletDiameter(widget.occupiedPelletFraction, 4), widget.pelletDiameter(widget.urgentPelletFraction, 6)];
            for (let k = 0; k < ds.length; k++)
                if (((widget.cellSize - ds[k]) % 2) !== 0)
                    offBy.push(widget.cellSize + "/" + ds[k]);
        }
        harness.expect("pellets centre on a whole pixel at every size", offBy.length, 0);
        if (offBy.length > 0)
            console.log("        off-centre at cell/diameter: " + offBy.join(" "));
        widget.pluginData = {
            "workspaceCount": 5,
            "maxSlots": 10,
            "ghostMode": "behind",
            "perMonitor": false
        };

        // Resume from sleep asks for a full compositor refresh.
        const before = Hyprland.refreshWorkspacesCalls;
        SessionService.sessionResumed();
        resumeTimer.before = before;
        resumeTimer.start();
    }

    Timer {
        id: resumeTimer
        interval: 200
        property int before: 0
        onTriggered: {
            harness.expect("sessionResumed triggers a state refresh", Hyprland.refreshWorkspacesCalls > resumeTimer.before, true);

            // Simulate a DROPPED compositor event: mutate the workspace list in
            // place so no valuesChanged is emitted, exactly like an event missed
            // across suspend. The watchdog must repair it without a reload.
            Hyprland.workspaces.values.push(harness.ws(4));
            Hyprland.focusedWorkspace.id = 4;
            Hyprland.monitors.values[0].activeWorkspace.id = 4;
            console.log("INFO  strip immediately after the silent change: " + harness.strip());
            console.log("INFO  injected a silently-missed event; waiting for the watchdog...");
            watchdogTimer.start();
        }
    }

    Timer {
        id: watchdogTimer
        interval: 3600
        onTriggered: {
            harness.check("watchdog self-heals a dropped event", "1:ghost 2:ghost 3:ghost 4:pacman* 5:dot");

            // The vertical pill (side bars) must build the same strip.
            const vcol = widget.verticalPillItem;
            let vcount = 0;
            let vfocused = -1;
            if (vcol) {
                for (let i = 0; i < vcol.children.length; i++) {
                    const c = vcol.children[i];
                    if (c.kind === undefined)
                        continue;
                    vcount++;
                    if (c.info.focused)
                        vfocused = c.info.num;
                }
            }
            harness.expect("vertical pill builds the same slot count", vcount, widget.slotCount);
            harness.expect("vertical pill tracks the focused workspace", vfocused, widget.focusedWorkspaceId);
            console.log("=== " + harness.checks + " checks, " + (harness.failures === 0 ? "ALL PASS" : harness.failures + " FAILURES") + " ===");

            // Leave a representative strip on screen for the render grab.
            harness.setState([1, 2, 3, 4, 5], 3, {
                "windowsOn": [1, 4],
                "wsOpts": {
                    "5": {
                        "urgent": true
                    }
                }
            });
        }
    }
}
