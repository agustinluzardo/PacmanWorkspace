import QtQuick
Rectangle {
    width: 420
    height: 700
    color: "#12141a"
    PacmanWorkspacesSettingsUT {
        id: s
        width: 400
        anchors.centerIn: parent
    }
    Component.onCompleted: {
        console.log("settings children:", s.content.length)
        console.log("=== settings component constructed cleanly ===")
    }
}
