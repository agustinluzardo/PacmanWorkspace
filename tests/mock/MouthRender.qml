// Renders Pac-Man still, with and without the mouth pellet, so the difference
// can be counted rather than assumed. A property being true says nothing about
// whether anything was drawn.
import QtQuick

Rectangle {
    id: h
    width: 300; height: 160; color: "#000000"

    PacmanWorkspacesUT { id: a }
    PacmanWorkspacesUT { id: b }

    Column {
        anchors.centerIn: parent
        spacing: 24
        Row { spacing: 14
            Text { text: "con puntito"; color: "#888"; font.pixelSize: 11; width: 80
                   horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
            Loader { id: la; sourceComponent: a.horizontalBarPill; anchors.verticalCenter: parent.verticalCenter } }
        Row { spacing: 14
            Text { text: "sin puntito"; color: "#888"; font.pixelSize: 11; width: 80
                   horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
            Loader { id: lb; sourceComponent: b.horizontalBarPill; anchors.verticalCenter: parent.verticalCenter } }
    }

    Component.onCompleted: {
        a.pluginData = ({ "animations": false, "mouthPellet": true,  "workspaceCount": 2, "autoIconSize": false, "iconSizeOverride": 48 });
        b.pluginData = ({ "animations": false, "mouthPellet": false, "workspaceCount": 2, "autoIconSize": false, "iconSizeOverride": 48 });
        console.log("con puntito / sin puntito, ambos quietos");
    }
}
