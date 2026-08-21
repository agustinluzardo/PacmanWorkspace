# Pac-Man Workspaces

A Pac-Man workspace indicator for [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell).

Pac-Man sits on the workspace you are on, chomping and facing whichever way you
last travelled. Ghosts mark the other workspaces, untouched ones stay as pellets,
and a workspace that goes urgent flashes as a power pellet.

It follows the 1980 cabinet fairly closely: the arcade's own palette (Pac-Man
`#FFFF00`; Blinky, Pinky, Inky and Clyde in their real colours, with blue
pupils; peach maze food), Pac-Man's three-frame chomp rather than a smooth
tween, ghost skirts that shuffle between two frames instead of bobbing, and
energizers that blink hard on and off. One shared sprite clock drives all of it,
so every icon in the bar animates in step the way it does in the game — and it
costs a handful of property writes a second instead of a per-frame animation.

Everything is vector geometry (`QtQuick.Shapes`), so it stays sharp at any bar
size and survives suspend/resume without going stale. It also fits into the rest
of the shell: sizes follow the bar's thickness and icon scale, DMS' global
animation setting switches the sprite clock off, and a **Palette** setting swaps
the arcade primaries for your Material You theme colours when they are too loud
for your bar.

Works on horizontal and vertical DankBars. Hyprland is the primary target; niri
is supported through DMS' `NiriService`.

## Install

This repo *is* the plugin, so clone it straight into the DMS plugins directory:

```sh
git clone https://github.com/agustinluzardo/PacmanWorkspace \
  ~/.config/DankMaterialShell/plugins/PacmanWorkspaces
```

Then restart the shell (see [Troubleshooting](#troubleshooting) — a plain
**Scan** is often not enough), enable it under **Settings → Plugins**, and add it
to a bar section in **Settings → DankBar**.

To update later:

```sh
git -C ~/.config/DankMaterialShell/plugins/PacmanWorkspaces pull
```

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
- **Size icons from the bar** – on by default: the icon size comes from the bar's
  thickness and DMS' icon scale (21px on a standard 48px bar). Turn it off and an
  **Icon size** slider appears to pin an exact value.
- **Space icons automatically** – same idea for the gap between icons, with a
  **Spacing** slider behind it.
- **Pellet size** – how big an untouched workspace's pellet is, as a percentage
  of the icon size (default 38%, so a reachable-but-unused workspace reads as a
  power pellet rather than a speck). Occupied and urgent slots scale up from it.
- **Per-monitor workspaces** – each bar shows the workspaces of the monitor it
  lives on. Turn it off to have every bar mirror the focused monitor. (DMS'
  own *Workspaces follow focus* setting also forces the mirrored behaviour.)

**Colours & ghosts**

- **Palette** – *Arcade* uses the cabinet's own colours (and darkens the peach
  maze food on light bars so it still reads). *Adaptive* maps Pac-Man to
  `Theme.primary` and the four ghosts to your theme's error / tertiary / info /
  warning colours.
- **Ghosts appear on** – workspaces *behind you* (they chase Pac-Man, the
  default), workspaces *with windows open*, or *every other workspace*.
- **Ghost colours** – one stable colour per workspace, or by distance behind you.
- **Ghost motion** – *Arcade* shuffles the sprite's skirt between two frames the
  way the cabinet animates them, or *Float* drifts the whole ghost up and down.
- **Frightened ghosts** – off by default. Going back to a lower workspace counts
  as eating an energizer, so the ghosts turn blue for five seconds and flash
  white in the last two before recovering.

**Behaviour**

- **Animations** – the sprite clock: the three-frame chomp, the shuffling ghost
  skirts, the blinking energizers and the landing bounce. DMS' global animation
  setting switches these off too, and the clock stops while the widget is hidden
  or the machine is going to sleep.
- **Animation style** – *Arcade* steps the sprites on a shared frame clock;
  *Smooth* tweens the same sprites continuously at the display's refresh rate.
- **Scroll to switch** / **Reverse scroll direction**.

## Troubleshooting

**The plugin does not show up in Settings → Plugins, even after pressing Scan.**

Two things cause this, and the first one is not obvious.

*DMS caches manifest paths.* `PluginService.resyncAll()` only reads a
`plugin.json` whose path it does not already know:

```js
const prev = knownManifests[key];
if (!prev) loadPluginManifestFile(...);
```

So once a path has been seen — including one rejected earlier and cached as
`bad` — pressing **Scan** will never re-read it. That cache lives in memory
only, so restarting the shell clears it:

```sh
dms kill && dms run     # or: systemctl --user restart dms
```

*The directory layout is wrong.* DMS scans exactly one level deep: it lists the
directories inside `plugins/` and looks for `<dir>/plugin.json`. This is what it
has to look like:

```
~/.config/DankMaterialShell/plugins/PacmanWorkspaces/plugin.json                    ✓
~/.config/DankMaterialShell/plugins/PacmanWorkspaces/PacmanWorkspaces/plugin.json   ✗ nested too deep
```

To check what DMS actually sees:

```sh
PL="${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/plugins"
for d in "$PL"/*/; do
  [ -f "$d/plugin.json" ] && echo "OK   $(basename "$d")" || echo "MISS $(basename "$d")"
done
```

**Two copies installed.** Two directories declaring the same plugin id
(`pacmanWorkspaces`) means DMS loads only one of them, and not necessarily the
newer one. Remove the stale directory:

```sh
find "${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/plugins" \
  -name plugin.json -exec grep -l pacmanWorkspaces {} +
```

**Still nothing.** The shell log names the reason:

```sh
dms logs 2>&1 | grep -i "plugin\|manifest" | tail -30
```

## Development

`tests/` holds an offscreen harness that runs the real QML against mocked
Quickshell and DMS modules — no compositor, no DMS install, no GPU:

```sh
./tests/run.sh
```

It covers 16 slot-range scenarios, a delegate-churn regression guard, shape
rendering, settings construction, and 16 integration checks. See
[`tests/README.md`](tests/README.md). The `tests/` directory is never scanned by
DMS, so it is harmless to leave in place after installing.

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
