pragma Singleton
import QtQuick
QtObject {
    property var lastFocused: null
    // Every target, in order: a scroll that silently drops a notch is only
    // visible if you can see the whole sequence, not just where it ended up.
    // Recording only the last one is how that bug hid.
    property var focusCalls: []

    function focusWorkspace(w) {
        lastFocused = w;
        focusCalls = focusCalls.concat([w]);
        console.log("MOCK focusWorkspace", w);
    }
}
