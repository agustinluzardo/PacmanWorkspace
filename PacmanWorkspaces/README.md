# Pac-Man Workspaces

A Pac-Man workspace indicator for [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell).

Pac-Man sits on the workspace you are on, chomping and facing whichever way you
last travelled. Ghosts mark the other workspaces, untouched ones stay as pellets,
and a workspace that goes urgent flashes as a power pellet.

Works on horizontal and vertical DankBars. Hyprland is the primary target; niri
is supported through DMS' `NiriService`.

## Install

```sh
cp -r PacmanWorkspaces ~/.config/DankMaterialShell/plugins/
```

Then enable it in DMS under **Settings → Plugins**, and add it to a bar section
in **Settings → DankBar**.

## Using it

| Action | Result |
| --- | --- |
| Left click a slot | Jump to that workspace |
| Scroll over the widget | Move one workspace at a time |

## Settings

**Layout**

- **Minimum slots** – how many slots are always shown, even when empty.
- **Maximum slots** – the strip grows past the minimum as you use higher
  workspaces, but never beyond this. Set it equal to the minimum for a fixed
  count. This is also what stops a stray high workspace id (say `100`) from
  turning the bar into a hundred icons.
- **Icon size** – `0` follows the bar's own calibrated icon size, which is
  usually what you want; it then tracks bar thickness and DMS' icon scale.
- **Spacing** – `0` derives the gap from the icon size.
- **Per-monitor workspaces** – each bar shows the workspaces of the monitor it
  lives on. Turn it off to have every bar mirror the focused monitor. (DMS'
  own *Workspaces follow focus* setting also forces the mirrored behaviour.)

**Ghosts**

- **Ghosts appear on** – workspaces *behind you* (they chase Pac-Man, the
  default), workspaces *with windows open*, or *every other workspace*.
- **Ghost colours** – one stable colour per workspace, or by distance behind you.

**Behaviour**

- **Animations** – chomping, the landing bounce, drifting ghosts and the
  flashing power pellet. DMS' global animation setting switches these off too.
- **Scroll to switch** / **Reverse scroll direction**.

## Notes on the 2.0 rewrite

Version 1 drew every icon into a `Canvas`. Three bugs came out of that, plus a
few more from how workspace state was read:

- **Pac-Man came back stretched and pixelated after sleep.** `Canvas` keeps a
  raster backing store that is not re-rendered when the surface is torn down and
  rebuilt (DPMS off, suspend/resume, output hotplug), so the old image was left
  scaled to the new size. Everything is now `QtQuick.Shapes` vector geometry,
  which the scene graph regenerates from live bindings and which has no backing
  store to go stale. The chomp and the landing bounce animate the *radius* that
  feeds the path, so Pac-Man is re-tessellated rather than scaled.
- **Ghosts stopped appearing and Pac-Man stayed on an old workspace.** The
  `Repeater` was handed a freshly built array on every change, so every delegate
  was destroyed and rebuilt on each workspace switch; dropped `requestPaint()`
  calls then left stale or empty canvases behind. The model is now a plain slot
  count, so delegates are reused across workspace switches.
- **Occupied workspaces never registered.** The old code read `workspace.windows`,
  which does not exist on Quickshell's `HyprlandWorkspace`, so it was always
  `undefined > 0` → `false`. Occupancy now comes from live toplevel tracking.
- **Nothing recovered from a missed compositor event.** A watchdog hashes live
  compositor state every few seconds and forces a recompute only when it
  disagrees with what is drawn, and resuming from sleep asks Hyprland for a full
  refresh. Reloading the plugin by hand should no longer be necessary.
- Special and named workspaces (scratchpads, negative ids) no longer take slots,
  the widget is per-monitor, sizes follow the bar instead of a hardcoded 21px,
  and workspace switching goes through `HyprlandService` so it keeps working
  under Hyprland's Lua config.

The `plugin.json` manifest also gained the `capabilities` field, which the DMS
plugin schema lists as required.
