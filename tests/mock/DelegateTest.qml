pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: root
    width: 300
    height: 60
    color: "#101216"

    property int revision: 0
    property int created: 0
    property int destroyed: 0

    property int liveMax: 5

    // Mirrors the real wsSlots binding: depends on revision, rebuilt as a fresh
    // array each time, but exposed to the Repeater only as a COUNT.
    readonly property var wsSlots: {
        root.revision;
        const out = [];
        for (let n = 1; n <= root.liveMax; n++)
            out.push({
                    "num": n,
                    "focused": n === (root.revision % root.liveMax) + 1
                });
        return out;
    }
    readonly property int slotCount: root.wsSlots.length

    function slotAt(i) {
        const s = root.wsSlots;
        return (i >= 0 && i < s.length) ? s[i] : {
            "num": 0,
            "focused": false
        };
    }

    Component {
        id: cellDelegate

        Rectangle {
            id: cell
            required property int index

            readonly property var info: root.slotAt(cell.index)

            width: 20
            height: 20
            radius: 10
            color: cell.info.focused ? "#FFD400" : "#444a55"

            Component.onCompleted: root.created++
            Component.onDestruction: root.destroyed++
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 6
        Repeater {
            model: root.slotCount
            delegate: cellDelegate
        }
    }

    property int failures: 0
    function expect(label, actual, wanted) {
        const ok = actual === wanted;
        if (!ok)
            root.failures++;
        console.log((ok ? "PASS " : "FAIL ") + label + " = " + actual + (ok ? "" : " (expected " + wanted + ")"));
    }

    Component.onCompleted: {
        console.log("=== delegate lifecycle ===");
        expect("delegates created initially", root.created, 5);
        const createdAfterInit = root.created;

        // 20 workspace switches. This is THE regression guard: the slot data is
        // rebuilt as a fresh array every time, but because the Repeater only
        // ever sees a count, not one delegate may be torn down.
        for (let i = 0; i < 20; i++)
            root.revision++;

        expect("no delegates created across 20 switches", root.created, createdAfterInit);
        expect("no delegates destroyed across 20 switches", root.destroyed, 0);

        // Changing the SLOT COUNT is different: Repeater regenerates the whole
        // strip on an integer-model change rather than appending to it. That is
        // fine now and only now - Shapes draw from their bindings on the first
        // frame after creation, so a regenerated delegate is correct
        // immediately. Under the old Canvas the same regeneration was the bug:
        // a fresh Canvas that never serviced its queued requestPaint() stayed
        // blank or kept stale pixels. This asserts the real contract so the
        // difference is not mistaken for a regression later.
        root.liveMax = 8;
        expect("count change regenerates the strip (created)", root.created, 5 + 8);
        expect("count change regenerates the strip (destroyed)", root.destroyed, 5);

        root.liveMax = 4;
        expect("shrinking regenerates too (created)", root.created, 5 + 8 + 4);
        expect("shrinking regenerates too (destroyed)", root.destroyed, 5 + 8);

        // Focus must actually track: revision 2 -> focused num 3.
        root.revision = 2;
        root.liveMax = 5;
        let focusedNum = -1;
        for (let i = 0; i < root.wsSlots.length; i++)
            if (root.wsSlots[i].focused)
                focusedNum = root.wsSlots[i].num;
        expect("focused slot tracks state", focusedNum, 3);

        console.log("=== " + (root.failures === 0 ? "ALL PASS" : root.failures + " FAILURES") + " ===");
    }
}
