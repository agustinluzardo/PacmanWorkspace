import QtQuick

Rectangle {
    id: root
    width: 200
    height: 60
    color: "#000000"

    property int minSlots: 5
    property int maxSlots: 10

    // ---- verbatim copy of the wsSlots range algorithm from PacmanWorkspaces.qml
    function computeRange(live, focused) {
        const byNum = {};
        let lo = 0;
        let hi = 0;
        for (let i = 0; i < live.length; i++) {
            const w = live[i];
            byNum[w.num] = w;
            if (lo === 0 || w.num < lo)
                lo = w.num;
            if (w.num > hi)
                hi = w.num;
        }
        if (lo === 0) {
            lo = 1;
            hi = 1;
        }
        if (focused >= 1) {
            if (focused > hi)
                hi = focused;
            if (focused < lo)
                lo = focused;
        }

        const minS = root.minSlots;
        const maxS = Math.max(minS, root.maxSlots);

        let start = (lo <= minS || hi <= maxS) ? 1 : lo;
        let end = Math.max(start + minS - 1, hi);

        if (end - start + 1 > maxS) {
            if (focused >= 1 && focused - start > maxS - 1)
                start = Math.max(1, focused - maxS + 1);
            end = start + maxS - 1;
            if (focused > end) {
                end = focused;
                start = Math.max(1, end - maxS + 1);
            }
        }
        return [start, end];
    }

    function mk(nums) {
        return nums.map(n => ({
                    "num": n
                }));
    }

    property int failures: 0

    function check(label, live, focused, minS, maxS, wantStart, wantEnd) {
        root.minSlots = minS;
        root.maxSlots = maxS;
        const r = root.computeRange(root.mk(live), focused);
        const okRange = (r[0] === wantStart && r[1] === wantEnd);
        const focusVisible = focused < 1 || (focused >= r[0] && focused <= r[1]);
        const withinCap = (r[1] - r[0] + 1) <= Math.max(minS, maxS);
        const atLeastMin = (r[1] - r[0] + 1) >= minS;
        const ok = okRange && focusVisible && withinCap && atLeastMin;
        if (!ok)
            root.failures++;
        console.log((ok ? "PASS " : "FAIL ") + label + "  live=[" + live + "] focused=" + focused + " min=" + minS + " max=" + maxS + " -> [" + r[0] + ".." + r[1] + "]" + (okRange ? "" : " EXPECTED [" + wantStart + ".." + wantEnd + "]") + (focusVisible ? "" : " FOCUS-NOT-VISIBLE") + (withinCap ? "" : " OVER-CAP") + (atLeastMin ? "" : " UNDER-MIN"));
    }

    Component.onCompleted: {
        console.log("=== slot range scenarios ===");
        check("fresh session", [1], 1, 5, 10, 1, 5);
        check("moved to ws2", [1, 2], 2, 5, 10, 1, 5);
        // The reported bug: ws1 destroyed when leaving it empty, user now on 3.
        check("BUG: on ws3, ws1 gone", [2, 3], 3, 5, 10, 1, 5);
        check("BUG: on ws3, only ws3 alive", [3], 3, 5, 10, 1, 5);
        check("BUG: on ws5", [5], 5, 5, 10, 1, 5);
        check("BUG: on ws7 grows", [7], 7, 5, 10, 1, 7);
        check("on ws8 grows", [1, 2, 8], 8, 5, 10, 1, 8);
        check("no workspaces yet", [], 1, 5, 10, 1, 5);
        check("fixed 3 slots", [1, 2, 3], 3, 3, 3, 1, 3);
        check("hypr per-monitor block 11-15", [11, 12, 13, 14, 15], 12, 5, 10, 11, 15);
        check("stray high id 100 stays capped", [1, 2, 100], 2, 5, 10, 1, 10);
        check("lone high workspace", [12], 12, 5, 10, 12, 16);
        check("cap slides to keep focus", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 9, 5, 6, 4, 9);
        check("cap keeps low focus anchored", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 2, 5, 6, 1, 6);
        check("min 1 slot", [1], 1, 1, 1, 1, 1);
        check("focus beyond everything", [1], 25, 5, 10, 16, 25);

        console.log("=== " + (root.failures === 0 ? "ALL PASS" : root.failures + " FAILURES") + " ===");
    }
}
