import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root

    pluginId: "pacmanWorkspaces"

    StyledText {
        width: parent.width
        text: "Pac-Man Workspaces"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Pac-Man marks the workspace you are on, ghosts mark the others, and untouched workspaces stay as pellets. An urgent workspace flashes as a power pellet. Click a slot to jump to it, or scroll over the widget."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StyledText {
        width: parent.width
        text: "Layout"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SliderSetting {
        settingKey: "workspaceCount"
        label: "Minimum slots"
        description: "How many workspace slots are always shown, even when they are empty."
        defaultValue: 5
        minimum: 1
        maximum: 20
    }

    SliderSetting {
        settingKey: "maxSlots"
        label: "Maximum slots"
        description: "The strip grows past the minimum as you use higher workspaces, but never beyond this. Set it equal to the minimum for a fixed number of slots."
        defaultValue: 10
        minimum: 1
        maximum: 30
    }

    ToggleSetting {
        id: autoIconSize
        settingKey: "autoIconSize"
        label: "Size icons from the bar"
        description: "Derives the icon size from the bar's thickness and icon scale - 21px on a standard 48px bar. Turn it off to pin an exact size."
        defaultValue: true
    }

    SliderSetting {
        settingKey: "iconSizeOverride"
        label: "Icon size"
        visible: !autoIconSize.value
        defaultValue: 21
        minimum: 10
        maximum: 48
        unit: "px"
    }

    ToggleSetting {
        id: autoSpacing
        settingKey: "autoSpacing"
        label: "Space icons automatically"
        description: "Derives the gap between icons from their size. Turn it off to set the gap yourself."
        defaultValue: true
    }

    SliderSetting {
        settingKey: "spacingOverride"
        label: "Spacing"
        visible: !autoSpacing.value
        defaultValue: 6
        minimum: 0
        maximum: 24
        unit: "px"
    }

    SliderSetting {
        settingKey: "pelletSize"
        label: "Pellet size"
        description: "How big an untouched workspace's pellet is, as a percentage of the icon size. A workspace with windows open is 1.5x this, and an urgent one 2x."
        defaultValue: 30
        minimum: 10
        maximum: 60
        unit: "%"
    }

    ToggleSetting {
        settingKey: "perMonitor"
        label: "Per-monitor workspaces"
        description: "Each bar shows the workspaces of the monitor it lives on. Turn this off to have every bar mirror whichever monitor currently has focus."
        defaultValue: true
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StyledText {
        width: parent.width
        text: "Colours & ghosts"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SelectionSetting {
        settingKey: "palette"
        label: "Palette"
        description: "Arcade uses the 1980 cabinet's own colours. Adaptive uses your DankMaterialShell theme instead, for bars where pure arcade primaries are too loud."
        defaultValue: "arcade"
        options: [
            {
                "label": "Arcade (authentic)",
                "value": "arcade"
            },
            {
                "label": "Adaptive (follows your theme)",
                "value": "theme"
            }
        ]
    }

    SelectionSetting {
        settingKey: "ghostMode"
        label: "Ghosts appear on"
        description: "Where the ghosts sit relative to Pac-Man."
        defaultValue: "behind"
        options: [
            {
                "label": "Workspaces behind you (chasing)",
                "value": "behind"
            },
            {
                "label": "Workspaces with windows open",
                "value": "occupied"
            },
            {
                "label": "Every other workspace",
                "value": "all"
            }
        ]
    }

    SelectionSetting {
        settingKey: "ghostColorMode"
        label: "Ghost colours"
        description: "Per workspace keeps each workspace's ghost the same colour every time. By distance recolours them as you move, so the ghost right behind you is always the same one."
        defaultValue: "workspace"
        options: [
            {
                "label": "One colour per workspace",
                "value": "workspace"
            },
            {
                "label": "By distance behind you",
                "value": "distance"
            }
        ]
    }

    SelectionSetting {
        settingKey: "ghostMotion"
        label: "Ghost motion"
        description: "Arcade shuffles the sprite's skirt between two frames, the way the cabinet animates them. Float drifts the whole ghost up and down instead."
        defaultValue: "arcade"
        options: [
            {
                "label": "Arcade (shuffling skirt)",
                "value": "arcade"
            },
            {
                "label": "Float (drifting)",
                "value": "float"
            },
            {
                "label": "Both (drifting + shuffling)",
                "value": "both"
            }
        ]
    }

    ToggleSetting {
        settingKey: "frightenedGhosts"
        label: "Frightened ghosts"
        description: "Going back to a lower workspace counts as eating an energizer: the ghosts turn blue for a few seconds, then flash white before they recover, like they do in the game."
        defaultValue: false
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StyledText {
        width: parent.width
        text: "Behaviour"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "animations"
        label: "Animations"
        description: "Chomping, the bounce when you land on a workspace, drifting ghosts and the flashing power pellet. Turning DMS' global animations off disables these too."
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "animationStyle"
        label: "Animation style"
        description: "Arcade steps through sprite frames on a shared clock, the way the cabinet does. Smooth tweens the same sprites continuously at your display's refresh rate."
        defaultValue: "arcade"
        options: [
            {
                "label": "Arcade (frame-stepped)",
                "value": "arcade"
            },
            {
                "label": "Smooth (60fps)",
                "value": "smooth"
            }
        ]
    }

    ToggleSetting {
        settingKey: "scrollToSwitch"
        label: "Scroll to switch"
        description: "Scrolling over the widget moves between workspaces."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "scrollReversed"
        label: "Reverse scroll direction"
        description: "Scroll up moves to a higher workspace instead of a lower one."
        defaultValue: false
    }
}
