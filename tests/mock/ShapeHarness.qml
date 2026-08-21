import QtQuick
import QtQuick.Shapes

Rectangle {
    id: win
    width: 900
    height: 560
    color: "#12141a"

    // Mirrors PacmanWorkspaces.qml geometry verbatim.
    component PacCell: Item {
        id: cell
        property int cellSize: 32
        property color tint: "#FFD400"
        property real mouthAngle: 34
        property real bounce: 1.0
        property bool facingLeft: false

        width: cellSize
        height: cellSize
        readonly property real cx: width / 2
        readonly property real cy: height / 2
        readonly property real pacRestRadius: cellSize / 2 - Math.max(1, cellSize * 0.08)
        readonly property real pacRadius: Math.min(cellSize / 2 - 0.5, pacRestRadius * bounce)

        Shape {
            anchors.fill: parent
            transformOrigin: Item.Center
            rotation: cell.facingLeft ? 180 : 0
            ShapePath {
                fillColor: cell.tint
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
    }

    component GhostCell: Item {
        id: cell
        property int cellSize: 32
        property color tint: "#FF4B4B"
        property bool ghostLooksLeft: false
        property real ghostBob: 0

        width: cellSize
        height: cellSize
        readonly property real cx: width / 2
        readonly property real gMargin: Math.max(1, cellSize * 0.07)
        readonly property real gR: cellSize / 2 - gMargin
        readonly property real gDomeY: gMargin + gR
        readonly property real gFoot: gR * 0.32
        readonly property real gBaseY: cellSize - gMargin - gFoot
        readonly property real gBump: gR / 2
        readonly property real eyeR: gR * 0.35
        readonly property real eyeY: gDomeY - gR * 0.1
        readonly property real eyeDX: gR * 0.4

        Item {
            anchors.fill: parent
            transform: Translate {
                y: cell.ghostBob
            }

            Shape {
                anchors.fill: parent
                ShapePath {
                    fillColor: cell.tint
                    strokeColor: "transparent"
                    startX: cell.cx - cell.gR
                    startY: cell.gDomeY
                    PathAngleArc {
                        centerX: cell.cx
                        centerY: cell.gDomeY
                        radiusX: cell.gR
                        radiusY: cell.gR
                        startAngle: 180
                        sweepAngle: 180
                        moveToStart: false
                    }
                    PathLine {
                        x: cell.cx + cell.gR
                        y: cell.gBaseY
                    }
                    PathQuad {
                        x: cell.cx + cell.gR - cell.gBump
                        y: cell.gBaseY
                        controlX: cell.cx + cell.gR - cell.gBump * 0.5
                        controlY: cell.gBaseY + cell.gFoot
                    }
                    PathQuad {
                        x: cell.cx + cell.gR - cell.gBump * 2
                        y: cell.gBaseY
                        controlX: cell.cx + cell.gR - cell.gBump * 1.5
                        controlY: cell.gBaseY + cell.gFoot
                    }
                    PathQuad {
                        x: cell.cx + cell.gR - cell.gBump * 3
                        y: cell.gBaseY
                        controlX: cell.cx + cell.gR - cell.gBump * 2.5
                        controlY: cell.gBaseY + cell.gFoot
                    }
                    PathQuad {
                        x: cell.cx - cell.gR
                        y: cell.gBaseY
                        controlX: cell.cx + cell.gR - cell.gBump * 3.5
                        controlY: cell.gBaseY + cell.gFoot
                    }
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
                    color: "#FFFFFF"
                    antialiasing: true
                    Rectangle {
                        width: cell.eyeR
                        height: cell.eyeR
                        radius: width / 2
                        color: "#1A2FB0"
                        antialiasing: true
                        x: (parent.width - width) / 2 + (cell.ghostLooksLeft ? -cell.eyeR * 0.42 : cell.eyeR * 0.42)
                        y: (parent.height - height) / 2 + cell.eyeR * 0.2
                    }
                }
            }
        }
    }

    component DotCell: Item {
        id: cell
        property int cellSize: 32
        property color tint: "#9aa0aa"
        property bool occupied: false
        property bool pellet: false
        width: cellSize
        height: cellSize
        Rectangle {
            anchors.centerIn: parent
            width: cell.pellet ? Math.max(6, Math.round(cell.cellSize * 0.646)) : Math.max(4, Math.round(cell.cellSize * (cell.occupied ? 0.513 : 0.38)))
            height: width
            radius: width / 2
            color: cell.tint
            antialiasing: true
        }
    }

    readonly property var ghostPalette: ["#FF4B4B", "#FFA8D8", "#56E0F0", "#FFB03A"]

    Column {
        anchors.centerIn: parent
        spacing: 26

        Repeater {
            model: [21, 32, 64]

            Row {
                id: sizeRow
                required property int modelData
                spacing: Math.max(3, Math.round(modelData * 0.3))

                Rectangle {
                    width: 60
                    height: sizeRow.modelData
                    color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: sizeRow.modelData + "px"
                        color: "#8891a0"
                        font.pixelSize: 12
                    }
                }
                PacCell {
                    cellSize: sizeRow.modelData
                    mouthAngle: 34
                }
                PacCell {
                    cellSize: sizeRow.modelData
                    mouthAngle: 2
                }
                PacCell {
                    cellSize: sizeRow.modelData
                    mouthAngle: 34
                    bounce: 1.18
                }
                PacCell {
                    cellSize: sizeRow.modelData
                    mouthAngle: 34
                    facingLeft: true
                }
                GhostCell {
                    cellSize: sizeRow.modelData
                    tint: win.ghostPalette[0]
                }
                GhostCell {
                    cellSize: sizeRow.modelData
                    tint: win.ghostPalette[1]
                    ghostLooksLeft: true
                }
                GhostCell {
                    cellSize: sizeRow.modelData
                    tint: win.ghostPalette[2]
                    ghostBob: -Math.max(1, sizeRow.modelData * 0.07)
                }
                GhostCell {
                    cellSize: sizeRow.modelData
                    tint: win.ghostPalette[3]
                }
                DotCell {
                    cellSize: sizeRow.modelData
                }
                DotCell {
                    cellSize: sizeRow.modelData
                    occupied: true
                }
                DotCell {
                    cellSize: sizeRow.modelData
                    pellet: true
                    tint: "#FFE0A3"
                }
            }
        }

        // A realistic strip: focused on 3, ghosts behind, dots ahead.
        Rectangle {
            width: 300
            height: 40
            radius: 10
            color: "#1e222b"

            Row {
                anchors.centerIn: parent
                spacing: 6
                GhostCell {
                    cellSize: 21
                    tint: win.ghostPalette[0]
                }
                GhostCell {
                    cellSize: 21
                    tint: win.ghostPalette[1]
                }
                PacCell {
                    cellSize: 21
                }
                DotCell {
                    cellSize: 21
                    occupied: true
                    tint: "#e6e8ec"
                }
                DotCell {
                    cellSize: 21
                    tint: "#6b727e"
                }
            }
        }
    }
}
