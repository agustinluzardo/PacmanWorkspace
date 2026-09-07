import QtQuick

// DMS' ColorSetting, as the settings page uses it. Only the shape matters here:
// the page has to construct and the key has to be reachable.
Item {
    property string settingKey: ""
    property string label: ""
    property string description: ""
    property string defaultValue: "#000000"
    property string value: defaultValue
    width: parent ? parent.width : 0
    height: 48
}
