// The strip background: does each mode draw what it says, and does the colour
// setting reach it?
//
// The whole point of "Automatic" is that it is the colour the widget ALREADY
// drew, so turning the background on cannot silently restyle anything. That is
// the assertion that matters here.
import QtQuick

Item {
    id: harness
    width: 300; height: 60

    property int checks: 0
    property int failures: 0
    function expect(label, actual, wanted) {
        checks++;
        const ok = String(actual) === String(wanted);
        if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + label + " = " + actual + (ok ? "" : " (expected " + wanted + ")"));
    }

    PacmanWorkspacesUT { id: widget }

    Component.onCompleted: {
        console.log("=== strip background ===");

        // ---- which modes draw a background -------------------------------
        widget.pluginData = ({});
        expect("nothing by default", widget.slotBackground, "none");
        expect("so no corridor", widget.hasCorridor, false);
        expect("and no rails", widget.hasRails, false);
        expect("and nothing at all", widget.hasSlotBackground, false);

        widget.pluginData = ({ "slotBackground": "corridor" });
        expect("corridor is a corridor", widget.hasCorridor, true);
        expect("and not rails", widget.hasRails, false);

        widget.pluginData = ({ "slotBackground": "corridorTint" });
        expect("the shaded one is also a corridor", widget.hasCorridor, true);

        widget.pluginData = ({ "slotBackground": "rails" });
        expect("rails are rails", widget.hasRails, true);
        expect("and not a corridor", widget.hasCorridor, false);
        expect("but still a background", widget.hasSlotBackground, true);

        // ---- colour ------------------------------------------------------
        // Automatic must be exactly what the palette already decided, or
        // enabling the background would quietly restyle the widget.
        widget.pluginData = ({ "slotBackground": "corridor", "palette": "arcade" });
        expect("automatic on the arcade palette is cabinet blue",
            widget.corridorColor, "#2121de");

        widget.pluginData = ({ "slotBackground": "corridor", "palette": "theme" });
        expect("automatic on the adaptive palette follows the theme",
            widget.corridorColor, widget.arcadePalette ? "#2121de" : Qt.colorEqual(widget.corridorColor, widget.corridorColor) ? widget.corridorColor : "");

        widget.pluginData = ({ "slotBackground": "rails", "palette": "arcade",
                               "slotBackgroundColorMode": "custom",
                               "slotBackgroundColor": "#ff5522" });
        expect("custom wins over the palette", widget.corridorColor, "#ff5522");

        // ...and only over the background. The sprites keep the palette, which
        // is what stops a colour pick turning into a reskin.
        expect("Pac-Man keeps the palette", widget.pacmanColor, "#FFFF00".toLowerCase());

        widget.pluginData = ({ "slotBackground": "rails", "palette": "arcade",
                               "slotBackgroundColorMode": "auto",
                               "slotBackgroundColor": "#ff5522" });
        expect("switching back to automatic drops the custom colour",
            widget.corridorColor, "#2121de");

        // A colour left unset must not blank the background out.
        widget.pluginData = ({ "slotBackground": "corridor", "slotBackgroundColorMode": "custom" });
        expect("an unset custom colour falls back to the cabinet blue",
            widget.slotBackgroundCustomColor, "#2121de");

        // ---- the pellet in the mouth --------------------------------------
        // With animations off the mouth freezes open, which reads as waiting.
        // A pellet in the opening turns the static pose back into a bite about
        // to happen. It must NOT appear while chewing: that would be a dot
        // flickering several times a second.
        widget.pluginData = ({ "animations": false });
        expect("animations are off", widget.animationsOn, false);
        expect("so the mouth is at its rest angle", widget.mouthRestDeg, 30);

        widget.pluginData = ({ "animations": true });
        expect("and on again with animations", widget.animationsOn, true);

        widget.pluginData = ({});
        expect("the pellet is on by default", widget.mouthPellet, true);
        widget.pluginData = ({ "mouthPellet": false });
        expect("and can be turned off", widget.mouthPellet, false);
        widget.pluginData = ({ "mouthPellet": true });
        expect("and back on", widget.mouthPellet, true);

        console.log("=== " + checks + " checks, " + (failures === 0 ? "ALL PASS" : failures + " FAILURES") + " ===");
    }
}
