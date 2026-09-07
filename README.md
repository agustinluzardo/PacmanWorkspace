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
  way the cabinet animates them, *Float* drifts the whole ghost up and down, or
  *Both* does the two together.
- **Frightened ghosts** – off by default. Going back to a lower workspace counts
  as eating an energizer, so the ghosts turn blue for five seconds and flash
  white in the last two before recovering. If a move leaves no ghost on screen
  at all, the effect ends there rather than burning down invisibly and greeting
  the next ghost already blue.

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

## 2.4.0 — an optional maze background, a pellet in the mouth, and an audit of the suite

### The corridor

**Strip background** (Settings, off by default) draws a stretch of maze behind
the pellets. Four values:

- `None` — as before
- `Corridor outline` — just the blue outline, the panel's own background shows through
- `Corridor, shaded` — the outline plus a dark veil that gives the sprites contrast
- `Rails only` — the two walls with the ends left open, so the strip reads as a
  length of corridor carrying on past the widget rather than as a box

The rails' thickness comes from `cellSize` rather than a fixed number, so it
follows when you change the icon size.

**Strip background colour** picks what the corridor or rails are drawn in. The
colour swatch only appears while the mode is Custom — left on screen under
Automatic it invites a pick the widget then ignores. Leaving Custom also puts
the stored colour back to the cabinet blue, so the swatch agrees with what is
actually drawn; before that it kept showing the old pick, which meant the widget
was right and the settings page was lying about it.
`Automatic` is exactly the colour the widget already used — cabinet blue on the
Arcade palette, your theme's accent on Adaptive — so switching the background on
can never quietly restyle anything. `Custom` overrides **only** the background;
the ghosts and Pac-Man keep the palette, which is what stops a colour pick
turning into a reskin. That separation is asserted, not assumed.

The **whole** maze was tried and dropped: at 36px tall its walls turn into noise
and bury the pellets, which are the information. One corridor does read, because
that is the shape the eye already associates with the game.

Corridor costs about 6px of height; rails cost far less, since they leave the
ends open. Either shrinks the sprites, which is why this is off by default.

### The pellet in the mouth

With animations off Pac-Man's mouth freezes open, which reads as waiting rather
than eating. **Pellet in the mouth when still** (on by default) puts a pellet in
the opening — the bite about to happen, the way the arcade frame does. Turn it
off to leave the mouth empty.

It deliberately does nothing while animations are on: a dot appearing and
vanishing several times a second is noise, not information.

### The scroll fix, carried across

This release is built on 2.1.0, which did not have the wheel fix from the 2.2.x
line. That fix was extracted and applied on its own — the ghost-colour changes
that shipped alongside it were left behind, since DankMaterialShell 1.6.0 fixed
that upstream.

The old rate limiter dropped a notch *after* the wheel accumulator had already
debited it, so a quick spin moved one workspace and lost the rest. Steps now
measure from the workspace they are heading to. The integration suite spins the
wheel three notches without letting the compositor confirm any of them, which is
exactly the window the bug lived in; reverting the fix breaks three of those
assertions.

### What the audit turned up

Adding the corridor wrapped the pill's `Row` in an `Item`, and **the integration
test went blank** — correctly, because the structure had changed: its reader
assumed the cells were direct children of the pill's root. It now walks in
depth, so it describes what the strip shows rather than how it is nested.

That exposed something larger: **a suite producing no checks at all passed
without saying anything.** With the reader broken, the run still came out green.
`run.sh` now requires a floor of checks per suite and prints the count.

With that floor in place, two suites turned out to be assertion-less smoke
tests:

- **`shapes`** rendered a reference image and asserted nothing. A drawing that
  came out blank passed just the same. Its pixels are now counted
  (`tests/pixels.py`, a PNG decoder in plain Python).
- **`settings`** built the page without checking that the controls existed. It
  now counts one per option: a setting that fails quietly leaves the page built
  and one control short.

A new `background` suite covers the four modes and the colour resolution: 16
checks, including that `Automatic` returns the same colour the palette already
produced and that a custom pick does not leak onto the sprites. Reverting each
of those rules breaks between one and three of them.

`SettingsTest` no longer hardcodes how many settings there should be — it did,
and every new setting then broke it for the wrong reason. The page now reports
the keys it actually built and `run.sh` compares them against the source, which
is the only place that can say what should have been built.

A `colormode` suite covers that: 10 checks over the swatch's visibility and the
round trip out of Custom and back. Writing it turned up a hole in its own guard
— an early return when the page failed to build printed a short summary instead
of a failure, which is the same "a suite that asserts nothing looks fine"
problem in miniature. It counts as a failure now.

A `mouth` render draws Pac-Man still, with and without the pellet, and counts
the pixels: the two halves differ only by that setting, so a property reading
"on" is not taken as proof anything reached the screen.

Per-suite counts: slots 16, delegates 8, shapes (pixels), background 22,
mouth (pixels), settings 2, integration 28, frightened 20.
