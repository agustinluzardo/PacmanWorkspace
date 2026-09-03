// NOTE: no `pragma ComponentBehavior: Bound` here. DMS instantiates
// horizontalBarPill / verticalBarPill from a Loader that lives in BasePill.qml,
// and a bound component refuses to be created outside its own creation context
// ("Cannot instantiate bound component outside its creation context"), which
// leaves the pill empty. Every lookup below is explicitly qualified instead.

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Modules.Plugins

// Pac-Man style workspace indicator.
//
// Everything is drawn with QtQuick.Shapes (scene-graph vector geometry) rather
// than Canvas. Canvas keeps a raster backing store that is not re-rendered when
// the surface is torn down and rebuilt (DPMS off, suspend/resume, output hotplug)
// or when the item is resized while unexposed, which is what made Pac-Man come
// back stretched and pixelated after sleep, and what made ghosts stop appearing
// once a queued requestPaint() was dropped. Shapes have no backing store: the
// scene graph regenerates them from the live bindings on every frame it needs.
PluginComponent {
    id: root

    // ------------------------------------------------------------- settings --
    readonly property int minSlots: Math.max(1, Math.min(20, root.pluginData?.workspaceCount ?? 5))
    readonly property int maxSlots: Math.max(root.minSlots, Math.min(30, root.pluginData?.maxSlots ?? 10))
    // "behind"   - ghosts chase you: every slot with a lower number than the focused one
    // "occupied" - ghosts sit on every workspace that has windows open
    // "all"      - ghosts on every slot that is not the focused one
    readonly property string ghostMode: root.pluginData?.ghostMode ?? "behind"
    // "workspace" - each workspace always gets the same ghost (stable colours)
    // "distance"  - ghost colour follows how far behind you the slot is
    readonly property string ghostColorMode: root.pluginData?.ghostColorMode ?? "workspace"
    readonly property bool perMonitor: root.pluginData?.perMonitor ?? true
    readonly property bool animationsEnabled: root.pluginData?.animations ?? true
    readonly property bool scrollEnabled: root.pluginData?.scrollToSwitch ?? true
    readonly property bool scrollReversed: root.pluginData?.scrollReversed ?? false
    // Sizing is either derived from the bar or pinned to an exact value. A slider
    // parked at 0 meaning "derive it" read as switched off, so the choice is an
    // explicit flag and the slider always shows a real pixel size.
    readonly property bool autoIconSize: root.pluginData?.autoIconSize ?? true
    readonly property int iconSizeOverride: Math.max(10, Math.min(48, root.pluginData?.iconSizeOverride ?? 21))
    readonly property bool autoSpacing: root.pluginData?.autoSpacing ?? true
    readonly property int spacingOverride: Math.max(0, Math.min(24, root.pluginData?.spacingOverride ?? 6))
    // "arcade" - the sprite's skirt shuffles between two frames, as on the cabinet
    // "float"  - the ghosts drift up and down instead
    // "both"   - drifting, with the skirt still shuffling
    readonly property string ghostMotion: root.pluginData?.ghostMotion ?? "arcade"
    readonly property bool ghostSkirtMoves: root.ghostMotion === "arcade" || root.ghostMotion === "both"
    readonly property bool ghostFloats: root.ghostMotion === "float" || root.ghostMotion === "both"
    // Diameter of an empty slot's pellet, as a percentage of the icon size. An
    // untouched-but-reachable workspace reads as a power pellet rather than a
    // speck; occupied and urgent slots scale up from it and stay distinguishable.
    readonly property int pelletSizePercent: Math.max(10, Math.min(60, root.pluginData?.pelletSize ?? 30))
    readonly property real pelletFraction: root.pelletSizePercent / 100
    readonly property real occupiedPelletFraction: Math.min(0.52, root.pelletFraction * 1.5)
    readonly property real urgentPelletFraction: Math.min(0.70, root.pelletFraction * 2)

    // anchors.centerIn puts the pellet at (cellSize - diameter) / 2, so unless
    // the diameter has the same parity as the cell that lands on a half pixel:
    // a 6px dot in a 21px cell centres at y=7.5 and renders visibly higher than
    // its 9px neighbour, which centres at exactly 6. Match the parity.
    function pelletDiameter(fraction, minimum) {
        let d = Math.max(minimum, Math.round(root.cellSize * fraction))
        if (((root.cellSize - d) % 2) !== 0)
            d += 1
        return d
    }

    // DMS' global "no animations" setting collapses every duration to 0; honour it.
    readonly property bool animationsOn: root.animationsEnabled && Theme.shortDuration > 0

    // ------------------------------------------------------------- geometry --
    readonly property real dpr: root.parentScreen ? CompositorService.getScreenScale(root.parentScreen) : 1

    // Follows the bar's calibrated icon size (and its thickness / icon-scale
    // settings) instead of a hardcoded pixel count, and is snapped to whole
    // device pixels so nothing lands on a half pixel under fractional scaling.
    // 21px at the reference 48px bar - the size the Canvas version used, which is
    // what this is calibrated to. Theme.barIconSize(48, -4) would give 20 instead
    // (Theme.iconSize is 24), so the bar's icon metric is scaled rather than used
    // directly. Still tracks bar thickness and the bar's icon-scale setting, and
    // is snapped to whole device pixels so nothing lands on a half pixel under
    // fractional scaling.
    readonly property real referenceCellSize: 21
    readonly property int cellSize: {
        if (!root.autoIconSize)
            return Math.max(10, Math.round(Theme.snap(root.iconSizeOverride, root.dpr)))
        const scale = root.barConfig?.iconScale ?? 1
        const base = (root.barThickness / 48) * root.referenceCellSize * scale
        return Math.max(10, Math.round(Theme.snap(base, root.dpr)))
    }
    readonly property real cellSpacing: {
        const base = root.autoSpacing ? Math.max(3, Math.round(root.cellSize * 0.3)) : root.spacingOverride
        return Theme.snap(base, root.dpr)
    }

    // --------------------------------------------------------------- colours --
    // "arcade"  - the 1980 cabinet's own palette
    // "theme"   - Material You colours from DMS, for bars where pure arcade
    //             primaries are too loud
    readonly property string palette: root.pluginData?.palette ?? "arcade"
    readonly property bool arcadePalette: root.palette !== "theme"

    readonly property color pacmanColor: root.arcadePalette ? "#FFFF00" : Theme.primary

    // Blinky, Pinky, Inky, Clyde - the cabinet's exact values, in the order they
    // leave the ghost house.
    readonly property var arcadeGhosts: ["#FF0000", "#FFB8FF", "#00FFFF", "#FFB852"]
    readonly property var themeGhosts: [Theme.error, Theme.tertiary, Theme.info, Theme.warning]
    readonly property var ghostPalette: root.arcadePalette ? root.arcadeGhosts : root.themeGhosts

    // The arcade maze draws dots and energizers in the same peach; on a light bar
    // that has almost no contrast, so it is darkened there.
    // On the cabinet's CRT the maze food reads as white, not as the peach the
    // sprite sheet stores - which on a dark bar just looked brown. Size, not
    // colour, is what separates an occupied workspace from an untouched one.
    readonly property color pelletColor: {
        if (!root.arcadePalette)
            return Theme.surfaceText
        return Theme.isLightMode ? "#33270F" : "#FFFFFF"
    }
    readonly property color dimPelletColor: root.arcadePalette ? Theme.withAlpha(root.pelletColor, 0.65) : Theme.surfaceVariantText

    // Classic frightened mode: walking back the way you came is Pac-Man eating an
    // energizer, so the ghosts turn blue, then flash white just before it wears
    // off, exactly as the cabinet does.
    readonly property bool frightenedEnabled: root.pluginData?.frightenedGhosts ?? false
    readonly property int frightenedMs: 5000
    property bool frightened: false
    property bool frightenedFlash: false
    readonly property bool frightenedWhite: root.frightened && root.frightenedFlash && root.animationsOn && (root.spriteFrame % 2 === 0)
    readonly property color frightenedBodyColor: root.frightenedWhite ? "#FFFFFF" : (root.arcadePalette ? "#2121DE" : Theme.info)
    readonly property color frightenedPupilColor: root.frightenedWhite ? "#FF0000" : "#FFFFFF"

    Timer {
        id: frightenedFlashTimer
        interval: Math.max(1000, root.frightenedMs - 2000)
        onTriggered: root.frightenedFlash = true
    }

    Timer {
        id: frightenedTimer
        interval: root.frightenedMs
        onTriggered: {
            root.frightened = false
            root.frightenedFlash = false
        }
    }

    // What a slot renders as. Lives here rather than in the delegate so the root
    // can also tell whether any ghost is on screen at all.
    function kindFor(info) {
        if (info.focused)
            return "pacman"
        if (info.urgent)
            return "pellet"
        switch (root.ghostMode) {
        case "all":
            return "ghost"
        case "occupied":
            return info.occupied ? "ghost" : "dot"
        default:
            return info.behind ? "ghost" : "dot"
        }
    }

    readonly property int visibleGhostCount: {
        const s = root.wsSlots ?? []
        let n = 0
        for (let i = 0; i < s.length; i++)
            if (root.kindFor(s[i]) === "ghost")
                n++
        return n
    }

    // With no ghost on screen there is nothing to frighten, and letting the
    // effect burn down invisibly means the next ghost you walk back towards
    // shows up already blue and part-spent. End it instead.
    onVisibleGhostCountChanged: {
        if (root.visibleGhostCount === 0)
            Qt.callLater(root.clearFrightenedIfStillEmpty)
    }

    // Deferred on purpose. Switching workspace rebuilds the whole slot list, and
    // the ghost count can pass through zero part-way through that rebuild.
    // Acting on that transient tore the effect down a frame after arming it.
    function clearFrightenedIfStillEmpty() {
        if (root.visibleGhostCount === 0)
            root.clearFrightened()
    }

    function clearFrightened() {
        root.frightened = false
        root.frightenedFlash = false
        frightenedTimer.stop()
        frightenedFlashTimer.stop()
    }

    function startFrightened() {
        if (!root.frightenedEnabled)
            return
        root.frightened = true
        root.frightenedFlash = false
        frightenedFlashTimer.restart()
        frightenedTimer.restart()
    }

    onFrightenedEnabledChanged: {
        if (!root.frightenedEnabled)
            root.clearFrightened()
    }

    readonly property color ghostEyeColor: "#FFFFFF"
    readonly property color ghostPupilColor: root.arcadePalette ? "#2121DE" : Theme.primary

    function ghostColorFor(info) {
        const n = root.ghostPalette.length
        if (root.ghostColorMode === "distance") {
            const d = Math.max(1, info.distance)
            return root.ghostPalette[(d - 1) % n]
        }
        return root.ghostPalette[((info.num - 1) % n + n) % n]
    }

    // ---------------------------------------------------------- sprite clock --
    // The arcade animates on a frame counter, not on smooth tweens: Pac-Man
    // steps through three mouth frames, the ghosts' skirt alternates, and the
    // energizers blink hard on and off. One shared timer drives all of it, so
    // every sprite in the bar stays in step the way it does in the game - and it
    // costs four property writes a second instead of a full per-frame animation.
    // "arcade" - stepped on a frame counter, like the cabinet
    // "smooth"  - tweened continuously at the display's refresh rate
    readonly property string animationStyle: root.pluginData?.animationStyle ?? "arcade"
    readonly property bool smoothAnimation: root.animationStyle === "smooth"

    // Continuous 0..1 ramp that drives everything in smooth mode, so the two
    // styles share one set of sprites and only differ in how they are driven.
    property real smoothPhase: 0

    SequentialAnimation {
        running: root.animationsOn && root.smoothAnimation && root.visible && !(SessionService.preparingForSleep ?? false)
        loops: Animation.Infinite

        NumberAnimation {
            target: root
            property: "smoothPhase"
            to: 1
            duration: 260
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "smoothPhase"
            to: 0
            duration: 260
            easing.type: Easing.InOutSine
        }

        onRunningChanged: {
            if (!running)
                root.smoothPhase = 0
        }
    }

    property int spriteFrame: 0
    // Mouth aperture per frame: wide, half, closed, half.
    readonly property var mouthFrames: [38, 20, 0, 20]
    readonly property real mouthRestDeg: 30

    Timer {
        interval: 130
        repeat: true
        running: root.animationsOn && !root.smoothAnimation && root.visible && !(SessionService.preparingForSleep ?? false)
        onTriggered: root.spriteFrame = (root.spriteFrame + 1) % 4
        onRunningChanged: {
            if (!running)
                root.spriteFrame = 0
        }
    }

    // ------------------------------------------------------------ compositor --
    readonly property bool niriMode: CompositorService.isNiri
    readonly property string screenName: root.parentScreen?.name ?? ""
    // When true the widget mirrors whichever monitor currently has focus instead
    // of pinning itself to the monitor its bar lives on.
    readonly property bool followFocus: !root.perMonitor || root.screenName === "" || (SettingsData.workspaceFollowFocus ?? false)

    // Single revision counter every derived binding depends on. Compositor state
    // is also read live, so ordinary QML reactivity does the work; the counter is
    // what lets an explicit signal (or the watchdog below) force a recompute when
    // an event is missed instead of leaving the widget frozen until it is
    // reloaded by hand.
    property int revision: 0

    function bumpRevision() {
        root.revision = root.revision + 1
    }

    // 0 means "the compositor state is not readable right now". Snapping to 1 in
    // that case made a momentary blip - a refreshWorkspaces() from the watchdog,
    // for instance - look like a walk back to the first workspace, which turned
    // the ghosts blue every few seconds and kept re-arming the effect before it
    // could expire.
    readonly property int resolvedFocusId: {
        root.revision

        if (root.niriMode) {
            const wss = NiriService.allWorkspaces ?? []
            for (let i = 0; i < wss.length; i++) {
                const w = wss[i]
                if (!w)
                    continue
                const match = root.followFocus ? (w.is_focused === true) : (w.is_active === true && w.output === root.screenName)
                if (match)
                    return (w.idx ?? 0) + 1
            }
            return 0
        }

        if (!root.followFocus) {
            const mons = Hyprland.monitors?.values ?? []
            for (let i = 0; i < mons.length; i++) {
                if (mons[i]?.name !== root.screenName)
                    continue
                const monId = mons[i].activeWorkspace?.id
                if (monId !== undefined && monId > 0)
                    return monId
                break
            }
        }

        const id = Hyprland.focusedWorkspace?.id
        return (id !== undefined && id > 0) ? id : 0
    }

    property int lastKnownFocusId: 1

    onResolvedFocusIdChanged: {
        if (root.resolvedFocusId > 0)
            root.lastKnownFocusId = root.resolvedFocusId
    }

    readonly property int focusedWorkspaceId: root.resolvedFocusId > 0 ? root.resolvedFocusId : root.lastKnownFocusId

    // Normalised workspace records, so the slot maths below is compositor
    // agnostic: `num` is the number shown in the bar, `key` is what the
    // compositor needs to focus it.
    function _hyprlandWorkspaces() {
        const out = []
        const all = Hyprland.workspaces?.values ?? []
        const toplevels = Hyprland.toplevels?.values ?? []

        // Prefer live toplevel tracking; fall back to the last hyprctl snapshot
        // only when toplevel tracking has nothing at all (i.e. is not up yet).
        const useIpcCounts = toplevels.length === 0
        const counts = {}
        for (let i = 0; i < toplevels.length; i++) {
            const wid = toplevels[i]?.workspace?.id
            if (wid !== undefined && wid > 0)
                counts[wid] = (counts[wid] ?? 0) + 1
        }

        for (let i = 0; i < all.length; i++) {
            const ws = all[i]
            if (!ws)
                continue
            const id = ws.id
            // Hyprland gives named workspaces negative ids and prefixes special
            // ones (scratchpads); neither belongs in a numbered strip.
            if (id === undefined || id <= 0)
                continue
            const name = ws.name ?? ""
            if (name === "special" || name.indexOf("special:") === 0)
                continue
            if (!root.followFocus && root.screenName && ws.monitor?.name !== root.screenName)
                continue

            out.push({
                "num": id,
                "key": id,
                "name": name.length > 0 ? name : String(id),
                "windows": useIpcCounts ? (ws.lastIpcObject?.windows ?? 0) : (counts[id] ?? 0),
                "urgent": ws.urgent === true
            })
        }
        return out
    }

    function _niriWorkspaces() {
        const out = []
        const all = NiriService.allWorkspaces ?? []
        const windows = NiriService.windows ?? []

        const counts = {}
        for (let i = 0; i < windows.length; i++) {
            const wid = windows[i]?.workspace_id
            if (wid !== undefined)
                counts[wid] = (counts[wid] ?? 0) + 1
        }

        for (let i = 0; i < all.length; i++) {
            const w = all[i]
            if (!w)
                continue
            if (!root.followFocus && root.screenName && w.output !== root.screenName)
                continue
            const num = (w.idx ?? 0) + 1
            out.push({
                "num": num,
                "key": w.id,
                "name": (w.name && w.name.length > 0) ? w.name : String(num),
                "windows": counts[w.id] ?? 0,
                "urgent": w.is_urgent === true
            })
        }
        return out
    }

    function _liveWorkspaces() {
        return root.niriMode ? root._niriWorkspaces() : root._hyprlandWorkspaces()
    }

    // The full strip, recomputed from live compositor state. `minSlots` is a
    // floor, not a fixed size: the strip grows as higher workspaces are used and
    // shrinks again when they are destroyed, bounded by `maxSlots` so a stray
    // high workspace id can never blow the bar up into dozens of icons.
    readonly property var wsSlots: {
        root.revision
        root.minSlots
        root.maxSlots
        root.followFocus
        root.screenName
        root.niriMode

        const live = root._liveWorkspaces()
        const focused = root.focusedWorkspaceId

        const byNum = {}
        let lo = 0
        let hi = 0
        for (let i = 0; i < live.length; i++) {
            const w = live[i]
            byNum[w.num] = w
            if (lo === 0 || w.num < lo)
                lo = w.num
            if (w.num > hi)
                hi = w.num
        }
        if (lo === 0) {
            lo = 1
            hi = 1
        }
        if (focused >= 1) {
            if (focused > hi)
                hi = focused
            if (focused < lo)
                lo = focused
        }

        const minS = root.minSlots
        const maxS = Math.max(minS, root.maxSlots)

        // Anchor the strip at 1 for ordinary setups. Only follow a high block
        // (Hyprland per-monitor ranges such as 11..20) when the workspaces in
        // play genuinely start above the strip we would otherwise draw.
        let start = (lo <= minS || hi <= maxS) ? 1 : lo
        let end = Math.max(start + minS - 1, hi)

        if (end - start + 1 > maxS) {
            if (focused >= 1 && focused - start > maxS - 1)
                start = Math.max(1, focused - maxS + 1)
            end = start + maxS - 1
            if (focused > end) {
                end = focused
                start = Math.max(1, end - maxS + 1)
            }
        }

        const out = []
        for (let n = start; n <= end; n++) {
            const w = byNum[n]
            const isFocused = (n === focused)
            out.push({
                "num": n,
                // A slot with no live workspace can still be focused on Hyprland
                // (the dispatcher creates it); on niri there is nothing to focus.
                "key": w ? w.key : (root.niriMode ? null : n),
                "name": w ? w.name : String(n),
                "exists": !!w,
                "windows": w ? w.windows : 0,
                "occupied": !!w && w.windows > 0,
                "urgent": !!w && w.urgent && !isFocused,
                "focused": isFocused,
                "behind": n < focused,
                "distance": focused - n
            })
        }
        return out
    }

    readonly property int slotCount: root.wsSlots.length

    readonly property var fallbackSlot: ({
            "num": 1,
            "key": 1,
            "name": "1",
            "exists": false,
            "windows": 0,
            "occupied": false,
            "urgent": false,
            "focused": false,
            "behind": false,
            "distance": 0
        })

    function slotAt(i) {
        const s = root.wsSlots ?? []
        return (i >= 0 && i < s.length) ? s[i] : root.fallbackSlot
    }

    // Pac-Man turns to face the direction you just travelled in - except on the
    // first slot, where there is nothing further left to eat, so he turns back
    // around against the wall.
    property int previousFocusedId: -1
    property bool facingLeft: false

    onFocusedWorkspaceIdChanged: {
        const slots = root.wsSlots ?? []
        const firstNum = slots.length > 0 ? slots[0].num : 1
        const movedBack = root.previousFocusedId > 0 && root.focusedWorkspaceId < root.previousFocusedId
        if (root.focusedWorkspaceId <= firstNum)
            root.facingLeft = false
        else if (root.previousFocusedId > 0 && root.focusedWorkspaceId !== root.previousFocusedId)
            root.facingLeft = root.focusedWorkspaceId < root.previousFocusedId
        if (movedBack)
            root.startFrightened()
        root.previousFocusedId = root.focusedWorkspaceId
    }

    // ---------------------------------------------------------- interaction --
    function switchTo(slot) {
        if (!slot)
            return
        if (root.niriMode) {
            if (slot.key !== null && slot.key !== undefined)
                NiriService.switchToWorkspace(slot.key)
            return
        }
        // Goes through HyprlandService so it keeps working under Hyprland's Lua
        // config, where the plain `workspace` dispatcher is not the right call.
        HyprlandService.focusWorkspace(slot.key ?? slot.num)
    }

    // Where the last step sent us, until the compositor confirms it. Two
    // notches in quick succession both used to be measured from the same
    // not-yet-updated focus, and the rate limiter that hid that problem dropped
    // the second notch outright - after the wheel accumulator had already
    // debited it - so a quick spin moved one workspace and the rest vanished.
    // Stepping from where we are heading instead means every notch counts.
    property int pendingFocusNum: 0

    Timer {
        id: pendingFocusTimer
        // Only a safety net: if the compositor never confirms the move, stop
        // stepping from a workspace we never actually reached.
        interval: 600
        onTriggered: root.pendingFocusNum = 0
    }

    function stepWorkspace(delta) {
        const s = root.wsSlots
        if (s.length === 0)
            return

        let idx = -1
        if (root.pendingFocusNum > 0) {
            for (let i = 0; i < s.length; i++) {
                if (s[i].num === root.pendingFocusNum) {
                    idx = i
                    break
                }
            }
        }
        if (idx < 0) {
            for (let i = 0; i < s.length; i++) {
                if (s[i].focused) {
                    idx = i
                    break
                }
            }
        }
        if (idx < 0)
            idx = 0

        const next = idx + delta
        if (next < 0 || next >= s.length)
            return

        root.pendingFocusNum = s[next].num
        pendingFocusTimer.restart()
        root.switchTo(s[next])
    }

    // ------------------------------------------------------------ freshness --
    // Hyprland event names worth recomputing on. Anything not listed here (mouse
    // moves, active-window churn) cannot change what this widget draws.
    readonly property var watchedHyprEvents: ({
            "workspace": 1,
            "workspacev2": 1,
            "focusedmon": 1,
            "focusedmonv2": 1,
            "createworkspace": 1,
            "createworkspacev2": 1,
            "destroyworkspace": 1,
            "destroyworkspacev2": 1,
            "moveworkspace": 1,
            "moveworkspacev2": 1,
            "renameworkspace": 1,
            "activespecial": 1,
            "activespecialv2": 1,
            "openwindow": 1,
            "closewindow": 1,
            "movewindow": 1,
            "movewindowv2": 1,
            "urgent": 1,
            "monitoradded": 1,
            "monitoraddedv2": 1,
            "monitorremoved": 1,
            "monitorremovedv2": 1,
            "configreloaded": 1
        })

    Connections {
        target: root.niriMode ? null : Hyprland

        function onRawEvent(event) {
            if (root.watchedHyprEvents[event.name] !== undefined)
                root.bumpRevision()
        }

        function onFocusedWorkspaceChanged() {
            root.bumpRevision()
        }

        function onFocusedMonitorChanged() {
            root.bumpRevision()
        }
    }

    Connections {
        target: root.niriMode ? null : Hyprland.workspaces

        function onValuesChanged() {
            root.bumpRevision()
        }
    }

    Connections {
        target: root.niriMode ? null : Hyprland.monitors

        function onValuesChanged() {
            root.bumpRevision()
        }
    }

    Connections {
        target: root.niriMode ? null : Hyprland.toplevels

        function onValuesChanged() {
            root.bumpRevision()
        }
    }

    Connections {
        target: root.niriMode ? NiriService : null

        function onAllWorkspacesChanged() {
            root.bumpRevision()
        }

        function onWindowsChanged() {
            root.bumpRevision()
        }
    }

    function resync() {
        if (!root.niriMode) {
            Hyprland.refreshMonitors()
            Hyprland.refreshWorkspaces()
            Hyprland.refreshToplevels()
        }
        root.bumpRevision()
    }

    // Coming back from suspend the compositor socket may have missed events
    // while we were asleep, so ask for a full state refresh rather than trusting
    // whatever was last cached.
    Connections {
        target: SessionService

        function onSessionResumed() {
            Qt.callLater(root.resync)
        }
    }

    Connections {
        target: Quickshell

        function onScreensChanged() {
            Qt.callLater(root.resync)
        }
    }

    Component.onCompleted: Qt.callLater(root.resync)

    onVisibleChanged: {
        if (root.visible)
            Qt.callLater(root.resync)
    }

    // Cheap self-healing watchdog. It hashes the live compositor state and only
    // bumps the revision when that hash disagrees with what we last drew, so it
    // costs nothing while events are flowing and still repairs the widget within
    // a few seconds if one is ever dropped - no more reloading the plugin by hand.
    property string lastStateSignature: ""

    function stateSignature() {
        if (root.niriMode) {
            const wss = NiriService.allWorkspaces ?? []
            let s = "n:" + (NiriService.windows?.length ?? 0)
            for (let i = 0; i < wss.length; i++) {
                const w = wss[i]
                s += "|" + (w?.idx ?? -1) + "," + (w?.output ?? "") + "," + (w?.is_active === true ? 1 : 0) + "," + (w?.is_focused === true ? 1 : 0)
            }
            return s
        }

        let s = "h:" + (Hyprland.focusedWorkspace?.id ?? 0)
        const mons = Hyprland.monitors?.values ?? []
        for (let i = 0; i < mons.length; i++)
            s += "|m" + (mons[i]?.name ?? "") + "=" + (mons[i]?.activeWorkspace?.id ?? 0)

        const all = Hyprland.workspaces?.values ?? []
        for (let i = 0; i < all.length; i++) {
            const w = all[i]
            s += "|w" + (w?.id ?? 0) + "," + (w?.monitor?.name ?? "") + "," + (w?.urgent === true ? 1 : 0)
        }

        // Order-independent digest of which workspace each window sits on, so a
        // window moving between workspaces is caught as well as one opening.
        const toplevels = Hyprland.toplevels?.values ?? []
        let occ = toplevels.length
        for (let i = 0; i < toplevels.length; i++)
            occ = (occ + ((toplevels[i]?.workspace?.id ?? 0) + 7) * 131) % 2147483647
        return s + ":o" + occ
    }

    Timer {
        interval: 3000
        repeat: true
        triggeredOnStart: true
        running: root.visible && !(SessionService.preparingForSleep ?? false)
        onTriggered: {
            const sig = root.stateSignature()
            if (sig === root.lastStateSignature)
                return
            root.lastStateSignature = sig
            root.bumpRevision()
        }
    }

    // ------------------------------------------------------------- delegate --
    Component {
        id: cellDelegate

        Item {
            id: cell

            required property int index

            readonly property var info: root.slotAt(cell.index)
            readonly property bool isFocused: cell.info.focused
            readonly property bool isUrgent: cell.info.urgent
            readonly property bool isOccupied: cell.info.occupied
            readonly property bool hovered: cellMouse.containsMouse
            // Both bar pills are instantiated at once; only the one matching the
            // bar orientation is visible. Item.visible is inherited, so this also
            // keeps the hidden strip from animating in the background.
            readonly property bool animate: root.animationsOn && cell.visible

            readonly property string kind: root.kindFor(cell.info)

            // Each sprite carries its own colour. A single shared tint with a
            // ColorAnimation on it cross-faded through the ghost's colour when a
            // slot turned into Pac-Man, so clicking a ghost painted a blue or red
            // Pac-Man for a moment before it settled on yellow.
            function shade(c) {
                return cell.hovered ? Theme.hoverTint(c) : c
            }
            readonly property color pacmanTint: cell.shade(root.pacmanColor)
            readonly property color ghostTint: cell.shade(root.frightened ? root.frightenedBodyColor : root.ghostColorFor(cell.info))
            readonly property color pelletTint: cell.shade(cell.kind === "dot" && !cell.isOccupied ? root.dimPelletColor : root.pelletColor)

            width: root.cellSize
            height: root.cellSize

            readonly property real cx: cell.width / 2
            readonly property real cy: cell.height / 2

            // -- Pac-Man ---------------------------------------------------
            readonly property real mouthAngle: {
                if (!cell.animate)
                    return root.mouthRestDeg
                if (root.smoothAnimation)
                    return 2 + (root.mouthFrames[0] - 2) * root.smoothPhase
                return root.mouthFrames[root.spriteFrame]
            }
            // The bounce scales the radius that feeds the path, not the item, so
            // the wedge is re-tessellated at the new size instead of a finished
            // image being stretched.
            property real bounce: 1.0
            readonly property real pacRestRadius: root.cellSize / 2 - Math.max(1, root.cellSize * 0.08)
            // Clamped so a bounce can never reach the cell edge and get shaved off
            // at small icon sizes (at 21px the unclamped peak left 0.1px of room).
            readonly property real pacRadius: Math.min(root.cellSize / 2 - 0.5, cell.pacRestRadius * cell.bounce)

            SequentialAnimation {
                id: bounceAnim

                NumberAnimation {
                    target: cell
                    property: "bounce"
                    to: 1.18
                    duration: 90
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: cell
                    property: "bounce"
                    to: 1.0
                    duration: 170
                    easing.type: Easing.OutBack
                }
            }

            onIsFocusedChanged: {
                if (cell.isFocused && cell.animate)
                    bounceAnim.restart()
                else if (!cell.isFocused)
                    cell.bounce = 1.0
            }

            // Changing the slot count regenerates every delegate (Repeater rebuilds
            // on an integer model change), so the already-focused cell never sees an
            // isFocused transition. Bounce once on creation instead of staying flat.
            Component.onCompleted: {
                if (cell.isFocused)
                    Qt.callLater(() => {
                            if (cell.isFocused && cell.animate)
                                bounceAnim.restart()
                        })
            }

            // -- Ghost geometry --------------------------------------------
            readonly property real gMargin: Math.max(1, root.cellSize * 0.07)
            // A Shape rebuilds its geometry when the path changes; a fillColor
            // swap on its own is not geometry, so a ghost standing still has
            // nothing forcing a repaint when only its colour moves - which is
            // how one ghost could stay red while its neighbour turned blue.
            //
            // The nudge is driven by the tint changing rather than by a list of
            // state flags. An earlier version keyed it to `frightened` alone and
            // missed the case that actually gets hit: the pointer moving onto a
            // ghost that is already blue changes the tint (hover lightens it)
            // without changing any of those flags. A counter cannot collide the
            // way a value derived from the colour could, so every change lands
            // on a different radius - by at most seven hundredths of a pixel.
            property int tintEpoch: 0

            onGhostTintChanged: cell.tintEpoch = (cell.tintEpoch + 1) % 8

            readonly property real gR: root.cellSize / 2 - cell.gMargin + cell.tintEpoch * 0.01
            readonly property real gDomeY: cell.gMargin + cell.gR
            readonly property real gFoot: cell.gR * 0.32
            readonly property real gBaseY: root.cellSize - cell.gMargin - cell.gFoot
            readonly property real gBump: cell.gR / 2
            readonly property real eyeR: cell.gR * 0.35
            readonly property real eyeY: cell.gDomeY - cell.gR * 0.1
            readonly property real eyeDX: cell.gR * 0.4
            // Ghosts watch Pac-Man.
            readonly property bool ghostLooksLeft: cell.info.num > root.focusedWorkspaceId

            // The arcade ghosts do not bob; their skirt shuffles between two
            // frames. Alternating which set of feet hangs lower reproduces that.
            readonly property bool skirtMoves: cell.animate && root.ghostSkirtMoves
            readonly property int skirtPhase: cell.skirtMoves ? (root.spriteFrame < 2 ? 0 : 1) : 0

            // Drifting ghosts, for anyone who prefers them to the arcade shuffle.
            // Neighbouring slots move in opposite phase so the row is not in lockstep.
            readonly property real ghostBob: {
                if (!cell.animate || !root.ghostFloats)
                    return 0
                const t = root.smoothAnimation ? root.smoothPhase : (root.spriteFrame < 2 ? 0 : 1)
                const swing = (cell.index % 2 === 0) ? t : 1 - t
                return -Math.max(1, root.cellSize * 0.08) * swing
            }

            function footDepth(index) {
                if (cell.skirtMoves && root.smoothAnimation) {
                    const t = (index % 2) === 0 ? root.smoothPhase : 1 - root.smoothPhase
                    return cell.gFoot * (0.4 + 0.6 * t)
                }
                if (!cell.skirtMoves)
                    return cell.gFoot * 0.7
                return cell.gFoot * ((index % 2) === cell.skirtPhase ? 1 : 0.4)
            }

            // -- Visuals ---------------------------------------------------
            Rectangle {
                anchors.centerIn: parent
                width: root.cellSize + Math.round(root.cellSpacing * 0.6)
                height: width
                radius: width / 2
                color: Theme.surfaceTextHover
                antialiasing: true
                opacity: cell.hovered ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    enabled: root.animationsOn
                    NumberAnimation {
                        duration: Theme.shortDuration
                    }
                }
            }

            Shape {
                anchors.fill: parent
                visible: cell.kind === "pacman"
                preferredRendererType: Shape.CurveRenderer
                transformOrigin: Item.Center
                rotation: root.facingLeft ? 180 : 0

                Behavior on rotation {
                    enabled: root.animationsOn
                    RotationAnimation {
                        duration: Theme.shortDuration
                        direction: RotationAnimation.Shortest
                    }
                }

                ShapePath {
                    fillColor: cell.pacmanTint
                    strokeColor: "transparent"
                    startX: cell.cx
                    startY: cell.cy

                    PathAngleArc {
                        centerX: cell.cx
                        centerY: cell.cy
                        radiusX: cell.pacRadius
                        radiusY: cell.pacRadius
                        startAngle: cell.mouthAngle
                        sweepAngle: 360 - 2 * cell.mouthAngle
                        moveToStart: false
                    }
                    PathLine {
                        x: cell.cx
                        y: cell.cy
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: cell.kind === "ghost"

                transform: Translate {
                    y: cell.ghostBob

                    Behavior on y {
                        enabled: root.animationsOn && !root.smoothAnimation
                        NumberAnimation {
                            duration: 240
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: cell.ghostTint
                        strokeColor: "transparent"
                        startX: cell.cx - cell.gR
                        startY: cell.gDomeY

                        // Rounded dome across the top.
                        PathAngleArc {
                            centerX: cell.cx
                            centerY: cell.gDomeY
                            radiusX: cell.gR
                            radiusY: cell.gR
                            startAngle: 180
                            sweepAngle: 180
                            moveToStart: false
                        }
                        // Straight right flank down to the skirt.
                        PathLine {
                            x: cell.cx + cell.gR
                            y: cell.gBaseY
                        }
                        // Four scalloped feet, right to left.
                        PathQuad {
                            x: cell.cx + cell.gR - cell.gBump
                            y: cell.gBaseY
                            controlX: cell.cx + cell.gR - cell.gBump * 0.5
                            controlY: cell.gBaseY + cell.footDepth(0)
                        }
                        PathQuad {
                            x: cell.cx + cell.gR - cell.gBump * 2
                            y: cell.gBaseY
                            controlX: cell.cx + cell.gR - cell.gBump * 1.5
                            controlY: cell.gBaseY + cell.footDepth(1)
                        }
                        PathQuad {
                            x: cell.cx + cell.gR - cell.gBump * 3
                            y: cell.gBaseY
                            controlX: cell.cx + cell.gR - cell.gBump * 2.5
                            controlY: cell.gBaseY + cell.footDepth(2)
                        }
                        PathQuad {
                            x: cell.cx - cell.gR
                            y: cell.gBaseY
                            controlX: cell.cx + cell.gR - cell.gBump * 3.5
                            controlY: cell.gBaseY + cell.footDepth(3)
                        }
                        // Left flank back up to the dome.
                        PathLine {
                            x: cell.cx - cell.gR
                            y: cell.gDomeY
                        }
                    }
                }

                Repeater {
                    model: 2

                    Rectangle {
                        id: eye

                        required property int index

                        readonly property real side: eye.index === 0 ? -1 : 1

                        x: cell.cx + eye.side * cell.eyeDX - cell.eyeR
                        y: cell.eyeY - cell.eyeR
                        width: cell.eyeR * 2
                        height: cell.eyeR * 2
                        radius: width / 2
                        color: root.ghostEyeColor
                        antialiasing: true

                        Rectangle {
                            width: cell.eyeR
                            height: cell.eyeR
                            radius: width / 2
                            color: root.frightened ? root.frightenedPupilColor : root.ghostPupilColor
                            antialiasing: true
                            x: (parent.width - width) / 2 + (cell.ghostLooksLeft ? -cell.eyeR * 0.42 : cell.eyeR * 0.42)
                            y: (parent.height - height) / 2 + cell.eyeR * 0.2

                            Behavior on x {
                                enabled: root.animationsOn
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }
                    }
                }
            }

            // Pellet (an urgent workspace, drawn as a blinking energizer) and the
            // plain dot for an untouched slot share one circle.
            Rectangle {
                id: pellet

                anchors.centerIn: parent
                // The maze energizers blink hard on and off rather than fading.
                visible: (cell.kind === "dot") || (cell.kind === "pellet" && (!cell.animate || root.smoothAnimation || root.spriteFrame < 2))
                // Smooth mode pulses the energizer instead of cutting it in and out.
                opacity: (cell.kind === "pellet" && cell.animate && root.smoothAnimation) ? (0.3 + 0.7 * root.smoothPhase) : 1
                width: {
                    if (cell.kind === "pellet")
                        return root.pelletDiameter(root.urgentPelletFraction, 6)
                    return root.pelletDiameter(cell.isOccupied ? root.occupiedPelletFraction : root.pelletFraction, 4)
                }
                height: width
                radius: width / 2
                color: cell.pelletTint
                antialiasing: true

            }

            MouseArea {
                id: cellMouse

                anchors.fill: parent
                // Grow the hit target into half the gap on each side so the icons
                // are comfortable to click without the targets overlapping.
                anchors.margins: -Math.floor(root.cellSpacing / 2)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: root.switchTo(cell.info)
            }
        }
    }

    // One notch of a mouse wheel is 120 units; a touchpad sends many small deltas,
    // so they are accumulated to the same threshold instead of firing per event.
    component WorkspaceWheel: WheelHandler {
        id: wheel

        property real accumulated: 0

        enabled: root.scrollEnabled
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            if (delta === 0)
                return
            // Reversing direction mid-gesture should not fire off a leftover step.
            if ((delta > 0 && wheel.accumulated < 0) || (delta < 0 && wheel.accumulated > 0))
                wheel.accumulated = 0

            wheel.accumulated += delta
            const dir = root.scrollReversed ? -1 : 1
            while (wheel.accumulated >= 120) {
                wheel.accumulated -= 120
                root.stepWorkspace(-dir)
            }
            while (wheel.accumulated <= -120) {
                wheel.accumulated += 120
                root.stepWorkspace(dir)
            }
        }
    }

    // The model is a plain slot COUNT, never the slot array. The previous version
    // handed the Repeater a freshly built array on every change, so every delegate
    // was destroyed and rebuilt on each workspace switch - the churn that left
    // Pac-Man stranded on an old slot. With a count, a workspace switch changes
    // only the delegates' bindings and nothing is recreated.
    // (Changing the count itself does still regenerate the strip - that is how
    // Repeater behaves - but a regenerated Shape draws correctly on its first
    // frame, unlike the Canvas it replaced.)
    horizontalBarPill: Component {
        Row {
            spacing: root.cellSpacing

            WorkspaceWheel {}

            Repeater {
                model: root.slotCount
                delegate: cellDelegate
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: root.cellSpacing

            WorkspaceWheel {}

            Repeater {
                model: root.slotCount
                delegate: cellDelegate
            }
        }
    }
}
