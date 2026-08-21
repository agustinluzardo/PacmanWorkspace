# Test harness

Runs the plugin offscreen against mocked Quickshell and DankMaterialShell
modules, so behaviour can be checked without a compositor, a DMS install or a
GPU.

```sh
./tests/run.sh
```

On Debian/Ubuntu the dependencies are:

```sh
apt-get install qt6-base-dev qt6-declarative-dev qt6-declarative-dev-tools \
                qml6-module-qtquick qml6-module-qtquick-shapes \
                qml6-module-qtqml-workerscript qml6-module-qtquick-window
```

## What is mocked

`mock/qs/` and `mock/Quickshell/` are small stand-ins whose property surface
mirrors the real DMS and Quickshell types (`Theme`, `SettingsData`,
`CompositorService`, `NiriService`, `HyprlandService`, `SessionService`,
`Hyprland`, `PluginComponent`, and the `*Setting` components). The mock
`Hyprland` exposes `workspaces` / `monitors` / `toplevels` models with a
`values` list that emits `valuesChanged`, a `rawEvent` signal and counted
`refresh*()` invokables, which is enough to drive every code path in the widget.

`render.cpp` is a ~30 line QQuickView host that loads a QML file offscreen,
grabs the result to a PNG and reports any QML errors.

## The suites

| Suite | What it covers |
| --- | --- |
| `SlotTest` | The slot-range algorithm in isolation: 16 scenarios covering the reported bug (moving to workspace 3+), strip growth, per-monitor id blocks such as `11..20`, a stray high workspace id, and the min/max clamping. Every case also asserts that the focused workspace stays visible and the strip never exceeds the cap. |
| `DelegateTest` | The regression guard: 20 workspace switches must not destroy or recreate a single delegate. Also pins down that a *slot count* change does regenerate the strip, which is expected and harmless with Shapes. |
| `ShapeHarness` | Renders Pac-Man (open, closed, bounced, flipped), all four ghosts, dots and the power pellet at 21 / 32 / 64 px so the vector geometry can be eyeballed. |
| `SettingsTest` | Constructs the real settings page against the mocked setting components, catching any property that does not exist. |
| `FrightenedTest` | The frightened-mode lifecycle in real time: it arms on a backwards move, flashes near the end, expires on schedule, does not arm going forward, re-arms on a new backwards move, and - the regression that mattered - is not armed by a momentary blip in compositor state. |
| `IntegrationTest` | Drives the **real** `PacmanWorkspaces.qml` through the reported scenarios: moving to workspaces 3, 4, 5 and 7; occupancy; urgent workspaces; ghost modes; special and named workspaces; clicking; scrolling; resume-from-sleep refresh; a deliberately *dropped* compositor event that the watchdog has to repair; and the vertical bar pill. |

Rendered PNGs are written to `tests/.build/` for inspection.

## Known-good deviations

- `Shape.CurveRenderer` is stripped from the copy under test, because it needs
  Qt >= 6.6 and the suite should run on older Qt too. It affects rasterisation
  only, never geometry or logic.
- `qmllint` reports unqualified access to `root` and `cell` inside the delegate
  `Component`. That is expected: `pragma ComponentBehavior: Bound` cannot be used
  in a DMS plugin, because DMS instantiates the bar pills from a `Loader` in
  `BasePill.qml` and a bound component refuses to be created outside its own
  creation context. Those ids resolve through the component's creation context at
  runtime instead, which `IntegrationTest` verifies end to end. `run.sh` fails on
  any warning other than these and the known `Qt.callLater` false positive.
