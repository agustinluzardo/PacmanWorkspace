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
        const n = s.content.length
        console.log("settings children:", n)

        // Constructing without errors does not say the controls exist: a
        // setting that fails quietly leaves the whole page built and one
        // control short. Counting catches that.
        //
        // The count is NOT hardcoded here - it was, and every new setting then
        // broke this test for the wrong reason. The page reports what it built
        // and run.sh compares that against the source, which is the only place
        // that can say what SHOULD have been built.
        const keys = []
        for (let i = 0; i < n; i++)
            if (s.content[i] && s.content[i].settingKey !== undefined && s.content[i].settingKey !== "")
                keys.push(s.content[i].settingKey)

        console.log("SETTING_KEYS " + keys.join(","))
        console.log((keys.length > 0 ? "PASS " : "FAIL ") + "the page built controls = " + keys.length)

        const unique = keys.filter(function (k, i) { return keys.indexOf(k) === i })
        console.log((unique.length === keys.length ? "PASS " : "FAIL ")
            + "every setting key is unique = " + unique.length + "/" + keys.length)
        console.log("=== settings component constructed cleanly ===")
    }
}
