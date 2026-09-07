// The custom colour must not be reachable, or stale, while it does nothing.
//
// What was reported: with the mode back on Automatic the settings page still
// showed the old custom colour in its swatch. The widget drew the right thing,
// so only the page was lying - which is worse than a wrong colour, because it
// tells you the setting is in a state it is not.
import QtQuick

Item {
    id: harness
    width: 400; height: 600

    property int checks: 0
    property int failures: 0
    function expect(label, actual, wanted) {
        checks++;
        const ok = String(actual).toLowerCase() === String(wanted).toLowerCase();
        if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + label + " = " + actual + (ok ? "" : " (expected " + wanted + ")"));
    }

    PacmanWorkspacesSettingsUT { id: page; anchors.fill: parent }

    function find(key) {
        for (let i = 0; i < page.content.length; i++)
            if (page.content[i] && page.content[i].settingKey === key)
                return page.content[i];
        return null;
    }

    Component.onCompleted: {
        console.log("=== custom background colour ===");

        const mode = harness.find("slotBackgroundColorMode");
        const colour = harness.find("slotBackgroundColor");

        expect("the mode control exists", mode !== null, true);
        expect("the colour control exists", colour !== null, true);
        if (!mode || !colour) {
            // Loudly, and as a failure. An early return that only prints a
            // summary reads as a short suite rather than a broken one - and
            // that is exactly how a settings page that failed to parse slipped
            // past this test while it was being written.
            harness.failures++;
            console.log("FAIL the settings page did not build its controls - nothing below ran");
            console.log("=== " + checks + " checks, " + harness.failures + " FAILURES ===");
            return;
        }

        expect("it starts on automatic", mode.value, "auto");
        expect("and the colour is hidden there", colour.visible, false);
        expect("sitting at the cabinet blue", colour.value, "#2121DE");

        mode.value = "custom";
        expect("custom reveals the colour", colour.visible, true);

        colour.value = "#ff1900";
        expect("and it can be changed", colour.value, "#ff1900");

        // The bug: this is where the swatch used to keep the red.
        mode.value = "auto";
        expect("leaving custom hides it again", colour.visible, false);
        expect("AND puts the colour back", colour.value, "#2121DE");

        // Round trip: going back to custom must not resurrect the old pick.
        mode.value = "custom";
        expect("returning to custom starts from the default", colour.value, "#2121DE");

        console.log("=== " + checks + " checks, " + (failures === 0 ? "ALL PASS" : failures + " FAILURES") + " ===");
    }
}
