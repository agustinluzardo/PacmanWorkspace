import QtQuick
Item {
    id: root
    required property string pluginId
    property var pluginService: null
    default property list<QtObject> content
    signal settingChanged()
    property var variants: []
    implicitHeight: col.implicitHeight
    width: 400
    onContentChanged: {
        for (let i = 0; i < content.length; i++) {
            const item = content[i]
            if (item instanceof Item) item.parent = col
        }
    }
    function saveValue(key, value) {}
    function loadValue(key, defaultValue) { return defaultValue }
    Column { id: col; width: parent.width; spacing: 8 }
}
